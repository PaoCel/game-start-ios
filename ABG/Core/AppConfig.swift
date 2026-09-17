import Foundation

enum AppConfig {
  static let projectId = "comple-ruspa-2026"
  static let appURLScheme = "abg"
  static let inviteWebHost = "borderlandgames.it"
  static let inviteWebBaseURL = URL(string: "https://borderlandgames.it")!
  static let inviteLandingPath = "download-ios"
  static let appStoreURL: URL? = URL(string: "https://apps.apple.com/app/id6760287886")

  static func inviteDeepLink(code: String, isOperatorInvite: Bool) -> URL? {
    let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedCode.isEmpty else { return nil }

    var components = URLComponents()
    components.scheme = appURLScheme
    components.host = isOperatorInvite ? "admin" : "player"
    components.queryItems = [
      URLQueryItem(name: isOperatorInvite ? "operatorCode" : "code", value: normalizedCode)
    ]
    return components.url
  }

  static func inviteLandingURL(code: String, isOperatorInvite: Bool) -> URL? {
    let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedCode.isEmpty else { return nil }

    var components = URLComponents(
      url: inviteWebBaseURL.appendingPathComponent(inviteLandingPath),
      resolvingAgainstBaseURL: false
    )
    var queryItems = [
      URLQueryItem(name: isOperatorInvite ? "operatorCode" : "code", value: normalizedCode)
    ]
    if let appStoreURL {
      queryItems.append(URLQueryItem(name: "appStoreUrl", value: appStoreURL.absoluteString))
    }
    components?.queryItems = queryItems
    return components?.url
  }

  static func inviteShareText(code: String, isOperatorInvite: Bool) -> String {
    let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
    let accessLabel = isOperatorInvite ? "operatore" : "player"
    var lines: [String] = [
      "Invito Game Start! per accesso \(accessLabel).",
      "Borderland Games"
    ]

    if let landingURL = inviteLandingURL(code: normalizedCode, isOperatorInvite: isOperatorInvite) {
      lines.append(landingURL.absoluteString)
    }

    if let deepLink = inviteDeepLink(code: normalizedCode, isOperatorInvite: isOperatorInvite) {
      lines.append("Apertura diretta app: \(deepLink.absoluteString)")
    }

    if let appStoreURL {
      lines.append("App Store: \(appStoreURL.absoluteString)")
    }

    lines.append("Codice \(accessLabel): \(normalizedCode)")
    return lines.joined(separator: "\n")
  }

  enum Callable {
    static let listGameCatalog = "listGameCatalog"
    static let playerGetActiveGameStatus = "playerGetActiveGameStatus"
    static let playerJoinActiveGame = "playerJoinActiveGame"
    static let playerJoinByCode = "playerJoinByCode"
    static let playerGetProfile = "playerGetProfile"
    static let playerUpdateProfile = "playerUpdateProfile"
    static let submitScan = "submitScan"
    static let playerEnsureQrCode = "playerEnsureQrCode"
    static let playerRegisterBraceletToken = "playerRegisterBraceletToken"
    static let playerRegisterPushToken = "playerRegisterPushToken"
    static let playerUnregisterPushToken = "playerUnregisterPushToken"
    static let playerDeleteAccount = "playerDeleteAccount"
    static let playerSetTeamReady = "playerSetTeamReady"
    static let playerSendTeamReadyReminder = "playerSendTeamReadyReminder"
    static let playerSelectOwnTeam = "playerSelectOwnTeam"
    static let playerShuffleTeams = "playerShuffleTeams"

    static let adminUpdateGameConfig = "adminUpdateGameConfig"
    static let adminSetTeamBaseToken = "adminSetTeamBaseToken"
    static let adminUpdatePlayerProfile = "adminUpdatePlayerProfile"
    static let adminCreateGame = "adminCreateGame"
    static let getActiveGame = "getActiveGame"
    static let adminTransitionPhase = "adminTransitionPhase"
    static let adminStartGame = "adminStartGame"
    static let adminPauseResume = "adminPauseResume"
    static let adminEndMatch = "adminEndMatch"
    static let adminSelectRandomTeamLeaders = "adminSelectRandomTeamLeaders"
    static let leaderDistributeTeamPoints = "leaderDistributeTeamPoints"
    static let playerGetScoreboard = "playerGetScoreboard"
    static let adminAssignPlayerTeam = "adminAssignPlayerTeam"
    static let adminRemovePlayer = "adminRemovePlayer"
    static let adminSetTeamLeader = "adminSetTeamLeader"
    static let adminRegisterGameItem = "adminRegisterGameItem"
    static let adminAttachItemToken = "adminAttachItemToken"
    static let adminGetGameItems = "adminGetGameItems"
    static let adminGetRoster = "adminGetRoster"                 // reads games/{gameId}/publicPlayers
    static let adminListOwnedGames = "adminListOwnedGames"
    static let adminGetGameSnapshot = "adminGetGameSnapshot"
    static let adminExportGameEvents = "adminExportGameEvents"
    static let adminDeleteGame = "adminDeleteGame"
    static let adminLookupGameTag = "adminLookupGameTag"
    static let adminCleanupTokenConflict = "adminCleanupTokenConflict"
  }
}
