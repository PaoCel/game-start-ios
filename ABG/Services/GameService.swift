import Foundation

protocol GameService {
    func listGameCatalog() async throws -> [GameCatalogEntry]
    func fetchMatchSnapshot(gameId: String?) async throws -> MatchSnapshot
    func fetchOwnProfile() async throws -> PlayerProfile
    func fetchTeamParticipants(gameId: String) async throws -> [MatchSnapshot.Participant]
    func joinActiveGame(nickname: String) async throws -> MatchSnapshot
    func joinMatch(gameCode: String, nickname: String) async throws -> MatchSnapshot
    func joinSelectedGame(gameId: String, nickname: String, asLockedGameMaster: Bool) async throws -> MatchSnapshot
    func joinGameByCode(codeOrLink: String, nickname: String?) async throws -> GameAccessSummary
    func listAccessibleGames() async throws -> [GameAccessSummary]
    func submitScan(gameId: String, token: String, tokenCandidates: [String], source: String) async throws -> ScanSubmissionOutcome
    func ensurePlayerQRCode(gameId: String?) async throws -> (token: String, url: String)
    func registerBraceletToken(token: String, gameId: String?, tokenCandidates: [String]) async throws -> String
    func registerPushToken(token: String, gameId: String, userAgent: String?) async throws
    func unregisterPushToken(token: String?) async throws
    func deleteCurrentAccount() async throws
    func setTeamReady(gameId: String, isReady: Bool) async throws -> MatchSnapshot
    func sendTeamReadyReminder(gameId: String) async throws
    func playerSelectOwnTeam(gameId: String, teamId: String) async throws
    func playerShuffleTeams(gameId: String) async throws
    func savePlayerProfile(_ profile: PlayerProfile) async throws
    func fetchAdminActiveGame() async throws -> AdminGameStatus
    func fetchAdminGame(gameId: String) async throws -> AdminGameStatus
    func fetchAdminOwnedGames() async throws -> [GameSummary]
    func createAdminGame(
        name: String,
        gameId: String?,
        gameDefinitionId: String?,
        config: GameplayConfigSnapshot,
        itemMode: ItemMode,
        autonomousSetup: AutonomousGameSetup?
    ) async throws -> AdminGameStatus
    func deleteAdminGame(gameId: String) async throws
    func transitionToDistribution(gameId: String) async throws
    func startMatch(gameId: String) async throws
    func pauseMatch(gameId: String) async throws
    func resumeMatch(gameId: String) async throws
    func endMatch(gameId: String) async throws
    func pickRandomLeaders(gameId: String) async throws
    func distributeTeamPoints(gameId: String, allocations: [String: Int]) async throws
    func updateGameConfig(
        gameId: String,
        config: GameplayConfigSnapshot,
        itemMode: ItemMode?,
        autonomousSetup: AutonomousGameSetup?
    ) async throws
    func setBaseToken(gameId: String, teamId: String, token: String, tokenCandidates: [String], overwriteExistingBase: Bool) async throws
    // Roster — reads games/{gameId}/publicPlayers (correct data source for admin)
    func adminFetchRoster(gameId: String) async throws -> [AdminGameStatus.Participant]
    // Player management
    func adminAssignPlayerToTeam(gameId: String, playerId: String, teamId: String?) async throws
    func adminRemovePlayerFromGame(gameId: String, playerId: String) async throws
    func adminSetTeamLeader(gameId: String, playerId: String, teamId: String) async throws
    // Game items
    func adminRegisterGameItem(gameId: String, token: String?, tokenCandidates: [String], icon: String, points: Int, collectorTeamId: String?) async throws -> AdminGameStatus.GameItem
    func adminAttachItemToken(gameId: String, itemId: String, token: String, tokenCandidates: [String]) async throws
    func adminFetchGameItems(gameId: String) async throws -> [AdminGameStatus.GameItem]
    func adminExportGameEvents(gameId: String, limit: Int) async throws -> AdminGameEventExport
    func adminLookupTag(gameId: String, token: String, tokenCandidates: [String]) async throws -> AdminGameStatus.TagLookup
    // Token conflict cleanup
    func adminCleanupTokenConflict(gameId: String, token: String, tokenCandidates: [String], correctType: String) async throws
}

