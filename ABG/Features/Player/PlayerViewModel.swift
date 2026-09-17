import Combine
import Foundation

@MainActor
final class PlayerViewModel: ObservableObject {
    struct MatchEndSummary: Equatable {
        struct PlayerStanding: Identifiable, Equatable {
            let id: String
            let nickname: String
            let teamId: String
            let teamName: String
            let roleInTeam: String?
            let points: Int
            let isEliminated: Bool
        }

        struct TeamStanding: Identifiable, Equatable {
            let id: String
            let teamId: String
            let teamName: String
            let totalPoints: Int
            let activePlayers: Int
            let eliminatedPlayers: Int
            let players: [PlayerStanding]
        }

        let title: String
        let subtitle: String
        let scoreline: String?
        let personalLabel: String
        let personalPoints: Int
        let teamStandings: [TeamStanding]
        let playerRanking: [PlayerStanding]
        let endedByElimination: Bool
    }

    enum BattleResult {
        case win(delta: Int)
        case lose(delta: Int)
        case tie
        case baseCaptured(amount: Int)
        case baseActivated
        case eliminated
    }

    enum ScanStatus {
        case pending
        case teamSyncPending(seconds: Int)
        case completed(delta: Int)
        case invalidTarget(reason: String)
        case cooldown(seconds: Int)
        case protectedTarget(reason: String)
        case actionBlocked(reason: String)
        case baseCaptured(amount: Int)
        case baseActivated
        case eliminated
    }

    private enum CooldownScope: String {
        case selfCooldown = "SELF"
        case opponent = "OPPONENT"
        case teammate = "TEAMMATE"
        case pair = "PAIR"
    }

    struct ActivityEntry: Identifiable {
        enum Kind {
            case ok
            case warn
            case error
        }

        let id = UUID()
        let timestamp: String
        let message: String
        let kind: Kind
    }

    struct DistributionMember: Identifiable, Equatable {
        let id: String
        let nickname: String
        let avatarDataUrl: String?
        let roleInTeam: String?
        let assignedPoints: Int

        var isLeader: Bool {
            (roleInTeam ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "LEADER"
        }
    }

    @Published var profile: PlayerProfile = .empty
    @Published var snapshot: MatchSnapshot = .placeholder
    @Published var statusMessage = ""
    @Published var manualToken = ""
    @Published var settingsPresented = false
    @Published var isPointsVisible = false
    @Published var pointsDeltaLabel = ""
    @Published var isLoading = false
    @Published var isSavingProfile = false
    @Published var isReadingNFC = false
    @Published var isResolvingScan = false
    @Published var isOffline = false
    private var lastSeenEngagementKey = ""
    // Offset orologio server-locale: il countdown non deve fidarsi del clock del telefono.
    private var serverClockOffsetMs = 0
    @Published var isRegisteringBracelet = false
    @Published var battleResult: BattleResult? = nil
    @Published var currentBattleSummary: ScanBattleSummary? = nil
    @Published var showEliminationOverlay = false
    @Published var matchEndSummary: MatchEndSummary? = nil
    @Published var lastScanStatus: ScanStatus? = nil
    @Published var teamSyncRemainingSec: Int? = nil
    @Published var lastScanContextLabel: String? = nil
    @Published var activityLog: [ActivityEntry] = []
    @Published private(set) var distributionDraftAllocations: [String: Int] = [:]
    @Published var isSubmittingDistribution = false
    @Published var isSettingTeamReady = false
    @Published var isSendingTeamReadyReminder = false
    @Published var distributionErrorMessage = ""
    @Published var distributionSuccessMessage = ""
    @Published var qrCodePreview: QRCodePreview? = nil
    @Published var preMatchAdminStatus: AdminGameStatus? = nil
    @Published var preMatchGameItems: [AdminGameStatus.GameItem] = []
    @Published var preMatchLookupResult: AdminGameStatus.TagLookup? = nil
    @Published var preMatchStatusMessage = ""
    @Published var isUpdatingOwnTeam = false
    @Published var isShufflingTeams = false
    @Published var isScanningPreMatchTag = false

    private let gameService: GameService
    private let authService: AuthService
    private let nfcService: NFCService
    private let initialGameCode: String
    private let isGuestSession: Bool
    private let guestCardCode: String
    private let isPreviewMode: Bool
    private let initialAutonomousSetup: AutonomousGameSetup?
    private var timerTask: Task<Void, Never>?
    private var backendSyncTask: Task<Void, Never>?
    private var transientStatusResetTask: Task<Void, Never>?
    private var pointsDeltaResetTask: Task<Void, Never>?
    private var pendingOutcomeTimeoutTask: Task<Void, Never>?
    private var scanResolutionTimeoutTask: Task<Void, Never>?
    private var isSilentSyncInFlight = false
    private var didAttemptInitialJoin = false
    private var hasSeenLiveMatch = false
    private var hasLoggedMatchEnd = false
    private var userDismissedMatchEnd = false
    private var hasConfirmedServerPoints = false
    private var stateGeneration = 0
    private var consecutiveSilentSyncFailures = 0
    private var lastResolvedBattleSummaryId: String?
    private var hasUnsavedDistributionChanges = false
    private var lastPushRegistrationContext: String?
    private var didAttemptAutomaticTeamAssignment = false

    private static let postBattleBaseTouchReason = "POST_BATTLE_NEEDS_BASE_TOUCH"
    private static let matchStartBaseTouchReason = "MATCH_START_NEEDS_BASE_TOUCH"
    private static let enemyBaseCaptureReason = "ENEMY_BASE_CAPTURE"
    private static let inactivePenaltyBlockReason = "INACTIVE_PENALTY_BLOCK"
    private static let postNFCHandoffDelayNs: UInt64 = 250_000_000
    private static let baseRecoveryReasons: Set<String> = [
        postBattleBaseTouchReason,
        matchStartBaseTouchReason,
        enemyBaseCaptureReason,
        inactivePenaltyBlockReason
    ]

    init(
        gameService: GameService,
        authService: AuthService,
        nfcService: NFCService,
        initialGameCode: String = "",
        isGuestSession: Bool = false,
        guestCardCode: String = "AS",
        isPreviewMode: Bool = false,
        initialAutonomousSetup: AutonomousGameSetup? = nil
    ) {
        self.gameService = gameService
        self.authService = authService
        self.nfcService = nfcService
        self.initialGameCode = initialGameCode.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isGuestSession = isGuestSession
        self.guestCardCode = PlayingCardCatalog.normalizeCode(guestCardCode)
        self.isPreviewMode = isPreviewMode
        self.initialAutonomousSetup = initialAutonomousSetup
    }

    var cardImageURL: URL? {
        let raw = PlayingCardCatalog.imageURLString(for: displayCardCode)
        return URL(string: raw)
    }

    var displayCardCode: String {
        let liveCode = PlayingCardCatalog.normalizeCode(snapshot.playingCard ?? "")
        if !liveCode.isEmpty {
            return liveCode
        }
        return profile.resolvedCardCode
    }

    var displayCardDeckIndex: Int? {
        snapshot.identityDeckIndex ?? profile.identityDeckIndex
    }

    var canUseNFC: Bool {
        nfcService.isSupported
    }

    var isQRCodeEnabled: Bool {
        snapshot.scanMode.isQREnabled
    }

    var primaryActionTitle: String {
        if isMatchClosed {
            return "MATCH CHIUSO"
        }
        if !snapshot.isJoined {
            return "Riprova ingresso"
        }
        if snapshot.scanMode == .bracelet {
            return isReadingNFC ? "SCANNING..." : "GIOCA"
        }
        return "GIOCA"
    }

    var canPerformGameAction: Bool {
        snapshot.state.uppercased() == "LIVE" &&
        snapshot.battleStatus.uppercased() == "ACTIVE" &&
        (snapshot.cooldownRemainingSec ?? 0) <= 0
    }

    var canPerformBaseRecoveryAction: Bool {
        guard snapshot.isJoined else { return false }
        guard snapshot.state.uppercased() == "LIVE" else { return false }
        guard snapshot.battleStatus.uppercased() == "INACTIVE" else { return false }
        guard (snapshot.cooldownRemainingSec ?? 0) <= 0 else { return false }

        let reason = snapshot.inactiveReason?.uppercased() ?? ""
        return Self.baseRecoveryReasons.contains(reason)
    }

    var requiresBaseTouchReactivation: Bool {
        canPerformBaseRecoveryAction
    }

    var canTriggerPrimaryAction: Bool {
        if isReadingNFC || isResolvingScan {
            return false
        }
        if !snapshot.isJoined {
            return true
        }
        return canPerformGameAction || canPerformBaseRecoveryAction
    }

    var canSubmitManualBraceletToken: Bool {
        !normalizeToken(manualToken).isEmpty && !isRegisteringBracelet && canRegisterPlayerTag
    }

    var canScanWithQRCode: Bool {
        isQRCodeEnabled &&
        snapshot.isJoined &&
        !snapshot.gameId.isEmpty &&
        !isReadingNFC &&
        !isResolvingScan &&
        (canPerformGameAction || canPerformBaseRecoveryAction)
    }

    var canShowPersonalQRCode: Bool {
        snapshot.isJoined && isQRCodeEnabled && !normalizeToken(snapshot.qrToken).isEmpty
    }

    var scoreboardTeams: [MatchEndSummary.TeamStanding] {
        buildScoreboardData().teams
    }

    private var currentGameBraceletToken: String? {
        let liveToken = normalizeToken(snapshot.braceletToken)
        if snapshot.isJoined {
            return liveToken.isEmpty ? nil : liveToken
        }
        if !liveToken.isEmpty {
            return liveToken
        }
        let profileToken = normalizeToken(profile.preferredBraceletToken)
        return profileToken.isEmpty ? nil : profileToken
    }

    var maskedBraceletToken: String {
        maskToken(currentGameBraceletToken)
    }

    var canRegisterPlayerTag: Bool {
        currentGameBraceletToken == nil
    }

    var hasPenaltyBlock: Bool {
        (snapshot.cooldownRemainingSec ?? 0) > 0
    }

    var hasBaseDefenseWindow: Bool {
        (snapshot.baseDefenseRemainingSec ?? 0) > 0
    }

    var hasBaseDefenseCooldownWindow: Bool {
        (snapshot.baseDefenseCooldownRemainingSec ?? 0) > 0
    }

    var baseDetailTeamId: String? {
        if let teamId = snapshot.teamId?.trimmingCharacters(in: .whitespacesAndNewlines), !teamId.isEmpty {
            return teamId
        }
        if let teamId = profile.teamId?.trimmingCharacters(in: .whitespacesAndNewlines), !teamId.isEmpty {
            return teamId
        }
        return nil
    }

    var canShowBaseDetails: Bool {
        snapshot.isJoined && baseDetailTeamId != nil
    }

    var battleStateTitle: String {
        if isMatchClosed {
            return "Match chiuso"
        }
        switch snapshot.battleStatus.uppercased() {
        case "ACTIVE":
            return hasBaseDefenseWindow ? "Base potenziata" : "Attivo"
        case "ELIMINATED":
            return "Eliminato"
        default:
            if hasBaseDefenseWindow {
                return "Base potenziata"
            }
            return hasPenaltyBlock ? "Bloccato" : "Inattivo"
        }
    }

    var battleStateDetail: String {
        if isMatchClosed {
            return "La partita e terminata. Non sono piu disponibili azioni di gioco."
        }

        if snapshot.battleStatus.uppercased() == "ELIMINATED" {
            return "Hai esaurito i punti e non puoi piu partecipare agli scontri."
        }

        if let cooldown = snapshot.cooldownRemainingSec, cooldown > 0 {
            return "Blocco penalty attivo per \(formatDuration(cooldown)). La base non puo sbloccarti prima della scadenza."
        }

        if let baseDefense = snapshot.baseDefenseRemainingSec, baseDefense > 0 {
            return "La tua base e potenziata ancora per \(formatDuration(baseDefense)). Gli assalti alla base vengono risolti contro la sua difesa attiva."
        }

        switch snapshot.inactiveReason?.uppercased() {
        case "POST_BATTLE_NEEDS_BASE_TOUCH":
            return "Dopo lo scontro devi toccare la tua base per tornare attivo."
        case "ENEMY_BASE_CAPTURE":
            return "Hai catturato la base nemica: ora devi tornare alla tua base."
        case "MATCH_START_NEEDS_BASE_TOUCH":
            return "Il match e live: tocca la tua base per entrare in gioco."
        default:
            return snapshot.battleStatus.uppercased() == "ACTIVE"
                ? "Premi Gioca e fai una sola lettura NFC: il backend decide l'esito."
                : "Tocca la tua base per riattivarti prima di un nuovo scontro."
        }
    }

