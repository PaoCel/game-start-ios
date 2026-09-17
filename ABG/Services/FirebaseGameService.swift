#if canImport(FirebaseFunctions)
import FirebaseFunctions
import Foundation
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

final class FirebaseGameService: GameService {
  private lazy var functions = Functions.functions(region: "us-central1")
  private let callableTimeoutNs: UInt64 = 12_000_000_000
  private let profileCacheLock = NSLock()
  private var cachedOwnProfile: PlayerProfile?
  private var cachedOwnProfileUid: String?
  private var ownProfileTask: Task<PlayerProfile, Error>?

  func listGameCatalog() async throws -> [GameCatalogEntry] {
    let payload = try await call(AppConfig.Callable.listGameCatalog, [:])
    let root = asDict(payload)
    let rawEntries = asArray(root["games"])
    return rawEntries.compactMap { parseGameCatalogEntry(asDict($0)) }
  }

  func fetchMatchSnapshot(gameId: String?) async throws -> MatchSnapshot {
    var request: [String: Any] = [:]
    if let gameId, !gameId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      request["gameId"] = gameId
    }
    let payload = try await call(AppConfig.Callable.playerGetActiveGameStatus, request)
    let root = asDict(payload)
    AppLogger.info("[FGS] playerGetActiveGameStatus top-level keys: \(root.keys.sorted().joined(separator: ", "))")
    return parseMatchSnapshot(root)
  }

  func fetchOwnProfile() async throws -> PlayerProfile {
    let currentUid = currentAuthenticatedUid()
    if let cached = cachedProfile(for: currentUid) {
      return cached
    }
    if let task = inFlightProfileTask(for: currentUid) {
      return try await task.value
    }

    let task = Task<PlayerProfile, Error> {
      let payload = try await self.call(AppConfig.Callable.playerGetProfile, [:])
      let root = asDict(payload)
      return PlayerProfile(
        uid: string(root["uid"]) ?? "",
        nickname: string(root["nickname"]) ?? "",
        avatarDataUrl: string(root["avatarDataUrl"]),
        playingCard: self.normalizePlayingCard(string(root["playingCard"])),
        identityCardCode: nil,
        identityDeckIndex: nil,
        points: int(root["points"]) ?? 0,
        teamId: string(root["teamId"]),
        roleInTeam: string(root["roleInTeam"]),
        preferredBraceletToken: string(root["preferredBraceletToken"]) ?? string(root["braceletToken"]),
        profileCompleted: bool(root["profileCompleted"])
      )
    }
    storeProfileTask(task, for: currentUid)

    do {
      let profile = try await task.value
      storeCachedProfile(profile, for: currentUid)
      return profile
    } catch {
      clearProfileTask(for: currentUid)
      throw error
    }
  }

  func fetchTeamParticipants(gameId: String) async throws -> [MatchSnapshot.Participant] {
    let payload = try await call(AppConfig.Callable.playerGetScoreboard, ["gameId": gameId])
    let root = asDict(payload)
    AppLogger.info("[FGS] playerGetScoreboard top-level keys: \(root.keys.sorted().joined(separator: ", "))")
    // Server returns { players: [{uid, nickname, avatarDataUrl, teamId, points, isSelf}] }
    let raw: [Any]
    if let players = root["players"] as? [Any], !players.isEmpty {
      raw = players
    } else {
      raw = asArray(root["players"])
    }
    let participants = parseMatchParticipantArray(raw)
    AppLogger.info("[FGS] playerGetScoreboard parsed \(participants.count) participants")
    return participants
  }

  func joinActiveGame(nickname: String) async throws -> MatchSnapshot {
    let payload = try await call(
      AppConfig.Callable.playerJoinActiveGame,
      [
        "nickname": nickname
      ]
    )
    return try await confirmedJoinSnapshot(
      fromPayload: payload,
      fallbackGameId: nil,
      errorCode: 1001,
      errorMessage: "Join non confermato dal server"
    )
  }

  func joinMatch(gameCode: String, nickname: String) async throws -> MatchSnapshot {
    let payload = try await call(
      AppConfig.Callable.playerJoinActiveGame,
      [
        "nickname": nickname,
        "code": gameCode,
        "gameCode": gameCode,
        "matchCode": gameCode
      ]
    )
    return try await confirmedJoinSnapshot(
      fromPayload: payload,
      fallbackGameId: gameCode,
      errorCode: 1003,
      errorMessage: "Join non confermato dal server"
    )
  }

  func joinSelectedGame(gameId: String, nickname: String, asLockedGameMaster: Bool) async throws -> MatchSnapshot {
    let payload = try await call(
      AppConfig.Callable.playerJoinActiveGame,
      [
        "nickname": nickname,
        "gameId": gameId,
        "asLockedGameMaster": asLockedGameMaster
      ]
    )
    return try await confirmedJoinSnapshot(
      fromPayload: payload,
      fallbackGameId: gameId,
      errorCode: 1007,
      errorMessage: "Join non confermato dal server"
    )
  }

  func joinGameByCode(codeOrLink: String, nickname: String?) async throws -> GameAccessSummary {
    var payload: [String: Any] = ["code": codeOrLink]
    if let nickname, !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      payload["nickname"] = nickname
    }
    let result = try await call(AppConfig.Callable.playerJoinByCode, payload)
    if let parsed = parseGameAccessSummary(asDict(result)) {
      return parsed
    }
    throw NSError(
      domain: "FirebaseGameService",
      code: 1011,
      userInfo: [NSLocalizedDescriptionKey: "Risposta join codice non valida"]
    )
  }

  func listAccessibleGames() async throws -> [GameAccessSummary] {
    let payload = try await call(AppConfig.Callable.adminListOwnedGames, [:])
    let root = asDict(payload)
    let rawGames = asArray(root["games"])
    return rawGames.compactMap { entry in
      parseGameAccessSummary(asDict(entry))
    }
  }

  // Il requestId resta stabile per i retry della stessa azione (timeout client con
  // callable andata comunque a segno): il server dedupa su uid_requestId, quindi il
  // retry restituisce l'esito già calcolato invece di produrre un secondo colpo.
  private var pendingScanRequestIds: [String: (id: String, createdAt: Date)] = [:]

  func submitScan(gameId: String, token: String, tokenCandidates: [String], source: String) async throws -> ScanSubmissionOutcome {
    let normalizedToken = normalizeTagToken(token)
    let normalizedCandidates = normalizeTagTokenCandidates([normalizedToken] + tokenCandidates)

    let requestKey = "\(gameId)|\(normalizedToken)|\(source)"
    let requestId: String
    if let cached = pendingScanRequestIds[requestKey],
       Date().timeIntervalSince(cached.createdAt) < 25 {
      requestId = cached.id
    } else {
      requestId = "\(Int(Date().timeIntervalSince1970 * 1000))_ios_\(source)_\(UUID().uuidString.lowercased())"
      pendingScanRequestIds[requestKey] = (requestId, Date())
    }

    let payload = try await call(
        AppConfig.Callable.submitScan,
        [
          "gameId": gameId,
          "requestId": requestId,
          "scannedToken": normalizedToken,
          "tokenCandidates": normalizedCandidates
        ]
      )
    pendingScanRequestIds.removeValue(forKey: requestKey)

    if let rawStatus = string(payload) {
      return ScanSubmissionOutcome(
        status: rawStatus,
        ownPoints: nil,
        opponentUid: nil,
        amount: nil,
        transferId: nil,
        itemId: nil,
        effectType: nil,
        reason: nil,
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

    let root = asDict(payload)
    return ScanSubmissionOutcome(
      status: string(root["status"]) ?? "UNKNOWN",
      ownPoints: int(root["ownPoints"]),
      opponentUid: string(root["opponentUid"]),
      amount: int(root["amount"]),
      transferId: string(root["transferId"]),
      itemId: string(root["itemId"]),
      effectType: string(root["effectType"]),
      reason: string(root["reason"]),
      cooldownRemainingSec: int(root["cooldownRemainingSec"]),
      cooldownScope: string(root["cooldownScope"]),
      availableInSec: int(root["availableInSec"]),
      battleStatus: string(root["battleStatus"]),
      inactiveReason: string(root["inactiveReason"]),
      baseDefenseRemainingSec: int(root["baseDefenseRemainingSec"]),
      baseDefenseCooldownRemainingSec: int(root["baseDefenseCooldownRemainingSec"]),
      baseDefensePoints: int(root["baseDefensePoints"]),
      battleSummary: parseBattleSummary(root["battleSummary"])
    )
  }

  func ensurePlayerQRCode(gameId: String?) async throws -> (token: String, url: String) {
    var payload: [String: Any] = [:]
    if let gameId, !gameId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      payload["gameId"] = gameId
    }
    let result = try await call(AppConfig.Callable.playerEnsureQrCode, payload)
    let root = asDict(result)
    let token = string(root["qrToken"]) ?? ""
    let url = string(root["qrUrl"]) ?? (token.isEmpty ? "" : "/s/\(token)")
    guard !token.isEmpty else {
      throw NSError(
        domain: "FirebaseGameService",
        code: 1011,
        userInfo: [NSLocalizedDescriptionKey: "QR giocatore non restituito dal backend"]
      )
    }
    return (token: token, url: url)
  }

  func registerBraceletToken(token: String, gameId: String?, tokenCandidates: [String]) async throws -> String {
    let normalized = normalizeTagToken(token)
    let normalizedCandidates = normalizeTagTokenCandidates([normalized] + tokenCandidates)
    guard !normalized.isEmpty else {
      throw NSError(
        domain: "FirebaseGameService",
        code: 1006,
        userInfo: [NSLocalizedDescriptionKey: "Token braccialetto mancante"]
      )
    }

    var payload: [String: Any] = ["token": normalized]
    if !normalizedCandidates.isEmpty {
      payload["tokenCandidates"] = normalizedCandidates
    }
    if let gameId, !gameId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      payload["gameId"] = gameId
    }

    let result = try await call(AppConfig.Callable.playerRegisterBraceletToken, payload)
    let root = asDict(result)
    return string(root["token"]) ?? normalized
  }

  func registerPushToken(token: String, gameId: String, userAgent: String?) async throws {
    var payload: [String: Any] = [
      "token": token,
      "gameId": gameId
    ]
    if let userAgent, !userAgent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      payload["userAgent"] = userAgent
    }
    _ = try await call(AppConfig.Callable.playerRegisterPushToken, payload)
  }

  func unregisterPushToken(token: String?) async throws {
    var payload: [String: Any] = [:]
    if let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      payload["token"] = token
    }
    _ = try await call(AppConfig.Callable.playerUnregisterPushToken, payload)
  }

  func deleteCurrentAccount() async throws {
    let uid = currentAuthenticatedUid()
    _ = try await call(AppConfig.Callable.playerDeleteAccount, ["confirm": true])
    clearCachedProfile(for: uid)
  }

  func setTeamReady(gameId: String, isReady: Bool) async throws -> MatchSnapshot {
    _ = try await call(
      AppConfig.Callable.playerSetTeamReady,
      [
        "gameId": gameId,
        "isReady": isReady
      ]
    )
    return try await fetchMatchSnapshot(gameId: gameId)
  }

  func sendTeamReadyReminder(gameId: String) async throws {
    _ = try await call(
      AppConfig.Callable.playerSendTeamReadyReminder,
      ["gameId": gameId]
    )
  }

  func playerSelectOwnTeam(gameId: String, teamId: String) async throws {
    _ = try await call(
      AppConfig.Callable.playerSelectOwnTeam,
      [
        "gameId": gameId,
        "teamId": teamId
      ]
    )
  }

  func playerShuffleTeams(gameId: String) async throws {
    _ = try await call(
      AppConfig.Callable.playerShuffleTeams,
      ["gameId": gameId]
    )
  }

  func savePlayerProfile(_ profile: PlayerProfile) async throws {
    var payload: [String: Any] = ["nickname": profile.nickname]
    if let avatarDataUrl = profile.avatarDataUrl, !avatarDataUrl.isEmpty {
      payload["avatarDataUrl"] = avatarDataUrl
    }
    _ = try await call(AppConfig.Callable.playerUpdateProfile, payload)
    storeCachedProfile(profile, for: currentAuthenticatedUid())
  }

  func fetchAdminActiveGame() async throws -> AdminGameStatus {
    let payload = try await call(AppConfig.Callable.getActiveGame, [:])
    let root = asDict(payload)
    AppLogger.info("[ADMIN] getActiveGame top keys: \(root.keys.sorted().joined(separator: ", "))")
    for key in ["game", "activeGame", "data", "result", "payload"] {
      if let nested = root[key] as? [String: Any] {
        AppLogger.info("[ADMIN] .\(key) keys: \(nested.keys.sorted().joined(separator: ", "))")
      }
    }
    for key in ["players", "participants", "roster", "joinedPlayers", "teams", "members", "publicPlayers"] {
      if let arr = root[key] as? [Any] {
        AppLogger.info("[ADMIN] root[\(key)] array count=\(arr.count)")
      } else if let dict = root[key] as? [String: Any] {
        AppLogger.info("[ADMIN] root[\(key)] dict keys: \(dict.keys.sorted().joined(separator: ", "))")
      }
    }
    if let bases = root["bases"] as? [String: Any] {
      AppLogger.info("[ADMIN] bases: \(bases)")
    }
    let result = parseAdminGameStatus(root)
    AppLogger.info("[ADMIN] parsed → id='\(result.gameId)' state='\(result.state)' players=\(result.participants.count) baseA='\(result.teamABaseToken ?? "-")' baseB='\(result.teamBBaseToken ?? "-")'")
    return result
  }

  func fetchAdminGame(gameId: String) async throws -> AdminGameStatus {
    let payload = try await call(AppConfig.Callable.adminGetGameSnapshot, ["gameId": gameId])
    let root = asDict(payload)
    return parseAdminGameStatus(root)
  }

  func fetchAdminOwnedGames() async throws -> [GameSummary] {
    let payload = try await call(AppConfig.Callable.adminListOwnedGames, [:])
    let root = asDict(payload)
    let rawGames = asArray(root["games"])
    return parseGameSummaryArray(rawGames)
  }

  func createAdminGame(
    name: String,
    gameId: String?,
    gameDefinitionId: String?,
    config: GameplayConfigSnapshot,
    itemMode: ItemMode,
    autonomousSetup: AutonomousGameSetup?
  ) async throws -> AdminGameStatus {
    var payload: [String: Any] = [
      "name": name,
      "config": configPayload(config),
      "itemMode": itemMode.rawValue
    ]
    if let gameId, !gameId.isEmpty {
      payload["gameId"] = gameId
    }
    if let gameDefinitionId, !gameDefinitionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      payload["gameDefinitionId"] = gameDefinitionId
    }
    mergeAutonomousSetup(autonomousSetup, into: &payload)

    let result = try await call(AppConfig.Callable.adminCreateGame, payload)
    return parseAdminGameStatus(asDict(result))
  }

  func deleteAdminGame(gameId: String) async throws {
    _ = try await call(AppConfig.Callable.adminDeleteGame, ["gameId": gameId])
  }

  func transitionToDistribution(gameId: String) async throws {
    _ = try await call(
      AppConfig.Callable.adminTransitionPhase,
      [
        "gameId": gameId,
        "toState": "DISTRIBUTION"
      ]
    )
  }

  func startMatch(gameId: String) async throws {
    _ = try await call(AppConfig.Callable.adminStartGame, ["gameId": gameId])
  }

  func pauseMatch(gameId: String) async throws {
    _ = try await call(AppConfig.Callable.adminPauseResume, ["gameId": gameId, "action": "PAUSE"])
  }

  func resumeMatch(gameId: String) async throws {
    _ = try await call(AppConfig.Callable.adminPauseResume, ["gameId": gameId, "action": "RESUME"])
  }

  func endMatch(gameId: String) async throws {
    _ = try await call(AppConfig.Callable.adminEndMatch, ["gameId": gameId])
  }

  func pickRandomLeaders(gameId: String) async throws {
    _ = try await call(AppConfig.Callable.adminSelectRandomTeamLeaders, ["gameId": gameId])
  }

  func distributeTeamPoints(gameId: String, allocations: [String: Int]) async throws {
    let normalized = allocations
      .map { (playerId: $0.key, points: max(0, $0.value)) }
      .filter { !$0.playerId.isEmpty }

    // Backend expects allocations[].uid (not playerId).
    // Keep playerId too for compatibility with older callable variants.
    let distributionPayload = normalized.map {
      [
        "uid": $0.playerId,
        "playerId": $0.playerId,
        "points": $0.points
      ]
    }
    let pointsByPlayerId = Dictionary(uniqueKeysWithValues: normalized.map { ($0.playerId, $0.points) })

    // gameId is required by the server callable leaderDistributeTeamPoints.
    _ = try await call(
      AppConfig.Callable.leaderDistributeTeamPoints,
      [
        "gameId": gameId,
        "allocations": distributionPayload,
        "distribution": distributionPayload,
        "teammates": distributionPayload,
        "pointsByPlayerId": pointsByPlayerId
      ]
    )
  }

  func updateGameConfig(
    gameId: String,
    config: GameplayConfigSnapshot,
    itemMode: ItemMode?,
    autonomousSetup: AutonomousGameSetup?
  ) async throws {
    var payload: [String: Any] = [
      "gameId": gameId,
      "config": configPayload(config)
    ]
    if let itemMode {
      payload["itemMode"] = itemMode.rawValue
    }
    mergeAutonomousSetup(autonomousSetup, into: &payload)
    _ = try await call(AppConfig.Callable.adminUpdateGameConfig, payload)
  }

  func setBaseToken(gameId: String, teamId: String, token: String, tokenCandidates: [String], overwriteExistingBase: Bool) async throws {
    let normalized = normalizeTagToken(token)
    let normalizedCandidates = normalizeTagTokenCandidates([normalized] + tokenCandidates)
    AppLogger.info("[ADMIN] setBaseToken → gameId='\(gameId)' teamId='\(teamId)' token='\(normalized)'")
    var payload: [String: Any] = [
      "gameId": gameId,
      "teamId": teamId,
      "token": normalized
    ]
    if !normalizedCandidates.isEmpty {
      payload["tokenCandidates"] = normalizedCandidates
    }
    if overwriteExistingBase {
      payload["overwriteExistingBase"] = true
    }
    _ = try await call(AppConfig.Callable.adminSetTeamBaseToken, payload)
  }

  func adminFetchRoster(gameId: String) async throws -> [AdminGameStatus.Participant] {
    let result = try await call(AppConfig.Callable.adminGetRoster, ["gameId": gameId])
    let root = asDict(result)
    let parsed = uniqueParticipants(parseAdminParticipants(root))
    AppLogger.info("[ADMIN] adminFetchRoster → parsed \(parsed.count) players from keys [\(root.keys.sorted().joined(separator: ","))]")
    return parsed
  }

  func adminCleanupTokenConflict(gameId: String, token: String, tokenCandidates: [String], correctType: String) async throws {
    let normalized = normalizeTagToken(token)
    let normalizedCandidates = normalizeTagTokenCandidates([normalized] + tokenCandidates)
    _ = try await call(
      AppConfig.Callable.adminCleanupTokenConflict,
      [
        "gameId": gameId,
        "token": normalized,
        "tokenCandidates": normalizedCandidates,
        "correctType": correctType
      ]
    )
  }

  func adminAssignPlayerToTeam(gameId: String, playerId: String, teamId: String?) async throws {
    var payload: [String: Any] = ["gameId": gameId, "playerId": playerId]
    if let teamId { payload["teamId"] = teamId }
    _ = try await call(AppConfig.Callable.adminAssignPlayerTeam, payload)
  }

  func adminRemovePlayerFromGame(gameId: String, playerId: String) async throws {
    _ = try await call(AppConfig.Callable.adminRemovePlayer, ["gameId": gameId, "playerId": playerId])
  }

  func adminSetTeamLeader(gameId: String, playerId: String, teamId: String) async throws {
    _ = try await call(AppConfig.Callable.adminSetTeamLeader, ["gameId": gameId, "playerId": playerId, "teamId": teamId])
  }

  func adminRegisterGameItem(gameId: String, token: String?, tokenCandidates: [String], icon: String, points: Int, collectorTeamId: String?) async throws -> AdminGameStatus.GameItem {
    let normalized = normalizeTagToken(token)
    let normalizedCandidates = normalized.isEmpty
      ? []
      : normalizeTagTokenCandidates([normalized] + tokenCandidates)
    var mutablePayload: [String: Any] = [
      "gameId": gameId,
      "icon": icon,
      "points": points
    ]
    if !normalized.isEmpty {
      mutablePayload["token"] = normalized
      mutablePayload["tokenCandidates"] = normalizedCandidates
    }
    if let collectorTeamId, !collectorTeamId.isEmpty {
      mutablePayload["collectorTeamId"] = collectorTeamId
    }
    let result = try await call(AppConfig.Callable.adminRegisterGameItem, mutablePayload)
    let root = asDict(result)
    let id = string(root["itemId"]) ?? string(root["token"]) ?? string(root["id"]) ?? UUID().uuidString.lowercased()
    let retIcon = string(root["icon"]) ?? icon
    let retPoints = int(root["points"]) ?? points
    return AdminGameStatus.GameItem(
      id: id,
      icon: retIcon,
      points: retPoints,
      collectorTeamId: string(root["collectorTeamId"]) ?? collectorTeamId,
      nfcToken: string(root["nfcToken"]) ?? normalized,
      qrToken: string(root["qrToken"]),
      qrUrl: string(root["qrUrl"])
    )
  }

  func adminAttachItemToken(gameId: String, itemId: String, token: String, tokenCandidates: [String]) async throws {
    let normalized = normalizeTagToken(token)
    let normalizedCandidates = normalizeTagTokenCandidates([normalized] + tokenCandidates)
    _ = try await call(
      AppConfig.Callable.adminAttachItemToken,
      [
        "gameId": gameId,
        "itemId": itemId,
        "token": normalized,
        "tokenCandidates": normalizedCandidates
      ]
    )
  }

  func adminFetchGameItems(gameId: String) async throws -> [AdminGameStatus.GameItem] {
    let result = try await call(AppConfig.Callable.adminGetGameItems, ["gameId": gameId])
    let root = asDict(result)
    let raw = asArray(root["items"]) as? [[String: Any]] ?? (root["items"] as? [Any]).flatMap { $0 as? [[String: Any]] } ?? []
    return raw.compactMap { item -> AdminGameStatus.GameItem? in
      guard let id = string(item["itemId"]) ?? string(item["token"]) ?? string(item["id"]) else { return nil }
      let icon = string(item["icon"]) ?? "questionmark.circle"
      let pts = int(item["points"]) ?? 0
      return AdminGameStatus.GameItem(
        id: id,
        icon: icon,
        points: pts,
        collectorTeamId: string(item["collectorTeamId"]),
        nfcToken: string(item["nfcToken"]),
        qrToken: string(item["qrToken"]),
        qrUrl: string(item["qrUrl"])
      )
    }
  }

  func adminExportGameEvents(gameId: String, limit: Int) async throws -> AdminGameEventExport {
    let result = try await call(
      AppConfig.Callable.adminExportGameEvents,
      [
        "gameId": gameId,
        "limit": max(50, limit)
      ]
    )
    return parseAdminGameEventExport(asDict(result))
  }

  func adminLookupTag(gameId: String, token: String, tokenCandidates: [String]) async throws -> AdminGameStatus.TagLookup {
    let normalized = normalizeTagToken(token)
    let normalizedCandidates = normalizeTagTokenCandidates([normalized] + tokenCandidates)
    let result = try await call(
      AppConfig.Callable.adminLookupGameTag,
      ["gameId": gameId, "token": normalized, "tokenCandidates": normalizedCandidates]
    )
    let root = asDict(result)
    return AdminGameStatus.TagLookup(
      tagId: string(root["tagId"]) ?? normalized,
      entityType: string(root["entityType"]) ?? "free",
      bindingId: string(root["bindingId"]),
      ownerId: string(root["ownerId"]),
      teamId: string(root["teamId"]) ?? string(root["teamLabel"]),
      itemId: string(root["itemId"]),
      playerUid: string(root["playerUid"]),
      playerNickname: string(root["playerNickname"]),
      itemIcon: string(root["itemIcon"]),
      itemPoints: int(root["itemPoints"])
    )
  }

  private func call(_ name: String, _ data: [String: Any]) async throws -> Any {
    if shouldLogFunctionLifecycle(name) {
      AppLogger.info("Functions call start: \(name)")
    }

    return try await withCheckedThrowingContinuation { continuation in
      let stateQueue = DispatchQueue(label: "firebase.call.\(name).state")
      var completed = false

      func finish(_ result: Result<Any, Error>) {
        stateQueue.sync {
          guard !completed else { return }
          completed = true
          switch result {
          case .success(let payload):
            if shouldLogFunctionLifecycle(name) {
              AppLogger.info("Functions call success: \(name)")
            }
            continuation.resume(returning: payload)
          case .failure(let error):
            AppLogger.error("Functions call failed: \(name) - \(error.localizedDescription)")
            continuation.resume(throwing: error)
          }
        }
      }

      let callable = functions.httpsCallable(name)
      callable.call(data) { result, error in
        if let error {
          finish(.failure(error))
          return
        }
        guard let result else {
          finish(
            .failure(
              NSError(
                domain: "FirebaseGameService",
                code: 1005,
                userInfo: [NSLocalizedDescriptionKey: "Nessuna risposta dalla chiamata Firebase: \(name)"]
              )
            )
          )
          return
        }
        finish(.success(result.data))
      }

      let timeout = DispatchTime.now() + .nanoseconds(Int(callableTimeoutNs))
      DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: timeout) {
        finish(
          .failure(
            NSError(
              domain: "FirebaseGameService",
              code: 1004,
              userInfo: [NSLocalizedDescriptionKey: "Timeout chiamata Firebase: \(name)"]
            )
          )
        )
      }
    }
  }

  private func confirmedJoinSnapshot(
    fromPayload payload: Any,
    fallbackGameId: String?,
    errorCode: Int,
    errorMessage: String
  ) async throws -> MatchSnapshot {
    let direct = parseMatchSnapshot(asDict(payload))
    if direct.isJoined {
      return direct
    }

    var refreshRequest: [String: Any] = [:]
    if let fallbackGameId, !fallbackGameId.isEmpty {
      refreshRequest["gameId"] = fallbackGameId
    }
    let refreshedPayload = try await call(AppConfig.Callable.playerGetActiveGameStatus, refreshRequest)
    let refreshed = parseMatchSnapshot(asDict(refreshedPayload))
    if refreshed.isJoined {
      return refreshed
    }

    throw NSError(
      domain: "FirebaseGameService",
      code: errorCode,
      userInfo: [NSLocalizedDescriptionKey: errorMessage]
    )
  }

  private func asDict(_ value: Any?) -> [String: Any] {
    value as? [String: Any] ?? [:]
  }

  private func asArray(_ value: Any?) -> [Any] {
    value as? [Any] ?? []
  }

  private func string(_ value: Any?) -> String? {
    if let value = value as? String {
      let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
    }
    return nil
  }

  private func int(_ value: Any?) -> Int? {
    if let value = value as? Int {
      return value
    }
    if let value = value as? NSNumber {
      return value.intValue
    }
    if let value = value as? String {
      return Int(value)
    }
    return nil
  }

  private func bool(_ value: Any?) -> Bool {
    if let value = value as? Bool {
      return value
    }
    if let value = value as? NSNumber {
      return value.boolValue
    }
    if let value = value as? String {
      return value.lowercased() == "true" || value == "1"
    }
    return false
  }

  private func configPayload(_ config: GameplayConfigSnapshot) -> [String: Any] {
    let handshakeWindowSec = max(1, config.handshakeWindowSec)
    return [
      "scanMode": config.scanMode.rawValue,
      "handshakeWindowSec": handshakeWindowSec,
      "pairCooldownSec": max(1, config.pairCooldownSec),
      "playerCooldownSec": max(1, config.playerCooldownSec),
      "inactivePenaltyBlockDurationSec": max(1, config.inactivePenaltyBlockDurationSec),
      "teamSyncWindowSec": max(handshakeWindowSec, config.teamSyncWindowSec),
      "baseContactWindowSec": max(1, config.baseContactWindowSec),
      "baseDefenseMultiplier": max(1, config.baseDefenseMultiplier),
      "baseDefenseDurationSec": max(1, config.baseDefenseDurationSec),
      "baseDefenseCooldownSec": max(1, config.baseDefenseCooldownSec),
      "duelTransferPoints": max(1, config.duelTransferPoints),
      "baseCapturePoints": max(1, config.baseCapturePoints),
      "baseDefensePoints": max(1, config.baseDefensePoints),
      "startingPoints": max(1, config.startingPoints),
      "countdownSec": max(1, config.countdownSec),
      "matchDurationSec": max(60, config.matchDurationSec),
      "timezone": config.timezone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? "Europe/Rome"
        : config.timezone
    ]
  }

  private func mergeAutonomousSetup(_ setup: AutonomousGameSetup?, into payload: inout [String: Any]) {
    guard let setup else { return }
    payload["hostMode"] = setup.hostMode.rawValue
    payload["autonomousMode"] = setup.isAutonomous
    payload["teamAssignmentMode"] = setup.teamAssignmentMode.rawValue
    if let creatorUid = setup.creatorUid?.trimmingCharacters(in: .whitespacesAndNewlines), !creatorUid.isEmpty {
      payload["creatorUid"] = creatorUid
    }
  }

  private func parseAutonomousSetup(from root: [String: Any]) -> (setup: AutonomousGameSetup, hasMetadata: Bool) {
    let candidateRoots = adminCandidateRoots(root)
    let hostModeRaw = firstNonEmptyString(
      in: candidateRoots,
      keys: ["hostMode", "playMode", "matchMode", "hostingMode"]
    )
    let teamAssignmentRaw = firstNonEmptyString(
      in: candidateRoots,
      keys: ["teamAssignmentMode", "teamSelectionMode", "teamMode"]
    )
    let creatorUid = firstNonEmptyString(
      in: candidateRoots,
      keys: ["creatorUid", "createdByUid", "ownerUid", "hostUid"]
    )
    let hasAutonomousFlag = candidateRoots.contains {
      $0.keys.contains("autonomousMode") || $0.keys.contains("selfHosted")
    }
    let autonomousFlagValue = candidateRoots.contains {
      bool($0["autonomousMode"]) || bool($0["selfHosted"])
    }

    let hostMode: MatchHostingMode
    switch hostModeRaw?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
    case MatchHostingMode.autonomous.rawValue:
      hostMode = .autonomous
    case MatchHostingMode.gameMaster.rawValue:
      hostMode = .gameMaster
    default:
      hostMode = autonomousFlagValue ? .autonomous : .gameMaster
    }

    let teamAssignmentMode: TeamAssignmentMode
    switch teamAssignmentRaw?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
    case TeamAssignmentMode.random.rawValue:
      teamAssignmentMode = .random
    default:
      teamAssignmentMode = .manual
    }

    return (
      setup: AutonomousGameSetup(
        hostMode: hostMode,
        teamAssignmentMode: teamAssignmentMode,
        creatorUid: creatorUid
      ),
      hasMetadata: hostModeRaw != nil || teamAssignmentRaw != nil || creatorUid != nil || hasAutonomousFlag
    )
  }

  private func parseGameplayConfig(_ value: Any?) -> GameplayConfigSnapshot {
    let root = asDict(value)
    let modeRaw = (string(root["scanMode"]) ?? GameplayConfigSnapshot.default.scanMode.rawValue).uppercased()
    let scanMode = modeRaw == ScanMode.qr.rawValue ? ScanMode.qr : .bracelet
    let handshakeWindowSec = max(
      1,
      int(root["handshakeWindowSec"]) ?? GameplayConfigSnapshot.default.handshakeWindowSec
    )

    return GameplayConfigSnapshot(
      scanMode: scanMode,
      handshakeWindowSec: handshakeWindowSec,
      pairCooldownSec: max(1, int(root["pairCooldownSec"]) ?? GameplayConfigSnapshot.default.pairCooldownSec),
      playerCooldownSec: max(1, int(root["playerCooldownSec"]) ?? GameplayConfigSnapshot.default.playerCooldownSec),
      inactivePenaltyBlockDurationSec: max(1, int(root["inactivePenaltyBlockDurationSec"]) ?? GameplayConfigSnapshot.default.inactivePenaltyBlockDurationSec),
      teamSyncWindowSec: max(
        handshakeWindowSec,
        int(root["teamSyncWindowSec"]) ?? GameplayConfigSnapshot.default.teamSyncWindowSec
      ),
      baseContactWindowSec: max(1, int(root["baseContactWindowSec"]) ?? GameplayConfigSnapshot.default.baseContactWindowSec),
      baseDefenseMultiplier: max(1, int(root["baseDefenseMultiplier"]) ?? GameplayConfigSnapshot.default.baseDefenseMultiplier),
      baseDefenseDurationSec: max(1, int(root["baseDefenseDurationSec"]) ?? GameplayConfigSnapshot.default.baseDefenseDurationSec),
      baseDefenseCooldownSec: max(1, int(root["baseDefenseCooldownSec"]) ?? GameplayConfigSnapshot.default.baseDefenseCooldownSec),
      duelTransferPoints: max(1, int(root["duelTransferPoints"]) ?? GameplayConfigSnapshot.default.duelTransferPoints),
      baseCapturePoints: max(1, int(root["baseCapturePoints"]) ?? GameplayConfigSnapshot.default.baseCapturePoints),
      baseDefensePoints: max(1, int(root["baseDefensePoints"]) ?? int(root["baseCapturePoints"]) ?? GameplayConfigSnapshot.default.baseDefensePoints),
      startingPoints: max(1, int(root["startingPoints"]) ?? GameplayConfigSnapshot.default.startingPoints),
      countdownSec: max(1, int(root["countdownSec"]) ?? GameplayConfigSnapshot.default.countdownSec),
      matchDurationSec: max(60, int(root["matchDurationSec"]) ?? GameplayConfigSnapshot.default.matchDurationSec),
      timezone: string(root["timezone"]) ?? GameplayConfigSnapshot.default.timezone
    )
  }

  private func mergedGameplayConfig(
    base value: Any?,
    fallbackRoot: [String: Any]
  ) -> GameplayConfigSnapshot {
    var merged = asDict(value)
    let passthroughKeys = [
      "scanMode",
      "handshakeWindowSec",
      "pairCooldownSec",
      "playerCooldownSec",
      "inactivePenaltyBlockDurationSec",
      "teamSyncWindowSec",
      "baseContactWindowSec",
      "baseDefenseMultiplier",
      "baseDefenseDurationSec",
      "baseDefenseCooldownSec",
      "duelTransferPoints",
      "baseCapturePoints",
      "baseDefensePoints",
      "startingPoints",
      "countdownSec",
      "matchDurationSec",
      "timezone"
    ]

    for key in passthroughKeys where merged[key] == nil {
      if let fallbackValue = fallbackRoot[key] {
        merged[key] = fallbackValue
      }
    }

    return parseGameplayConfig(merged)
  }

  private func parseMatchSnapshot(_ root: [String: Any]) -> MatchSnapshot {
    let config = mergedGameplayConfig(base: root["config"], fallbackRoot: root)
    let autonomousSetup = parseAutonomousSetup(from: root)
    let gameId = string(root["activeGameId"]) ?? string(root["gameId"]) ?? ""
    let state = string(root["state"]) ?? "NOT_STARTED"
    let remaining = int(root["remainingSec"]) ?? config.matchDurationSec
    let battleStatus = string(root["battleStatus"]) ?? "INACTIVE"
    let roleInTeam = string(root["roleInTeam"]) ?? string(root["role"])
    let isCurrentPlayerLeader =
      bool(root["isTeamLeader"]) ||
      bool(root["isLeader"]) ||
      bool(root["isCurrentPlayerLeader"]) ||
      isLeaderRole(roleInTeam)
    let participants = parseMatchParticipants(root)
    let isJoined = resolveIsJoined(root: root, participants: participants)
    let joinAllowed = bool(root["joinAllowed"]) || isJoined
    // teamId is returned at top level by playerGetActiveGameStatus for the current player
    let teamId = string(root["teamId"])
    let points = int(root["points"])
    let braceletToken = string(root["braceletToken"])
    let qrToken = string(root["qrToken"])
    let qrUrl = string(root["qrUrl"]) ?? (qrToken.flatMap { $0.isEmpty ? nil : "/s/\($0)" })
    let identityCardCode = string(root["identityCardCode"]) ?? string(root["playingCard"])
    let identityDeckIndex = int(root["identityDeckIndex"])

    return MatchSnapshot(
      gameId: gameId,
      state: state,
      config: config,
      remainingSec: remaining,
      liveEndsAtMs: int(root["liveEndsAtMs"]),
      serverNowMs: int(root["serverNowMs"]),
      isJoined: isJoined,
      joinAllowed: joinAllowed,
      battleStatus: battleStatus,
      playingCard: optionalPlayingCard(identityCardCode),
      identityDeckIndex: identityDeckIndex,
      inactiveReason: string(root["inactiveReason"]),
      cooldownRemainingSec: int(root["cooldownRemainingSec"]),
      baseDefenseRemainingSec: int(root["baseDefenseRemainingSec"]),
      baseDefenseCooldownRemainingSec: int(root["baseDefenseCooldownRemainingSec"]),
      baseDefensePoints: int(root["baseDefensePoints"]),
      teamDistributionSubmitted: bool(root["teamDistributionSubmitted"]),
      teamDistributionTotal: int(root["teamDistributionTotal"]),
      teamDistributionRemaining: int(root["teamDistributionRemaining"]),
      teamReadyForLive: bool(root["teamReadyForLive"]),
      opponentTeamReadyForLive: bool(root["opponentTeamReadyForLive"]),
      allTeamsReadyForLive: bool(root["allTeamsReadyForLive"]),
      isCurrentPlayerLeader: isCurrentPlayerLeader,
      points: points,
      roleInTeam: roleInTeam,
      participants: participants,
      teamId: teamId,
      braceletToken: braceletToken,
      qrToken: qrToken,
      qrUrl: qrUrl,
      lastBattleSummary: parseBattleSummary(root["lastBattleSummary"]),
      incomingEngagement: parseIncomingEngagement(root["incomingEngagement"]),
      autonomousSetup: autonomousSetup.setup,
      hasAutonomousSetup: autonomousSetup.hasMetadata
    )
  }

  private func parseIncomingEngagement(_ raw: Any?) -> MatchSnapshot.IncomingEngagement? {
    let root = asDict(raw)
    guard
      let attackerId = string(root["attackerId"])?.nonEmpty,
      let expiresAtMs = int(root["expiresAtMs"])
    else { return nil }
    return MatchSnapshot.IncomingEngagement(
      attackerId: attackerId,
      attackerName: string(root["attackerName"])?.nonEmpty ?? attackerId,
      expiresAtMs: expiresAtMs
    )
  }

  private func parseBattleSummary(_ raw: Any?) -> ScanBattleSummary? {
    let root = asDict(raw)
    guard !root.isEmpty else { return nil }

    guard
      let summaryId = string(root["summaryId"])?.nonEmpty,
      let status = string(root["status"])?.nonEmpty
    else {
      return nil
    }

    guard
      let scannerSide = parseBattleSummarySide(root["scannerSide"], fallbackKey: "SCANNER"),
      let opponentSide = parseBattleSummarySide(root["opponentSide"], fallbackKey: "OPPONENT")
    else {
      return nil
    }

    return ScanBattleSummary(
      summaryId: summaryId,
      status: status,
      winnerSide: string(root["winnerSide"]) ?? "TIE",
      resolutionMode: string(root["resolutionMode"]) ?? "POINTS",
      viewerSide: string(root["viewerSide"]),
      amount: int(root["amount"]) ?? 0,
      penaltyApplied: bool(root["penaltyApplied"]),
      scannerWasInactive: bool(root["scannerWasInactive"]),
      opponentWasInactive: bool(root["opponentWasInactive"]),
      scannerSide: scannerSide,
      opponentSide: opponentSide
    )
  }

  private func parseBattleSummarySide(_ raw: Any?, fallbackKey: String) -> ScanBattleSummary.Side? {
    let root = asDict(raw)
    guard !root.isEmpty else { return nil }

    let participants = asArray(root["participants"]).compactMap { entry -> ScanBattleSummary.Participant? in
      let item = asDict(entry)
      guard !item.isEmpty else { return nil }
      let id = string(item["uid"]) ?? string(item["id"]) ?? UUID().uuidString
      let nickname = string(item["nickname"]) ?? string(item["label"]) ?? "Giocatore"
      let teamId = string(item["teamId"])
      return ScanBattleSummary.Participant(
        id: id,
        nickname: nickname,
        teamId: teamId,
        teamName: normalizedBattleTeamLabel(
          teamId: teamId,
          fallback: string(item["teamName"])
        ),
        isPrimary: bool(item["isPrimary"])
      )
    }

    let teamId = string(root["teamId"])
    let teamName = normalizedBattleTeamLabel(
      teamId: teamId,
      fallback: string(root["teamName"])
    )

    return ScanBattleSummary.Side(
      key: string(root["key"]) ?? fallbackKey,
      teamId: teamId,
      teamName: teamName,
      label: preferredBattleSideLabel(
        teamId: teamId,
        teamName: teamName,
        rawLabel: string(root["label"]),
        participants: participants,
        fallbackKey: fallbackKey
      ),
      participants: participants,
      totalBefore: int(root["totalBefore"]) ?? 0,
      totalAfter: int(root["totalAfter"]) ?? 0,
      isGroup: bool(root["isGroup"]) || participants.count > 1
    )
  }

  private func normalizedBattleTeamLabel(teamId: String?, fallback: String?) -> String? {
    let normalized = (teamId ?? fallback ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .uppercased()

    switch normalized {
    case "A", "TEAM_A", "GIOCATORI":
      return "Giocatori"
    case "B", "TEAM_B", "CITTADINI":
      return "Cittadini"
    default:
      return fallback?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }
  }

  private func preferredBattleSideLabel(
    teamId: String?,
    teamName: String?,
    rawLabel: String?,
    participants: [ScanBattleSummary.Participant],
    fallbackKey: String
  ) -> String {
    if let normalizedTeamName = normalizedBattleTeamLabel(teamId: teamId, fallback: teamName) {
      return normalizedTeamName
    }
    if let rawLabel = rawLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
      return rawLabel
    }
    if let firstNickname = participants.first?.nickname.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
      return firstNickname
    }
    return fallbackKey
  }

  private func resolveIsJoined(root: [String: Any], participants: [MatchSnapshot.Participant]) -> Bool {
    if root.keys.contains("isJoined") {
      return bool(root["isJoined"])
    }

    // Il backend restituisce sempre isJoined esplicito: se manca, fail-closed
    // (le euristiche sotto restano solo diagnostiche, non decidono più "true").
    let joinedFlags = ["joined", "playerJoined", "isPlayerInGame", "inGame"]
    let heuristicJoined = joinedFlags.contains { root.keys.contains($0) && bool(root[$0]) }
      || !asDict(root["player"]).isEmpty || !asDict(root["self"]).isEmpty || !asDict(root["me"]).isEmpty
      || string(root["uid"]) != nil || string(root["playerId"]) != nil || string(root["joinedAt"]) != nil
      || !participants.isEmpty

    if heuristicJoined {
      AppLogger.info("[FGS] resolveIsJoined: isJoined assente, euristiche direbbero true → fail-closed false")
    }
    return false
  }

  private func parseMatchParticipants(_ root: [String: Any]) -> [MatchSnapshot.Participant] {
    let candidateRoots = matchCandidateRoots(root)
    for candidate in candidateRoots {
      let directKeys = ["players", "participants", "roster", "joinedPlayers", "teammates", "members", "publicPlayers"]
      for key in directKeys {
        let parsed = parseMatchParticipantArray(asArray(candidate[key]))
        if !parsed.isEmpty {
          return parsed
        }

        if let asMap = candidate[key] as? [String: Any] {
          let fromMap = parseMatchParticipantArray(Array(asMap.values))
          if !fromMap.isEmpty {
            return fromMap
          }
        }
      }

      let teams = asDict(candidate["teams"])
      if !teams.isEmpty {
        var merged: [MatchSnapshot.Participant] = []
        merged += parseMatchParticipantArray(asArray(teams["TEAM_A"]), forcedTeamId: "TEAM_A")
        merged += parseMatchParticipantArray(asArray(teams["TEAM_B"]), forcedTeamId: "TEAM_B")
        merged += parseMatchParticipantArray(asArray(teams["UNASSIGNED"]))
        if let teamAMap = teams["TEAM_A"] as? [String: Any] {
          merged += parseMatchParticipantArray(Array(teamAMap.values), forcedTeamId: "TEAM_A")
        }
        if let teamBMap = teams["TEAM_B"] as? [String: Any] {
          merged += parseMatchParticipantArray(Array(teamBMap.values), forcedTeamId: "TEAM_B")
        }
        if let unassignedMap = teams["UNASSIGNED"] as? [String: Any] {
          merged += parseMatchParticipantArray(Array(unassignedMap.values))
        }
        if !merged.isEmpty {
          return uniqueMatchParticipants(merged)
        }
      }

      // Some backends return publicPlayers as a map uid->{...}
      if let publicPlayersMap = candidate["publicPlayers"] as? [String: Any], !publicPlayersMap.isEmpty {
        let values = Array(publicPlayersMap.values)
        let parsed = parseMatchParticipantArray(values)
        if !parsed.isEmpty { return parsed }
      }
    }

    return []
  }

  private func parseMatchParticipantArray(_ raw: [Any], forcedTeamId: String? = nil) -> [MatchSnapshot.Participant] {
    var list: [MatchSnapshot.Participant] = []
    for entry in raw {
      let item = asDict(entry)
      if item.isEmpty {
        continue
      }

      let id = string(item["uid"]) ?? string(item["id"]) ?? UUID().uuidString
      let nickname = string(item["nickname"]) ?? string(item["name"]) ?? "Giocatore"
      let avatar = string(item["avatarDataUrl"]) ?? string(item["avatarUrl"])
      let teamId = forcedTeamId ?? string(item["teamId"]) ?? string(item["team"])
      let role = string(item["roleInTeam"]) ?? string(item["role"])
      let card =
        string(item["identityCardCode"]) ??
        string(item["playingCard"]) ??
        string(item["cardCode"])
      let points = int(item["points"])
      list.append(
        MatchSnapshot.Participant(
          id: id,
          nickname: nickname,
          avatarDataUrl: avatar,
          teamId: teamId,
          roleInTeam: role,
          playingCard: optionalPlayingCard(card),
          identityDeckIndex: int(item["identityDeckIndex"]),
          points: points
        )
      )
    }
    return list
  }

  private func uniqueMatchParticipants(_ raw: [MatchSnapshot.Participant]) -> [MatchSnapshot.Participant] {
    var seen: Set<String> = []
    var unique: [MatchSnapshot.Participant] = []
    for participant in raw {
      if seen.insert(participant.id).inserted {
        unique.append(participant)
      }
    }
    return unique
  }

  private func normalizePlayingCard(_ value: String?) -> String {
    let normalized = PlayingCardCatalog.normalizeCode(value ?? "")
    if normalized.isEmpty {
      return "AS"
    }
    return normalized
  }

  private func optionalPlayingCard(_ value: String?) -> String? {
    let normalized = PlayingCardCatalog.normalizeCode(value ?? "")
    return normalized.isEmpty ? nil : normalized
  }

  private func parseAdminGameStatus(_ root: [String: Any]) -> AdminGameStatus {
    let candidateRoots = adminCandidateRoots(root)
    let gameObject = selectAdminPrimaryObject(from: candidateRoots)
    let configRoot = selectAdminConfig(from: candidateRoots, fallback: gameObject)
    let autonomousSetup = parseAutonomousSetup(from: root)

    let gameId = firstNonEmptyString(
      in: candidateRoots,
      keys: ["gameId", "id", "activeGameId", "matchId", "game_id"]
    ) ?? ""

    let modeRaw = string(configRoot["scanMode"]) ?? firstNonEmptyString(in: candidateRoots, keys: ["scanMode", "scan_mode"])
    let hasMode = modeRaw != nil
    let rawDuration = int(configRoot["matchDurationSec"]) ?? firstNonEmptyInt(in: candidateRoots, keys: ["matchDurationSec", "match_duration_sec"])
    let hasDuration = rawDuration != nil
    let hasConfigSnapshot = hasMode || hasDuration || !configRoot.isEmpty

    let state = firstNonEmptyString(in: candidateRoots, keys: ["state", "status"]) ?? "N/A"
    let name = firstNonEmptyString(in: candidateRoots, keys: ["name", "title"]) ?? gameId
    let gameDefinitionId = firstNonEmptyString(
      in: candidateRoots,
      keys: ["gameDefinitionId", "gameDefinitionSlug", "gameType"]
    ) ?? "borderland-classic"
    let gameDefinitionName = firstNonEmptyString(
      in: candidateRoots,
      keys: ["gameDefinitionName", "gameTypeName", "gameLabel"]
    ) ?? "Borderland Classic"
    let baseSnapshot = resolveAdminBaseSnapshot(from: candidateRoots)
    let config = mergedGameplayConfig(base: configRoot, fallbackRoot: gameObject)

    AppLogger.info("[ADMIN] parseAdminGameStatus → id='\(gameId)' state='\(state)' rootKeys=[\(root.keys.sorted().joined(separator: ","))]")

    return AdminGameStatus(
      name: name,
      gameId: gameId,
      gameDefinitionId: gameDefinitionId,
      gameDefinitionName: gameDefinitionName,
      state: state,
      config: config,
      hasConfigSnapshot: hasConfigSnapshot,
      hasBaseSnapshot: baseSnapshot.hasSnapshot,
      participants: parseAdminParticipants(root),
      teamABaseToken: baseSnapshot.teamAToken,
      teamBBaseToken: baseSnapshot.teamBToken,
      teamABaseQrToken: baseSnapshot.teamAQrToken,
      teamBBaseQrToken: baseSnapshot.teamBQrToken,
      itemMode: parseItemMode(firstNonEmptyString(in: candidateRoots, keys: ["itemMode", "item_mode"])),
      gameItems: [],
      autonomousSetup: autonomousSetup.setup,
      hasAutonomousSetup: autonomousSetup.hasMetadata
    )
  }

  private func selectAdminPrimaryObject(from candidateRoots: [[String: Any]]) -> [String: Any] {
    candidateRoots.max { adminSnapshotScore($0) < adminSnapshotScore($1) } ?? [:]
  }

  private func adminSnapshotScore(_ candidate: [String: Any]) -> Int {
    var score = 0
    if !asDict(candidate["config"]).isEmpty { score += 3 }
    if !asDict(candidate["bases"]).isEmpty { score += 4 }
    if !asDict(candidate["baseTokens"]).isEmpty { score += 4 }
    if !asDict(candidate["teamBases"]).isEmpty { score += 4 }
    if candidate.keys.contains("teamABaseToken") || candidate.keys.contains("teamBBaseToken") { score += 4 }
    if string(candidate["state"]) != nil || string(candidate["status"]) != nil { score += 2 }
    if string(candidate["gameId"]) != nil || string(candidate["id"]) != nil { score += 1 }
    return score
  }

  private func selectAdminConfig(from candidateRoots: [[String: Any]], fallback: [String: Any]) -> [String: Any] {
    for candidate in candidateRoots {
      let config = asDict(candidate["config"])
      if !config.isEmpty {
        return config
      }
    }
    return asDict(fallback["config"])
  }

  private func firstNonEmptyString(in candidateRoots: [[String: Any]], keys: [String]) -> String? {
    for candidate in candidateRoots {
      for key in keys {
        if let value = string(candidate[key]), !value.isEmpty {
          return value
        }
      }
    }
    return nil
  }

  private func firstNonEmptyInt(in candidateRoots: [[String: Any]], keys: [String]) -> Int? {
    for candidate in candidateRoots {
      for key in keys {
        if let value = int(candidate[key]) {
          return value
        }
      }
    }
    return nil
  }

  private func resolveAdminBaseSnapshot(from candidateRoots: [[String: Any]]) -> (
    teamAToken: String?,
    teamBToken: String?,
    teamAQrToken: String?,
    teamBQrToken: String?,
    hasSnapshot: Bool
  ) {
    let teamAKeys = ["TEAM_A", "teamA", "team_a", "A"]
    let teamBKeys = ["TEAM_B", "teamB", "team_b", "B"]
    let directAKeys = [
      "teamABaseToken",
      "teamABaseTokenHash",
      "teamA_baseToken",
      "teamA_baseTokenHash",
      "baseTokenTeamA",
      "baseTokenA",
      "team_a_base_token"
    ]
    let directBKeys = [
      "teamBBaseToken",
      "teamBBaseTokenHash",
      "teamB_baseToken",
      "teamB_baseTokenHash",
      "baseTokenTeamB",
      "baseTokenB",
      "team_b_base_token"
    ]
    let containerKeys = ["bases", "baseTokens", "teamBases", "basesByTeam"]

    var teamAToken: String?
    var teamBToken: String?
    var teamAQrToken: String?
    var teamBQrToken: String?
    var hasSnapshot = false

    for candidate in candidateRoots {
      for key in directAKeys {
        if candidate.keys.contains(key) { hasSnapshot = true }
        if teamAToken == nil, let value = tokenString(from: candidate[key]) {
          teamAToken = value
          hasSnapshot = true
        }
      }
      for key in directBKeys {
        if candidate.keys.contains(key) { hasSnapshot = true }
        if teamBToken == nil, let value = tokenString(from: candidate[key]) {
          teamBToken = value
          hasSnapshot = true
        }
      }

      for key in containerKeys {
        if candidate.keys.contains(key) { hasSnapshot = true }
        let container = asDict(candidate[key])
        if container.isEmpty { continue }

        for teamKey in teamAKeys {
          if container.keys.contains(teamKey) { hasSnapshot = true }
          let teamValue = container[teamKey]
          if teamAToken == nil, let value = tokenString(from: teamValue) {
            teamAToken = value
            hasSnapshot = true
          }
          if teamAQrToken == nil, let value = qrTokenString(from: teamValue) {
            teamAQrToken = value
            hasSnapshot = true
          }
        }

        for teamKey in teamBKeys {
          if container.keys.contains(teamKey) { hasSnapshot = true }
          let teamValue = container[teamKey]
          if teamBToken == nil, let value = tokenString(from: teamValue) {
            teamBToken = value
            hasSnapshot = true
          }
          if teamBQrToken == nil, let value = qrTokenString(from: teamValue) {
            teamBQrToken = value
            hasSnapshot = true
          }
        }
      }
    }

    return (
      teamAToken: teamAToken,
      teamBToken: teamBToken,
      teamAQrToken: teamAQrToken,
      teamBQrToken: teamBQrToken,
      hasSnapshot: hasSnapshot
    )
  }

  private func tokenString(from value: Any?) -> String? {
    if let direct = string(value), !direct.isEmpty {
      return direct
    }
    let object = asDict(value)
    if !object.isEmpty {
      return string(object["token"]) ??
        string(object["baseTokenHash"]) ??
        string(object["tokenHash"]) ??
        string(object["id"]) ??
        string(object["tagId"]) ??
        string(object["value"])
    }
    return nil
  }

  private func qrTokenString(from value: Any?) -> String? {
    let object = asDict(value)
    if !object.isEmpty {
      return string(object["qrToken"]) ?? string(object["qr_token"])
    }
    return nil
  }

  private func parseAdminParticipants(_ root: [String: Any]) -> [AdminGameStatus.Participant] {
    let candidateRoots = adminCandidateRoots(root)
    AppLogger.info("[ADMIN] parseAdminParticipants: checking \(candidateRoots.count) candidate roots, keys=[\(root.keys.sorted().joined(separator: ","))]")
    for (idx, candidate) in candidateRoots.enumerated() {
      // Log all keys at this candidate level that might hold player data
      let playerKeys = ["players", "participants", "roster", "joinedPlayers", "teammates", "members", "publicPlayers", "teams"]
      for key in playerKeys {
        if let arr = candidate[key] as? [Any] {
          AppLogger.info("[ADMIN]   candidate[\(idx)][\(key)] = array(\(arr.count))")
        } else if let dict = candidate[key] as? [String: Any] {
          AppLogger.info("[ADMIN]   candidate[\(idx)][\(key)] = dict(keys: \(dict.keys.sorted().joined(separator: ",")))")
        }
      }
      if let parsed = parseAdminParticipants(in: candidate), !parsed.isEmpty {
        AppLogger.info("[ADMIN]   → found \(parsed.count) participants in candidate[\(idx)]")
        return parsed
      }
    }
    AppLogger.info("[ADMIN]   → 0 participants found across all candidates")
    return []
  }

  private func matchCandidateRoots(_ root: [String: Any]) -> [[String: Any]] {
    var roots: [[String: Any]] = [root]
    let nestedKeys = ["game", "activeGame", "activeMatch", "match", "data", "payload", "result"]
    for key in nestedKeys {
      let nested = asDict(root[key])
      if !nested.isEmpty {
        roots.append(nested)
      }
    }
    return roots
  }

  private func adminCandidateRoots(_ root: [String: Any]) -> [[String: Any]] {
    let nestedKeys = ["game", "activeGame", "activeMatch", "match", "data", "payload", "result"]
    var roots: [[String: Any]] = [root]
    var frontier: [[String: Any]] = [root]
    var seen: Set<String> = [dictionarySignature(root)]
    var depth = 0

    while !frontier.isEmpty && depth < 5 {
      var nextLevel: [[String: Any]] = []
      for node in frontier {
        for key in nestedKeys {
          let nested = asDict(node[key])
          if nested.isEmpty { continue }
          let signature = dictionarySignature(nested)
          if seen.insert(signature).inserted {
            roots.append(nested)
            nextLevel.append(nested)
          }
        }
      }
      frontier = nextLevel
      depth += 1
    }

    return roots
  }

  private func dictionarySignature(_ node: [String: Any]) -> String {
    let keys = node.keys.sorted().joined(separator: "|")
    let gameId = string(node["gameId"]) ?? string(node["id"]) ?? string(node["activeGameId"]) ?? ""
    let state = string(node["state"]) ?? string(node["status"]) ?? ""
    return "\(keys)#\(gameId)#\(state)#\(node.count)"
  }

  private func parseAdminParticipants(in root: [String: Any]) -> [AdminGameStatus.Participant]? {
    let directKeys = ["players", "participants", "roster", "joinedPlayers", "teammates", "members", "publicPlayers"]
    for key in directKeys {
      let parsedArray = parseParticipantsArray(asArray(root[key]))
      if !parsedArray.isEmpty {
        return parsedArray
      }

      if let dict = root[key] as? [String: Any] {
        let parsedMap = parseParticipantsMap(dict)
        if !parsedMap.isEmpty {
          return parsedMap
        }
      }
    }

    let teams = asDict(root["teams"])
    if !teams.isEmpty {
      var merged: [AdminGameStatus.Participant] = []
      merged += parseParticipantsArray(asArray(teams["TEAM_A"]), forcedTeamId: "TEAM_A")
      merged += parseParticipantsArray(asArray(teams["TEAM_B"]), forcedTeamId: "TEAM_B")
      merged += parseParticipantsArray(asArray(teams["UNASSIGNED"]))

      if let teamAMap = teams["TEAM_A"] as? [String: Any] {
        merged += parseParticipantsMap(teamAMap, forcedTeamId: "TEAM_A")
      }
      if let teamBMap = teams["TEAM_B"] as? [String: Any] {
        merged += parseParticipantsMap(teamBMap, forcedTeamId: "TEAM_B")
      }
      if let unassignedMap = teams["UNASSIGNED"] as? [String: Any] {
        merged += parseParticipantsMap(unassignedMap)
      }

      if !merged.isEmpty {
        return uniqueParticipants(merged)
      }
    }

    return nil
  }

  private func parseParticipantsArray(_ raw: [Any], forcedTeamId: String? = nil) -> [AdminGameStatus.Participant] {
    raw.compactMap { entry in
      parseAdminParticipant(asDict(entry), fallbackId: nil, forcedTeamId: forcedTeamId)
    }
  }

  private func parseParticipantsMap(_ raw: [String: Any], forcedTeamId: String? = nil) -> [AdminGameStatus.Participant] {
    raw.compactMap { key, value in
      parseAdminParticipant(asDict(value), fallbackId: key, forcedTeamId: forcedTeamId)
    }
  }

  private func parseAdminParticipant(
    _ item: [String: Any],
    fallbackId: String?,
    forcedTeamId: String?
  ) -> AdminGameStatus.Participant? {
    guard !item.isEmpty else { return nil }

    let publicProfile = asDict(item["publicProfile"])
    let profile = asDict(item["profile"])
    let player = asDict(item["player"])
    let user = asDict(item["user"])
    let assignment = asDict(item["assignment"])
    let rosterEntry = asDict(item["participant"])
    let teamObject = asDict(item["team"])

    let sources = [item, publicProfile, profile, player, user, assignment, rosterEntry, teamObject]

    let id =
      participantString(in: sources, keys: ["uid", "playerId", "id", "userId"]) ??
      fallbackId ??
      UUID().uuidString

    let nickname =
      participantString(in: sources, keys: ["nickname", "name", "displayName"]) ??
      "Giocatore"

    let teamId =
      forcedTeamId ??
      participantString(in: [item, assignment, teamObject, publicProfile, profile, player], keys: ["teamId", "team", "teamLabel"])

    let role =
      participantString(in: [item, assignment, publicProfile, profile, player], keys: ["roleInTeam", "role", "playerRole"])

    let card =
      participantString(
        in: sources,
        keys: ["identityCardCode", "playingCard", "cardCode"]
      )

    let avatar =
      participantString(in: sources, keys: ["avatarDataUrl", "avatarUrl", "photoURL", "photoUrl"])

    return AdminGameStatus.Participant(
      id: id,
      nickname: nickname,
      teamId: teamId,
      roleInTeam: role,
      playingCard: card,
      avatarDataUrl: avatar
    )
  }

  private func participantString(in sources: [[String: Any]], keys: [String]) -> String? {
    for source in sources where !source.isEmpty {
      for key in keys {
        if let value = string(source[key]), !value.isEmpty {
          return value
        }
      }
    }
    return nil
  }

  private func parseGameSummaryArray(_ raw: [Any]) -> [GameSummary] {
    raw.compactMap { entry in
      let item = asDict(entry)
      if item.isEmpty {
        return nil
      }

      let gameId = string(item["gameId"]) ?? string(item["id"]) ?? ""
      guard !gameId.isEmpty else {
        return nil
      }

      return GameSummary(
        id: gameId,
        name: string(item["name"]) ?? gameId,
        state: string(item["state"]) ?? "N/A",
        playerCount: int(item["playerCount"]) ?? 0,
        isActive: bool(item["isActive"])
      )
    }
  }

  private func parseAdminGameEventExport(_ root: [String: Any]) -> AdminGameEventExport {
    let entries = asArray(root["entries"]).map { rawValue -> AdminGameEventExport.Entry in
      let item = asDict(rawValue)
      return AdminGameEventExport.Entry(
        id: string(item["id"]) ?? UUID().uuidString,
        sequence: int(item["sequence"]),
        type: string(item["type"]) ?? "EVENT",
        scope: string(item["scope"]),
        createdAt: string(item["createdAt"]),
        actorUid: string(item["actorUid"]),
        actorNickname: string(item["actorNickname"]),
        severity: string(item["severity"]) ?? "INFO",
        message: string(item["message"]) ?? "",
        payloadJson: string(item["payloadJson"]) ?? "{}"
      )
    }

    return AdminGameEventExport(
      gameId: string(root["gameId"]) ?? "",
      gameName: string(root["gameName"]) ?? "",
      state: string(root["state"]) ?? "N/A",
      exportedAt: string(root["exportedAt"]) ?? "",
      totalEventCount: int(root["totalEventCount"]) ?? entries.count,
      truncated: bool(root["truncated"]),
      entries: entries
    )
  }

  private func parseGameAccessSummary(_ item: [String: Any]) -> GameAccessSummary? {
    let gameId = string(item["gameId"]) ?? string(item["id"]) ?? ""
    guard !gameId.isEmpty else {
      return nil
    }

    let role = MatchScopedRole(rawValue: (string(item["role"]) ?? "none").lowercased()) ?? .none
    let updatedAt = parseIsoDate(string(item["updatedAt"]) ?? string(item["createdAt"]))
    let autonomousSetup = parseAutonomousSetup(from: item)
    return GameAccessSummary(
      id: gameId,
      name: string(item["name"]) ?? gameId,
      gameDefinitionId: string(item["gameDefinitionId"]) ?? "borderland-classic",
      gameDefinitionName: string(item["gameDefinitionName"]) ?? "Borderland Classic",
      state: string(item["state"]) ?? "N/A",
      role: role,
      playerCount: int(item["playerCount"]) ?? 0,
      itemMode: parseItemMode(string(item["itemMode"])),
      joinedAsPlayer: bool(item["joinedAsPlayer"]),
      canManageSensitive: bool(item["canManageSensitive"]),
      canManageOperations: bool(item["canManageOperations"]),
      isCurrentUserLockedGm: bool(item["isCurrentUserLockedGm"]),
      gmPlayerLockEnabled: bool(item["gmPlayerLockEnabled"]),
      joinCode: string(item["joinCode"]),
      operatorInviteCode: string(item["operatorInviteCode"]),
      updatedAt: updatedAt,
      autonomousSetup: autonomousSetup.setup,
      hasAutonomousSetup: autonomousSetup.hasMetadata
    )
  }

  private func parseGameCatalogEntry(_ item: [String: Any]) -> GameCatalogEntry? {
    let id = string(item["id"]) ?? string(item["gameDefinitionId"]) ?? ""
    guard !id.isEmpty else {
      return nil
    }
    let supportedModes = asArray(item["supportedItemModes"])
      .compactMap { parseItemMode(string($0)) }
    let recommendedModes = asArray(item["recommendedItemModes"])
      .compactMap { parseItemMode(string($0)) }
    let defaultMode = parseItemMode(string(item["defaultItemMode"]))
    let sanitizedSupportedModes = supportedModes.isEmpty ? [.none] : supportedModes
    return GameCatalogEntry(
      id: id,
      name: string(item["name"]) ?? id,
      shortDescription: string(item["shortDescription"]) ?? "",
      supportedItemModes: sanitizedSupportedModes,
      recommendedItemModes: recommendedModes,
      defaultItemMode: sanitizedSupportedModes.contains(defaultMode) ? defaultMode : sanitizedSupportedModes[0],
      isActive: bool(item["isActive"]) || item["isActive"] == nil
    )
  }

  private func currentAuthenticatedUid() -> String? {
    #if canImport(FirebaseAuth)
    return Auth.auth().currentUser?.uid
    #else
    return nil
    #endif
  }

  private func cachedProfile(for uid: String?) -> PlayerProfile? {
    profileCacheLock.lock()
    defer { profileCacheLock.unlock() }
    guard cachedOwnProfileUid == uid else { return nil }
    return cachedOwnProfile
  }

  private func inFlightProfileTask(for uid: String?) -> Task<PlayerProfile, Error>? {
    profileCacheLock.lock()
    defer { profileCacheLock.unlock() }
    guard cachedOwnProfileUid == uid else { return nil }
    return ownProfileTask
  }

  private func storeProfileTask(_ task: Task<PlayerProfile, Error>, for uid: String?) {
    profileCacheLock.lock()
    defer { profileCacheLock.unlock() }
    cachedOwnProfileUid = uid
    ownProfileTask = task
  }

  private func storeCachedProfile(_ profile: PlayerProfile, for uid: String?) {
    profileCacheLock.lock()
    defer { profileCacheLock.unlock() }
    cachedOwnProfileUid = uid ?? profile.uid
    cachedOwnProfile = profile
    ownProfileTask = nil
  }

  private func clearProfileTask(for uid: String?) {
    profileCacheLock.lock()
    defer { profileCacheLock.unlock() }
    guard cachedOwnProfileUid == uid else { return }
    ownProfileTask = nil
  }

  private func clearCachedProfile(for uid: String?) {
    profileCacheLock.lock()
    defer { profileCacheLock.unlock() }
    guard cachedOwnProfileUid == uid else { return }
    cachedOwnProfileUid = nil
    cachedOwnProfile = nil
    ownProfileTask = nil
  }

  private func parseItemMode(_ rawValue: String?) -> ItemMode {
    switch (rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case ItemMode.shared.rawValue:
      return .shared
    case ItemMode.crossTeam.rawValue:
      return .crossTeam
    default:
      return .none
    }
  }

  private static let isoFormatterWithFractionalSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  private func parseIsoDate(_ rawValue: String?) -> Date? {
    guard let rawValue, !rawValue.isEmpty else { return nil }
    return Self.isoFormatterWithFractionalSeconds.date(from: rawValue)
      ?? Self.isoFormatter.date(from: rawValue)
  }

  private func uniqueParticipants(_ raw: [AdminGameStatus.Participant]) -> [AdminGameStatus.Participant] {
    var seen: Set<String> = []
    var unique: [AdminGameStatus.Participant] = []
    for participant in raw {
      if seen.insert(participant.id).inserted {
        unique.append(participant)
      }
    }
    return unique
  }

  private func shouldLogFunctionLifecycle(_ name: String) -> Bool {
    let noisyFunctions = [
      AppConfig.Callable.playerGetProfile,
      AppConfig.Callable.playerGetActiveGameStatus
    ]
    return !noisyFunctions.contains(name)
  }

  private func isLeaderRole(_ role: String?) -> Bool {
    let normalized = (role ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized.contains("leader")
  }

}
#endif