extension GameService {
    func fetchMatchSnapshot() async throws -> MatchSnapshot {
        try await fetchMatchSnapshot(gameId: nil)
    }

    func submitScan(gameId: String, token: String, source: String) async throws -> ScanSubmissionOutcome {
        try await submitScan(gameId: gameId, token: token, tokenCandidates: [], source: source)
    }

    func registerBraceletToken(token: String, gameId: String?) async throws -> String {
        try await registerBraceletToken(token: token, gameId: gameId, tokenCandidates: [])
    }

    func setBaseToken(gameId: String, teamId: String, token: String, overwriteExistingBase: Bool) async throws {
        try await setBaseToken(
            gameId: gameId,
            teamId: teamId,
            token: token,
            tokenCandidates: [],
            overwriteExistingBase: overwriteExistingBase
        )
    }

    func createAdminGame(name: String, gameId: String?, config: GameplayConfigSnapshot) async throws -> AdminGameStatus {
        try await createAdminGame(
            name: name,
            gameId: gameId,
            gameDefinitionId: nil,
            config: config,
            itemMode: .none,
            autonomousSetup: nil
        )
    }

    func createAdminGame(
        name: String,
        gameId: String?,
        gameDefinitionId: String?,
        config: GameplayConfigSnapshot,
        itemMode: ItemMode
    ) async throws -> AdminGameStatus {
        try await createAdminGame(
            name: name,
            gameId: gameId,
            gameDefinitionId: gameDefinitionId,
            config: config,
            itemMode: itemMode,
            autonomousSetup: nil
        )
    }

    func createAdminGame(name: String, gameId: String?, config: GameplayConfigSnapshot, itemMode: ItemMode) async throws -> AdminGameStatus {
        try await createAdminGame(
            name: name,
            gameId: gameId,
            gameDefinitionId: nil,
            config: config,
            itemMode: itemMode,
            autonomousSetup: nil
        )
    }

    func updateGameConfig(gameId: String, config: GameplayConfigSnapshot) async throws {
        try await updateGameConfig(gameId: gameId, config: config, itemMode: nil, autonomousSetup: nil)
    }

    func updateGameConfig(gameId: String, config: GameplayConfigSnapshot, itemMode: ItemMode?) async throws {
        try await updateGameConfig(
            gameId: gameId,
            config: config,
            itemMode: itemMode,
            autonomousSetup: nil
        )
    }

    func adminRegisterGameItem(gameId: String, token: String, icon: String, points: Int) async throws -> AdminGameStatus.GameItem {
        try await adminRegisterGameItem(
            gameId: gameId,
            token: token,
            tokenCandidates: [],
            icon: icon,
            points: points,
            collectorTeamId: nil
        )
    }

    func adminRegisterGameItem(gameId: String, token: String, tokenCandidates: [String], icon: String, points: Int) async throws -> AdminGameStatus.GameItem {
        try await adminRegisterGameItem(
            gameId: gameId,
            token: token,
            tokenCandidates: tokenCandidates,
            icon: icon,
            points: points,
            collectorTeamId: nil
        )
    }

    func adminLookupTag(gameId: String, token: String) async throws -> AdminGameStatus.TagLookup {
        try await adminLookupTag(gameId: gameId, token: token, tokenCandidates: [])
    }

    func adminCleanupTokenConflict(gameId: String, token: String, correctType: String) async throws {
        try await adminCleanupTokenConflict(
            gameId: gameId,
            token: token,
            tokenCandidates: [],
            correctType: correctType
        )
    }

    func adminRegisterGameItem(gameId: String, icon: String, points: Int, collectorTeamId: String?) async throws -> AdminGameStatus.GameItem {
        try await adminRegisterGameItem(
            gameId: gameId,
            token: nil,
            tokenCandidates: [],
            icon: icon,
            points: points,
            collectorTeamId: collectorTeamId
        )
    }