    var isMatchClosed: Bool {
        shouldTreatMatchAsEnded(snapshot)
    }

    var isDistributionPhase: Bool {
        snapshot.state.uppercased() == "DISTRIBUTION"
    }

    var isLobbyPhase: Bool {
        snapshot.state.uppercased() == "LOBBY"
    }

    var isPreMatchPhase: Bool {
        isLobbyPhase || isDistributionPhase
    }

    var resolvedAutonomousSetup: AutonomousGameSetup {
        if snapshot.hasAutonomousSetup {
            return snapshot.autonomousSetup
        }
        if let preMatchAdminStatus, preMatchAdminStatus.hasAutonomousSetup {
            return preMatchAdminStatus.autonomousSetup
        }
        if let initialAutonomousSetup {
            return initialAutonomousSetup
        }
        if let persisted = AutonomousGamePreferencesStore.load(for: snapshot.gameId.nonEmpty ?? initialGameCode) {
            return persisted
        }
        return .gameMasterDefault
    }

    var isAutonomousMatch: Bool {
        resolvedAutonomousSetup.isAutonomous
    }

    var requiresBraceletRegistrationGate: Bool {
        snapshot.isJoined && !isMatchClosed && currentGameBraceletToken == nil
    }

    var currentTeamId: String? {
        let value = normalizedTeamId(snapshot.teamId ?? profile.teamId)
        return value.isEmpty ? nil : value
    }

    var teamAParticipants: [MatchSnapshot.Participant] {
        orderedParticipants(for: "TEAM_A")
    }

    var teamBParticipants: [MatchSnapshot.Participant] {
        orderedParticipants(for: "TEAM_B")
    }

    var unassignedParticipants: [MatchSnapshot.Participant] {
        snapshot.participants
            .filter { normalizedTeamId($0.teamId).isEmpty }
            .sorted { $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending }
    }

    var isCurrentPlayerCreator: Bool {
        let creatorUid = resolvedAutonomousSetup.creatorUid?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let ownUid = profile.uid.trimmingCharacters(in: .whitespacesAndNewlines)
        return !creatorUid.isEmpty && creatorUid == ownUid
    }

    var canSelectOwnTeamManually: Bool {
        isPreMatchPhase &&
        snapshot.isJoined &&
        isAutonomousMatch &&
        resolvedAutonomousSetup.allowsManualTeamSelection &&
        !isUpdatingOwnTeam
    }

    var canShuffleTeams: Bool {
        isPreMatchPhase &&
        snapshot.isJoined &&
        resolvedAutonomousSetup.allowsRandomTeamAssignment &&
        isCurrentPlayerCreator &&
        !isShufflingTeams
    }

    var canScanPreMatchTags: Bool {
        snapshot.isJoined &&
        isPreMatchPhase &&
        !isScanningPreMatchTag &&
        !requiresBraceletRegistrationGate
    }

    var currentTeamBaseTokenMasked: String {
        guard let preMatchAdminStatus, let teamId = currentTeamId else { return "-" }
        switch normalizedTeamId(teamId) {
        case "TEAM_A":
            return maskToken(preMatchAdminStatus.teamABaseToken)
        case "TEAM_B":
            return maskToken(preMatchAdminStatus.teamBBaseToken)
        default:
            return "-"
        }
    }

