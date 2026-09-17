import Foundation
import Combine

@MainActor
final class PushRegistrationCoordinator {
  static let shared = PushRegistrationCoordinator()

  private var lastRegisteredPushContext: String?
  private var isSyncInProgress = false

  private init() {}

  func reset() {
    lastRegisteredPushContext = nil
  }

  func syncRegistration(
    gameService: GameService,
    games: [GameAccessSummary]? = nil,
    userAgent: String = "ios-home"
  ) async {
    guard !isSyncInProgress else { return }
    isSyncInProgress = true
    defer { isSyncInProgress = false }

    let token = await PushNotificationState.resolvedToken()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !token.isEmpty else { return }

    let availableGames: [GameAccessSummary]
    if let games {
      availableGames = games
    } else {
      availableGames = (try? await gameService.listAccessibleGames()) ?? []
    }

    guard let preferredGame = preferredPushGame(in: availableGames) else {
      if lastRegisteredPushContext != nil {
        try? await gameService.unregisterPushToken(token: token)
        lastRegisteredPushContext = nil
      }
      return
    }

    let context = "\(token)|\(preferredGame.id)"
    guard context != lastRegisteredPushContext else { return }

    do {
      try await gameService.registerPushToken(
        token: token,
        gameId: preferredGame.id,
        userAgent: userAgent
      )
      lastRegisteredPushContext = context
    } catch {
      AppLogger.error("push registration sync failed: \(error.localizedDescription)")
    }
  }

  private func preferredPushGame(in games: [GameAccessSummary]) -> GameAccessSummary? {
    games
      .filter { summary in
        !summary.isArchivedOrEnded &&
        (summary.joinedAsPlayer || summary.role == .player || summary.isCurrentUserLockedGm)
      }
      .sorted { lhs, rhs in
        let lhsLive = lhs.state.uppercased() == "LIVE"
        let rhsLive = rhs.state.uppercased() == "LIVE"
        if lhsLive != rhsLive {
          return lhsLive && !rhsLive
        }
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
      .first
  }
}

@MainActor
final class AppContainer: ObservableObject {
  struct PendingInvite: Equatable {
    let codeOrLink: String
    let isOperatorInvite: Bool
  }

  enum FlowStep: Equatable {
    case gameSelection
    case lobby
    case match
  }

  let authService: AuthService
  let gameService: GameService
  let nfcService: NFCService

  @Published var role: AppRole = .unknown
  @Published var isAuthenticated = false
  @Published var flowStep: FlowStep = .gameSelection
  @Published var selectedGameId: String?
  @Published var activeMatchCode: String = ""
  @Published var isGuestSession: Bool = false
  @Published var selectedGuestCardCode: String = "AS"
  @Published var lobbyStatusMessage: String = ""
  @Published var requiresAdminEntryChoice: Bool = false
  @Published var needsProfileCompletion: Bool = false
  @Published var isResolvingProfileGate: Bool = false
  @Published var pendingInvite: PendingInvite?
  // Intento scelto sulla schermata di benvenuto prima del login: la home lo
  // consuma per aprire subito il flusso giusto dopo l'autenticazione.
  enum EntryIntent {
    case joinMatch
    case createMatch
  }
  @Published var pendingEntryIntent: EntryIntent?
  // Gioco scelto nella hub dopo il login: azzerato a ogni nuova sessione, la
  // scelta va rifatta a ogni accesso.
  @Published var selectedGameDefinitionId: String?

  var selectedGameDefinition: GameDefinition? {
    guard let selectedGameDefinitionId else { return nil }
    return GameDefinition.allGames.first(where: { $0.id == selectedGameDefinitionId })
  }
  private var hasResolvedAdminEntryChoice = true

  func consumePendingEntryIntent() -> EntryIntent? {
    let intent = pendingEntryIntent
    pendingEntryIntent = nil
    return intent
  }
  private var pushTokenObserver: NSObjectProtocol?

  private enum StorageKeys {
    static let lastGameId = "app.lastGameId"
    static let lastMatchCode = "app.lastMatchCode"
  }

  convenience init() {
    self.init(
      authService: AuthServiceFactory.make(),
      gameService: GameServiceFactory.make(),
      nfcService: NFCServiceFactory.make()
    )
  }

  init(
    authService: AuthService,
    gameService: GameService,
    nfcService: NFCService
  ) {
    self.authService = authService
    self.gameService = gameService
    self.nfcService = nfcService
    pushTokenObserver = NotificationCenter.default.addObserver(
      forName: .pushTokenDidChange,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      Task { await PushRegistrationCoordinator.shared.syncRegistration(gameService: self.gameService) }
    }
  }

  deinit {
    if let pushTokenObserver {
      NotificationCenter.default.removeObserver(pushTokenObserver)
    }
  }

  func bootstrap() async {
    await authService.restoreSession()
    isAuthenticated = authService.currentUser != nil
    role = authService.currentRole
    isGuestSession = authService.currentUser?.isGuest ?? false
    requiresAdminEntryChoice = false
    hasResolvedAdminEntryChoice = true

    guard isAuthenticated else {
      flowStep = .gameSelection
      return
    }

    await refreshProfileCompletionRequirement()
    await PushRegistrationCoordinator.shared.syncRegistration(gameService: gameService)
    flowStep = .gameSelection
  }

  func didSignIn(as role: AppRole) {
    isAuthenticated = true
    self.role = role
    isGuestSession = authService.currentUser?.isGuest ?? false
    requiresAdminEntryChoice = false
    hasResolvedAdminEntryChoice = true
    needsProfileCompletion = false
    isResolvingProfileGate = false
    flowStep = .gameSelection
    selectedGameId = nil
    selectedGameDefinitionId = nil
    activeMatchCode = ""
    lobbyStatusMessage = ""

    Task { [weak self] in
      guard let self else { return }
      await self.refreshProfileCompletionRequirement()
      await PushRegistrationCoordinator.shared.syncRegistration(gameService: self.gameService)
    }
  }

