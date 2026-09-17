import SwiftUI

struct ScopedGamePlayView: View {
    let gameId: String
    let gameName: String
    let gameService: GameService
    let authService: AuthService
    let nfcService: NFCService
    let canSwitchToAdmin: Bool
    let initialAutonomousSetup: AutonomousGameSetup?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer
    @State private var showControlRoom = false

    init(
        gameId: String,
        gameName: String,
        gameService: GameService,
        authService: AuthService,
        nfcService: NFCService,
        startInPlayerFlow: Bool = false,
        canSwitchToAdmin: Bool = false,
        initialAutonomousSetup: AutonomousGameSetup? = nil
    ) {
        self.gameId = gameId
        self.gameName = gameName
        self.gameService = gameService
        self.authService = authService
        self.nfcService = nfcService
        self.canSwitchToAdmin = canSwitchToAdmin
        self.initialAutonomousSetup = initialAutonomousSetup
        _ = startInPlayerFlow
    }

    var body: some View {
        PlayerHomeView(
            viewModel: PlayerViewModel(
                gameService: gameService,
                authService: authService,
                nfcService: nfcService,
                initialGameCode: gameId,
                initialAutonomousSetup: initialAutonomousSetup
            ),
            gameName: gameName,
            logoutAction: { await container.logout() },
            exitMatchAction: { dismiss() },
            switchToAdminAction: canSwitchToAdmin ? { showControlRoom = true } : nil,
            canSwitchToAdmin: canSwitchToAdmin
        )
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showControlRoom) {
            ScopedControlRoomView(
                gameId: gameId,
                gameService: gameService,
                authService: authService,
                nfcService: nfcService
            )
        }
    }
}
