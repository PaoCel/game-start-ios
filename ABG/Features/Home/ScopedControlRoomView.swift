import SwiftUI

struct ScopedControlRoomView: View {
    let gameId: String
    let gameService: GameService
    let authService: AuthService
    let nfcService: NFCService

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        AdminHomeView(
            viewModel: AdminViewModel(
                gameService: gameService,
                authService: authService,
                nfcService: nfcService
            ),
            logoutAction: { await container.logout() },
            switchToPlayerAction: nil,
            backAction: { dismiss() },
            initialGameId: gameId
        )
        .navigationBarBackButtonHidden(true)
    }
}
