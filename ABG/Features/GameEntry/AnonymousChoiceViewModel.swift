import Foundation
import Combine

@MainActor
final class AnonymousChoiceViewModel: ObservableObject {
    enum PlayMode {
        case anonymous
        case withProfile
    }

    @Published var choice: PlayMode? = nil
    @Published var isJoining = false
    @Published var errorMessage = ""

    let game: GameDefinition
    private let gameService: GameService

    init(game: GameDefinition, gameService: GameService) {
        self.game = game
        self.gameService = gameService
    }

    func joinGame(as mode: PlayMode) async {
        guard !isJoining else { return }
        isJoining = true
        errorMessage = ""

        do {
            if mode == .withProfile {
                let profile = try await gameService.fetchOwnProfile()
                let nickname = profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                if nickname.isEmpty {
                    throw NSError(domain: "choice", code: 1, userInfo: [NSLocalizedDescriptionKey: "Completa prima il profilo giocatore"])
                }
            }
            choice = mode
        } catch {
            errorMessage = error.localizedDescription
        }

        isJoining = false
    }
}
