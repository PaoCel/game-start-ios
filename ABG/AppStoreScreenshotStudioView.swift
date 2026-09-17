import SwiftUI

enum AppStoreScreenshotLaunch {
  private static let launchArgument = "-app-store-screenshots"
  private static let sceneArgumentPrefix = "-app-store-screenshot-scene="

  static var isEnabled: Bool {
    let processInfo = ProcessInfo.processInfo
    return processInfo.arguments.contains(launchArgument) ||
      processInfo.environment["APP_STORE_SCREENSHOTS"] == "1"
  }

  static var initialScene: AppStoreScreenshotScene? {
    let processInfo = ProcessInfo.processInfo

    if let rawValue = processInfo.environment["APP_STORE_SCREENSHOT_SCENE"]?.trimmingCharacters(in: .whitespacesAndNewlines),
       let scene = AppStoreScreenshotScene(rawValue: rawValue.lowercased()) {
      return scene
    }

    for argument in processInfo.arguments {
      guard argument.hasPrefix(sceneArgumentPrefix) else { continue }
      let rawValue = String(argument.dropFirst(sceneArgumentPrefix.count)).lowercased()
      if let scene = AppStoreScreenshotScene(rawValue: rawValue) {
        return scene
      }
    }

    return nil
  }
}

enum AppStoreScreenshotScene: String, CaseIterable, Identifiable {
  case login
  case home
  case profile
  case gameplay
  case result
  case controlRoom = "control-room"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .login:
      return "Accesso"
    case .home:
      return "Home operativa"
    case .profile:
      return "Profilo player"
    case .gameplay:
      return "Gameplay live"
    case .result:
      return "Esito partita"
    case .controlRoom:
      return "Control room"
    }
  }

  var subtitle: String {
    switch self {
    case .login:
      return "Ingresso con Google, Apple o ospite."
    case .home:
      return "Hub con match attivo, inviti e accessi rapidi."
    case .profile:
      return "Nickname e avatar pronti prima dell'ingresso."
    case .gameplay:
      return "HUD live del player durante la partita."
    case .result:
      return "Riepilogo finale chiaro e leggibile."
    case .controlRoom:
      return "Regia operativa per team, codici e stato match."
    }
  }
}

struct AppStoreScreenshotStudioView: View {
  private let directScene = AppStoreScreenshotLaunch.initialScene

  var body: some View {
    Group {
      if let directScene {
        AppStoreScreenshotSceneHost(scene: directScene)
      } else {
        NavigationStack {
          ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.xl) {
              header

              VStack(spacing: Spacing.md) {
                ForEach(AppStoreScreenshotScene.allCases) { scene in
                  NavigationLink {
                    AppStoreScreenshotSceneHost(scene: scene)
                  } label: {
                    sceneCard(for: scene)
                  }
                  .buttonStyle(.plain)
                }
              }

              footer
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.xl)
          }
          .borderlandBackground()
          .navigationTitle("App Store Screenshots")
          .navigationBarTitleDisplayMode(.inline)
        }
      }
    }
  }

  private var header: some View {
    BorderlandCard(variant: .elevated) {
      VStack(alignment: .leading, spacing: Spacing.sm) {
        Text("Screenshot Studio")
          .font(AppTypography.title2)
          .foregroundStyle(BorderlandTheme.gold)

        Text("Apri una scena, aspetta che eventuali card si assestino e cattura lo schermo dal simulatore.")
          .font(AppTypography.callout)
          .foregroundStyle(BorderlandTheme.textMuted)

        Text("Ordine consigliato: Home, Gameplay, Control room, Profilo, Accesso.")
          .font(AppTypography.caption)
          .foregroundStyle(BorderlandTheme.textPrimary)
      }
    }
  }

  private func sceneCard(for scene: AppStoreScreenshotScene) -> some View {
    BorderlandCard {
      HStack(alignment: .top, spacing: Spacing.md) {
        VStack(alignment: .leading, spacing: Spacing.xs) {
          Text(scene.title)
            .font(AppTypography.title3)
            .foregroundStyle(BorderlandTheme.textPrimary)

          Text(scene.subtitle)
            .font(AppTypography.callout)
            .foregroundStyle(BorderlandTheme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 0)

        Image(systemName: "arrow.right.circle.fill")
          .font(.system(size: 28, weight: .semibold))
          .foregroundStyle(BorderlandTheme.gold)
      }
    }
  }

  private var footer: some View {
    Text("Per aprire direttamente una scena: imposta APP_STORE_SCREENSHOT_SCENE oppure usa -app-store-screenshot-scene=<nome>.")
      .font(AppTypography.caption)
      .foregroundStyle(BorderlandTheme.textDim)
  }
}