    var currentTeamBaseIsRegistered: Bool {
        guard let preMatchAdminStatus, let teamId = currentTeamId else { return false }
        switch normalizedTeamId(teamId) {
        case "TEAM_A":
            return !(preMatchAdminStatus.teamABaseToken ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case "TEAM_B":
            return !(preMatchAdminStatus.teamBBaseToken ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }

    var currentTeamSetupItems: [AdminGameStatus.GameItem] {
        guard let teamId = currentTeamId else { return [] }
        if itemModeForPreMatch == .crossTeam {
            return preMatchGameItems.filter { normalizedTeamId($0.collectorTeamId) != normalizedTeamId(teamId) }
        }
        return preMatchGameItems
    }

    var pendingCurrentTeamSetupItems: [AdminGameStatus.GameItem] {
        currentTeamSetupItems.filter { ($0.nfcToken ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var itemModeForPreMatch: ItemMode {
        preMatchAdminStatus?.itemMode ?? .none
    }

    var canEditTeamDistribution: Bool {
        isDistributionPhase && snapshot.isCurrentPlayerLeader
    }

    var distributionTotalPool: Int {
        10_000
    }

    var distributionMembers: [DistributionMember] {
        let allocations = currentDistributionAllocations()
        return distributionTeamParticipants().map { participant in
            DistributionMember(
                id: participant.id,
                nickname: participant.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Giocatore" : participant.nickname,
                avatarDataUrl: participant.avatarDataUrl,
                roleInTeam: participant.roleInTeam,
                assignedPoints: allocations[participant.id] ?? 0
            )
        }
    }

    var distributionAllocatedPoints: Int {
        currentDistributionAllocations().values.reduce(0, +)
    }

    var distributionRemainingPoints: Int {
        distributionTotalPool - distributionAllocatedPoints
    }

    var canSubmitTeamDistribution: Bool {
        canEditTeamDistribution &&
        !distributionMembers.isEmpty &&
        distributionRemainingPoints >= 0 &&
        !isSubmittingDistribution
    }

    var canToggleTeamReady: Bool {
        canEditTeamDistribution &&
        snapshot.teamDistributionSubmitted &&
        !hasUnsavedDistributionChanges &&
        !isSubmittingDistribution &&
        !isSettingTeamReady
    }

    var shouldShowTeamReadyReminder: Bool {
        isDistributionPhase &&
        snapshot.teamReadyForLive &&
        !snapshot.opponentTeamReadyForLive &&
        !snapshot.allTeamsReadyForLive &&
        currentTeamId != nil
    }

    var canSendTeamReadyReminder: Bool {
        shouldShowTeamReadyReminder &&
        !isSendingTeamReadyReminder
    }

    func onAppear() {
        guard !isPreviewMode else { return }
        Task {
            await refreshAll()
            await tryInitialJoinIfNeeded()
        }
        startTimerLoop()
        startBackendSyncLoop()
    }

    func onDisappear() {
        guard !isPreviewMode else { return }
        timerTask?.cancel()
        timerTask = nil
        backendSyncTask?.cancel()
        backendSyncTask = nil
        transientStatusResetTask?.cancel()
        transientStatusResetTask = nil
        pendingOutcomeTimeoutTask?.cancel()
        pendingOutcomeTimeoutTask = nil
    }

    func refreshAll(
        updateStatusMessage: Bool = true,
        showLoading: Bool = true,
        silentOnError: Bool = false,
        preferredPoints: Int? = nil
    ) async {
        if showLoading {
            isLoading = true
        }
        defer {
            if showLoading {
                isLoading = false
            }
        }

        let capturedGeneration = stateGeneration
        do {
            // Task espliciti invece di async let: il teardown del child task di
            // async let abortiva in Release su device (asyncLet_finish_after_task_completion)
            // dentro le callable Firebase. Percorso caldo: la parallelismo resta.
            let profileFetch = Task { [gameService] in try await gameService.fetchOwnProfile() }
            let matchFetch = Task { [gameService, initialGameCode] in
                try await gameService.fetchMatchSnapshot(gameId: initialGameCode.nonEmpty)
            }
            let fetchedProfile = try await profileFetch.value
            let fetchedSnapshot = try await matchFetch.value
            let scoreboardParticipants: [MatchSnapshot.Participant]
            if let gameId = fetchedSnapshot.gameId.nonEmpty {
                scoreboardParticipants = (try? await gameService.fetchTeamParticipants(gameId: gameId)) ?? []
            } else {
                scoreboardParticipants = []
            }

            consecutiveSilentSyncFailures = 0
            isOffline = false

            // Una scan/join locale partita durante il fetch ha già aggiornato lo stato:
            // questo risultato è superato e non va applicato sopra.
            guard capturedGeneration == stateGeneration else { return }

            let previousPoints = profile.points
            let previousSnapshot = snapshot
            applyFetchedState(
                fetchedProfile: fetchedProfile,
                fetchedSnapshot: enrichedSnapshot(
                    fetchedSnapshot,
                    scoreboardParticipants: scoreboardParticipants
                ),
                preferredPoints: preferredPoints
            )
            await ensurePlayerQRCodeIfNeeded()
            await refreshPreMatchSupportDataIfNeeded()
            await autoAssignRandomTeamIfNeeded()
            await syncPushRegistrationIfNeeded()
            showPointsDeltaIfNeeded(previous: previousPoints, current: profile.points)
            reconcilePendingStateIfNeeded(
                previousSnapshot: previousSnapshot,
                previousPoints: previousPoints
            )
            updateMatchEndStateIfNeeded()
            syncDistributionDraftIfNeeded(
                profile: profile,
                snapshot: snapshot
            )

            if updateStatusMessage && !isMatchClosed && !isDistributionPhase {
                statusMessage = "Profilo aggiornato"
            }
        } catch {
            guard !silentOnError else {
                consecutiveSilentSyncFailures += 1
                if consecutiveSilentSyncFailures >= 3 {
                    isOffline = true
                }
                return
            }
            statusMessage = "Errore refresh: \(error.localizedDescription)"
            appendLog("Refresh fallito", kind: .error)
        }
    }

    func performPrimaryAction() {
        if !snapshot.isJoined {
            Task { await tryInitialJoinIfNeeded(forceRetry: true) }
            return
        }

        let canStartScan = canPerformGameAction || canPerformBaseRecoveryAction
        guard canStartScan else {
            if snapshot.battleStatus.uppercased() == "ELIMINATED" {
                statusMessage = "Sei eliminato: non puoi piu combattere in questo match."
                lastScanStatus = .eliminated
                appendLog(statusMessage, kind: .error)
                return
            }
            if let cooldown = snapshot.cooldownRemainingSec, cooldown > 0 {
                statusMessage = "Cooldown attivo. Riprova tra \(formatDuration(cooldown))."
                lastScanStatus = .cooldown(seconds: cooldown)
                appendLog(statusMessage, kind: .warn)
                return
            }
            if snapshot.state.uppercased() != "LIVE" {
                statusMessage = "Partita non attiva. La scansione si abilita solo in fase live."
                lastScanStatus = .actionBlocked(reason: statusMessage)
                appendLog(statusMessage, kind: .warn)
                return
            }
            statusMessage = "Azione temporaneamente non disponibile."
            lastScanStatus = .actionBlocked(reason: statusMessage)
            appendLog(statusMessage, kind: .warn)
            return
        }

        // NFC is the only allowed path in this build.
        playWithNFC()
    }

    func joinActiveGame() {
        guard !isLoading else { return }
        guard !initialGameCode.isEmpty else {
            statusMessage = "Inserisci un codice partita in lobby"
            return
        }

        isLoading = true
        stateGeneration += 1
        let fallbackNickname = authService.currentUser?.displayName
            ?? authService.currentUser?.email?.split(separator: "@").first.map(String.init)
            ?? "Player iOS"
        let nickname = profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? fallbackNickname
            : profile.nickname

        Task {
            defer { isLoading = false }
            do {
                // Guests must have profileCompleted=true server-side before joining.
                // Auto-complete with minimal values so the server allows the join.
                if isGuestSession {
                    try await ensureGuestProfileCompleted(nickname: nickname)
                }
                snapshot = try await gameService.joinSelectedGame(
                    gameId: initialGameCode,
                    nickname: nickname,
                    asLockedGameMaster: false
                )
                await ensurePlayerQRCodeIfNeeded()
                await syncPushRegistrationIfNeeded(force: true)
                statusMessage = "Ingresso nel game completato"
                appendLog(statusMessage, kind: .ok)
                await refreshAll(updateStatusMessage: false)
            } catch {
                statusMessage = "Errore ingresso game: \(error.localizedDescription)"
                appendLog(statusMessage, kind: .error)
            }
        }
    }

    func playWithNFC() {
        guard snapshot.isJoined else {
            statusMessage = "Entra prima nel game attivo"
            return
        }
        guard !snapshot.gameId.isEmpty else {
            statusMessage = "Game ID non disponibile"
            return
        }

        guard nfcService.isSupported else {
            statusMessage = "NFC non disponibile su questo iPhone"
            return
        }

        guard !isReadingNFC && !isResolvingScan else { return }
        stateGeneration += 1
        transientStatusResetTask?.cancel()
        lastScanContextLabel = nil
        currentBattleSummary = nil

        Task {
            var didReadTag = false
            do {
                let previousPoints = profile.points
                isReadingNFC = true
                let tagRead = try await nfcService.readTag(prompt: "Avvicina il braccialetto")
                didReadTag = true
                isReadingNFC = false
                try? await Task.sleep(nanoseconds: Self.postNFCHandoffDelayNs)
                isResolvingScan = true
                scheduleScanResolutionTimeout()
                lastScanStatus = .pending
                statusMessage = "Tag letto. Sto calcolando l'esito."
                appendLog("Tag letto, calcolo esito in corso.", kind: .warn)
                let outcome = try await gameService.submitScan(
                    gameId: snapshot.gameId,
                    token: tagRead.primaryToken,
                    tokenCandidates: tagRead.candidates,
                    source: "nfc"
                )
                cancelScanResolutionTimeout()
                isResolvingScan = false
                handleScanOutcome(outcome, previousPoints: previousPoints)
                await refreshAll(
                    updateStatusMessage: false,
                    showLoading: false,
                    silentOnError: true,
                    preferredPoints: profile.points
                )
            } catch {
                isReadingNFC = false
                cancelScanResolutionTimeout()
                isResolvingScan = false
                let prefix = didReadTag ? "Conferma azione fallita" : "Lettura NFC fallita"
                statusMessage = "\(prefix): \(error.localizedDescription)"
                lastScanStatus = .actionBlocked(reason: statusMessage)
                appendLog(statusMessage, kind: .error)
                scheduleTransientStatusReset(after: 1.8)
            }
        }
    }

    func playWithQRCode(_ token: String) {
        guard snapshot.isJoined else {
            statusMessage = "Entra prima nel game attivo"
            return
        }
        guard !snapshot.gameId.isEmpty else {
            statusMessage = "Game ID non disponibile"
            return
        }
        guard isQRCodeEnabled else {
            statusMessage = "QR non attivo in questo game"
            return
        }

        let normalizedToken = normalizeToken(token)
        guard !normalizedToken.isEmpty else {
            statusMessage = "QR non valido"
            appendLog(statusMessage, kind: .warn)
            return
        }

        guard !isReadingNFC && !isResolvingScan else { return }
        stateGeneration += 1
        transientStatusResetTask?.cancel()
        lastScanContextLabel = nil
        currentBattleSummary = nil

        Task {
            do {
                let previousPoints = profile.points
                isResolvingScan = true
                scheduleScanResolutionTimeout()
                lastScanStatus = .pending
                statusMessage = "QR letto. Sto calcolando l'esito."
                appendLog("QR letto, calcolo esito in corso.", kind: .warn)
                let outcome = try await gameService.submitScan(
                    gameId: snapshot.gameId,
                    token: normalizedToken,
                    tokenCandidates: [normalizedToken],
                    source: "qr"
                )
                cancelScanResolutionTimeout()
                isResolvingScan = false
                handleScanOutcome(outcome, previousPoints: previousPoints)
                await refreshAll(
                    updateStatusMessage: false,
                    showLoading: false,
                    silentOnError: true,
                    preferredPoints: profile.points
                )
            } catch {
                cancelScanResolutionTimeout()
                isResolvingScan = false
                statusMessage = "Conferma azione QR fallita: \(error.localizedDescription)"
                lastScanStatus = .actionBlocked(reason: statusMessage)
                appendLog(statusMessage, kind: .error)
                scheduleTransientStatusReset(after: 1.8)
            }
        }
    }

    func showPersonalQRCode() {
        let token = normalizeToken(snapshot.qrToken)
        guard !token.isEmpty else { return }
        qrCodePreview = QRCodePreview(
            title: "Il tuo QR code",
            subtitle: "Gli altri player possono usarlo per completare scontri, battaglie e interazioni.",
            token: token
        )
    }

    func registerBraceletFromNFC() {
        guard canRegisterPlayerTag else {
            statusMessage = "Tag giocatore già attivato: non può essere modificato."
            appendLog(statusMessage, kind: .warn)
            return
        }
        guard nfcService.isSupported else {
            statusMessage = "NFC non disponibile su questo iPhone"
            appendLog(statusMessage, kind: .warn)
            return
        }
        guard !isRegisteringBracelet && !isReadingNFC else { return }

        isRegisteringBracelet = true
        Task {
            defer { isRegisteringBracelet = false }
            do {
                let tagRead = try await nfcService.readTag(prompt: "Avvicina il tuo braccialetto")
                try await registerBraceletToken(
                    tagRead.primaryToken,
                    tokenCandidates: tagRead.candidates,
                    source: "nfc"
                )
            } catch {
                statusMessage = "Registrazione braccialetto fallita: \(error.localizedDescription)"
                appendLog(statusMessage, kind: .error)
            }
        }
    }

    func registerBraceletFromManualInput() {
        guard canRegisterPlayerTag else {
            statusMessage = "Tag giocatore già attivato: non può essere modificato."
            appendLog(statusMessage, kind: .warn)
            return
        }
        let normalized = normalizeToken(manualToken)
        guard !normalized.isEmpty else {
            statusMessage = "Inserisci un token valido"
            appendLog(statusMessage, kind: .warn)
            return
        }
        guard !isRegisteringBracelet else { return }

        isRegisteringBracelet = true
        Task {
            defer { isRegisteringBracelet = false }
            do {
                try await registerBraceletToken(normalized, source: "manuale")
            } catch {
                statusMessage = "Registrazione braccialetto fallita: \(error.localizedDescription)"
                appendLog(statusMessage, kind: .error)
            }
        }
    }

    func cancelNFCScan() {
        nfcService.cancelReading()
        statusMessage = "Scansione annullata"
        appendLog(statusMessage, kind: .warn)
    }

    func clearBattleResult() {
        battleResult = nil
        currentBattleSummary = nil
        lastScanContextLabel = nil
    }

    func dismissMatchEndSummary() {
        matchEndSummary = nil
        userDismissedMatchEnd = true
    }

    func dismissEliminationOverlay() {
        showEliminationOverlay = false
    }

    func saveProfile(onComplete: ((Bool) -> Void)? = nil) {
        guard !isSavingProfile else { return }
        profile.nickname = sanitizeProfileNickname(profile.nickname)
        profile.avatarDataUrl = sanitizeProfileAvatar(profile.avatarDataUrl)
        isSavingProfile = true

        Task {
            defer { isSavingProfile = false }
            do {
                try await gameService.savePlayerProfile(profile)
                statusMessage = "Profilo salvato"
                appendLog(statusMessage, kind: .ok)
                onComplete?(true)
            } catch {
                statusMessage = "Errore salvataggio: \(error.localizedDescription)"
                appendLog(statusMessage, kind: .error)
                onComplete?(false)
            }
        }
    }

    func logout() async {
        do {
            try await authService.signOut()
        } catch {
            statusMessage = "Logout fallito: \(error.localizedDescription)"
        }
    }

    private func startTimerLoop() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if snapshot.state.uppercased() == "LIVE" {
                    if let liveEndsAtMs = snapshot.liveEndsAtMs {
                        let nowMs = Int(Date().timeIntervalSince1970 * 1000) + serverClockOffsetMs
                        let remainingMs = max(0, liveEndsAtMs - nowMs)
                        snapshot.remainingSec = Int(ceil(Double(remainingMs) / 1000.0))
                    } else if snapshot.remainingSec > 0 {
                        snapshot.remainingSec -= 1
                    }
                    // A timer zero NON si forza ENDED: la chiusura arriva solo dallo
                    // stato server al poll successivo (clock skew non deve chiudere il match).
                    if snapshot.remainingSec < 0 {
                        snapshot.remainingSec = 0
                    }
                }
                if let cooldown = snapshot.cooldownRemainingSec, cooldown > 0 {
                    let nextCooldown = max(0, cooldown - 1)
                    snapshot.cooldownRemainingSec = nextCooldown
                    if nextCooldown == 0, case .some(.cooldown) = lastScanStatus {
                        lastScanStatus = nil
                    }
                }
                if case .some(.teamSyncPending) = lastScanStatus,
                   let teamSyncRemainingSec,
                   teamSyncRemainingSec > 0 {
                    self.teamSyncRemainingSec = max(0, teamSyncRemainingSec - 1)
                }
                if let baseDefense = snapshot.baseDefenseRemainingSec, baseDefense > 0 {
                    let nextBaseDefense = max(0, baseDefense - 1)
                    snapshot.baseDefenseRemainingSec = nextBaseDefense > 0 ? nextBaseDefense : nil
                    if nextBaseDefense == 0 {
                        snapshot.baseDefensePoints = nil
                    }
                } else if let baseDefenseCooldown = snapshot.baseDefenseCooldownRemainingSec,
                          baseDefenseCooldown > 0 {
                    let nextBaseDefenseCooldown = max(0, baseDefenseCooldown - 1)
                    snapshot.baseDefenseCooldownRemainingSec =
                        nextBaseDefenseCooldown > 0 ? nextBaseDefenseCooldown : nil
                }
                updateMatchEndStateIfNeeded()
            }
        }
    }

    private func startBackendSyncLoop() {
        backendSyncTask?.cancel()
        backendSyncTask = Task {
            while !Task.isCancelled {
                let interval = backendSyncInterval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled {
                    break
                }
                await silentSyncFromBackend()
            }
        }
    }

    private var backendSyncInterval: Double {
        switch lastScanStatus {
        case .pending:
            return 1
        case .teamSyncPending(let seconds):
            let remaining = max(1, teamSyncRemainingSec ?? seconds)
            return remaining > 3 ? 1.5 : 1
        default:
            break
        }
        if isDistributionPhase, snapshot.isJoined {
            return 3
        }
        if snapshot.state.uppercased() == "LIVE", snapshot.isJoined {
            return 3
        }
        return 15
    }

    private func silentSyncFromBackend() async {
        guard snapshot.isJoined else { return }
        guard !isLoading && !isReadingNFC && !isResolvingScan && !isSilentSyncInFlight else { return }
        isSilentSyncInFlight = true
        defer { isSilentSyncInFlight = false }
        await refreshAll(
            updateStatusMessage: false,
            showLoading: false,
            silentOnError: true
        )
    }

    private func tryInitialJoinIfNeeded(forceRetry: Bool = false) async {
        guard !snapshot.isJoined else { return }
        guard !initialGameCode.isEmpty else { return }
        if didAttemptInitialJoin && !forceRetry {
            return
        }
        didAttemptInitialJoin = true
        joinActiveGame()
    }

    private func applyFetchedState(
        fetchedProfile: PlayerProfile,
        fetchedSnapshot: MatchSnapshot,
        preferredPoints: Int?
    ) {
        var mergedProfile = fetchedProfile
        let normalizedSnapshot = normalizedSnapshotLifecycle(fetchedSnapshot)

        if let livePoints = normalizedSnapshot.points {
            mergedProfile.points = livePoints
            hasConfirmedServerPoints = true
        } else if let preferredPoints {
            mergedProfile.points = preferredPoints
        }
        if let liveTeam = normalizedSnapshot.teamId?.nonEmpty {
            mergedProfile.teamId = liveTeam
        }
        if let liveRole = normalizedSnapshot.roleInTeam?.nonEmpty {
            mergedProfile.roleInTeam = liveRole
        }
        if normalizedSnapshot.isJoined {
            mergedProfile.preferredBraceletToken = normalizedSnapshot.braceletToken
            mergedProfile.identityCardCode = normalizedSnapshot.playingCard
            mergedProfile.identityDeckIndex = normalizedSnapshot.identityDeckIndex
        }

        profile = mergedProfile
        snapshot = normalizedSnapshot
        let closedState = normalizedSnapshot.state.uppercased()
        if closedState != "ENDED" && closedState != "ARCHIVED" {
            userDismissedMatchEnd = false
        }
        if let serverNowMs = normalizedSnapshot.serverNowMs {
            serverClockOffsetMs = serverNowMs - Int(Date().timeIntervalSince1970 * 1000)
        }
        notifyIncomingEngagementIfNeeded(normalizedSnapshot)
    }

    // Il bersaglio di un duello pendente deve accorgersene anche senza guardare
    // lo schermo: haptic pesante alla prima comparsa dell'ingaggio.
    private func notifyIncomingEngagementIfNeeded(_ snapshot: MatchSnapshot) {
        guard let engagement = snapshot.incomingEngagement else { return }
        let key = "\(engagement.attackerId)-\(engagement.expiresAtMs)"
        guard key != lastSeenEngagementKey else { return }
        lastSeenEngagementKey = key
        guard !matchesPendingState else { return }
        HapticManager.heavyImpact()
        HapticManager.warning()
    }

    var incomingEngagement: MatchSnapshot.IncomingEngagement? {
        guard let engagement = snapshot.incomingEngagement else { return nil }
        guard !matchesPendingState else { return nil }
        return engagement
    }

    private func showPointsDeltaIfNeeded(previous: Int, current: Int) {
        let delta = current - previous
        guard delta != 0 else { return }

        pointsDeltaLabel = delta > 0 ? "+\(delta)" : "\(delta)"
        pointsDeltaResetTask?.cancel()
        pointsDeltaResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.pointsDeltaLabel = ""
            }
        }
    }

    private func reconcilePendingStateIfNeeded(
        previousSnapshot: MatchSnapshot,
        previousPoints: Int
    ) {
        if let summary = snapshot.lastBattleSummary,
           summary.summaryId != lastResolvedBattleSummaryId,
           previousSnapshot.lastBattleSummary?.summaryId != summary.summaryId ||
            currentBattleSummary?.summaryId != summary.summaryId ||
            matchesPendingState {
            cancelPendingOutcomeTimeout()
            presentResolvedBattle(
                summary: summary,
                fallbackDelta: summary.viewerDelta,
                fallbackOpponentName: summary.opposingSideData.label,
                synced: true
            )
            return
        }

        guard matchesPendingState else { return }

        let currentPoints = profile.points
        let pointsDelta = currentPoints - previousPoints
        let battleChanged = previousSnapshot.battleStatus.uppercased() != snapshot.battleStatus.uppercased()
        let pointsChanged = currentPoints != previousPoints

        guard battleChanged || pointsChanged else { return }

        switch snapshot.battleStatus.uppercased() {
        case "ELIMINATED":
            cancelPendingOutcomeTimeout()
            lastScanStatus = .eliminated
            battleResult = .eliminated
            currentBattleSummary = nil
            showEliminationOverlay = true
            statusMessage = "Esito scontro aggiornato dal backend: eliminato."
            appendLog(statusMessage, kind: .error)
        case "INACTIVE":
            cancelPendingOutcomeTimeout()
            presentResolvedBattle(
                summary: nil,
                fallbackDelta: pointsDelta,
                fallbackOpponentName: nil,
                synced: true
            )
        default:
            break
        }
    }

    private func handleScanOutcome(_ outcome: ScanSubmissionOutcome, previousPoints: Int) {
        cancelPendingOutcomeTimeout()
        let opponentName = displayName(for: outcome.opponentUid)
        let status = normalizeScanStatus(outcome.status)
        let cooldownScope = resolvedCooldownScope(for: outcome, status: status)
        lastScanContextLabel = battleContextLabel(for: outcome.battleSummary, fallbackOpponentName: opponentName)
        currentBattleSummary = outcome.battleSummary

        if let ownPoints = outcome.ownPoints {
            profile.points = ownPoints
            hasConfirmedServerPoints = true
        }
        if let serverBattleStatus = outcome.battleStatus?.nonEmpty {
            snapshot.battleStatus = serverBattleStatus.uppercased()
            if snapshot.battleStatus.uppercased() == "ACTIVE" {
                snapshot.inactiveReason = nil
            }
        }
        if let inactiveReason = outcome.inactiveReason {
            snapshot.inactiveReason = inactiveReason.nonEmpty
        }
        if let cooldownRemainingSec = outcome.cooldownRemainingSec,
           shouldPersistCooldown(for: outcome, status: status, scope: cooldownScope) {
            snapshot.cooldownRemainingSec = max(0, cooldownRemainingSec)
        }
        if let battleSummary = outcome.battleSummary {
            snapshot.lastBattleSummary = battleSummary
        }
        if hasConfirmedServerPoints && profile.points <= 0 {
            snapshot.battleStatus = "ELIMINATED"
        }

        let delta = profile.points - previousPoints

        switch status {
        case "BASE_ACTIVATED":
            snapshot.battleStatus = "ACTIVE"
            snapshot.inactiveReason = nil
            snapshot.cooldownRemainingSec = nil
            snapshot.baseDefenseRemainingSec = normalizedOptionalSeconds(outcome.baseDefenseRemainingSec)
            snapshot.baseDefenseCooldownRemainingSec =
                normalizedOptionalSeconds(outcome.baseDefenseCooldownRemainingSec)
            snapshot.baseDefensePoints = normalizedOptionalPoints(outcome.baseDefensePoints)
            currentBattleSummary = nil
            snapshot.lastBattleSummary = nil
            lastScanStatus = .baseActivated
            battleResult = .baseActivated
            statusMessage = outcome.reason?.nonEmpty ?? "Base registrata: sei di nuovo attivo."
            appendLog(statusMessage, kind: .ok)
            scheduleTransientStatusReset(after: 2.2)

        case "BASE_CAPTURED":
            let baseDelta = outcome.amount ?? delta
            snapshot.battleStatus = outcome.battleStatus?.nonEmpty ?? "INACTIVE"
            snapshot.inactiveReason = outcome.inactiveReason?.nonEmpty
                ?? (baseDelta >= 0 ? Self.enemyBaseCaptureReason : Self.postBattleBaseTouchReason)
            snapshot.cooldownRemainingSec = nil
            currentBattleSummary = nil
            snapshot.lastBattleSummary = nil
            if baseDelta >= 0 {
                let gained = max(0, baseDelta)
                lastScanStatus = .baseCaptured(amount: gained)
                battleResult = .baseCaptured(amount: gained)
                statusMessage = outcome.reason?.nonEmpty ?? enemyBaseCaptureMessage(points: gained)
                appendLog(statusMessage, kind: .ok)
            } else {
                let lost = abs(baseDelta)
                lastScanStatus = .completed(delta: -lost)
                battleResult = .lose(delta: lost)
                statusMessage = outcome.reason?.nonEmpty ?? "Assalto alla base fallito (\(signedDelta(-lost)) punti)."
                appendLog(statusMessage, kind: .warn)
            }
            scheduleTransientStatusReset(after: 3.2)

        case "TEAM_SYNC_PENDING":
            transientStatusResetTask?.cancel()
            currentBattleSummary = nil
            snapshot.lastBattleSummary = nil
            lastScanContextLabel = nil
            let teamSyncWindow = max(1, snapshot.config.teamSyncWindowSec)
            teamSyncRemainingSec = teamSyncWindow
            lastScanStatus = .teamSyncPending(seconds: teamSyncWindow)
            statusMessage = opponentName == nil
                ? "Sync squadra attivo: il compagno ha pochi secondi per ingaggiare il nemico."
                : "Sync squadra attivo con \(opponentName!)."
            appendLog(statusMessage, kind: .warn)
            schedulePendingOutcomeTimeout(
                after: teamSyncWindow,
                message: "Finestra di sync squadra scaduta."
            )

        case "ITEM_COLLECTED":
            let effectType = outcome.effectType?.nonEmpty ?? "ITEM"
            let readableEffect = effectType.replacingOccurrences(of: "_", with: " ").capitalized
            currentBattleSummary = nil
            snapshot.lastBattleSummary = nil
            lastScanStatus = .completed(delta: delta)
            statusMessage = delta == 0
                ? "Oggetto raccolto: \(readableEffect)."
                : "Oggetto raccolto: \(readableEffect) (\(signedDelta(delta)) punti)."
            appendLog(statusMessage, kind: delta >= 0 ? .ok : .warn)
            scheduleTransientStatusReset(after: 2.2)

        case "PENDING":
            transientStatusResetTask?.cancel()
            currentBattleSummary = nil
            snapshot.lastBattleSummary = nil
            lastScanContextLabel = nil
            teamSyncRemainingSec = nil
            lastScanStatus = .pending
            let isPendingWhileInactive = snapshot.battleStatus.uppercased() != "ACTIVE"
            if isPendingWhileInactive {
                statusMessage = opponentName == nil
                    ? "Ingaggio registrato mentre sei inattivo. Se la sfida si chiude ora scatta il blocco di 10 minuti."
                    : "Ingaggio registrato con \(opponentName!) mentre sei inattivo. Se la sfida si chiude ora scatta il blocco di 10 minuti per entrambi."
                appendLog(statusMessage, kind: .warn)
            } else {
                statusMessage = opponentName == nil
                    ? "Prima scansione registrata. Ora l'avversario deve leggere il tuo tag."
                    : "Ingaggio registrato con \(opponentName!). Ora deve leggere il tuo tag."
                appendLog("Handshake aperto: attesa scansione reciproca.", kind: .warn)
            }
            schedulePendingOutcomeTimeout(
                after: snapshot.config.handshakeWindowSec,
                message: "Finestra dello scontro scaduta."
            )

        case "COMPLETED":
            snapshot.battleStatus = "INACTIVE"
            snapshot.inactiveReason = outcome.inactiveReason?.nonEmpty ?? Self.postBattleBaseTouchReason
            if outcome.cooldownRemainingSec == nil {
                snapshot.cooldownRemainingSec = nil
            }
            presentResolvedBattle(
                summary: outcome.battleSummary,
                fallbackDelta: delta,
                fallbackOpponentName: opponentName,
                synced: false
            )

        case "COMPLETED_TIE":
            snapshot.battleStatus = "INACTIVE"
            snapshot.inactiveReason = outcome.inactiveReason?.nonEmpty ?? Self.postBattleBaseTouchReason
            if outcome.cooldownRemainingSec == nil {
                snapshot.cooldownRemainingSec = nil
            }
            presentResolvedBattle(
                summary: outcome.battleSummary,
                fallbackDelta: 0,
                fallbackOpponentName: opponentName,
                synced: false
            )

        case "COMPLETED_NO_POINTS":
            snapshot.battleStatus = "INACTIVE"
            snapshot.inactiveReason = outcome.inactiveReason?.nonEmpty ?? Self.postBattleBaseTouchReason
            if outcome.cooldownRemainingSec == nil {
                snapshot.cooldownRemainingSec = nil
            }
            presentResolvedBattle(
                summary: outcome.battleSummary,
                fallbackDelta: 0,
                fallbackOpponentName: opponentName,
                synced: false
            )

        case "IGNORED_SELF_SCAN", "REJECTED_SELF_SCAN":
            let message = "Hai scansionato il tuo braccialetto. Nessuna azione."
            currentBattleSummary = nil
            lastScanStatus = .invalidTarget(reason: message)
            statusMessage = message
            appendLog("Self scan ignorata.", kind: .warn)
            scheduleTransientStatusReset(after: 1.8)

        case "INACTIVE_PENALTY_APPLIED":
            snapshot.battleStatus = "INACTIVE"
            snapshot.inactiveReason = outcome.inactiveReason?.nonEmpty ?? Self.inactivePenaltyBlockReason
            currentBattleSummary = nil
            let sec = max(0, outcome.cooldownRemainingSec ?? snapshot.config.inactivePenaltyBlockDurationSec)
            snapshot.cooldownRemainingSec = sec
            let reason = outcome.reason?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            let message: String
            if reason.contains("enemy base") {
                message = "Penalty inattivita applicata: sei bloccato per \(formatDuration(sec))."
            } else if opponentName == nil {
                message = "Penalty inattivita applicata: tu e l'altro player siete bloccati per \(formatDuration(sec))."
            } else {
                message = "Penalty inattivita applicata: tu e \(opponentName!) siete bloccati per \(formatDuration(sec))."
            }
            lastScanStatus = .cooldown(seconds: sec)
            statusMessage = message
            appendLog(message, kind: .error)

        case "REJECTED_INACTIVE_PLAYER":
            let message = inactivePlayerMessage(reason: outcome.reason, opponentName: opponentName)
            lastScanStatus = .actionBlocked(reason: message)
            statusMessage = message
            appendLog("Scansione bloccata: player inattivo.", kind: .warn)
            scheduleTransientStatusReset(after: 1.8)

        case "REJECTED_PAIR_COOLDOWN", "REJECTED_PLAYER_COOLDOWN":
            let sec = max(0, outcome.cooldownRemainingSec ?? 0)
            let message = cooldownMessage(scope: cooldownScope, seconds: sec, opponentName: opponentName)
            if shouldPersistCooldown(for: outcome, status: status, scope: cooldownScope) {
                snapshot.cooldownRemainingSec = sec
                lastScanStatus = .cooldown(seconds: sec)
                appendLog("Scansione bloccata: cooldown personale attivo.", kind: .warn)
            } else {
                lastScanStatus = .actionBlocked(reason: message)
                appendLog(message, kind: .warn)
                scheduleTransientStatusReset(after: 1.8)
            }
            statusMessage = message

        case "REJECTED_HANDSHAKE_WINDOW":
            let message = "Finestra handshake scaduta. Riprova lo scambio."
            lastScanStatus = .actionBlocked(reason: message)
            statusMessage = message
            appendLog(message, kind: .warn)
            scheduleTransientStatusReset(after: 1.8)

        case "REJECTED_TEAM_BLOCKED":
            let message = teamBlockedMessage(
                reason: outcome.reason,
                seconds: max(0, outcome.cooldownRemainingSec ?? 0)
            )
            lastScanStatus = .protectedTarget(reason: message)
            statusMessage = message
            appendLog(message, kind: .warn)
            scheduleTransientStatusReset(after: 1.8)

        case "REJECTED_ELIMINATED":
            snapshot.battleStatus = "ELIMINATED"
            snapshot.cooldownRemainingSec = nil
            currentBattleSummary = nil
            lastScanStatus = .eliminated
            battleResult = .eliminated
            showEliminationOverlay = true
            statusMessage = "Sei eliminato: non puoi più combattere in questo match."
            appendLog("Scansione bloccata: player eliminato.", kind: .error)

        case "REJECTED_GAME_STATE":
            let reason = outcome.reason?.nonEmpty ?? "Partita non in stato LIVE."
            let message = "Scansione non disponibile: \(reason)"
            lastScanStatus = .actionBlocked(reason: message)
            statusMessage = message
            appendLog(message, kind: .warn)
            scheduleTransientStatusReset(after: 1.8)

        case "REJECTED_ITEM_UNAVAILABLE":
            let sec = max(0, outcome.availableInSec ?? 0)
            let suffix = sec > 0 ? " Riprova tra \(formatDuration(sec))." : ""
            let message = "Oggetto non disponibile.\(suffix)"
            lastScanStatus = .actionBlocked(reason: message)
            statusMessage = message
            appendLog(message, kind: .warn)
            scheduleTransientStatusReset(after: 1.8)

        case "REJECTED_NOT_REGISTERED":
            let reason = outcome.reason?.nonEmpty ?? "Giocatore non registrato nel game."
            let message = "Scansione rifiutata: \(reason)"
            lastScanStatus = .invalidTarget(reason: message)
            statusMessage = message
            appendLog(message, kind: .error)
            scheduleTransientStatusReset(after: 1.8)

        case "REJECTED_INVALID_CODE":
            let reason = outcome.reason?.nonEmpty ?? "Tag non valido per questa partita."
            let message = "Scansione rifiutata: \(reason)"
            lastScanStatus = .invalidTarget(reason: message)
            statusMessage = message
            appendLog(message, kind: .warn)
            scheduleTransientStatusReset(after: 1.8)

        default:
            let reason = outcome.reason?.nonEmpty
            let message = reason != nil
                ? "Scansione rifiutata: \(status) (\(reason!))"
                : "Scansione rifiutata: \(status)"
            lastScanStatus = .actionBlocked(reason: message)
            statusMessage = message
            appendLog(message, kind: .error)
            scheduleTransientStatusReset(after: 1.8)
        }

        if hasConfirmedServerPoints && profile.points <= 0 && snapshot.battleStatus.uppercased() == "ELIMINATED" {
            lastScanStatus = .eliminated
            battleResult = .eliminated
            currentBattleSummary = nil
            showEliminationOverlay = true
        }

        showPointsDeltaIfNeeded(previous: previousPoints, current: profile.points)
        updateMatchEndStateIfNeeded()
    }

    private func registerBraceletToken(
        _ token: String,
        tokenCandidates: [String] = [],
        source: String
    ) async throws {
        let normalized = normalizeToken(token)
        let normalizedCandidates = normalizeTagTokenCandidates([normalized] + tokenCandidates)
        guard !normalized.isEmpty else {
            throw NSError(domain: "PlayerViewModel", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Token non valido"])
        }

        let registered = try await gameService.registerBraceletToken(
            token: normalized,
            gameId: snapshot.gameId.nonEmpty,
            tokenCandidates: normalizedCandidates
        )
        profile.preferredBraceletToken = normalizeToken(registered)
        snapshot.braceletToken = normalizeToken(registered)
        manualToken = ""

        statusMessage = "Braccialetto NFC collegato (\(maskedBraceletToken))."
        appendLog("Braccialetto collegato via \(source): \(maskedBraceletToken)", kind: .ok)

        await refreshAll(
            updateStatusMessage: false,
            showLoading: false,
            silentOnError: true,
            preferredPoints: profile.points
        )
    }

    private func displayName(for uid: String?) -> String? {
        guard let uid = uid?.nonEmpty else { return nil }
        let participant = snapshot.participants.first { $0.id == uid }
        let nickname = participant?.nickname.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return nickname.isEmpty ? nil : nickname
    }

    private func ownDisplayName() -> String {
        let nickname = profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return nickname.isEmpty ? "Tu" : nickname
    }

    private func summarySideDisplayName(_ side: ScanBattleSummary.Side) -> String {
        if side.isGroup, let participantLine = side.participantLine?.nonEmpty {
            return participantLine
        }
        if let preferredLabel = side.teamName?.nonEmpty ?? side.label.nonEmpty {
            return preferredLabel
        }
        return side.primaryName
    }

    private func opposingResultLabel(for summary: ScanBattleSummary) -> String? {
        let value = summarySideDisplayName(summary.opposingSideData)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func battleContextLabel(for opponentName: String?) -> String? {
        guard let opponentName else { return nil }
        return "\(ownDisplayName()) vs \(opponentName)"
    }

    private func battleContextLabel(
        for summary: ScanBattleSummary?,
        fallbackOpponentName: String?
    ) -> String? {
        if let summary {
            return "\(summarySideDisplayName(summary.viewerSideData)) vs \(summarySideDisplayName(summary.opposingSideData))"
        }
        return battleContextLabel(for: fallbackOpponentName)
    }

    func distributionPoints(for memberId: String) -> Int {
        currentDistributionAllocations()[memberId] ?? 0
    }

    func updateDistributionDraft(for memberId: String, points: Int) {
        guard canEditTeamDistribution else { return }
        distributionDraftAllocations[memberId] = max(0, min(points, distributionTotalPool))
        hasUnsavedDistributionChanges = true
        distributionErrorMessage = ""
        distributionSuccessMessage = ""
    }

    func submitTeamDistribution() {
        guard canSubmitTeamDistribution else { return }
        guard let gameId = snapshot.gameId.nonEmpty else {
            distributionErrorMessage = "Game non disponibile."
            return
        }

        isSubmittingDistribution = true
        distributionErrorMessage = ""
        distributionSuccessMessage = ""

        Task {
            defer { isSubmittingDistribution = false }
            do {
                try await gameService.distributeTeamPoints(
                    gameId: gameId,
                    allocations: currentDistributionAllocations()
                )
                hasUnsavedDistributionChanges = false
                snapshot.teamReadyForLive = false
                distributionSuccessMessage = "Distribuzione salvata."
                statusMessage = "Distribuzione punti salvata."
                appendLog(statusMessage, kind: .ok)
                await refreshAll(updateStatusMessage: false, showLoading: false, silentOnError: true)
            } catch {
                distributionErrorMessage = "Distribuzione fallita: \(error.localizedDescription)"
                appendLog(distributionErrorMessage, kind: .error)
            }
        }
    }

    func setTeamReady(_ isReady: Bool) {
        guard canToggleTeamReady else { return }
        guard let gameId = snapshot.gameId.nonEmpty else {
            distributionErrorMessage = "Game non disponibile."
            return
        }

        isSettingTeamReady = true
        distributionErrorMessage = ""
        distributionSuccessMessage = ""

        Task {
            defer { isSettingTeamReady = false }
            do {
                _ = try await gameService.setTeamReady(gameId: gameId, isReady: isReady)
                await refreshAll(updateStatusMessage: false, showLoading: false, silentOnError: true)
                distributionSuccessMessage = snapshot.state.uppercased() == "LIVE"
                    ? "Entrambe le squadre sono pronte: il match e live."
                    : (isReady ? "Team pronto. In attesa dell'altra squadra." : "Team non piu pronto.")
                statusMessage = distributionSuccessMessage
                appendLog(distributionSuccessMessage, kind: .ok)
            } catch {
                distributionErrorMessage = "Aggiornamento pronto fallito: \(error.localizedDescription)"
                appendLog(distributionErrorMessage, kind: .error)
            }
        }
    }

    func sendTeamReadyReminder() {
        guard canSendTeamReadyReminder else { return }
        guard let gameId = snapshot.gameId.nonEmpty else {
            distributionErrorMessage = "Game non disponibile."
            return
        }

        isSendingTeamReadyReminder = true
        distributionErrorMessage = ""

        Task {
            defer { isSendingTeamReadyReminder = false }
            do {
                try await gameService.sendTeamReadyReminder(gameId: gameId)
                let message = "Sollecito inviato all'altra squadra."
                distributionSuccessMessage = message
                statusMessage = message
                appendLog(message, kind: .ok)
            } catch {
                let message = "Invio sollecito fallito: \(error.localizedDescription)"
                distributionErrorMessage = message
                appendLog(message, kind: .error)
            }
        }
    }

    func canJoinTeam(_ teamId: String) -> Bool {
        let normalizedTargetTeamId = normalizedTeamId(teamId)
        guard normalizedTargetTeamId == "TEAM_A" || normalizedTargetTeamId == "TEAM_B" else { return false }
        guard canSelectOwnTeamManually else { return false }
        guard currentTeamId != normalizedTargetTeamId else { return false }
        return teamParticipantCount(for: normalizedTargetTeamId) + 1 <= maxBalancedTeamSize
    }

    func selectOwnTeam(_ teamId: String) {
        let normalizedTargetTeamId = normalizedTeamId(teamId)
        guard canJoinTeam(normalizedTargetTeamId) else { return }
        guard let gameId = snapshot.gameId.nonEmpty else {
            preMatchStatusMessage = "Partita non disponibile."
            return
        }

        isUpdatingOwnTeam = true
        preMatchStatusMessage = ""

        Task {
            defer { isUpdatingOwnTeam = false }
            do {
                try await gameService.playerSelectOwnTeam(
                    gameId: gameId,
                    teamId: normalizedTargetTeamId
                )

                await refreshAll(updateStatusMessage: false, showLoading: false, silentOnError: true)
                let targetTeamName = teamDisplayName(for: normalizedTargetTeamId)
                preMatchStatusMessage = currentTeamId == normalizedTargetTeamId
                    ? "Sei entrato in \(targetTeamName)."
                    : "Team aggiornato: \(targetTeamName)."
                statusMessage = preMatchStatusMessage
                appendLog(preMatchStatusMessage, kind: .ok)
            } catch {
                preMatchStatusMessage = "Cambio squadra fallito: \(error.localizedDescription)"
                appendLog(preMatchStatusMessage, kind: .error)
            }
        }
    }

    func shuffleTeams() {
        guard canShuffleTeams else { return }
        guard let gameId = snapshot.gameId.nonEmpty else {
            preMatchStatusMessage = "Partita non disponibile."
            return
        }

        let participants = uniquePreMatchParticipants()
        guard participants.count >= 2 else {
            preMatchStatusMessage = "Servono almeno due player per mischiare le squadre."
            return
        }

        isShufflingTeams = true
        preMatchStatusMessage = ""

        Task {
            defer { isShufflingTeams = false }
            do {
                try await gameService.playerShuffleTeams(gameId: gameId)

                await refreshAll(updateStatusMessage: false, showLoading: false, silentOnError: true)
                preMatchStatusMessage = "Squadre rimescolate."
                statusMessage = preMatchStatusMessage
                appendLog(preMatchStatusMessage, kind: .ok)
            } catch {
                preMatchStatusMessage = "Shuffle squadre fallito: \(error.localizedDescription)"
                appendLog(preMatchStatusMessage, kind: .error)
            }
        }
    }

    func scanCurrentTeamBaseToken() {
        guard snapshot.isCurrentPlayerLeader else {
            preMatchStatusMessage = "Solo il leader può registrare la base del team."
            return
        }
        guard let gameId = snapshot.gameId.nonEmpty, let teamId = currentTeamId else {
            preMatchStatusMessage = "Base non disponibile: manca il team."
            return
        }
        guard canUseNFC else {
            preMatchStatusMessage = "NFC non disponibile su questo iPhone."
            return
        }
        guard canScanPreMatchTags else { return }

        isScanningPreMatchTag = true
        preMatchStatusMessage = ""

        Task {
            defer { isScanningPreMatchTag = false }
            do {
                let tagRead = try await nfcService.readTag(prompt: "Avvicina il tag della base \(teamDisplayName(for: teamId))")
                try await gameService.setBaseToken(
                    gameId: gameId,
                    teamId: teamId,
                    token: tagRead.primaryToken,
                    tokenCandidates: tagRead.candidates,
                    overwriteExistingBase: false
                )
                await refreshPreMatchSupportDataIfNeeded()
                await refreshAll(updateStatusMessage: false, showLoading: false, silentOnError: true)
                preMatchStatusMessage = "Base \(teamDisplayName(for: teamId)) registrata."
                appendLog(preMatchStatusMessage, kind: .ok)
            } catch {
                preMatchStatusMessage = "Registrazione base fallita: \(error.localizedDescription)"
                appendLog(preMatchStatusMessage, kind: .error)
            }
        }
    }

    func attachTokenToPreMatchItem(_ item: AdminGameStatus.GameItem) {
        guard snapshot.isCurrentPlayerLeader else {
            preMatchStatusMessage = "Solo il leader può collegare i tag degli oggetti."
            return
        }
        guard let gameId = snapshot.gameId.nonEmpty else {
            preMatchStatusMessage = "Partita non disponibile."
            return
        }
        guard canUseNFC else {
            preMatchStatusMessage = "NFC non disponibile su questo iPhone."
            return
        }
        guard canScanPreMatchTags else { return }

        isScanningPreMatchTag = true
        preMatchStatusMessage = ""

        Task {
            defer { isScanningPreMatchTag = false }
            do {
                let tagRead = try await nfcService.readTag(prompt: "Avvicina il tag per l'oggetto da \(item.points) punti")
                try await gameService.adminAttachItemToken(
                    gameId: gameId,
                    itemId: item.id,
                    token: tagRead.primaryToken,
                    tokenCandidates: tagRead.candidates
                )
                await refreshPreMatchSupportDataIfNeeded()
                preMatchStatusMessage = "Tag oggetto collegato (\(item.points) pt)."
                appendLog(preMatchStatusMessage, kind: .ok)
            } catch {
                preMatchStatusMessage = "Collegamento tag oggetto fallito: \(error.localizedDescription)"
                appendLog(preMatchStatusMessage, kind: .error)
            }
        }
    }

    func checkPreMatchTag() {
        guard let gameId = snapshot.gameId.nonEmpty else {
            preMatchStatusMessage = "Partita non disponibile."
            return
        }
        guard canUseNFC else {
            preMatchStatusMessage = "NFC non disponibile su questo iPhone."
            return
        }
        guard canScanPreMatchTags else { return }

        isScanningPreMatchTag = true
        preMatchStatusMessage = ""

        Task {
            defer { isScanningPreMatchTag = false }
            do {
                let tagRead = try await nfcService.readTag(prompt: "Avvicina il tag da controllare")
                let lookup = try await gameService.adminLookupTag(
                    gameId: gameId,
                    token: tagRead.primaryToken,
                    tokenCandidates: tagRead.candidates
                )
                preMatchLookupResult = lookup
                preMatchStatusMessage = "Tag controllato correttamente."
                appendLog(preMatchStatusMessage, kind: .ok)
            } catch {
                preMatchStatusMessage = "Controllo tag fallito: \(error.localizedDescription)"
                appendLog(preMatchStatusMessage, kind: .error)
            }
        }
    }

    func clearPreMatchLookup() {
        preMatchLookupResult = nil
    }

    private func resolvedCooldownScope(
        for outcome: ScanSubmissionOutcome,
        status: String
    ) -> CooldownScope? {
        if let rawScope = outcome.cooldownScope?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
           let scope = CooldownScope(rawValue: rawScope) {
            return scope
        }

        let normalizedReason = outcome.reason?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if status == "REJECTED_PAIR_COOLDOWN" || normalizedReason.contains("pair cooldown") {
            return .pair
        }
        if normalizedReason.contains("opponent cooldown") {
            return .opponent
        }
        if normalizedReason.contains("one teammate is blocked") {
            return .teammate
        }
        if normalizedReason.contains("player cooldown") || status == "INACTIVE_PENALTY_APPLIED" {
            return .selfCooldown
        }
        return nil
    }

    private func shouldPersistCooldown(
        for outcome: ScanSubmissionOutcome,
        status: String,
        scope: CooldownScope?
    ) -> Bool {
        if status == "INACTIVE_PENALTY_APPLIED" {
            return true
        }
        guard status == "REJECTED_PLAYER_COOLDOWN" || status == "REJECTED_PAIR_COOLDOWN" else {
            return false
        }
        if scope == .selfCooldown {
            return true
        }

        let normalizedReason = outcome.reason?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return normalizedReason == "player cooldown is still active."
    }

    private func cooldownMessage(
        scope: CooldownScope?,
        seconds: Int,
        opponentName: String?
    ) -> String {
        let suffix = seconds > 0 ? " Riprova tra \(formatDuration(seconds))." : ""
        switch scope {
        case .pair:
            if let opponentName {
                return "La coppia con \(opponentName) e ancora in cooldown.\(suffix)"
            }
            return "Questa coppia e ancora in cooldown.\(suffix)"
        case .opponent:
            if let opponentName {
                return "\(opponentName) e ancora bloccato.\(suffix)"
            }
            return "L'altro giocatore e ancora bloccato.\(suffix)"
        case .teammate:
            if let opponentName {
                return "\(opponentName) e ancora bloccato e non puo partecipare ora.\(suffix)"
            }
            return "Il compagno coinvolto e ancora bloccato.\(suffix)"
        case .selfCooldown, .none:
            return "Cooldown attivo.\(suffix)"
        }
    }

    private func teamBlockedMessage(reason: String?, seconds: Int) -> String {
        let normalizedReason = reason?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let suffix = seconds > 0 ? " Riprova tra \(formatDuration(seconds))." : ""
        if normalizedReason.contains("base") && normalizedReason.contains("cooldown") {
            return "Base avversaria in cooldown: non e attaccabile ora.\(suffix)"
        }
        return "Compagno squadra non ingaggiabile in questo momento.\(suffix)"
    }

    private func enemyBaseCaptureMessage(points: Int) -> String {
        let cooldownSec = max(0, snapshot.config.baseDefenseCooldownSec)
        let suffix = cooldownSec > 0
            ? " Base bloccata per \(formatDuration(cooldownSec))."
            : ""
        return "Base avversaria catturata (+\(points) punti).\(suffix)"
    }

    private func inactivePlayerMessage(reason: String?, opponentName: String?) -> String {
        let normalizedReason = reason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch normalizedReason {
        case "Opponent is not available for battle.":
            return opponentName == nil
                ? "Questo giocatore e bloccato o non disponibile."
                : "\(opponentName!) e bloccato o non disponibile."
        case "Touch your own base before attacking.":
            return "Non sei disponibile per questo ingaggio."
        case "Inactive players cannot collect items.":
            return "Sei inattivo: non puoi raccogliere oggetti finche non rientri."
        case "Both teammates must be active. Touch your base first.":
            return "Il team non e disponibile per questa azione."
        default:
            if let opponentName {
                return "\(opponentName) non e disponibile per questo ingaggio."
            }
            if !normalizedReason.isEmpty {
                return "Ingaggio rifiutato: \(normalizedReason)"
            }
            return "Ingaggio rifiutato: almeno uno dei due player non e disponibile."
        }
    }

    private func enrichedSnapshot(
        _ snapshot: MatchSnapshot,
        scoreboardParticipants: [MatchSnapshot.Participant]
    ) -> MatchSnapshot {
        guard !scoreboardParticipants.isEmpty else { return snapshot }

        var merged = snapshot
        var uniqueParticipants: [String: MatchSnapshot.Participant] = [:]
        for participant in snapshot.participants {
            uniqueParticipants[participant.id] = participant
        }
        for participant in scoreboardParticipants {
            uniqueParticipants[participant.id] = participant
        }
        merged.participants = uniqueParticipants.values.sorted {
            $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending
        }
        return merged
    }

    private func normalizedSnapshotLifecycle(_ snapshot: MatchSnapshot) -> MatchSnapshot {
        var normalized = snapshot
        if normalized.state.uppercased() == "LIVE" {
            hasSeenLiveMatch = true
        }
        if shouldTreatMatchAsEnded(normalized) {
            normalized.state = "ENDED"
            normalized.remainingSec = 0
        }
        return normalized
    }

    private func shouldTreatMatchAsEnded(_ snapshot: MatchSnapshot) -> Bool {
        // Solo lo stato server chiude il match: il countdown locale a zero non basta
        // (il server degrada già LIVE scaduto a ENDED in resolveEffectiveGameState).
        let state = snapshot.state.uppercased()
        return state == "ENDED" || state == "ARCHIVED"
    }

    private func updateMatchEndStateIfNeeded() {
        guard isMatchClosed else { return }

        isReadingNFC = false
        isResolvingScan = false
        transientStatusResetTask?.cancel()
        cancelPendingOutcomeTimeout()
        battleResult = nil
        currentBattleSummary = nil
        lastScanStatus = nil

        if !hasLoggedMatchEnd {
            statusMessage = "Partita terminata."
            appendLog(statusMessage, kind: .ok)
            hasLoggedMatchEnd = true
        }
        guard !userDismissedMatchEnd else { return }
        matchEndSummary = buildMatchEndSummary()
    }

    private func buildMatchEndSummary() -> MatchEndSummary {
        let personalPoints = snapshot.points ?? profile.points
        let scoreboard = buildScoreboardData()
        let ownTeamId = normalizedTeamId(snapshot.teamId ?? profile.teamId)
        let ownName = ownDisplayName()
        let teamStandings = scoreboard.teams
        let rankedParticipants = scoreboard.players
        let rank = rankedParticipants.firstIndex { $0.id == profile.uid }.map { $0 + 1 }
        let rankLine = rank.map { "Posizione finale #\($0)" }
        let ownStanding = teamStandings.first(where: { $0.teamId == ownTeamId })
        let opponentStanding = teamStandings.first(where: { $0.teamId != ownTeamId })
        let eliminatedTeams = teamStandings.filter { !$0.players.isEmpty && $0.activePlayers == 0 }
        let activeTeams = teamStandings.filter { $0.activePlayers > 0 }
        let endedByElimination = !eliminatedTeams.isEmpty && !activeTeams.isEmpty

        if let ownStanding, let opponentStanding {
            let scoreline = "\(ownStanding.teamName) \(ownStanding.totalPoints) • \(opponentStanding.teamName) \(opponentStanding.totalPoints)"
            let title: String
            let subtitle: String

            if endedByElimination {
                if ownStanding.activePlayers > 0 && opponentStanding.activePlayers == 0 {
                    title = "VITTORIA DI SQUADRA"
                    subtitle = "La partita termina per eliminazione totale: \(opponentStanding.teamName) non ha più giocatori attivi."
                } else if ownStanding.activePlayers == 0 && opponentStanding.activePlayers > 0 {
                    title = "SCONFITTA DI SQUADRA"
                    subtitle = "La partita termina per eliminazione totale: il tuo team non ha più giocatori attivi."
                } else if ownStanding.totalPoints > opponentStanding.totalPoints {
                    title = "VITTORIA DI SQUADRA"
                    subtitle = "Eliminazione simultanea: il tuo team chiude con più punti."
                } else if ownStanding.totalPoints < opponentStanding.totalPoints {
                    title = "SCONFITTA DI SQUADRA"
                    subtitle = "Eliminazione simultanea: l'altra squadra chiude con più punti."
                } else {
                    title = "PAREGGIO"
                    subtitle = "Entrambe le squadre sono state eliminate con lo stesso punteggio."
                }
            } else if ownStanding.totalPoints > opponentStanding.totalPoints {
                title = "VITTORIA DI SQUADRA"
                subtitle = "Il tempo è scaduto: la tua squadra chiude davanti."
            } else if ownStanding.totalPoints < opponentStanding.totalPoints {
                title = "SCONFITTA DI SQUADRA"
                subtitle = "Il tempo è scaduto: l'altra squadra chiude davanti."
            } else {
                title = "PAREGGIO"
                subtitle = "Il tempo è scaduto: le squadre chiudono in parità."
            }

            return MatchEndSummary(
                title: title,
                subtitle: subtitle,
                scoreline: scoreline,
                personalLabel: ownName,
                personalPoints: personalPoints,
                teamStandings: teamStandings,
                playerRanking: rankedParticipants,
                endedByElimination: endedByElimination
            )
        }

        return MatchEndSummary(
            title: "PARTITA TERMINATA",
            subtitle: endedByElimination
                ? "La partita è stata chiusa per eliminazione totale di una squadra."
                : "Il tempo di gioco è finito. Nessuna altra scansione è consentita.",
            scoreline: rankLine,
            personalLabel: ownName,
            personalPoints: personalPoints,
            teamStandings: teamStandings,
            playerRanking: rankedParticipants,
            endedByElimination: endedByElimination
        )
    }

    private func normalizedTeamId(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func orderedParticipants(for teamId: String) -> [MatchSnapshot.Participant] {
        snapshot.participants
            .filter { normalizedTeamId($0.teamId) == normalizedTeamId(teamId) }
            .sorted { lhs, rhs in
                let lhsLeader = (lhs.roleInTeam ?? "").uppercased() == "LEADER"
                let rhsLeader = (rhs.roleInTeam ?? "").uppercased() == "LEADER"
                if lhsLeader != rhsLeader {
                    return lhsLeader && !rhsLeader
                }
                return lhs.nickname.localizedCaseInsensitiveCompare(rhs.nickname) == .orderedAscending
            }
    }

    private func teamParticipantCount(for teamId: String) -> Int {
        orderedParticipants(for: teamId).count
    }

    private var maxBalancedTeamSize: Int {
        Int(ceil(Double(max(1, uniquePreMatchParticipants().count)) / 2.0))
    }

    private func uniquePreMatchParticipants() -> [MatchSnapshot.Participant] {
        var ordered: [MatchSnapshot.Participant] = []
        var seenIds: Set<String> = []

        for participant in snapshot.participants {
            let participantId = participant.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !participantId.isEmpty else { continue }
            if seenIds.insert(participantId).inserted {
                ordered.append(participant)
            }
        }

        let ownUid = profile.uid.trimmingCharacters(in: .whitespacesAndNewlines)
        if !ownUid.isEmpty, !seenIds.contains(ownUid) {
            ordered.append(
                MatchSnapshot.Participant(
                    id: ownUid,
                    nickname: ownDisplayName(),
                    avatarDataUrl: profile.avatarDataUrl,
                    teamId: snapshot.teamId ?? profile.teamId,
                    roleInTeam: snapshot.roleInTeam ?? profile.roleInTeam,
                    playingCard: snapshot.playingCard ?? profile.identityCardCode,
                    identityDeckIndex: snapshot.identityDeckIndex ?? profile.identityDeckIndex,
                    points: snapshot.points ?? profile.points
                )
            )
        }

        return ordered
    }

    private func refreshPreMatchSupportDataIfNeeded() async {
        guard isPreMatchPhase, let gameId = snapshot.gameId.nonEmpty else {
            preMatchAdminStatus = nil
            preMatchGameItems = []
            preMatchLookupResult = nil
            preMatchStatusMessage = ""
            didAttemptAutomaticTeamAssignment = false
            return
        }

        let fetchedAdminStatus = try? await gameService.fetchAdminGame(gameId: gameId)
        let fetchedGameItems = (try? await gameService.adminFetchGameItems(gameId: gameId)) ?? []

        if let fetchedAdminStatus {
            preMatchAdminStatus = fetchedAdminStatus
            if !fetchedAdminStatus.hasAutonomousSetup,
               let persisted = AutonomousGamePreferencesStore.load(for: gameId) {
                preMatchAdminStatus = AdminGameStatus(
                    name: fetchedAdminStatus.name,
                    gameId: fetchedAdminStatus.gameId,
                    gameDefinitionId: fetchedAdminStatus.gameDefinitionId,
                    gameDefinitionName: fetchedAdminStatus.gameDefinitionName,
                    state: fetchedAdminStatus.state,
                    config: fetchedAdminStatus.config,
                    hasConfigSnapshot: fetchedAdminStatus.hasConfigSnapshot,
                    hasBaseSnapshot: fetchedAdminStatus.hasBaseSnapshot,
                    participants: fetchedAdminStatus.participants,
                    teamABaseToken: fetchedAdminStatus.teamABaseToken,
                    teamBBaseToken: fetchedAdminStatus.teamBBaseToken,
                    teamABaseQrToken: fetchedAdminStatus.teamABaseQrToken,
                    teamBBaseQrToken: fetchedAdminStatus.teamBBaseQrToken,
                    itemMode: fetchedAdminStatus.itemMode,
                    gameItems: fetchedAdminStatus.gameItems,
                    autonomousSetup: persisted,
                    hasAutonomousSetup: false
                )
            }
        }

        preMatchGameItems = fetchedGameItems
    }

    private func autoAssignRandomTeamIfNeeded() async {
        guard isPreMatchPhase else { return }
        guard resolvedAutonomousSetup.allowsRandomTeamAssignment else {
            didAttemptAutomaticTeamAssignment = false
            return
        }
        guard currentTeamId == nil else { return }
        guard !didAttemptAutomaticTeamAssignment else { return }
        guard let gameId = snapshot.gameId.nonEmpty else { return }

        let ownUid = profile.uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ownUid.isEmpty else { return }
        didAttemptAutomaticTeamAssignment = true

        let teamAPlayers = teamParticipantCount(for: "TEAM_A")
        let teamBPlayers = teamParticipantCount(for: "TEAM_B")
        let targetTeamId: String
        if teamAPlayers == teamBPlayers {
            targetTeamId = Bool.random() ? "TEAM_A" : "TEAM_B"
        } else {
            targetTeamId = teamAPlayers < teamBPlayers ? "TEAM_A" : "TEAM_B"
        }

        do {
            try await gameService.playerSelectOwnTeam(
                gameId: gameId,
                teamId: targetTeamId
            )
            await refreshAll(updateStatusMessage: false, showLoading: false, silentOnError: true)
            preMatchStatusMessage = "Squadra assegnata automaticamente: \(teamDisplayName(for: targetTeamId))."
            appendLog(preMatchStatusMessage, kind: .ok)
        } catch {
            didAttemptAutomaticTeamAssignment = false
            preMatchStatusMessage = "Assegnazione automatica fallita: \(error.localizedDescription)"
            appendLog(preMatchStatusMessage, kind: .error)
        }
    }

    private func distributionTeamParticipants() -> [MatchSnapshot.Participant] {
        let teamId = normalizedTeamId(snapshot.teamId ?? profile.teamId)
        let participants = snapshot.participants.filter { normalizedTeamId($0.teamId) == teamId }

        let resolvedParticipants: [MatchSnapshot.Participant]
        if participants.isEmpty, !profile.uid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedParticipants = [
                MatchSnapshot.Participant(
                    id: profile.uid,
                    nickname: profile.nickname,
                    avatarDataUrl: profile.avatarDataUrl,
                    teamId: profile.teamId,
                    roleInTeam: profile.roleInTeam,
                    playingCard: profile.identityCardCode,
                    identityDeckIndex: profile.identityDeckIndex,
                    points: snapshot.points ?? profile.points
                )
            ]
        } else {
            resolvedParticipants = participants
        }

        return resolvedParticipants.sorted { lhs, rhs in
            let lhsLeader = (lhs.roleInTeam ?? "").uppercased() == "LEADER"
            let rhsLeader = (rhs.roleInTeam ?? "").uppercased() == "LEADER"
            if lhsLeader != rhsLeader {
                return lhsLeader && !rhsLeader
            }
            return lhs.nickname.localizedCaseInsensitiveCompare(rhs.nickname) == .orderedAscending
        }
    }

    private func buildScoreboardData() -> (
        teams: [MatchEndSummary.TeamStanding],
        players: [MatchEndSummary.PlayerStanding]
    ) {
        let rawParticipants = snapshot.participants.filter {
            !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        let participants: [MatchSnapshot.Participant]
        if rawParticipants.isEmpty,
           let ownUid = profile.uid.nonEmpty {
            participants = [
                MatchSnapshot.Participant(
                    id: ownUid,
                    nickname: ownDisplayName(),
                    avatarDataUrl: profile.avatarDataUrl,
                    teamId: snapshot.teamId ?? profile.teamId,
                    roleInTeam: snapshot.roleInTeam ?? profile.roleInTeam,
                    playingCard: snapshot.playingCard ?? profile.identityCardCode,
                    identityDeckIndex: snapshot.identityDeckIndex ?? profile.identityDeckIndex,
                    points: snapshot.points ?? profile.points
                )
            ]
        } else {
            participants = rawParticipants
        }

        let playerStandings = participants
            .map { participant -> MatchEndSummary.PlayerStanding in
                let normalizedTeam = normalizedTeamId(participant.teamId)
                let points = participant.points ?? (
                    participant.id == profile.uid ? (snapshot.points ?? profile.points) : 0
                )
                return MatchEndSummary.PlayerStanding(
                    id: participant.id,
                    nickname: participant.nickname.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Giocatore",
                    teamId: normalizedTeam,
                    teamName: teamDisplayName(for: normalizedTeam),
                    roleInTeam: participant.roleInTeam?.nonEmpty,
                    points: points,
                    isEliminated: points <= 0
                )
            }
            .sorted { lhs, rhs in
                if lhs.points == rhs.points {
                    return lhs.nickname.localizedCaseInsensitiveCompare(rhs.nickname) == .orderedAscending
                }
                return lhs.points > rhs.points
            }

        let teams = Dictionary(grouping: playerStandings, by: \.teamId)
            .filter { !$0.key.isEmpty }
            .map { teamId, players in
                let orderedPlayers = players.sorted { lhs, rhs in
                    if lhs.points == rhs.points {
                        return lhs.nickname.localizedCaseInsensitiveCompare(rhs.nickname) == .orderedAscending
                    }
                    return lhs.points > rhs.points
                }
                return MatchEndSummary.TeamStanding(
                    id: teamId,
                    teamId: teamId,
                    teamName: teamDisplayName(for: teamId),
                    totalPoints: orderedPlayers.reduce(0) { $0 + $1.points },
                    activePlayers: orderedPlayers.filter { !$0.isEliminated }.count,
                    eliminatedPlayers: orderedPlayers.filter(\.isEliminated).count,
                    players: orderedPlayers
                )
            }
            .sorted { lhs, rhs in
                if lhs.totalPoints == rhs.totalPoints {
                    return lhs.teamName.localizedCaseInsensitiveCompare(rhs.teamName) == .orderedAscending
                }
                return lhs.totalPoints > rhs.totalPoints
            }

        return (teams: teams, players: playerStandings)
    }

    private func remoteDistributionAllocations(
        profile: PlayerProfile,
        snapshot: MatchSnapshot
    ) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: distributionTeamParticipants().map { participant in
            let fallbackSelfPoints = participant.id == profile.uid ? (snapshot.points ?? profile.points) : 0
            return (participant.id, max(0, participant.points ?? fallbackSelfPoints))
        })
    }

    private func currentDistributionAllocations() -> [String: Int] {
        let remote = remoteDistributionAllocations(profile: profile, snapshot: snapshot)
        guard canEditTeamDistribution else { return remote }
        guard !distributionDraftAllocations.isEmpty else { return remote }

        var merged: [String: Int] = [:]
        for key in remote.keys {
            merged[key] = max(0, distributionDraftAllocations[key] ?? remote[key] ?? 0)
        }
        return merged
    }

    private func syncDistributionDraftIfNeeded(
        profile: PlayerProfile,
        snapshot: MatchSnapshot
    ) {
        guard snapshot.state.uppercased() == "DISTRIBUTION" else {
            distributionDraftAllocations = [:]
            hasUnsavedDistributionChanges = false
            distributionErrorMessage = ""
            distributionSuccessMessage = ""
            return
        }

        let remote = remoteDistributionAllocations(profile: profile, snapshot: snapshot)
        if !snapshot.isCurrentPlayerLeader {
            distributionDraftAllocations = remote
            hasUnsavedDistributionChanges = false
            return
        }

        guard hasUnsavedDistributionChanges else {
            distributionDraftAllocations = remote
            return
        }

        let remoteIds = Set(remote.keys)
        let draftIds = Set(distributionDraftAllocations.keys)
        if remoteIds != draftIds {
            var merged: [String: Int] = [:]
            for key in remote.keys {
                merged[key] = distributionDraftAllocations[key] ?? remote[key]
            }
            distributionDraftAllocations = merged
        }
    }

    private func teamDisplayName(for value: String?) -> String {
        switch normalizedTeamId(value) {
        case "A", "TEAM_A", "GIOCATORI":
            return "Giocatori"
        case "B", "TEAM_B", "CITTADINI":
            return "Cittadini"
        default:
            return "Senza team"
        }
    }

    private func normalizeToken(_ token: String?) -> String {
        normalizeTagToken(token)
    }

    private func sanitizeProfileNickname(_ value: String) -> String {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        guard !trimmed.isEmpty, !looksLikeAvatarPayload(trimmed) else {
            return ""
        }
        return String(trimmed.prefix(24))
    }

    private func sanitizeProfileAvatar(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, looksLikeAvatarPayload(trimmed) else {
            return nil
        }
        return trimmed
    }

    private func looksLikeAvatarPayload(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.hasPrefix("data:image/")
            || lower.hasPrefix("preset://")
            || lower.hasPrefix("http://")
            || lower.hasPrefix("https://")
    }

    private func normalizeScanStatus(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func signedDelta(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }

    private func formatDuration(_ totalSeconds: Int) -> String {
        let safeValue = max(0, totalSeconds)
        let minutes = safeValue / 60
        let seconds = safeValue % 60
        if minutes > 0 && seconds > 0 {
            return "\(minutes)m \(seconds)s"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(seconds)s"
    }

    private func normalizedOptionalSeconds(_ value: Int?) -> Int? {
        guard let value else { return nil }
        return value > 0 ? value : nil
    }

    private func normalizedOptionalPoints(_ value: Int?) -> Int? {
        guard let value else { return nil }
        return value > 0 ? value : nil
    }

    private func maskToken(_ token: String?) -> String {
        let normalized = normalizeToken(token)
        guard !normalized.isEmpty else { return "-" }
        if normalized.count <= 8 { return normalized }
        let prefix = normalized.prefix(4)
        let suffix = normalized.suffix(4)
        return "\(prefix)...\(suffix)"
    }

    private func appendLog(_ message: String, kind: ActivityEntry.Kind) {
        let stamp = DateFormatter.logStamp.string(from: Date())
        activityLog.insert(ActivityEntry(timestamp: stamp, message: message, kind: kind), at: 0)
        if activityLog.count > 10 {
            activityLog = Array(activityLog.prefix(10))
        }
    }

    private func scheduleTransientStatusReset(after delay: Double) {
        transientStatusResetTask?.cancel()
        transientStatusResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.clearTransientStatus()
            }
        }
    }

    private func schedulePendingOutcomeTimeout(after seconds: Int, message: String) {
        pendingOutcomeTimeoutTask?.cancel()
        let delay = max(1, seconds)
        pendingOutcomeTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                guard self.matchesPendingState else { return }
                guard !self.isResolvingScan else { return }
                self.teamSyncRemainingSec = nil
                self.lastScanStatus = nil
                self.lastScanContextLabel = nil
                self.currentBattleSummary = nil
                self.statusMessage = message
                self.appendLog(message, kind: .warn)
                self.pendingOutcomeTimeoutTask = nil
                self.scheduleTransientStatusReset(after: 1.6)
            }
        }
    }

