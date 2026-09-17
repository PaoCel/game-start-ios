import Foundation
import Combine
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class AdminViewModel: ObservableObject {

    // MARK: – Game config
    @Published var gameName = ""
    @Published var activeGameId = ""
    @Published var gameState = "N/A"
    @Published var matchDurationSec = GameplayConfigSnapshot.default.matchDurationSec
    @Published var selectedScanMode: ScanMode = GameplayConfigSnapshot.default.scanMode
    @Published var handshakeWindowSec = GameplayConfigSnapshot.default.handshakeWindowSec
    @Published var pairCooldownSec = GameplayConfigSnapshot.default.pairCooldownSec
    @Published var playerCooldownSec = GameplayConfigSnapshot.default.playerCooldownSec
    @Published var inactivePenaltyBlockDurationSec = GameplayConfigSnapshot.default.inactivePenaltyBlockDurationSec
    @Published var teamSyncWindowSec = GameplayConfigSnapshot.default.teamSyncWindowSec
    @Published var baseContactWindowSec = GameplayConfigSnapshot.default.baseContactWindowSec
    @Published var baseDefenseMultiplier = GameplayConfigSnapshot.default.baseDefenseMultiplier
    @Published var baseDefenseDurationSec = GameplayConfigSnapshot.default.baseDefenseDurationSec
    @Published var baseDefenseCooldownSec = GameplayConfigSnapshot.default.baseDefenseCooldownSec
    @Published var duelTransferPoints = GameplayConfigSnapshot.default.duelTransferPoints
    @Published var baseCapturePoints = GameplayConfigSnapshot.default.baseCapturePoints
    @Published var baseDefensePoints = GameplayConfigSnapshot.default.baseDefensePoints
    @Published var startingPoints = GameplayConfigSnapshot.default.startingPoints
    @Published var countdownSec = GameplayConfigSnapshot.default.countdownSec
    @Published var timezone = GameplayConfigSnapshot.default.timezone

    // MARK: – Base tokens
    @Published var teamABaseToken = ""
    @Published var teamBBaseToken = ""
    @Published var teamABaseQrToken = ""
    @Published var teamBBaseQrToken = ""
    @Published var itemMode: ItemMode = .none
    @Published var playerJoinCode = ""
    @Published var operatorInviteCode = ""

    // MARK: – Participants (realtime refreshed)
    @Published var participants: [AdminGameStatus.Participant] = []

    // MARK: – Game items
    @Published var gameItems: [AdminGameStatus.GameItem] = []

    // MARK: – UI state
    @Published var isBusy = false
    @Published var errorMessage: String = ""
    @Published var logLines: [String] = []
    @Published var backendEventExport: AdminGameEventExport? = nil
    @Published var isLoadingBackendEventExport = false

    // MARK: – NFC / scanning
    @Published var isScanning = false
    @Published var scanResult: TagLookupResult? = nil
    @Published var pendingNFCTeamId: String? = nil        // team waiting for base scan
    @Published var pendingItemToken: String? = nil         // token scanned for item add
    @Published var pendingItemTokenCandidates: [String] = []
    @Published var pendingItemConflict: AdminGameStatus.GameItem? = nil // existing item when conflict
    @Published var newItemPoints: Int = 10
    @Published var selectedItemCollectorTeamId: String = "TEAM_A"
    @Published var showItemPointsPrompt = false
    @Published var tokenIdentityConflict: TokenIdentityConflict? = nil
    @Published var qrCodePreview: QRCodePreview? = nil

    // MARK: – Player action sheet
    @Published var selectedPlayer: AdminGameStatus.Participant? = nil
    @Published var showPlayerActions = false

    // MARK: – NFC base conflict
    @Published var baseConflict: BaseConflict? = nil

    // MARK: – Game picker (schermata iniziale)
    /// true = mostra la lista game, false = siamo dentro un game selezionato
    @Published var showingGamePicker = true
    @Published var availableGames: [GameSummary] = []
    @Published var isLoadingGames = false

    private let gameService: GameService
    private let authService: AuthService
    let nfcService: NFCService

    private var refreshTask: Task<Void, Never>?
    private var currentContextGameId: String = ""
    private var cachedBaseTokensByGameId: [String: (teamA: String, teamB: String)] = [:]
    private var lastLoadedConfig: GameplayConfigSnapshot = .default
    private var lastLoadedItemMode: ItemMode = .none
    private var hasPendingConfigEdits = false
    private var isHydratingConfig = false
    private var configChangeCancellables: Set<AnyCancellable> = []

    init(gameService: GameService, authService: AuthService, nfcService: NFCService) {
        self.gameService = gameService
        self.authService = authService
        self.nfcService = nfcService
        bindConfigDirtyTracking()
    }

    deinit {
        refreshTask?.cancel()
    }

    // MARK: – Computed

    var canUseNFC: Bool { nfcService.isSupported }
    var isLiveState: Bool { gameState.uppercased() == "LIVE" }
    var isDistributionState: Bool { gameState.uppercased() == "DISTRIBUTION" }
    var isLobbyState: Bool { gameState.uppercased() == "LOBBY" }
    var isQREnabled: Bool { lastLoadedConfig.scanMode.isQREnabled }
    var scanModeStatusLabel: String { isQREnabled ? "NFC + QR" : "Solo NFC" }
    var canRegisterItems: Bool { itemMode != .none }
    var requiresCollectorTeamSelection: Bool { itemMode == .crossTeam }
    var selectedCollectorTeamIdForRegistration: String? {
        requiresCollectorTeamSelection ? selectedItemCollectorTeamId : nil
    }

    var teamAPlayers: [AdminGameStatus.Participant] {
        let team = participants.filter { normalizedTeamId($0.teamId) == "TEAM_A" }
        return sortedWithLeaderFirst(team)
    }

    var teamBPlayers: [AdminGameStatus.Participant] {
        let team = participants.filter { normalizedTeamId($0.teamId) == "TEAM_B" }
        return sortedWithLeaderFirst(team)
    }

    var unassignedPlayers: [AdminGameStatus.Participant] {
        participants.filter {
            let value = normalizedTeamId($0.teamId)
            return value != "TEAM_A" && value != "TEAM_B"
        }
    }

    var currentConfigSnapshot: GameplayConfigSnapshot {
        let resolvedHandshakeWindowSec = max(1, handshakeWindowSec)
        return GameplayConfigSnapshot(
            scanMode: selectedScanMode,
            handshakeWindowSec: resolvedHandshakeWindowSec,
            pairCooldownSec: max(1, pairCooldownSec),
            playerCooldownSec: max(1, playerCooldownSec),
            inactivePenaltyBlockDurationSec: max(1, inactivePenaltyBlockDurationSec),
            teamSyncWindowSec: max(resolvedHandshakeWindowSec, teamSyncWindowSec),
            baseContactWindowSec: max(1, lastLoadedConfig.baseContactWindowSec),
            baseDefenseMultiplier: max(1, baseDefenseMultiplier),
            baseDefenseDurationSec: max(1, baseDefenseDurationSec),
            baseDefenseCooldownSec: max(1, baseDefenseCooldownSec),
            duelTransferPoints: max(1, duelTransferPoints),
            baseCapturePoints: max(1, baseCapturePoints),
            baseDefensePoints: max(1, lastLoadedConfig.baseDefensePoints),
            startingPoints: max(1, startingPoints),
            countdownSec: max(1, countdownSec),
            matchDurationSec: max(60, matchDurationSec),
            timezone: timezone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? GameplayConfigSnapshot.default.timezone
                : timezone.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    // MARK: – Realtime refresh loop

    func startRealtimeUpdates() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.silentRefresh()
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 s
            }
        }
    }

    func stopRealtimeUpdates() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: – Game picker

    /// Chiamato all'apertura dell'Admin Console: carica il game attivo e lo aggiunge alla lista
    func loadGamePicker() {
        guard !isLoadingGames else { return }
        isLoadingGames = true
        Task {
            defer { isLoadingGames = false }
            do {
                availableGames = try await gameService.fetchAdminOwnedGames()
            } catch {
                appendLog("Errore caricamento game: \(error.localizedDescription)")
            }
        }
    }

    /// Seleziona un game dalla lista e apre la console
    func selectGame(_ summary: GameSummary) {
        loadGame(gameId: summary.id)
    }

    func loadGame(gameId: String) {
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let game = try await gameService.fetchAdminGame(gameId: gameId)
                applyGameStatus(game)
                // Load roster immediately from publicPlayers
                let roster = (try? await gameService.adminFetchRoster(gameId: gameId)) ?? []
                participants = roster
                await refreshGameItems(for: gameId)
                await refreshInviteAccess(for: gameId)
                showingGamePicker = false
                appendLog("Game selezionato: \(gameId) · \(participants.count) giocatori")
                startRealtimeUpdates()
            } catch {
                appendLog("Errore selezione game: \(error.localizedDescription)")
            }
        }
    }

    func backToGamePicker() {
        stopRealtimeUpdates()
        showingGamePicker = true
        participants = []
        gameItems = []
        teamABaseToken = ""
        teamBBaseToken = ""
        teamABaseQrToken = ""
        teamBBaseQrToken = ""
        pendingItemToken = nil
        pendingItemTokenCandidates = []
        pendingItemConflict = nil
        showItemPointsPrompt = false
        tokenIdentityConflict = nil
        qrCodePreview = nil
        scanResult = nil
        gameName = ""
        activeGameId = ""
        gameState = "N/A"
        itemMode = .none
        playerJoinCode = ""
        operatorInviteCode = ""
        selectedItemCollectorTeamId = "TEAM_A"
        backendEventExport = nil
        currentContextGameId = ""
        loadGamePicker()
    }

    /// Initial load + start polling (usato quando si entra direttamente nel game attivo)
    func loadActiveGame() {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let game = try await gameService.fetchAdminActiveGame()
                applyGameStatus(game)
                let gameId = game.gameId.trimmingCharacters(in: .whitespacesAndNewlines)
                if !gameId.isEmpty {
                    participants = (try? await gameService.adminFetchRoster(gameId: gameId)) ?? []
                    await refreshGameItems(for: gameId)
                    await refreshInviteAccess(for: gameId)
                } else {
                    participants = []
                    if !gameItems.isEmpty {
                        gameItems = []
                    }
                }
                appendLog("Game caricato: \(game.gameId.isEmpty ? "nessuno" : game.gameId) · \(participants.count) giocatori")
            } catch {
                appendLog("Errore caricamento: \(error.localizedDescription)")
            }
        }
        startRealtimeUpdates()
    }

    /// Carica gli oggetti solo quando la tab è effettivamente visibile
    func loadGameItemsIfNeeded() {
        let gameId = activeGameId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gameId.isEmpty else { return }
        Task {
            await refreshGameItems(for: gameId)
        }
    }

    func refreshBackendEventExport(limit: Int = 600) {
        let gameId = activeGameId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gameId.isEmpty else {
            appendLog("Log backend: gameId mancante")
            return
        }
        guard !isLoadingBackendEventExport else { return }

        isLoadingBackendEventExport = true
        Task {
            defer { isLoadingBackendEventExport = false }
            do {
                let export = try await gameService.adminExportGameEvents(gameId: gameId, limit: limit)
                backendEventExport = export
                appendLog(
                    export.truncated
                    ? "Log backend aggiornati: \(export.entries.count)/\(export.totalEventCount) eventi (ultimi eventi)"
                    : "Log backend aggiornati: \(export.entries.count) eventi"
                )
            } catch {
                appendLog("Errore log backend: \(error.localizedDescription)")
            }
        }
    }

    func copyBackendEventExport() {
        guard let backendEventExport else {
            appendLog("Nessun export backend da copiare")
            return
        }
        #if canImport(UIKit)
        UIPasteboard.general.string = backendEventExport.rawText
        appendLog("Export backend copiato negli appunti")
        #else
        appendLog("Clipboard non disponibile in questa build")
        #endif
    }

    private func silentRefresh() async {
        // Always poll when inside the console — don't bail even if activeGameId is not yet set.
        // Fetch game metadata and roster in parallel; roster comes from publicPlayers (correct source).
        do {
            let scopedGameId = currentContextGameId.trimmingCharacters(in: .whitespacesAndNewlines)
            let game = if scopedGameId.isEmpty {
                try await gameService.fetchAdminActiveGame()
            } else {
                try await gameService.fetchAdminGame(gameId: scopedGameId)
            }
            applyGameStatus(game)

            // Fetch roster separately once we have a valid gameId
            let gameId = game.gameId.trimmingCharacters(in: .whitespacesAndNewlines)
            if !gameId.isEmpty {
                do {
                    let roster = try await gameService.adminFetchRoster(gameId: gameId)
                    if roster != participants {
                        participants = roster
                    }
                } catch {
                    AppLogger.error("silentRefresh: roster fetch failed, keeping previous list: \(error.localizedDescription)")
                }
                await refreshGameItems(for: gameId)
                if playerJoinCode.isEmpty && operatorInviteCode.isEmpty {
                    await refreshInviteAccess(for: gameId)
                }
            } else {
                if !participants.isEmpty {
                    participants = []
                }
                if !gameItems.isEmpty {
                    gameItems = []
                }
                if !playerJoinCode.isEmpty || !operatorInviteCode.isEmpty {
                    playerJoinCode = ""
                    operatorInviteCode = ""
                }
            }
        } catch {
            // silent – don't pollute logs on every polling cycle
        }
    }

    // MARK: – Game actions

    /// Crea un nuovo game e apre direttamente la console
    func createGameAndEnter() {
        guard !isBusy else { return }
        let name = gameName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { appendLog("Nome game mancante"); return }
        let gameId = resolvedGameId(from: nil)

        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let created = try await gameService.createAdminGame(
                    name: name,
                    gameId: gameId,
                    config: currentConfigSnapshot
                )
                applyGameStatus(created)
                availableGames.insert(
                    GameSummary(
                        id: created.gameId,
                        name: name,
                        state: created.state,
                        playerCount: 0,
                        isActive: true
                    ),
                    at: 0
                )
                appendLog("Game creato: \(created.gameId)")
                showingGamePicker = false
                startRealtimeUpdates()
            } catch {
                appendLog("Errore creazione game: \(error.localizedDescription)")
            }
        }
    }

    func createGame() {
        guard !isBusy else { return }
        let name = gameName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { appendLog("Nome game mancante"); return }
        let gameId = resolvedGameId(from: activeGameId)

        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let created = try await gameService.createAdminGame(
                    name: name,
                    gameId: gameId,
                    config: currentConfigSnapshot
                )
                applyGameStatus(created)
                availableGames.insert(
                    GameSummary(
                        id: created.gameId,
                        name: name,
                        state: created.state,
                        playerCount: 0,
                        isActive: true
                    ),
                    at: 0
                )
                appendLog("Game creato: \(created.gameId)")
                startRealtimeUpdates()
            } catch {
                appendLog("Errore creazione game: \(error.localizedDescription)")
            }
        }
    }

    func deleteGame(_ summary: GameSummary) {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = ""

        Task {
            defer { isBusy = false }
            do {
                try await gameService.deleteAdminGame(gameId: summary.id)
                availableGames.removeAll { $0.id == summary.id }
                appendLog("Game eliminato: \(summary.id)")
                availableGames = try await gameService.fetchAdminOwnedGames()
            } catch {
                let msg = "Errore eliminazione game: \(error.localizedDescription)"
                appendLog(msg)
                errorMessage = msg
            }
        }
    }

    func transitionToDistribution() {
        guard isLobbyState || isLiveState else {
            appendLog("DISTRIBUTION errore: stato attuale \(gameState)")
            return
        }
        runGameAction(logPrefix: "DISTRIBUTION") { gameId in
            try await self.gameService.transitionToDistribution(gameId: gameId)
        }
    }

    func startLive() {
        runGameAction(logPrefix: "START LIVE") { gameId in
            try await self.gameService.startMatch(gameId: gameId)
        }
    }

    func endMatch() {
        guard isLiveState else { appendLog("END MATCH non consentito da stato \(gameState)"); return }
        runGameAction(logPrefix: "END MATCH") { gameId in
            try await self.gameService.endMatch(gameId: gameId)
        }
    }

    func pickRandomLeaders() {
        runGameAction(logPrefix: "Leader random") { gameId in
            try await self.gameService.pickRandomLeaders(gameId: gameId)
        }
    }

    func saveGameConfig() {
        let gameId = activeGameId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gameId.isEmpty else { appendLog("Game ID mancante"); return }
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                try await gameService.updateGameConfig(
                    gameId: gameId,
                    config: currentConfigSnapshot,
                    itemMode: itemMode
                )
                lastLoadedConfig = currentConfigSnapshot
                lastLoadedItemMode = itemMode
                hasPendingConfigEdits = false
                appendLog("Config gameplay salvata")
            } catch {
                appendLog("Errore save scan mode: \(error.localizedDescription)")
            }
        }
    }

    func resetConfigToLoaded() {
        isHydratingConfig = true
        selectedScanMode = lastLoadedConfig.scanMode
        matchDurationSec = max(60, lastLoadedConfig.matchDurationSec)
        handshakeWindowSec = max(1, lastLoadedConfig.handshakeWindowSec)
        pairCooldownSec = max(1, lastLoadedConfig.pairCooldownSec)
        playerCooldownSec = max(1, lastLoadedConfig.playerCooldownSec)
        inactivePenaltyBlockDurationSec = max(1, lastLoadedConfig.inactivePenaltyBlockDurationSec)
        teamSyncWindowSec = max(1, lastLoadedConfig.teamSyncWindowSec)
        baseContactWindowSec = max(1, lastLoadedConfig.baseContactWindowSec)
        baseDefenseMultiplier = max(1, lastLoadedConfig.baseDefenseMultiplier)
        baseDefenseDurationSec = max(1, lastLoadedConfig.baseDefenseDurationSec)
        baseDefenseCooldownSec = max(1, lastLoadedConfig.baseDefenseCooldownSec)
        duelTransferPoints = max(1, lastLoadedConfig.duelTransferPoints)
        baseCapturePoints = max(1, lastLoadedConfig.baseCapturePoints)
        baseDefensePoints = max(1, lastLoadedConfig.baseDefensePoints)
        startingPoints = max(1, lastLoadedConfig.startingPoints)
        countdownSec = max(1, lastLoadedConfig.countdownSec)
        timezone = lastLoadedConfig.timezone
        itemMode = lastLoadedItemMode
        hasPendingConfigEdits = false
        isHydratingConfig = false
        appendLog("Configurazione iniziale ripristinata")
    }

    // MARK: – Base token management

    /// Salva il token base direttamente (senza guard isBusy — usato internamente dopo NFC scan)
    private func persistBaseToken(
        teamId: String,
        token: String,
        tokenCandidates: [String] = [],
        overwriteExistingBase: Bool = false
    ) async {
        let gameId = activeGameId.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizeToken(token)
        let normalizedCandidates = normalizeTagTokenCandidates([normalized] + tokenCandidates)
        guard !gameId.isEmpty else { appendLog("Base \(teamId): gameId mancante"); return }
        guard !normalized.isEmpty else { appendLog("Base \(teamId): token vuoto"); return }

        appendLog("Salvataggio base \(teamId): gameId='\(gameId)' token='\(normalized)'")
        let lookup = await resolveTagLookup(
            for: normalized,
            tokenCandidates: normalizedCandidates,
            gameId: gameId
        )
        if lookup.entityType == "base",
           let lookupTeamId = lookup.teamLabel,
           normalizedTeamId(lookupTeamId) != normalizedTeamId(teamId) {
            if overwriteExistingBase {
                appendLog("Sovrascrittura base confermata: \(lookupTeamId) → \(teamId)")
            } else {
                appendLog("Conflitto base: token già usato da \(lookupTeamId)")
                baseConflict = BaseConflict(
                    token: normalized,
                    tokenCandidates: normalizedCandidates,
                    sourceTeamId: lookupTeamId,
                    targetTeamId: teamId
                )
                errorMessage = "Tag già usato come base (\(teamDisplayLabel(for: lookupTeamId))). Conferma per spostarlo."
                return
            }
        } else if lookup.entityType == "item" || lookup.entityType == "player" {
            tokenIdentityConflict = TokenIdentityConflict(
                token: normalized,
                tokenCandidates: normalizedCandidates,
                desiredRole: .base(teamId: teamId),
                existingRoleLabel: existingRoleLabel(for: lookup)
            )
            appendLog("Conflitto token: '\(normalized)' è già usato come \(lookup.entityType).")
            errorMessage = "Tag già associato a \(existingRoleLabel(for: lookup)). Conferma per sovrascrivere."
            return
        }

        do {
            try await gameService.setBaseToken(
                gameId: gameId,
                teamId: teamId,
                token: normalized,
                tokenCandidates: normalizedCandidates,
                overwriteExistingBase: overwriteExistingBase
            )
            setLocalBaseToken(teamId: teamId, token: normalized)
            await refreshTagAssociations(gameId: gameId)
            appendLog("Base \(teamId) impostata: \(normalized)")
            errorMessage = ""
            tokenIdentityConflict = nil
            baseConflict = nil
        } catch {
            let msg = error.localizedDescription
            if isLikelyTokenRegistryConflict(msg) {
                let latest = await resolveTagLookup(
                    for: normalized,
                    tokenCandidates: normalizedCandidates,
                    gameId: gameId
                )
                if latest.entityType == "base",
                   let latestTeamId = latest.teamLabel,
                   normalizedTeamId(latestTeamId) != normalizedTeamId(teamId),
                   !overwriteExistingBase {
                    baseConflict = BaseConflict(
                        token: normalized,
                        tokenCandidates: normalizedCandidates,
                        sourceTeamId: latestTeamId,
                        targetTeamId: teamId
                    )
                    appendLog("Conflitto token backend: '\(normalized)' è già base \(latestTeamId).")
                    errorMessage = "Tag già usato come base (\(teamDisplayLabel(for: latestTeamId))). Conferma per spostarlo."
                    return
                }
                if latest.entityType == "item" || latest.entityType == "player" {
                    tokenIdentityConflict = TokenIdentityConflict(
                        token: normalized,
                        tokenCandidates: normalizedCandidates,
                        desiredRole: .base(teamId: teamId),
                        existingRoleLabel: existingRoleLabel(for: latest)
                    )
                    appendLog("Conflitto token backend: '\(normalized)' è già associato.")
                    errorMessage = "Tag già associato a \(existingRoleLabel(for: latest)). Conferma per sovrascrivere."
                    return
                }
            }
            appendLog("Errore base \(teamId): \(msg)")
            errorMessage = msg
        }
    }

    /// Chiamato dall'UI quando si vuole impostare manualmente (non dopo NFC scan)
    func setBaseToken(teamId: String, token: String) {
        guard !isBusy else { return }
        Task {
            await persistBaseToken(teamId: teamId, token: token)
        }
    }

    func scanBaseToken(teamId: String) {
        guard canUseNFC else { appendLog("NFC non disponibile su questo iPhone"); return }
        guard !isBusy else { return }
        pendingNFCTeamId = teamId
        isScanning = true
        isBusy = true
        appendLog("NFC \(teamId): avvicina il braccialetto...")

        Task {
            defer { isBusy = false; isScanning = false; pendingNFCTeamId = nil }
            do {
                let tagRead = try await nfcService.readTag(prompt: "Avvicina braccialetto base \(teamId)")
                let token = normalizeToken(tagRead.primaryToken)
                appendLog("NFC \(teamId) letto: '\(token)'")
                await persistBaseToken(teamId: teamId, token: token, tokenCandidates: tagRead.candidates)
            } catch {
                appendLog("NFC \(teamId) fallita: \(error.localizedDescription)")
            }
        }
    }

    func resolveTokenIdentityConflict(overwrite: Bool) {
        guard let conflict = tokenIdentityConflict else { return }
        tokenIdentityConflict = nil

        guard overwrite else {
            appendLog("Sovrascrittura tag annullata")
            return
        }

        let gameId = activeGameId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gameId.isEmpty else {
            appendLog("Game ID mancante")
            errorMessage = "Game ID mancante"
            return
        }

        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                try await gameService.adminCleanupTokenConflict(
                    gameId: gameId,
                    token: conflict.token,
                    tokenCandidates: conflict.tokenCandidates,
                    correctType: "REMOVE"
                )

                switch conflict.desiredRole {
                case .base(let teamId):
                    try await gameService.setBaseToken(
                        gameId: gameId,
                        teamId: teamId,
                        token: conflict.token,
                        tokenCandidates: conflict.tokenCandidates,
                        overwriteExistingBase: false
                    )
                    setLocalBaseToken(teamId: teamId, token: conflict.token)
                    appendLog("Tag sovrascritto come base \(teamId): \(conflict.token)")
                case .newItem:
                    beginItemRegistrationFlow(token: conflict.token, tokenCandidates: conflict.tokenCandidates)
                    appendLog("Tag liberato: completa la registrazione oggetto per \(conflict.token)")
                case .existingItem(let itemId, let itemLabel):
                    try await gameService.adminAttachItemToken(
                        gameId: gameId,
                        itemId: itemId,
                        token: conflict.token,
                        tokenCandidates: conflict.tokenCandidates
                    )
                    appendLog("Tag sovrascritto e collegato a \(itemLabel ?? "oggetto"): \(conflict.token)")
                }

                await refreshTagAssociations(gameId: gameId)
                errorMessage = ""
            } catch {
                let msg = error.localizedDescription
                appendLog("Errore sovrascrittura tag: \(msg)")
                errorMessage = msg
            }
        }
    }

    func resolveBaseConflict(overwrite: Bool) {
        guard let conflict = baseConflict else { return }
        baseConflict = nil
        if overwrite {
            Task {
                await persistBaseToken(
                    teamId: conflict.targetTeamId,
                    token: conflict.token,
                    tokenCandidates: conflict.tokenCandidates,
                    overwriteExistingBase: true
                )
            }
        } else {
            appendLog("Sovrascrittura base annullata")
        }
    }

    // MARK: – Player management

    func selectPlayer(_ player: AdminGameStatus.Participant) {
        selectedPlayer = player
        showPlayerActions = true
    }

    func removePlayer(_ player: AdminGameStatus.Participant) {
        let gameId = activeGameId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gameId.isEmpty else { return }
        Task {
            do {
                try await gameService.adminRemovePlayerFromGame(gameId: gameId, playerId: player.id)
                appendLog("Giocatore rimosso: \(player.nickname)")
                await silentRefresh()
            } catch {
                appendLog("Errore rimozione: \(error.localizedDescription)")
            }
        }
    }

    func assignPlayer(_ player: AdminGameStatus.Participant, toTeam teamId: String?) {
        let gameId = activeGameId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gameId.isEmpty else { return }
        Task {
            do {
                try await gameService.adminAssignPlayerToTeam(gameId: gameId, playerId: player.id, teamId: teamId)
                let teamLabel = teamId ?? "nessun team"
                appendLog("\(player.nickname) → \(teamLabel)")
                await silentRefresh()
            } catch {
                appendLog("Errore assegnazione: \(error.localizedDescription)")
            }
        }
    }

    func setLeader(_ player: AdminGameStatus.Participant) {
        let gameId = activeGameId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gameId.isEmpty else { return }
        guard let teamId = player.teamId, !teamId.isEmpty else {
            appendLog("Il giocatore non ha un team assegnato")
            return
        }
        Task {
            do {
                try await gameService.adminSetTeamLeader(gameId: gameId, playerId: player.id, teamId: teamId)
                appendLog("\(player.nickname) impostato come leader di \(teamId)")
                await silentRefresh()
            } catch {
                appendLog("Errore set leader: \(error.localizedDescription)")
            }
        }
    }

    // MARK: – Game items

    func scanAndAddItem() {
        guard canUseNFC else { appendLog("NFC non disponibile"); return }
        guard !activeGameId.isEmpty else { appendLog("Nessun game attivo"); return }
        guard !isBusy else { return }
        tokenIdentityConflict = nil
        isScanning = true
        isBusy = true

        Task {
            defer { isScanning = false; isBusy = false }
            do {
                let tagRead = try await nfcService.readTag(prompt: "Avvicina l'oggetto da registrare")
                let token = normalizeToken(tagRead.primaryToken)
                let tokenCandidates = tagRead.candidates
                let gameId = activeGameId.trimmingCharacters(in: .whitespacesAndNewlines)
                let lookup = await resolveTagLookup(
                    for: token,
                    tokenCandidates: tokenCandidates,
                    gameId: gameId
                )
                switch lookup.entityType {
                case "base":
                    tokenIdentityConflict = TokenIdentityConflict(
                        token: token,
                        tokenCandidates: tokenCandidates,
                        desiredRole: .newItem,
                        existingRoleLabel: existingRoleLabel(for: lookup)
                    )
                    appendLog("Conflitto token: '\(token)' è già usato come base.")
                    errorMessage = "Tag già usato come base (\(teamDisplayLabel(for: lookup.teamLabel))). Conferma per sovrascrivere."
                case "player":
                    tokenIdentityConflict = TokenIdentityConflict(
                        token: token,
                        tokenCandidates: tokenCandidates,
                        desiredRole: .newItem,
                        existingRoleLabel: existingRoleLabel(for: lookup)
                    )
                    appendLog("Conflitto token: '\(token)' è già usato come giocatore.")
                    errorMessage = "Tag già associato a \(existingRoleLabel(for: lookup)). Conferma per sovrascrivere."
                case "item":
                    if let existing = gameItem(from: lookup) {
                        pendingItemConflict = existing
                        appendLog("Tag già registrato come oggetto: \(token)")
                    } else {
                        appendLog("Tag già registrato come oggetto: \(token)")
                        errorMessage = "Tag già registrato come oggetto."
                    }
                default:
                    beginItemRegistrationFlow(token: token, tokenCandidates: tokenCandidates)
                    errorMessage = ""
                }
            } catch {
                appendLog("NFC scan fallita: \(error.localizedDescription)")
            }
        }
    }

    func startAddItemFlow() {
        if isQREnabled {
            beginItemRegistrationFlow(token: nil)
        } else {
            scanAndAddItem()
        }
    }

    func confirmRegisterItem(token: String?, points: Int) {
        guard !isBusy else { return }
        let gameId = activeGameId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gameId.isEmpty else { return }
        let normalizedToken = normalizeToken(token)
        let tokenCandidates =
            normalizedToken.isEmpty
            ? []
            : normalizeTagTokenCandidates([normalizedToken] + pendingItemTokenCandidates)
        pendingItemToken = nil
        pendingItemTokenCandidates = []
        showItemPointsPrompt = false
        isBusy = true

        Task {
            defer { isBusy = false }
            do {
                if !normalizedToken.isEmpty {
                    let lookup = await resolveTagLookup(
                        for: normalizedToken,
                        tokenCandidates: tokenCandidates,
                        gameId: gameId
                    )
                    if lookup.entityType == "base" {
                        tokenIdentityConflict = TokenIdentityConflict(
                            token: normalizedToken,
                            tokenCandidates: tokenCandidates,
                            desiredRole: .newItem,
                            existingRoleLabel: existingRoleLabel(for: lookup)
                        )
                        appendLog("Conflitto token: '\(normalizedToken)' è già usato come base.")
                        errorMessage = "Tag già usato come base (\(teamDisplayLabel(for: lookup.teamLabel))). Conferma per sovrascrivere."
                        return
                    }
                    if lookup.entityType == "player" {
                        tokenIdentityConflict = TokenIdentityConflict(
                            token: normalizedToken,
                            tokenCandidates: tokenCandidates,
                            desiredRole: .newItem,
                            existingRoleLabel: existingRoleLabel(for: lookup)
                        )
                        appendLog("Conflitto token: '\(normalizedToken)' è già usato come giocatore.")
                        errorMessage = "Tag già associato a \(existingRoleLabel(for: lookup)). Conferma per sovrascrivere."
                        return
                    }
                    if lookup.entityType == "item" {
                        if let existing = gameItem(from: lookup) {
                            pendingItemConflict = existing
                            appendLog("Oggetto già registrato: \(existing.icon) · \(existing.points)pt · \(normalizedToken)")
                        }
                        errorMessage = "Tag già registrato come oggetto."
                        return
                    }
                }

                let icon = nextUniqueIcon()
                let item = try await gameService.adminRegisterGameItem(
                    gameId: gameId,
                    token: normalizedToken.isEmpty ? nil : normalizedToken,
                    tokenCandidates: tokenCandidates,
                    icon: icon,
                    points: points,
                    collectorTeamId: selectedCollectorTeamIdForRegistration
                )
                upsertGameItem(item)
                if let collectorTeamId = item.collectorTeamId {
                    if normalizedToken.isEmpty {
                        appendLog("Oggetto registrato: \(item.icon) · \(item.points)pt · \(teamDisplayLabel(for: collectorTeamId)) · QR pronto")
                    } else {
                        appendLog("Oggetto registrato: \(item.icon) · \(item.points)pt · \(teamDisplayLabel(for: collectorTeamId)) · \(normalizedToken)")
                    }
                } else {
                    if normalizedToken.isEmpty {
                        appendLog("Oggetto registrato: \(item.icon) · \(item.points)pt · QR pronto")
                    } else {
                        appendLog("Oggetto registrato: \(item.icon) · \(item.points)pt · \(normalizedToken)")
                    }
                }
                errorMessage = ""
                tokenIdentityConflict = nil
            } catch {
                let msg = error.localizedDescription
                if !normalizedToken.isEmpty && isLikelyTokenRegistryConflict(msg) {
                    let latest = await resolveTagLookup(
                        for: normalizedToken,
                        tokenCandidates: tokenCandidates,
                        gameId: gameId
                    )
                    if latest.entityType == "base" {
                        tokenIdentityConflict = TokenIdentityConflict(
                            token: normalizedToken,
                            tokenCandidates: tokenCandidates,
                            desiredRole: .newItem,
                            existingRoleLabel: existingRoleLabel(for: latest)
                        )
                        appendLog("Conflitto token backend: '\(normalizedToken)' è già base.")
                        errorMessage = "Tag già usato come base (\(teamDisplayLabel(for: latest.teamLabel))). Conferma per sovrascrivere."
                        return
                    }
                    if latest.entityType == "player" {
                        tokenIdentityConflict = TokenIdentityConflict(
                            token: normalizedToken,
                            tokenCandidates: tokenCandidates,
                            desiredRole: .newItem,
                            existingRoleLabel: existingRoleLabel(for: latest)
                        )
                        errorMessage = "Tag già associato a \(existingRoleLabel(for: latest)). Conferma per sovrascrivere."
                        return
                    }
                    if latest.entityType == "item" {
                        if let existing = gameItem(from: latest) {
                            pendingItemConflict = existing
                        }
                        errorMessage = "Tag già registrato come oggetto."
                        return
                    }
                }
                appendLog("Errore registrazione oggetto: \(msg)")
                errorMessage = msg
            }
        }
    }

    func attachNFCToken(to item: AdminGameStatus.GameItem) {
        guard canUseNFC else { appendLog("NFC non disponibile"); return }
        let gameId = activeGameId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gameId.isEmpty else { appendLog("Nessun game attivo"); return }
        guard !isBusy else { return }
        tokenIdentityConflict = nil
        pendingItemConflict = nil
        isScanning = true
        isBusy = true

        Task {
            defer { isScanning = false; isBusy = false }
            do {
                let tagRead = try await nfcService.readTag(prompt: "Avvicina il tag NFC da collegare all'oggetto")
                let token = normalizeToken(tagRead.primaryToken)
                let tokenCandidates = normalizeTagTokenCandidates([token] + tagRead.candidates)
                let lookup = await resolveTagLookup(
                    for: token,
                    tokenCandidates: tokenCandidates,
                    gameId: gameId
                )

                switch lookup.entityType {
                case "free":
                    try await gameService.adminAttachItemToken(
                        gameId: gameId,
                        itemId: item.id,
                        token: token,
                        tokenCandidates: tokenCandidates
                    )
                    upsertGameItem(updatedItem(item, nfcToken: token))
                    appendLog("Tag NFC collegato a oggetto \(item.icon): \(token)")
                    errorMessage = ""
                case "item":
                    if lookup.bindingId == item.id || tokensMatch(item.nfcToken, token) {
                        appendLog("Il tag NFC è già collegato a questo oggetto.")
                    } else {
                        tokenIdentityConflict = TokenIdentityConflict(
                            token: token,
                            tokenCandidates: tokenCandidates,
                            desiredRole: .existingItem(itemId: item.id, itemLabel: item.icon),
                            existingRoleLabel: existingRoleLabel(for: lookup)
                        )
                        errorMessage = "Tag già associato a \(existingRoleLabel(for: lookup)). Conferma per spostarlo."
                    }
                default:
                    tokenIdentityConflict = TokenIdentityConflict(
                        token: token,
                        tokenCandidates: tokenCandidates,
                        desiredRole: .existingItem(itemId: item.id, itemLabel: item.icon),
                        existingRoleLabel: existingRoleLabel(for: lookup)
                    )
                    errorMessage = "Tag già associato a \(existingRoleLabel(for: lookup)). Conferma per sovrascrivere."
                }
            } catch {
                appendLog("Collegamento tag NFC fallito: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
        }
    }

    func scanCheckItem() {
        guard canUseNFC else { appendLog("NFC non disponibile"); return }
        guard !activeGameId.isEmpty else { appendLog("Nessun game attivo"); return }
        guard !isBusy else { return }
        tokenIdentityConflict = nil
        isScanning = true
        isBusy = true

        Task {
            defer { isScanning = false; isBusy = false }
            do {
                let tagRead = try await nfcService.readTag(prompt: "Avvicina l'oggetto da verificare")
                let token = normalizeToken(tagRead.primaryToken)
                let gameId = activeGameId.trimmingCharacters(in: .whitespacesAndNewlines)
                pendingItemConflict = nil
                scanResult = await resolveTagLookup(
                    for: token,
                    tokenCandidates: tagRead.candidates,
                    gameId: gameId
                )
            } catch {
                appendLog("Controllo oggetto fallito: \(error.localizedDescription)")
            }
        }
    }

    // MARK: – Tag lookup (Overview "Controlla tag")

    func scanAndLookupTag() {
        guard canUseNFC else {
            scanResult = TagLookupResult(
                tagId: "",
                entityType: "error",
                entityLabel: "NFC non disponibile su questo dispositivo",
                bindingId: nil,
                teamLabel: nil,
                entityDetail: nil,
                itemIcon: nil,
                itemPoints: nil
            )
            return
        }
        guard !activeGameId.isEmpty else {
            scanResult = TagLookupResult(
                tagId: "",
                entityType: "error",
                entityLabel: "Nessun game attivo. Crea o carica una partita prima.",
                bindingId: nil,
                teamLabel: nil,
                entityDetail: nil,
                itemIcon: nil,
                itemPoints: nil
            )
            return
        }
        guard !isBusy else { return }
        tokenIdentityConflict = nil
        isScanning = true
        isBusy = true

        Task {
            defer { isScanning = false; isBusy = false }
            do {
                let tagRead = try await nfcService.readTag(prompt: "Avvicina il tag da identificare")
                let token = normalizeToken(tagRead.primaryToken)
                let gameId = activeGameId.trimmingCharacters(in: .whitespacesAndNewlines)
                scanResult = await resolveTagLookup(
                    for: token,
                    tokenCandidates: tagRead.candidates,
                    gameId: gameId
                )
            } catch {
                let msg = error.localizedDescription
                scanResult = TagLookupResult(
                    tagId: "",
                    entityType: "error",
                    entityLabel: "Errore NFC: \(msg)",
                    bindingId: nil,
                    teamLabel: nil,
                    entityDetail: nil,
                    itemIcon: nil,
                    itemPoints: nil
                )
                appendLog("Tag lookup fallito: \(msg)")
            }
        }
    }

    private func lookupTokenLocally(_ token: String) -> TagLookupResult {
        let normalized = normalizeToken(token)
        // Check team bases
        if !teamABaseToken.isEmpty && tokensMatch(teamABaseToken, normalized) {
            return TagLookupResult(tagId: normalized, entityType: "base", entityLabel: "Base Giocatori", bindingId: "TEAM_A", teamLabel: "TEAM_A", entityDetail: nil, itemIcon: nil, itemPoints: nil)
        }
        if !teamBBaseToken.isEmpty && tokensMatch(teamBBaseToken, normalized) {
            return TagLookupResult(tagId: normalized, entityType: "base", entityLabel: "Base Cittadini", bindingId: "TEAM_B", teamLabel: "TEAM_B", entityDetail: nil, itemIcon: nil, itemPoints: nil)
        }
        if !teamABaseQrToken.isEmpty && tokensMatch(teamABaseQrToken, normalized) {
            return TagLookupResult(tagId: normalized, entityType: "base", entityLabel: "Base Giocatori", bindingId: "TEAM_A", teamLabel: "TEAM_A", entityDetail: nil, itemIcon: nil, itemPoints: nil)
        }
        if !teamBBaseQrToken.isEmpty && tokensMatch(teamBBaseQrToken, normalized) {
            return TagLookupResult(tagId: normalized, entityType: "base", entityLabel: "Base Cittadini", bindingId: "TEAM_B", teamLabel: "TEAM_B", entityDetail: nil, itemIcon: nil, itemPoints: nil)
        }
        // Check game items
        if let item = gameItems.first(where: { tokensMatch($0.nfcToken, normalized) || tokensMatch($0.qrToken, normalized) }) {
            return TagLookupResult(tagId: normalized, entityType: "item", entityLabel: "Oggetto · \(item.points)pt", bindingId: item.id, teamLabel: nil, entityDetail: nil, itemIcon: item.icon, itemPoints: item.points)
        }
        // Free
        return TagLookupResult(tagId: normalized, entityType: "free", entityLabel: "Tag libero, non associato in questo game", bindingId: nil, teamLabel: nil, entityDetail: nil, itemIcon: nil, itemPoints: nil)
    }

    func clearScanResult() {
        scanResult = nil
        pendingItemToken = nil
        pendingItemTokenCandidates = []
        pendingItemConflict = nil
    }

    // MARK: – Logging

    func appendLog(_ value: String) {
        let line = "[\(DateFormatter.adminLogStamp.string(from: Date()))] \(value)"
        logLines.insert(line, at: 0)
        if logLines.count > 200 {
            logLines.removeLast(logLines.count - 200)
        }
    }

    // MARK: – Auth

    func logout() async {
        do {
            try await authService.signOut()
        } catch {
            appendLog("Logout fallito: \(error.localizedDescription)")
        }
    }

    // MARK: – Private helpers

    private func applyGameStatus(_ game: AdminGameStatus) {
        let normalizedGameId = game.gameId.trimmingCharacters(in: .whitespacesAndNewlines)
        let didChangeGame = currentContextGameId != normalizedGameId
        if currentContextGameId != normalizedGameId {
            teamABaseToken = ""
            teamBBaseToken = ""
            teamABaseQrToken = ""
            teamBBaseQrToken = ""
            gameItems = []
            backendEventExport = nil
            pendingItemToken = nil
            pendingItemTokenCandidates = []
            pendingItemConflict = nil
            showItemPointsPrompt = false
            tokenIdentityConflict = nil
            scanResult = nil
            currentContextGameId = normalizedGameId
        }

        gameName = game.name.trimmingCharacters(in: .whitespacesAndNewlines)
        activeGameId = normalizedGameId
        gameState = game.state
        itemMode = game.itemMode
        lastLoadedItemMode = game.itemMode
        if itemMode != .crossTeam {
            selectedItemCollectorTeamId = "TEAM_A"
        }
        if game.hasConfigSnapshot {
            let config = game.config
            lastLoadedConfig = config
            if didChangeGame || !hasPendingConfigEdits {
                isHydratingConfig = true
                selectedScanMode = config.scanMode
                matchDurationSec = max(60, config.matchDurationSec)
                handshakeWindowSec = max(1, config.handshakeWindowSec)
                pairCooldownSec = max(1, config.pairCooldownSec)
                playerCooldownSec = max(1, config.playerCooldownSec)
                inactivePenaltyBlockDurationSec = max(1, config.inactivePenaltyBlockDurationSec)
                teamSyncWindowSec = max(1, config.teamSyncWindowSec)
                baseContactWindowSec = max(1, config.baseContactWindowSec)
                baseDefenseMultiplier = max(1, config.baseDefenseMultiplier)
                baseDefenseDurationSec = max(1, config.baseDefenseDurationSec)
                baseDefenseCooldownSec = max(1, config.baseDefenseCooldownSec)
                duelTransferPoints = max(1, config.duelTransferPoints)
                baseCapturePoints = max(1, config.baseCapturePoints)
                baseDefensePoints = max(1, config.baseDefensePoints)
                startingPoints = max(1, config.startingPoints)
                countdownSec = max(1, config.countdownSec)
                timezone = config.timezone
                hasPendingConfigEdits = false
                isHydratingConfig = false
            }
        }
        if !game.participants.isEmpty || participants.isEmpty {
            participants = game.participants
        }
        if game.hasBaseSnapshot {
            teamABaseToken = normalizeToken(game.teamABaseToken)
            teamBBaseToken = normalizeToken(game.teamBBaseToken)
            teamABaseQrToken = normalizeToken(game.teamABaseQrToken)
            teamBBaseQrToken = normalizeToken(game.teamBBaseQrToken)
            cacheBaseTokens(
                gameId: normalizedGameId,
                teamA: teamABaseToken,
                teamB: teamBBaseToken
            )
        } else if let cached = cachedBaseTokensByGameId[normalizedGameId] {
            teamABaseToken = cached.teamA
            teamBBaseToken = cached.teamB
        }
    }

    private func refreshGameItems(for gameId: String) async {
        let normalizedGameId = gameId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedGameId.isEmpty else {
            if !gameItems.isEmpty {
                gameItems = []
            }
            return
        }
        do {
            let items = try await gameService.adminFetchGameItems(gameId: normalizedGameId)
            if items != gameItems {
                gameItems = items
            }
        } catch {
            AppLogger.error("refreshGameItems: fetch failed, keeping previous list: \(error.localizedDescription)")
        }
    }

    private func refreshTagAssociations(gameId: String) async {
        if let refreshedGame = try? await gameService.fetchAdminGame(gameId: gameId) {
            applyGameStatus(refreshedGame)
        }
        await refreshGameItems(for: gameId)
        await refreshInviteAccess(for: gameId)
    }

    private func refreshInviteAccess(for gameId: String) async {
        let normalizedGameId = gameId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedGameId.isEmpty else {
            playerJoinCode = ""
            operatorInviteCode = ""
            return
        }
        let summaries = (try? await gameService.listAccessibleGames()) ?? []
        guard let summary = summaries.first(where: { $0.id == normalizedGameId }) else {
            playerJoinCode = ""
            operatorInviteCode = ""
            return
        }
        playerJoinCode = summary.joinCode ?? ""
        operatorInviteCode = summary.operatorInviteCode ?? ""
    }

    private func bindConfigDirtyTracking() {
        let publishers: [AnyPublisher<Void, Never>] = [
            $selectedScanMode.map { _ in () }.eraseToAnyPublisher(),
            $matchDurationSec.map { _ in () }.eraseToAnyPublisher(),
            $handshakeWindowSec.map { _ in () }.eraseToAnyPublisher(),
            $pairCooldownSec.map { _ in () }.eraseToAnyPublisher(),
            $playerCooldownSec.map { _ in () }.eraseToAnyPublisher(),
            $inactivePenaltyBlockDurationSec.map { _ in () }.eraseToAnyPublisher(),
            $teamSyncWindowSec.map { _ in () }.eraseToAnyPublisher(),
            $baseContactWindowSec.map { _ in () }.eraseToAnyPublisher(),
            $baseDefenseMultiplier.map { _ in () }.eraseToAnyPublisher(),
            $baseDefenseDurationSec.map { _ in () }.eraseToAnyPublisher(),
            $baseDefenseCooldownSec.map { _ in () }.eraseToAnyPublisher(),
            $duelTransferPoints.map { _ in () }.eraseToAnyPublisher(),
            $baseCapturePoints.map { _ in () }.eraseToAnyPublisher(),
            $baseDefensePoints.map { _ in () }.eraseToAnyPublisher(),
            $startingPoints.map { _ in () }.eraseToAnyPublisher(),
            $countdownSec.map { _ in () }.eraseToAnyPublisher(),
            $timezone.map { _ in () }.eraseToAnyPublisher()
        ]

        publishers.forEach { publisher in
            publisher
                .dropFirst()
                .sink { [weak self] in
                    guard let self else { return }
                    guard !self.isHydratingConfig else { return }
                    self.hasPendingConfigEdits = self.currentConfigSnapshot != self.lastLoadedConfig
                }
                .store(in: &configChangeCancellables)
        }
    }

    private func resolveTagLookup(
        for token: String,
        tokenCandidates: [String] = [],
        gameId: String
    ) async -> TagLookupResult {
        let normalized = normalizeToken(token)
        guard !normalized.isEmpty else {
            return TagLookupResult(
                tagId: "",
                entityType: "free",
                entityLabel: "Tag libero, non associato in questo game",
                bindingId: nil,
                teamLabel: nil,
                entityDetail: nil,
                itemIcon: nil,
                itemPoints: nil
            )
        }
        do {
            let remote = try await gameService.adminLookupTag(
                gameId: gameId,
                token: normalized,
                tokenCandidates: tokenCandidates
            )
            return makeLookupResult(from: remote)
        } catch {
            appendLog("Lookup remoto fallito, uso cache locale: \(error.localizedDescription)")
            return lookupTokenLocally(normalized)
        }
    }

    private func makeLookupResult(from lookup: AdminGameStatus.TagLookup) -> TagLookupResult {
        switch lookup.entityType {
        case "base":
            return TagLookupResult(
                tagId: normalizeToken(lookup.tagId),
                entityType: "base",
                entityLabel: normalizedTeamId(lookup.teamId) == "TEAM_B" ? "Base Cittadini" : "Base Giocatori",
                bindingId: lookup.bindingId,
                teamLabel: lookup.teamId,
                entityDetail: nil,
                itemIcon: nil,
                itemPoints: nil
            )
        case "item":
            return TagLookupResult(
                tagId: normalizeToken(lookup.tagId),
                entityType: "item",
                entityLabel: "Oggetto · \((lookup.itemPoints ?? 0))pt",
                bindingId: lookup.itemId ?? lookup.bindingId,
                teamLabel: nil,
                entityDetail: nil,
                itemIcon: lookup.itemIcon,
                itemPoints: lookup.itemPoints
            )
        case "player":
            let nickname = (lookup.playerNickname ?? "Giocatore").trimmingCharacters(in: .whitespacesAndNewlines)
            return TagLookupResult(
                tagId: normalizeToken(lookup.tagId),
                entityType: "player",
                entityLabel: "Giocatore · \(nickname.isEmpty ? "Giocatore" : nickname)",
                bindingId: lookup.playerUid ?? lookup.bindingId,
                teamLabel: lookup.teamId,
                entityDetail: nil,
                itemIcon: nil,
                itemPoints: nil
            )
        default:
            return TagLookupResult(
                tagId: normalizeToken(lookup.tagId),
                entityType: "free",
                entityLabel: "Tag libero, non associato in questo game",
                bindingId: lookup.bindingId,
                teamLabel: nil,
                entityDetail: nil,
                itemIcon: nil,
                itemPoints: nil
            )
        }
    }

    private func existingRoleLabel(for lookup: TagLookupResult) -> String {
        switch lookup.entityType {
        case "base":
            return "base \(teamDisplayLabel(for: lookup.teamLabel))"
        case "item":
            return "oggetto"
        case "player":
            return lookup.entityLabel.lowercased()
        default:
            return lookup.entityLabel.lowercased()
        }
    }

    private func gameItem(from lookup: TagLookupResult) -> AdminGameStatus.GameItem? {
        guard lookup.entityType == "item" else { return nil }
        let itemId = lookup.bindingId ?? normalizeToken(lookup.tagId)
        guard !itemId.isEmpty else { return nil }
        return AdminGameStatus.GameItem(
            id: itemId,
            icon: lookup.itemIcon ?? "questionmark.circle",
            points: lookup.itemPoints ?? 0,
            nfcToken: normalizeToken(lookup.tagId)
        )
    }

    private func normalizedTeamId(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    func teamLabel(for teamId: String?) -> String {
        teamDisplayLabel(for: teamId)
    }

    private func teamDisplayLabel(for teamId: String?) -> String {
        switch normalizedTeamId(teamId) {
        case "TEAM_A": return "Giocatori"
        case "TEAM_B": return "Cittadini"
        default: return "team sconosciuto"
        }
    }

    private func setLocalBaseToken(teamId: String, token: String) {
        let normalized = normalizeToken(token)
        if teamId == "TEAM_A" {
            teamABaseToken = normalized
        } else if teamId == "TEAM_B" {
            teamBBaseToken = normalized
        }
        cacheBaseTokens(
            gameId: activeGameId,
            teamA: teamABaseToken,
            teamB: teamBBaseToken
        )
    }

    private func cacheBaseTokens(gameId: String, teamA: String, teamB: String) {
        let normalizedGameId = gameId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedGameId.isEmpty else { return }
        cachedBaseTokensByGameId[normalizedGameId] = (teamA: normalizeToken(teamA), teamB: normalizeToken(teamB))
    }

    private func sortedWithLeaderFirst(_ players: [AdminGameStatus.Participant]) -> [AdminGameStatus.Participant] {
        players.sorted { a, b in
            if a.isLeader && !b.isLeader { return true }
            if !a.isLeader && b.isLeader { return false }
            return a.nickname < b.nickname
        }
    }

    private func nextUniqueIcon() -> String {
        let used = Set(gameItems.map { $0.icon })
        for icon in GameItemIcons.allIcons where !used.contains(icon) {
            return icon
        }
        return "star.circle"
    }

    private func beginItemRegistrationFlow(token: String?, tokenCandidates: [String] = []) {
        let normalized = normalizeToken(token)
        pendingItemConflict = nil
        pendingItemToken = normalized.isEmpty ? nil : normalized
        pendingItemTokenCandidates =
            normalized.isEmpty
            ? []
            : normalizeTagTokenCandidates([normalized] + tokenCandidates)
        newItemPoints = 10
        showItemPointsPrompt = true
    }

    private func upsertGameItem(_ item: AdminGameStatus.GameItem) {
        if let idx = gameItems.firstIndex(where: { tokensMatch($0.id, item.id) }) {
            gameItems[idx] = item
        } else {
            gameItems.append(item)
        }
    }

    private func updatedItem(_ item: AdminGameStatus.GameItem, nfcToken: String) -> AdminGameStatus.GameItem {
        AdminGameStatus.GameItem(
            id: item.id,
            icon: item.icon,
            points: item.points,
            collectorTeamId: item.collectorTeamId,
            nfcToken: normalizeToken(nfcToken),
            qrToken: item.qrToken,
            qrUrl: item.qrUrl,
            registeredAt: item.registeredAt
        )
    }

    func showBaseQRCode(teamId: String) {
        let normalizedTeamId = normalizedTeamId(teamId)
        let token = normalizedTeamId == "TEAM_B" ? teamBBaseQrToken : teamABaseQrToken
        guard !token.isEmpty else { return }
        qrCodePreview = QRCodePreview(
            title: normalizedTeamId == "TEAM_B" ? "QR base Cittadini" : "QR base Giocatori",
            subtitle: "Puoi usare questo codice come alternativa al tag NFC.",
            token: token
        )
    }

    func showItemQRCode(_ item: AdminGameStatus.GameItem) {
        guard let token = item.qrToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            return
        }
        qrCodePreview = QRCodePreview(
            title: "QR oggetto",
            subtitle: "\(item.icon) · \(item.points) pt",
            token: token
        )
    }

    func showInviteQRCode(code: String, isOperator: Bool) {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty else { return }

        qrCodePreview = QRCodePreview(
            title: isOperator ? "QR accesso operatore" : "QR accesso player",
            subtitle: "Mostralo sullo schermo: dall'app si puo inquadrare dalla schermata \"Entra in una partita\" oppure inserire il codice a mano.",
            token: normalizedCode
        )
    }

    private func resolvedGameId(from raw: String?) -> String {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return randomGameId()
    }

    private func randomGameId() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let digits = "0123456789"
        let letterPart = String((0..<3).compactMap { _ in letters.randomElement() })
        let digitPart = String((0..<3).compactMap { _ in digits.randomElement() })
        return letterPart + digitPart
    }

    private func normalizeToken(_ token: String?) -> String {
        normalizeTagToken(token)
    }

    private func tokensMatch(_ lhs: String?, _ rhs: String?) -> Bool {
        let left = normalizeToken(lhs)
        let right = normalizeToken(rhs)
        guard !left.isEmpty, !right.isEmpty else { return false }
        if left == right { return true }
        return tokenComparableHash(left) == tokenComparableHash(right)
    }

    private func tokenComparableHash(_ normalizedToken: String) -> String {
        if isSha256Hex(normalizedToken) {
            return normalizedToken.lowercased()
        }
        return SHA256.hash(data: Data(normalizedToken.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func isSha256Hex(_ value: String) -> Bool {
        guard value.count == 64 else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 48...57, 65...70, 97...102:
                return true
            default:
                return false
            }
        }
    }

    private func isLikelyTokenRegistryConflict(_ message: String) -> Bool {
        let lower = message.lowercased()
        let hasTokenOrTag = lower.contains("token") || lower.contains("tag")
        let hasAlready = lower.contains("already") || lower.contains("già")
        let hasRegistrySignal = lower.contains("exists") || lower.contains("registrat")
        return hasTokenOrTag && (hasAlready || hasRegistrySignal)
    }

    private func runGameAction(logPrefix: String, action: @escaping (String) async throws -> Void) {
        let gameId = activeGameId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gameId.isEmpty else {
            appendLog("Game ID mancante")
            errorMessage = "Game ID mancante"
            return
        }
        guard !isBusy else { return }
        isBusy = true
        errorMessage = ""

        Task {
            defer { isBusy = false }
            do {
                try await action(gameId)
                appendLog("\(logPrefix) OK")
                errorMessage = ""
                await silentRefresh()
            } catch {
                let msg = "\(logPrefix) errore: \(error.localizedDescription)"
                appendLog(msg)
                errorMessage = msg
            }
        }
    }
}

private extension DateFormatter {
    static let adminLogStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

// MARK: – Supporting types

struct GameSummary: Identifiable, Equatable {
    let id: String
    let name: String
    let state: String
    let playerCount: Int
    let isActive: Bool

    var stateLabel: String {
        switch state.uppercased() {
        case "LIVE": return "In corso"
        case "LOBBY": return "Lobby"
        case "DISTRIBUTION": return "Distribution"
        case "ENDED": return "Terminato"
        case "ARCHIVED": return "Archiviato"
        default: return state
        }
    }
}

struct TagLookupResult: Equatable {
    let tagId: String
    let entityType: String       // "base" | "item" | "player" | "free" | "error"
    let entityLabel: String
    let bindingId: String?
    let teamLabel: String?
    let entityDetail: String?
    let itemIcon: String?
    let itemPoints: Int?
}

struct QRCodePreview: Identifiable, Equatable {
    let title: String
    let subtitle: String?
    let token: String

    var id: String { token }
}

struct BaseConflict: Equatable {
    let token: String
    let tokenCandidates: [String]
    let sourceTeamId: String
    let targetTeamId: String
}

enum DesiredTagRole: Equatable {
    case base(teamId: String)
    case newItem
    case existingItem(itemId: String, itemLabel: String?)
}

struct TokenIdentityConflict: Equatable {
    let token: String
    let tokenCandidates: [String]
    let desiredRole: DesiredTagRole
    let existingRoleLabel: String

    var alertMessage: String {
        switch desiredRole {
        case .base(let teamId):
            let team = teamId == "TEAM_A" ? "Giocatori" : "Cittadini"
            return "Questo tag è già associato a \(existingRoleLabel). Vuoi sovrascriverlo come base \(team)?"
        case .newItem:
            return "Questo tag è già associato a \(existingRoleLabel). Vuoi sovrascriverlo e usarlo come oggetto?"
        case .existingItem(_, let itemLabel):
            if let itemLabel, !itemLabel.isEmpty {
                return "Questo tag è già associato a \(existingRoleLabel). Vuoi spostarlo e collegarlo a \(itemLabel)?"
            }
            return "Questo tag è già associato a \(existingRoleLabel). Vuoi spostarlo e collegarlo a questo oggetto?"
        }
    }
}

enum GameItemIcons {
    static let allIcons: [String] = [
        "key.fill", "bolt.fill", "flame.fill", "drop.fill", "leaf.fill",
        "snowflake", "star.fill", "moon.fill", "sun.max.fill", "cloud.fill",
        "heart.fill", "shield.fill", "lock.fill", "bell.fill", "tag.fill",
        "bookmark.fill", "flag.fill", "mappin.fill", "crown.fill", "wand.and.stars",
        "cube.fill", "cylinder.fill", "diamond.fill", "triangle.fill", "octagon.fill"
    ]
}