    func adminAttachItemToken(gameId: String, itemId: String, token: String) async throws {
        try await adminAttachItemToken(
            gameId: gameId,
            itemId: itemId,
            token: token,
            tokenCandidates: []
        )
    }
}

enum GameServiceFactory {
    static func make() -> GameService {
        #if canImport(FirebaseFunctions)
        return FirebaseGameService()
        #else
        return MockGameService()
        #endif
    }
}

final class MockGameService: GameService {
    func listGameCatalog() async throws -> [GameCatalogEntry] {
        [
            GameCatalogEntry(
                id: "borderland-classic",
                name: "Borderland Classic",
                shortDescription: "Sfida live a squadre con identità random server-side, timer autorevole e punti segreti per player.",
                supportedItemModes: ItemMode.allCases,
                recommendedItemModes: [.none, .crossTeam],
                defaultItemMode: .none,
                isActive: true
            )
        ]
    }

    func fetchMatchSnapshot(gameId: String?) async throws -> MatchSnapshot {
        _ = gameId
        return .placeholder
    }

    func fetchOwnProfile() async throws -> PlayerProfile {
        var profile = PlayerProfile.empty
        profile.uid = "mock-player"
        profile.nickname = "Giocatore Demo"
        profile.profileCompleted = true
        return profile
    }

    func joinActiveGame(nickname: String) async throws -> MatchSnapshot {
        _ = nickname
        var snapshot = MatchSnapshot.placeholder
        snapshot.isJoined = true
        snapshot.joinAllowed = true
        snapshot.gameId = "mock-game"
        return snapshot
    }

    func fetchTeamParticipants(gameId: String) async throws -> [MatchSnapshot.Participant] {
        _ = gameId
        return []
    }

    func joinMatch(gameCode: String, nickname: String) async throws -> MatchSnapshot {
        _ = gameCode
        return try await joinActiveGame(nickname: nickname)
    }

    func joinSelectedGame(gameId: String, nickname: String, asLockedGameMaster: Bool) async throws -> MatchSnapshot {
        _ = gameId
        _ = asLockedGameMaster
        return try await joinActiveGame(nickname: nickname)
    }

    func joinGameByCode(codeOrLink: String, nickname: String?) async throws -> GameAccessSummary {
        _ = codeOrLink
        _ = nickname
        return GameAccessSummary(
            id: "mock-game",
            name: "Mock Game",
            gameDefinitionId: "borderland-classic",
            gameDefinitionName: "Borderland Classic",
            state: "LOBBY",
            role: .player,
            playerCount: 1,
            itemMode: .none,
            joinedAsPlayer: true,
            canManageSensitive: false,
            canManageOperations: false,
            isCurrentUserLockedGm: false,
            gmPlayerLockEnabled: false,
            joinCode: "MOCK123",
            operatorInviteCode: nil,
            updatedAt: nil,
            autonomousSetup: .gameMasterDefault,
            hasAutonomousSetup: false
        )
    }

    func listAccessibleGames() async throws -> [GameAccessSummary] {
        []
    }

    func ensurePlayerQRCode(gameId: String?) async throws -> (token: String, url: String) {
        let gameKey = (gameId?.isEmpty == false ? gameId! : "mock-game")
        let token = "player-\(gameKey)-mock-player"
        return (token: token, url: "https://borderland.games/code/\(token)")
    }

    func submitScan(gameId: String, token: String, tokenCandidates: [String], source: String) async throws -> ScanSubmissionOutcome {
        _ = gameId
        _ = tokenCandidates
        return ScanSubmissionOutcome(
            status: "COMPLETED",
            ownPoints: nil,
            opponentUid: nil,
            amount: 0,
            transferId: nil,
            itemId: nil,
            effectType: nil,
            reason: "scan accepted: \(token) via \(source)",
            cooldownRemainingSec: nil,
            cooldownScope: nil,
            availableInSec: nil,
            battleStatus: nil,
            inactiveReason: nil,
            baseDefenseRemainingSec: nil,
            baseDefenseCooldownRemainingSec: nil,
            baseDefensePoints: nil,
            battleSummary: nil
        )
    }

