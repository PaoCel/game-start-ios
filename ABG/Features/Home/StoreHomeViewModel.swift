import Combine
import Foundation

@MainActor
final class StoreHomeViewModel: ObservableObject {
    @Published var profile: PlayerProfile = .empty
    @Published var catalog: [GameCatalogEntry] = []
    @Published var games: [GameAccessSummary] = []
    @Published var isLoading = false
    @Published var isCreatingGame = false
    @Published var isJoiningGame = false
    @Published var errorMessage = ""

    private let authService: AuthService
    private let gameService: GameService
    private var pushTokenObserver: NSObjectProtocol?

    init(authService: AuthService, gameService: GameService) {
        self.authService = authService
        self.gameService = gameService
        pushTokenObserver = NotificationCenter.default.addObserver(
            forName: .pushTokenDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.syncPushRegistration() }
        }
    }

    deinit {
        if let pushTokenObserver {
            NotificationCenter.default.removeObserver(pushTokenObserver)
        }
    }

    var displayName: String {
        let nickname = profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if !nickname.isEmpty {
            return nickname
        }
        if let displayName = authService.currentUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            return displayName
        }
        return "Giocatore"
    }

    var avatarDataUrl: String? {
        profile.avatarDataUrl
    }

    var canCreateGames: Bool {
        !(authService.currentUser?.isGuest ?? false)
    }

    var needsProfileCompletion: Bool {
        !(authService.currentUser?.isGuest ?? false) && !profile.profileCompleted
    }

    var isBusy: Bool {
        isLoading || isCreatingGame || isJoiningGame
    }

    var canStartCreateFlow: Bool {
        canCreateGames && !catalog.isEmpty && !isBusy
    }

    var organizedGames: [GameAccessSummary] {
        activeGames.filter { $0.role.isManager }.sorted(by: sortByRecent)
    }

    var joinedGames: [GameAccessSummary] {
        activeGames
            .filter { $0.joinedAsPlayer || $0.role == .player || $0.isCurrentUserLockedGm }
            .sorted(by: sortByRecent)
    }

    var archivedGames: [GameAccessSummary] {
        games.filter(\.isArchivedOrEnded).sorted(by: sortByRecent)
    }

    var preferredLiveGame: GameAccessSummary? {
        activeGames
            .filter { summary in
                summary.state.uppercased() == "LIVE" &&
                (summary.joinedAsPlayer || summary.role == .player || summary.isCurrentUserLockedGm)
            }
            .sorted(by: sortByRecent)
            .first
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Niente async let sulle callable Firebase: il teardown del child task
            // abortiva in Release su device (asyncLet_finish_after_task_completion).
            profile = try await gameService.fetchOwnProfile()
            catalog = try await gameService.listGameCatalog()
            let loadedGames = try await gameService.listAccessibleGames()
            games = loadedGames.map(mergeAutonomousSetup)
            errorMessage = ""
            await syncPushRegistration()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshGames() async {
        do {
            let loadedGames = try await gameService.listAccessibleGames()
            games = loadedGames.map(mergeAutonomousSetup)
            errorMessage = ""
            await syncPushRegistration()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createGame(
        name: String,
        gameDefinitionId: String,
        config: GameplayConfigSnapshot,
        itemMode: ItemMode,
        autonomousSetup: AutonomousGameSetup
    ) async throws -> GameAccessSummary {
        guard !needsProfileCompletion else {
            throw profileCompletionRequiredError()
        }
        isCreatingGame = true
        defer { isCreatingGame = false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedDefinition = catalog.first(where: { $0.id == gameDefinitionId })
        var resolvedAutonomousSetup = autonomousSetup
        if resolvedAutonomousSetup.creatorUid?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            let creatorUid = profile.uid.trimmingCharacters(in: .whitespacesAndNewlines)
            resolvedAutonomousSetup.creatorUid = creatorUid.isEmpty ? nil : creatorUid
        }

        let created = try await gameService.createAdminGame(
            name: trimmedName,
            gameId: nil,
            gameDefinitionId: gameDefinitionId,
            config: config,
            itemMode: itemMode,
            autonomousSetup: resolvedAutonomousSetup
        )

        let fallbackSummary = GameAccessSummary(
            id: created.gameId,
            name: trimmedName,
            gameDefinitionId: gameDefinitionId,
            gameDefinitionName: selectedDefinition?.name ?? "Borderland Classic",
            state: created.state,
            role: .owner,
            playerCount: 0,
            itemMode: itemMode,
            joinedAsPlayer: false,
            canManageSensitive: true,
            canManageOperations: true,
            isCurrentUserLockedGm: false,
            gmPlayerLockEnabled: false,
            joinCode: nil,
            operatorInviteCode: nil,
            updatedAt: nil,
            autonomousSetup: resolvedAutonomousSetup,
            hasAutonomousSetup: true
        )
        AutonomousGamePreferencesStore.save(resolvedAutonomousSetup, for: created.gameId)

        do {
            let loadedGames = try await gameService.listAccessibleGames()
            games = loadedGames.map(mergeAutonomousSetup)
            return games.first(where: { $0.id == created.gameId }) ?? mergeAutonomousSetup(fallbackSummary)
        } catch {
            if !games.contains(where: { $0.id == fallbackSummary.id }) {
                games.insert(mergeAutonomousSetup(fallbackSummary), at: 0)
            }
            return mergeAutonomousSetup(fallbackSummary)
        }
    }

    func joinGame(codeOrLink: String) async throws -> GameAccessSummary {
        guard !needsProfileCompletion else {
            throw profileCompletionRequiredError()
        }
        isJoiningGame = true
        defer { isJoiningGame = false }

        let nickname = profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let joined = try await gameService.joinGameByCode(
            codeOrLink: codeOrLink,
            nickname: nickname.isEmpty ? nil : nickname
        )
        await refreshGames()
        return games.first(where: { $0.id == joined.id }) ?? mergeAutonomousSetup(joined)
    }

    private func sortByRecent(lhs: GameAccessSummary, rhs: GameAccessSummary) -> Bool {
        switch (lhs.updatedAt, rhs.updatedAt) {
        case let (left?, right?):
            return left > right
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        case (nil, nil):
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var activeGames: [GameAccessSummary] {
        games.filter { !$0.isArchivedOrEnded }
    }

    private var preferredPushGame: GameAccessSummary? {
        activeGames
            .filter { $0.joinedAsPlayer || $0.role == .player || $0.isCurrentUserLockedGm }
            .sorted { lhs, rhs in
                let lhsLive = lhs.state.uppercased() == "LIVE"
                let rhsLive = rhs.state.uppercased() == "LIVE"
                if lhsLive != rhsLive {
                    return lhsLive && !rhsLive
                }
                return sortByRecent(lhs: lhs, rhs: rhs)
            }
            .first
    }

    private func syncPushRegistration() async {
        let relevantGames = preferredPushGame.map { [$0] } ?? games
        await PushRegistrationCoordinator.shared.syncRegistration(
            gameService: gameService,
            games: relevantGames,
            userAgent: "ios-home"
        )
    }

    private func mergeAutonomousSetup(_ summary: GameAccessSummary) -> GameAccessSummary {
        guard !summary.hasAutonomousSetup else { return summary }
        guard let localSetup = AutonomousGamePreferencesStore.load(for: summary.id) else { return summary }
        return summary.applyingAutonomousSetup(localSetup)
    }

    private func profileCompletionRequiredError() -> NSError {
        NSError(
            domain: "StoreHomeViewModel",
            code: 1001,
            userInfo: [NSLocalizedDescriptionKey: "Completa prima il profilo per entrare nelle partite."]
        )
    }
}