private struct AppStoreScreenshotSceneHost: View {
  let scene: AppStoreScreenshotScene

  var body: some View {
    Group {
      switch scene {
      case .login:
        AppStoreLoginScreenshotScene()
      case .home:
        AppStoreHomeScreenshotScene()
      case .profile:
        AppStoreProfileScreenshotScene()
      case .gameplay:
        AppStoreGameplayScreenshotScene()
      case .result:
        AppStoreResultScreenshotScene()
      case .controlRoom:
        AppStoreControlRoomScreenshotScene()
      }
    }
    .toolbar(.hidden, for: .navigationBar)
  }
}

private struct AppStoreLoginScreenshotScene: View {
  var body: some View {
    LoginView(
      viewModel: AuthViewModel(
        authService: AppStoreScreenshotAuthService(user: nil, role: .player),
        onSignedIn: { _ in }
      )
    )
  }
}

private struct AppStoreHomeScreenshotScene: View {
  private let authService: AppStoreScreenshotAuthService
  private let gameService: AppStoreScreenshotGameService
  private let nfcService: UnsupportedNFCService

  @StateObject private var container: AppContainer

  init() {
    let authService = AppStoreScreenshotAuthService(
      user: AppUser(
        uid: "app-store-home",
        email: "support@borderlandgames.it",
        displayName: "Paolo"
      ),
      role: .player
    )
    let gameService = AppStoreScreenshotGameService()
    let nfcService = UnsupportedNFCService()

    self.authService = authService
    self.gameService = gameService
    self.nfcService = nfcService
    _container = StateObject(
      wrappedValue: AppContainer(
        authService: authService,
        gameService: gameService,
        nfcService: nfcService
      )
    )
  }

  var body: some View {
    StoreHomeView(
      gameService: gameService,
      authService: authService,
      nfcService: nfcService,
      logoutAction: { await Task.yield() }
    )
    .environmentObject(container)
    .task {
      if !container.isAuthenticated {
        container.didSignIn(as: .player)
      }
    }
  }
}

private struct AppStoreProfileScreenshotScene: View {
  @StateObject private var viewModel = ProfileCompletionViewModel(gameService: MockGameService())
  @State private var configured = false

  var body: some View {
    ProfileCompletionView(viewModel: viewModel) {}
      .task {
        guard !configured else { return }
        configured = true
        viewModel.nickname = "Ari Vega"
        viewModel.selectPresetAvatar(symbol: "sparkles")
        viewModel.currentStep = .review
      }
  }
}

private struct AppStoreGameplayScreenshotScene: View {
  var body: some View {
    PlayerHomeView(
      viewModel: .preview(scenario: .ready),
      logoutAction: { await Task.yield() }
    )
  }
}

private struct AppStoreResultScreenshotScene: View {
  var body: some View {
    MatchEndOverlay(
      summary: .init(
        title: "CITTADINI VINCONO",
        subtitle: "Il timer autorevole e scaduto. Il match live si chiude con punteggi aggiornati in tempo reale.",
        scoreline: "Cittadini 4.280  •  Giocatori 3.960",
        personalLabel: "Punteggio finale",
        personalPoints: 1320,
        teamStandings: [],
        playerRanking: [],
        endedByElimination: false
      ),
      onExit: {}
    )
  }
}

private struct AppStoreControlRoomScreenshotScene: View {
  @StateObject private var viewModel = AdminViewModel(
    gameService: MockGameService(),
    authService: MockAuthService(),
    nfcService: UnsupportedNFCService()
  )
  @State private var configured = false