  func refreshRoleFromBackend() async {
    guard isAuthenticated else { return }
    _ = await authService.refreshCurrentRole()
    isGuestSession = authService.currentUser?.isGuest ?? false
    requiresAdminEntryChoice = false
  }

  func continueRestoredAdminSession(as role: AppRole) {
    self.role = role
    requiresAdminEntryChoice = false
    hasResolvedAdminEntryChoice = true
    if role == .player, selectedGameId != nil {
      flowStep = .lobby
    } else {
      flowStep = .gameSelection
    }
  }

  func selectGame(_ gameId: String) {
    selectedGameId = gameId
    UserDefaults.standard.set(gameId, forKey: StorageKeys.lastGameId)
    flowStep = .lobby
    lobbyStatusMessage = ""
  }

  func enterMatchAsPlayer(code: String) {
    isGuestSession = false
    activeMatchCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
    UserDefaults.standard.set(activeMatchCode, forKey: StorageKeys.lastMatchCode)
    flowStep = .match
    lobbyStatusMessage = ""
  }

  func enterMatchAsGuest(code: String, cardCode: String) {
    isGuestSession = true
    selectedGuestCardCode = PlayingCardCatalog.normalizeCode(cardCode)
    activeMatchCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
    UserDefaults.standard.set(activeMatchCode, forKey: StorageKeys.lastMatchCode)
    flowStep = .match
    lobbyStatusMessage = ""
  }

  func enterMatchAsAdmin() {
    flowStep = .match
    lobbyStatusMessage = ""
  }

  func backToLobby() {
    flowStep = .lobby
  }

  func logout() async {
    if let token = PushNotificationState.currentToken {
      try? await gameService.unregisterPushToken(token: token)
    }
    PushRegistrationCoordinator.shared.reset()

    do {
      try await authService.signOut()
      resetSessionState()
    } catch {
      AppLogger.error("logout failed: \(error.localizedDescription)")
    }
  }

  func deleteAccount() async throws {
    PushRegistrationCoordinator.shared.reset()
    try await gameService.deleteCurrentAccount()

    do {
      try await authService.signOut()
    } catch {
      AppLogger.error("signout after account deletion failed: \(error.localizedDescription)")
    }

    PushNotificationState.store(token: nil)
    resetSessionState()
  }

  func didCompleteProfile() {
    needsProfileCompletion = false
    isResolvingProfileGate = false
    flowStep = .gameSelection
    Task { await PushRegistrationCoordinator.shared.syncRegistration(gameService: gameService) }
  }

  func handleIncomingURL(_ url: URL) {
    guard let invite = Self.extractPendingInvite(from: url) else { return }
    pendingInvite = invite
  }

  func consumePendingInvite() -> PendingInvite? {
    let invite = pendingInvite
    pendingInvite = nil
    return invite
  }

  func leaveMatch() {
    activeMatchCode = ""
    UserDefaults.standard.removeObject(forKey: StorageKeys.lastMatchCode)
    lobbyStatusMessage = ""
    flowStep = .gameSelection
    selectedGameId = nil
  }

  private func resetSessionState() {
    isAuthenticated = false
    role = .unknown
    isGuestSession = false
    selectedGuestCardCode = "AS"
    needsProfileCompletion = false
    isResolvingProfileGate = false
    pendingInvite = nil
    requiresAdminEntryChoice = false
    hasResolvedAdminEntryChoice = true
    flowStep = .gameSelection
    selectedGameId = nil
    selectedGameDefinitionId = nil
    activeMatchCode = ""
    lobbyStatusMessage = ""
    UserDefaults.standard.removeObject(forKey: StorageKeys.lastGameId)
    UserDefaults.standard.removeObject(forKey: StorageKeys.lastMatchCode)
  }

  private func refreshProfileCompletionRequirement() async {
    guard isAuthenticated else {
      needsProfileCompletion = false
      isResolvingProfileGate = false
      return
    }

    guard !(authService.currentUser?.isGuest ?? false) else {
      needsProfileCompletion = false
      isResolvingProfileGate = false
      return
    }

    isResolvingProfileGate = true
    defer { isResolvingProfileGate = false }

    do {
      let profile = try await gameService.fetchOwnProfile()
      if isAuthenticated {
        needsProfileCompletion = !profile.profileCompleted
      }
    } catch {
      needsProfileCompletion = false
      AppLogger.error("profile completion gate failed: \(error.localizedDescription)")
    }
  }

  private static func extractPendingInvite(from url: URL) -> PendingInvite? {
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let queryItems = components?.queryItems ?? []

    let parameterNames = ["code", "joinCode", "inviteCode", "operatorCode"]
    for name in parameterNames {
      if let value = queryItems.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.value?
        .trimmingCharacters(in: .whitespacesAndNewlines),
        !value.isEmpty {
        return PendingInvite(codeOrLink: value, isOperatorInvite: name.caseInsensitiveCompare("operatorCode") == .orderedSame)
      }
    }

    let pathParts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
    if pathParts.count >= 2 {
      let section = pathParts[pathParts.count - 2].lowercased()
      let code = pathParts[pathParts.count - 1].trimmingCharacters(in: .whitespacesAndNewlines)
      if !code.isEmpty && (section == "player" || section == "admin" || section == "operator") {
        return PendingInvite(codeOrLink: code, isOperatorInvite: section != "player")
      }
    }

    return nil
  }
}