    private func cancelPendingOutcomeTimeout() {
        pendingOutcomeTimeoutTask?.cancel()
        pendingOutcomeTimeoutTask = nil
        teamSyncRemainingSec = nil
    }

    // Il submitScan può restare in volo fino ai 60s di timeout URLSession: dopo 10s
    // liberiamo l'overlay, l'esito arriva comunque via polling su lastBattleSummary.
    private func scheduleScanResolutionTimeout() {
        scanResolutionTimeoutTask?.cancel()
        scanResolutionTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.isResolvingScan else { return }
                self.isResolvingScan = false
                self.statusMessage = "La rete è lenta: l'esito arriverà appena possibile."
            }
        }
    }

    private func cancelScanResolutionTimeout() {
        scanResolutionTimeoutTask?.cancel()
        scanResolutionTimeoutTask = nil
    }

    private func clearTransientStatus() {
        guard !isReadingNFC && !isResolvingScan else { return }
        if case .some(.eliminated) = lastScanStatus {
            return
        }
        if matchesPendingState {
            return
        }
        lastScanStatus = nil
        transientStatusResetTask = nil
    }

    private func presentResolvedBattle(
        summary: ScanBattleSummary?,
        fallbackDelta: Int,
        fallbackOpponentName: String?,
        synced: Bool
    ) {
        cancelPendingOutcomeTimeout()
        if let summary {
            currentBattleSummary = summary
            snapshot.lastBattleSummary = summary
            lastResolvedBattleSummaryId = summary.summaryId
            lastScanContextLabel = battleContextLabel(for: summary, fallbackOpponentName: nil)
        } else {
            currentBattleSummary = nil
            lastScanContextLabel = battleContextLabel(for: fallbackOpponentName)
        }

        let effectiveDelta = summary?.viewerDelta ?? fallbackDelta
        lastScanStatus = .completed(delta: effectiveDelta)

        if effectiveDelta > 0 {
            battleResult = .win(delta: effectiveDelta)
        } else if effectiveDelta < 0 {
            battleResult = .lose(delta: abs(effectiveDelta))
        } else {
            battleResult = .tie
        }

        let sourcePrefix = synced ? "Esito scontro sincronizzato" : "Sfida conclusa"
        let targetLabel = summary.flatMap(opposingResultLabel(for:)) ?? fallbackOpponentName
        let message: String
        if effectiveDelta > 0 {
            message = targetLabel == nil
                ? "\(sourcePrefix): \(signedDelta(effectiveDelta)) punti."
                : "\(sourcePrefix) contro \(targetLabel!): \(signedDelta(effectiveDelta)) punti."
        } else if effectiveDelta < 0 {
            message = targetLabel == nil
                ? "\(sourcePrefix): \(signedDelta(effectiveDelta)) punti."
                : "\(sourcePrefix) contro \(targetLabel!): \(signedDelta(effectiveDelta)) punti."
        } else {
            message = targetLabel == nil
                ? "\(sourcePrefix): nessun trasferimento."
                : "\(sourcePrefix) contro \(targetLabel!): nessun trasferimento."
        }

        statusMessage = message
        appendLog(message, kind: effectiveDelta > 0 ? .ok : (effectiveDelta < 0 ? .warn : .warn))

        if summary?.penaltyApplied == true,
           let cooldown = snapshot.cooldownRemainingSec,
           cooldown > 0 {
            appendLog("Penalty inattivita attivo per \(formatDuration(cooldown)).", kind: .error)
        } else {
            appendLog("Torna alla base per giocare ancora.", kind: .warn)
        }

        scheduleTransientStatusReset(after: summary == nil ? 3.0 : 3.6)
    }

    private var matchesPendingState: Bool {
        switch lastScanStatus {
        case .pending, .teamSyncPending:
            return true
        default:
            return false
        }
    }

    private func ensurePlayerQRCodeIfNeeded() async {
        guard snapshot.isJoined else { return }
        guard snapshot.scanMode.isQREnabled else { return }
        if !normalizeToken(snapshot.qrToken).isEmpty {
            return
        }
        let gameId = snapshot.gameId.nonEmpty ?? initialGameCode.nonEmpty
        do {
            let qr = try await gameService.ensurePlayerQRCode(gameId: gameId)
            snapshot.qrToken = qr.token
            snapshot.qrUrl = qr.url
        } catch {
            appendLog("QR personale non disponibile: \(error.localizedDescription)", kind: .warn)
        }
    }

    private func syncPushRegistrationIfNeeded(force: Bool = false) async {
        guard snapshot.isJoined, let gameId = snapshot.gameId.nonEmpty else { return }
        let token = await PushNotificationState.resolvedToken()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else { return }

        let context = "\(token)|\(gameId)"
        guard force || context != lastPushRegistrationContext else { return }

        do {
            try await gameService.registerPushToken(
                token: token,
                gameId: gameId,
                userAgent: "ios-player"
            )
            lastPushRegistrationContext = context
        } catch {
            AppLogger.error("player push registration failed: \(error.localizedDescription)")
        }
    }

    /// Ensures the server-side profile is marked complete for guest users.
    /// Guests bypass the onboarding UI so we push a minimal valid profile
    /// (nickname + default avatar + selected card) before the join call.
    private func ensureGuestProfileCompleted(nickname: String) async throws {
        var current = (try? await gameService.fetchOwnProfile()) ?? .empty
        guard !current.profileCompleted else { return }
        current.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.avatarDataUrl == nil || current.avatarDataUrl?.isEmpty == true {
            current.avatarDataUrl = ProfileCompletionViewModel.minimalAvatarDataURL
        }
        current.profileCompleted = true
        try await gameService.savePlayerProfile(current)
        AppLogger.info("[PlayerVM] guest profile auto-completed nickname=\(current.nickname)")
    }
}

private extension DateFormatter {
    static let logStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