  var body: some View {
    AdminHomeView(
      viewModel: viewModel,
      logoutAction: { await Task.yield() },
      switchToPlayerAction: nil,
      backAction: nil,
      initialGameId: nil
    )
    .task {
      guard !configured else { return }
      configured = true

      viewModel.showingGamePicker = false
      viewModel.gameName = "Borderland Arena"
      viewModel.activeGameId = "BLG-042"
      viewModel.gameState = "LIVE"
      viewModel.matchDurationSec = 3_600
      viewModel.itemMode = .crossTeam
      viewModel.playerJoinCode = "BORDER42"
      viewModel.operatorInviteCode = "CTRL42"
      viewModel.teamABaseToken = "AAAA1111"
      viewModel.teamBBaseToken = "BBBB2222"
      viewModel.logLines = [
        "[19:18:44] Live avviato",
        "[19:19:12] Oggetto assegnato a TEAM_B",
        "[19:19:30] Base TEAM_A verificata"
      ]
      viewModel.participants = [
        .init(id: "p1", nickname: "Ari", teamId: "TEAM_A", roleInTeam: "LEADER", playingCard: "AS", avatarDataUrl: nil),
        .init(id: "p2", nickname: "Luca", teamId: "TEAM_A", roleInTeam: nil, playingCard: "KH", avatarDataUrl: nil),
        .init(id: "p3", nickname: "Marta", teamId: "TEAM_B", roleInTeam: "LEADER", playingCard: "QD", avatarDataUrl: nil),
        .init(id: "p4", nickname: "Nina", teamId: "TEAM_B", roleInTeam: nil, playingCard: "JC", avatarDataUrl: nil)
      ]
      viewModel.gameItems = [
        .init(id: "item-1", icon: "bolt.fill", points: 200, collectorTeamId: "TEAM_B"),
        .init(id: "item-2", icon: "flame.fill", points: 350, collectorTeamId: "TEAM_A")
      ]
    }
  }
}

private final class AppStoreScreenshotAuthService: AuthService {
  private(set) var currentUser: AppUser?
  private(set) var currentRole: AppRole

  init(user: AppUser?, role: AppRole) {
    currentUser = user
    currentRole = role
  }

  func restoreSession() async {}

  func refreshCurrentRole() async -> AppRole {
    currentRole
  }

  func signInWithGoogle() async throws -> AppRole {
    currentUser = currentUser ?? AppUser(uid: "google-user", email: "user@example.com", displayName: "Player One")
    return currentRole
  }

  func signInWithApple() async throws -> AppRole {
    currentUser = currentUser ?? AppUser(uid: "apple-user", email: nil, displayName: "Player One")
    return currentRole
  }

  func signInAsGuest() async throws -> AppRole {
    currentUser = AppUser(uid: "guest-user", email: nil, displayName: "Guest", isGuest: true)
    return currentRole
  }

  func signOut() async throws {
    currentUser = nil
    currentRole = .unknown
  }
}

private final class AppStoreScreenshotGameService: GameService {
  private let base = MockGameService()
  private var profile: PlayerProfile
  private let games: [GameAccessSummary]

  init() {
    var profile = PlayerProfile.empty
    profile.uid = "app-store-player"
    profile.nickname = "Paolo"
    profile.profileCompleted = true
    self.profile = profile

    games = [
      GameAccessSummary(
        id: "borderland-arena",
        name: "Borderland Arena",
        gameDefinitionId: "borderland-classic",
        gameDefinitionName: "Borderland Classic",
        state: "LIVE",
        role: .owner,
        playerCount: 14,
        itemMode: .crossTeam,
        joinedAsPlayer: true,
        canManageSensitive: true,
        canManageOperations: true,
        isCurrentUserLockedGm: false,
        gmPlayerLockEnabled: false,
        joinCode: "BORDER42",
        operatorInviteCode: "CTRL42",
        updatedAt: Date(),
        autonomousSetup: .autonomousDefault,
        hasAutonomousSetup: true
      ),
      GameAccessSummary(
        id: "night-session",
        name: "Night Session",
        gameDefinitionId: "borderland-classic",
        gameDefinitionName: "Borderland Classic",
        state: "LOBBY",
        role: .owner,
        playerCount: 8,
        itemMode: .none,
        joinedAsPlayer: false,
        canManageSensitive: true,
        canManageOperations: true,
        isCurrentUserLockedGm: false,
        gmPlayerLockEnabled: false,
        joinCode: "NIGHT84",
        operatorInviteCode: "OPS84",
        updatedAt: Date().addingTimeInterval(-1_800),
        autonomousSetup: .autonomousDefault,
        hasAutonomousSetup: true
      )
    ]
  }