    func registerBraceletToken(token: String, gameId: String?, tokenCandidates: [String]) async throws -> String {
        _ = gameId
        _ = tokenCandidates
        return normalizeTagToken(token)
    }

    func registerPushToken(token: String, gameId: String, userAgent: String?) async throws {
        _ = token
        _ = gameId
        _ = userAgent
    }

    func unregisterPushToken(token: String?) async throws {
        _ = token
    }

    func deleteCurrentAccount() async throws {}

    func setTeamReady(gameId: String, isReady: Bool) async throws -> MatchSnapshot {
        _ = isReady
        return try await fetchMatchSnapshot(gameId: gameId)
    }

    func sendTeamReadyReminder(gameId: String) async throws {
        _ = gameId
    }

    func playerSelectOwnTeam(gameId: String, teamId: String) async throws {
        _ = gameId
        _ = teamId
    }

    func playerShuffleTeams(gameId: String) async throws {
        _ = gameId
    }

    func savePlayerProfile(_ profile: PlayerProfile) async throws {
        _ = profile
    }

    func fetchAdminActiveGame() async throws -> AdminGameStatus {
        .empty
    }

    func fetchAdminGame(gameId: String) async throws -> AdminGameStatus {
        _ = gameId
        return .empty
    }

    func fetchAdminOwnedGames() async throws -> [GameSummary] {
        []
    }

    func createAdminGame(
        name: String,
        gameId: String?,
        gameDefinitionId: String?,
        config: GameplayConfigSnapshot,
        itemMode: ItemMode,
        autonomousSetup: AutonomousGameSetup?
    ) async throws -> AdminGameStatus {
        _ = name
        _ = gameId
        _ = autonomousSetup
        return AdminGameStatus(
            name: name,
            gameId: "mock-game",
            gameDefinitionId: gameDefinitionId ?? "borderland-classic",
            gameDefinitionName: "Borderland Classic",
            state: "LOBBY",
            config: config,
            hasConfigSnapshot: true,
            hasBaseSnapshot: false,
            participants: [],
            teamABaseToken: nil,
            teamBBaseToken: nil,
            teamABaseQrToken: nil,
            teamBBaseQrToken: nil,
            itemMode: itemMode,
            gameItems: [],
            autonomousSetup: .gameMasterDefault,
            hasAutonomousSetup: false
        )
    }

    func deleteAdminGame(gameId: String) async throws {
        _ = gameId
    }

    func transitionToDistribution(gameId: String) async throws { _ = gameId }
    func startMatch(gameId: String) async throws { _ = gameId }
    func pauseMatch(gameId: String) async throws { _ = gameId }
    func resumeMatch(gameId: String) async throws { _ = gameId }
    func endMatch(gameId: String) async throws { _ = gameId }
    func pickRandomLeaders(gameId: String) async throws { _ = gameId }

    func distributeTeamPoints(gameId: String, allocations: [String: Int]) async throws {
        _ = gameId
        _ = allocations
    }

    func updateGameConfig(
        gameId: String,
        config: GameplayConfigSnapshot,
        itemMode: ItemMode?,
        autonomousSetup: AutonomousGameSetup?
    ) async throws {
        _ = gameId
        _ = config
        _ = itemMode
        _ = autonomousSetup
    }

    func setBaseToken(gameId: String, teamId: String, token: String, tokenCandidates: [String], overwriteExistingBase: Bool) async throws {
        _ = gameId
        _ = teamId
        _ = token
        _ = tokenCandidates
        _ = overwriteExistingBase
    }

    func adminAssignPlayerToTeam(gameId: String, playerId: String, teamId: String?) async throws {
        _ = gameId
        _ = playerId
        _ = teamId
    }

    func adminRemovePlayerFromGame(gameId: String, playerId: String) async throws {
        _ = gameId
        _ = playerId
    }

    func adminSetTeamLeader(gameId: String, playerId: String, teamId: String) async throws {
        _ = gameId
        _ = playerId
        _ = teamId
    }

    func adminFetchRoster(gameId: String) async throws -> [AdminGameStatus.Participant] {
        _ = gameId
        return []
    }

