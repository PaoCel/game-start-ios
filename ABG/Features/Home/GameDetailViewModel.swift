import Combine
import Foundation

@MainActor
final class GameDetailViewModel: ObservableObject {
    enum InviteKind {
        case player
        case `operator`

        var isOperatorInvite: Bool {
            self == .operator
        }
    }

    @Published var profile: PlayerProfile = .empty
    @Published var summary: GameAccessSummary?
    @Published var snapshot: MatchSnapshot = .placeholder
    @Published var adminStatus: AdminGameStatus?
    @Published var isLoading = false
    @Published var isPerformingAction = false
    @Published var errorMessage = ""
    @Published var infoMessage = ""

    private let gameId: String
    private let gameService: GameService
    private let authService: AuthService

    init(gameId: String, gameService: GameService, authService: AuthService) {
        self.gameId = gameId
        self.gameService = gameService
        self.authService = authService
    }

    var title: String {
        summary?.name ?? adminStatus?.name.nonEmpty ?? snapshot.gameId.nonEmpty ?? gameId
    }

    var gameDefinitionName: String {
        summary?.gameDefinitionName ?? adminStatus?.gameDefinitionName ?? "Borderland Classic"
    }

    var canOpenControlRoom: Bool {
        summary?.canManageSensitive == true
    }

    var canOpenPlayerFlow: Bool {
        summary?.joinedAsPlayer == true
    }

    var canJoinAsLockedGameMaster: Bool {
        guard let summary else { return false }
        return summary.role.isManager && !summary.joinedAsPlayer && !summary.isCurrentUserLockedGm
    }

    var canArchiveGame: Bool {
        summary?.role == .owner && summary?.isArchived == false
    }

    func inviteURL(for code: String, kind: InviteKind) -> URL? {
        AppConfig.inviteLandingURL(
            code: code,
            isOperatorInvite: kind.isOperatorInvite
        )
    }

    func inviteShareText(for code: String, kind: InviteKind) -> String {
        AppConfig.inviteShareText(
            code: code,
            isOperatorInvite: kind.isOperatorInvite
        )
    }

    func inviteQRCodePreview(for code: String, kind: InviteKind) -> QRCodePreview {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return QRCodePreview(
            title: kind.isOperatorInvite ? "QR accesso operatore" : "QR accesso player",
            subtitle: "Mostralo sullo schermo: dall'app si puo inquadrare dalla schermata \"Entra in una partita\" oppure inserire il codice a mano.",
            token: normalizedCode
        )
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Niente async let sulle callable Firebase (crash Release, v. StoreHomeViewModel).
            let games = try await gameService.listAccessibleGames()
            snapshot = try await gameService.fetchMatchSnapshot(gameId: gameId)
            profile = try await gameService.fetchOwnProfile()
            summary = games.first(where: { $0.id == gameId }).map(mergeAutonomousSetup)
            if summary?.canManageSensitive == true {
                adminStatus = (try? await gameService.fetchAdminGame(gameId: gameId)).map(mergeAutonomousSetup)
            } else {
                adminStatus = nil
            }
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshAfterAction() async {
        await load()
    }

    func joinAsPlayer() async -> Bool {
        guard !isPerformingAction else { return false }
        let nickname = preferredNickname()
        guard !nickname.isEmpty else {
            errorMessage = "Completa nickname e avatar prima di entrare come player."
            return false
        }

        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            _ = try await gameService.joinSelectedGame(
                gameId: gameId,
                nickname: nickname,
                asLockedGameMaster: summary?.role.isManager == true
            )
            infoMessage = summary?.role.isManager == true
                ? "Sei entrato come player con lock GM persistente."
                : "Ingresso come player completato."
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func archiveGame() async {
        guard canArchiveGame, !isPerformingAction else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            try await gameService.deleteAdminGame(gameId: gameId)
            infoMessage = "Partita archiviata."
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reuseGame() async {
        guard let summary, let adminStatus, !isPerformingAction else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            let suffix = DateFormatter.localizedString(from: .now, dateStyle: .short, timeStyle: .short)
            _ = try await gameService.createAdminGame(
                name: "\(summary.name) \(suffix)",
                gameId: nil,
                gameDefinitionId: summary.gameDefinitionId,
                config: adminStatus.config,
                itemMode: adminStatus.itemMode
            )
            infoMessage = "Nuova partita creata riusando configurazione e modalità oggetti."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func transitionToDistribution() async {
        await runManagerAction {
            try await gameService.transitionToDistribution(gameId: gameId)
        }
    }

    func startMatch() async {
        await runManagerAction {
            try await gameService.startMatch(gameId: gameId)
        }
    }

    func pauseMatch() async {
        await runManagerAction {
            try await gameService.pauseMatch(gameId: gameId)
        }
    }

    func resumeMatch() async {
        await runManagerAction {
            try await gameService.resumeMatch(gameId: gameId)
        }
    }

    func endMatch() async {
        await runManagerAction {
            try await gameService.endMatch(gameId: gameId)
        }
    }

    private func runManagerAction(_ action: () async throws -> Void) async {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            try await action()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func preferredNickname() -> String {
        let profileNickname = profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if !profileNickname.isEmpty {
            return profileNickname
        }
        let ownNickname = authService.currentUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !ownNickname.isEmpty {
            return ownNickname
        }
        return "Player iOS"
    }

    private func mergeAutonomousSetup(_ summary: GameAccessSummary) -> GameAccessSummary {
        guard !summary.hasAutonomousSetup else { return summary }
        guard let localSetup = AutonomousGamePreferencesStore.load(for: summary.id) else { return summary }
        return summary.applyingAutonomousSetup(localSetup)
    }

    private func mergeAutonomousSetup(_ status: AdminGameStatus) -> AdminGameStatus {
        guard !status.hasAutonomousSetup else { return status }
        guard let localSetup = AutonomousGamePreferencesStore.load(for: status.gameId) else { return status }
        return AdminGameStatus(
            name: status.name,
            gameId: status.gameId,
            gameDefinitionId: status.gameDefinitionId,
            gameDefinitionName: status.gameDefinitionName,
            state: status.state,
            config: status.config,
            hasConfigSnapshot: status.hasConfigSnapshot,
            hasBaseSnapshot: status.hasBaseSnapshot,
            participants: status.participants,
            teamABaseToken: status.teamABaseToken,
            teamBBaseToken: status.teamBBaseToken,
            teamABaseQrToken: status.teamABaseQrToken,
            teamBBaseQrToken: status.teamBBaseQrToken,
            itemMode: status.itemMode,
            gameItems: status.gameItems,
            autonomousSetup: localSetup,
            hasAutonomousSetup: false
        )
    }
}