  func listGameCatalog() async throws -> [GameCatalogEntry] {
    try await base.listGameCatalog()
  }

  func fetchMatchSnapshot(gameId: String?) async throws -> MatchSnapshot {
    try await base.fetchMatchSnapshot(gameId: gameId)
  }

  func fetchOwnProfile() async throws -> PlayerProfile {
    profile
  }

  func fetchTeamParticipants(gameId: String) async throws -> [MatchSnapshot.Participant] {
    try await base.fetchTeamParticipants(gameId: gameId)
  }

  func joinActiveGame(nickname: String) async throws -> MatchSnapshot {
    try await base.joinActiveGame(nickname: nickname)
  }

  func joinMatch(gameCode: String, nickname: String) async throws -> MatchSnapshot {
    try await base.joinMatch(gameCode: gameCode, nickname: nickname)
  }

  func joinSelectedGame(gameId: String, nickname: String, asLockedGameMaster: Bool) async throws -> MatchSnapshot {
    try await base.joinSelectedGame(gameId: gameId, nickname: nickname, asLockedGameMaster: asLockedGameMaster)
  }

  func joinGameByCode(codeOrLink: String, nickname: String?) async throws -> GameAccessSummary {
    _ = codeOrLink
    _ = nickname
    if let firstGame = games.first {
      return firstGame
    }
    return try await base.joinGameByCode(codeOrLink: codeOrLink, nickname: nickname)
  }

  func listAccessibleGames() async throws -> [GameAccessSummary] {
    games
  }

  func ensurePlayerQRCode(gameId: String?) async throws -> (token: String, url: String) {
    try await base.ensurePlayerQRCode(gameId: gameId)
  }

  func submitScan(gameId: String, token: String, tokenCandidates: [String], source: String) async throws -> ScanSubmissionOutcome {
    try await base.submitScan(gameId: gameId, token: token, tokenCandidates: tokenCandidates, source: source)
  }

  func registerBraceletToken(token: String, gameId: String?, tokenCandidates: [String]) async throws -> String {
    try await base.registerBraceletToken(token: token, gameId: gameId, tokenCandidates: tokenCandidates)
  }

  func registerPushToken(token: String, gameId: String, userAgent: String?) async throws {
    try await base.registerPushToken(token: token, gameId: gameId, userAgent: userAgent)
  }

  func unregisterPushToken(token: String?) async throws {
    try await base.unregisterPushToken(token: token)
  }

  func deleteCurrentAccount() async throws {
    try await base.deleteCurrentAccount()
  }

  func setTeamReady(gameId: String, isReady: Bool) async throws -> MatchSnapshot {
    try await base.setTeamReady(gameId: gameId, isReady: isReady)
  }

  func sendTeamReadyReminder(gameId: String) async throws {
    try await base.sendTeamReadyReminder(gameId: gameId)
  }

  func savePlayerProfile(_ profile: PlayerProfile) async throws {
    self.profile = profile
  }

  func fetchAdminActiveGame() async throws -> AdminGameStatus {
    try await base.fetchAdminActiveGame()
  }

  func fetchAdminGame(gameId: String) async throws -> AdminGameStatus {
    try await base.fetchAdminGame(gameId: gameId)
  }

  func fetchAdminOwnedGames() async throws -> [GameSummary] {
    [
      GameSummary(id: "borderland-arena", name: "Borderland Arena", state: "LIVE", playerCount: 14, isActive: true),
      GameSummary(id: "night-session", name: "Night Session", state: "LOBBY", playerCount: 8, isActive: true)
    ]
  }

  func createAdminGame(
    name: String,
    gameId: String?,
    gameDefinitionId: String?,
    config: GameplayConfigSnapshot,
    itemMode: ItemMode,
    autonomousSetup: AutonomousGameSetup?
  ) async throws -> AdminGameStatus {
    try await base.createAdminGame(
      name: name,
      gameId: gameId,
      gameDefinitionId: gameDefinitionId,
      config: config,
      itemMode: itemMode,
      autonomousSetup: autonomousSetup
    )
  }