    func adminRegisterGameItem(gameId: String, token: String?, tokenCandidates: [String], icon: String, points: Int, collectorTeamId: String?) async throws -> AdminGameStatus.GameItem {
        _ = gameId
        _ = tokenCandidates
        let itemId = token ?? UUID().uuidString.lowercased()
        let qrToken = "item-\(itemId)"
        return AdminGameStatus.GameItem(
            id: itemId,
            icon: icon,
            points: points,
            collectorTeamId: collectorTeamId,
            nfcToken: token,
            qrToken: qrToken,
            qrUrl: "https://borderland.games/code/\(qrToken)"
        )
    }

    func adminAttachItemToken(gameId: String, itemId: String, token: String, tokenCandidates: [String]) async throws {
        _ = gameId
        _ = itemId
        _ = token
        _ = tokenCandidates
    }

    func adminFetchGameItems(gameId: String) async throws -> [AdminGameStatus.GameItem] {
        _ = gameId
        return []
    }

    func adminExportGameEvents(gameId: String, limit: Int) async throws -> AdminGameEventExport {
        _ = gameId
        _ = limit
        return AdminGameEventExport(
            gameId: "mock-game",
            gameName: "Mock Game",
            state: "LIVE",
            exportedAt: "2026-03-11T18:40:00Z",
            totalEventCount: 4,
            truncated: false,
            entries: [
                .init(
                    id: "1",
                    sequence: 11,
                    type: "TEAM_SYNC_PENDING",
                    scope: "TEAM",
                    createdAt: "2026-03-11T18:31:12Z",
                    actorUid: "player-a",
                    actorNickname: "Paolo",
                    severity: "INFO",
                    message: "Sync team: Paolo collega Luca (5s)",
                    payloadJson: "{\n  \"scannerUid\": \"player-a\",\n  \"targetUid\": \"player-b\",\n  \"windowSec\": 5\n}"
                ),
                .init(
                    id: "2",
                    sequence: 12,
                    type: "SCAN_PENDING",
                    scope: "PLAYER",
                    createdAt: "2026-03-11T18:31:18Z",
                    actorUid: "player-a",
                    actorNickname: "Paolo",
                    severity: "WARNING",
                    message: "Ingaggio aperto: Paolo -> Marta (8s per la reciproca)",
                    payloadJson: "{\n  \"scannerUid\": \"player-a\",\n  \"opponentUid\": \"player-x\",\n  \"handshakeWindowSec\": 8\n}"
                ),
                .init(
                    id: "3",
                    sequence: 13,
                    type: "POINT_TRANSFER",
                    scope: "GLOBAL",
                    createdAt: "2026-03-11T18:31:21Z",
                    actorUid: "player-a",
                    actorNickname: "Paolo",
                    severity: "SUCCESS",
                    message: "Cittadini vince contro Giocatori (+500)",
                    payloadJson: "{\n  \"amount\": 500,\n  \"winnerSide\": \"OPPONENT\"\n}"
                ),
                .init(
                    id: "4",
                    sequence: 14,
                    type: "PLAYER_ELIMINATED",
                    scope: "GLOBAL",
                    createdAt: "2026-03-11T18:31:21Z",
                    actorUid: "player-a",
                    actorNickname: "Paolo",
                    severity: "ERROR",
                    message: "Marta eliminato",
                    payloadJson: "{\n  \"uid\": \"player-x\",\n  \"nickname\": \"Marta\"\n}"
                )
            ]
        )
    }

    func adminLookupTag(gameId: String, token: String, tokenCandidates: [String]) async throws -> AdminGameStatus.TagLookup {
        _ = gameId
        _ = tokenCandidates
        return AdminGameStatus.TagLookup(
            tagId: token,
            entityType: "free",
            bindingId: nil,
            ownerId: nil,
            teamId: nil,
            itemId: nil,
            playerUid: nil,
            playerNickname: nil,
            itemIcon: nil,
            itemPoints: nil
        )
    }

    func adminCleanupTokenConflict(gameId: String, token: String, tokenCandidates: [String], correctType: String) async throws {
        _ = gameId
        _ = token
        _ = tokenCandidates
        _ = correctType
    }
}