  func deleteAdminGame(gameId: String) async throws {
    try await base.deleteAdminGame(gameId: gameId)
  }

  func transitionToDistribution(gameId: String) async throws {
    try await base.transitionToDistribution(gameId: gameId)
  }

  func startMatch(gameId: String) async throws {
    try await base.startMatch(gameId: gameId)
  }

  func pauseMatch(gameId: String) async throws {
    try await base.pauseMatch(gameId: gameId)
  }

  func resumeMatch(gameId: String) async throws {
    try await base.resumeMatch(gameId: gameId)
  }

  func endMatch(gameId: String) async throws {
    try await base.endMatch(gameId: gameId)
  }

  func pickRandomLeaders(gameId: String) async throws {
    try await base.pickRandomLeaders(gameId: gameId)
  }

  func distributeTeamPoints(gameId: String, allocations: [String: Int]) async throws {
    try await base.distributeTeamPoints(gameId: gameId, allocations: allocations)
  }

  func updateGameConfig(
    gameId: String,
    config: GameplayConfigSnapshot,
    itemMode: ItemMode?,
    autonomousSetup: AutonomousGameSetup?
  ) async throws {
    try await base.updateGameConfig(
      gameId: gameId,
      config: config,
      itemMode: itemMode,
      autonomousSetup: autonomousSetup
    )
  }

  func setBaseToken(gameId: String, teamId: String, token: String, tokenCandidates: [String], overwriteExistingBase: Bool) async throws {
    try await base.setBaseToken(gameId: gameId, teamId: teamId, token: token, tokenCandidates: tokenCandidates, overwriteExistingBase: overwriteExistingBase)
  }

  func adminFetchRoster(gameId: String) async throws -> [AdminGameStatus.Participant] {
    try await base.adminFetchRoster(gameId: gameId)
  }

  func playerSelectOwnTeam(gameId: String, teamId: String) async throws {
    try await base.playerSelectOwnTeam(gameId: gameId, teamId: teamId)
  }

  func playerShuffleTeams(gameId: String) async throws {
    try await base.playerShuffleTeams(gameId: gameId)
  }

  func adminAssignPlayerToTeam(gameId: String, playerId: String, teamId: String?) async throws {
    try await base.adminAssignPlayerToTeam(gameId: gameId, playerId: playerId, teamId: teamId)
  }

  func adminRemovePlayerFromGame(gameId: String, playerId: String) async throws {
    try await base.adminRemovePlayerFromGame(gameId: gameId, playerId: playerId)
  }

  func adminSetTeamLeader(gameId: String, playerId: String, teamId: String) async throws {
    try await base.adminSetTeamLeader(gameId: gameId, playerId: playerId, teamId: teamId)
  }

  func adminRegisterGameItem(gameId: String, token: String?, tokenCandidates: [String], icon: String, points: Int, collectorTeamId: String?) async throws -> AdminGameStatus.GameItem {
    try await base.adminRegisterGameItem(gameId: gameId, token: token, tokenCandidates: tokenCandidates, icon: icon, points: points, collectorTeamId: collectorTeamId)
  }

  func adminAttachItemToken(gameId: String, itemId: String, token: String, tokenCandidates: [String]) async throws {
    try await base.adminAttachItemToken(gameId: gameId, itemId: itemId, token: token, tokenCandidates: tokenCandidates)
  }

  func adminFetchGameItems(gameId: String) async throws -> [AdminGameStatus.GameItem] {
    try await base.adminFetchGameItems(gameId: gameId)
  }

  func adminExportGameEvents(gameId: String, limit: Int) async throws -> AdminGameEventExport {
    try await base.adminExportGameEvents(gameId: gameId, limit: limit)
  }

  func adminLookupTag(gameId: String, token: String, tokenCandidates: [String]) async throws -> AdminGameStatus.TagLookup {
    try await base.adminLookupTag(gameId: gameId, token: token, tokenCandidates: tokenCandidates)
  }

  func adminCleanupTokenConflict(gameId: String, token: String, tokenCandidates: [String], correctType: String) async throws {
    try await base.adminCleanupTokenConflict(gameId: gameId, token: token, tokenCandidates: tokenCandidates, correctType: correctType)
  }
}
