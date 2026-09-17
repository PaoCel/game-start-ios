import Foundation
import Combine
import SwiftUI

@MainActor
final class GameSelectionViewModel: ObservableObject {
    @Published var games: [GameDefinition] = []
    @Published var nickname: String = "Giocatore"
    @Published var avatarDataUrl: String? = nil
    @Published var appearedCardIds: Set<String> = []
    @Published var emptyStateMessage: String = "Caricamento partita attiva..."

    private let authService: AuthService
    private let gameService: GameService
    private let maxNicknameLength = 24

    init(authService: AuthService, gameService: GameService) {
        self.authService = authService
        self.gameService = gameService
    }

    func onAppear() {
        if let display = sanitizedNickname(from: authService.currentUser?.displayName) {
            nickname = display
        }

        Task {
            do {
                // Niente async let sulle callable Firebase (crash Release, v. StoreHomeViewModel).
                let profile = try await gameService.fetchOwnProfile()
                let snapshot = try await gameService.fetchMatchSnapshot()

                let rawNickname = profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                if let cleanNickname = sanitizedNickname(from: rawNickname) {
                    nickname = cleanNickname
                }

                if let cleanAvatar = sanitizedAvatar(from: profile.avatarDataUrl) {
                    avatarDataUrl = cleanAvatar
                } else if isLikelyAvatarPayload(rawNickname), let recoveredAvatar = sanitizedAvatar(from: rawNickname) {
                    avatarDataUrl = recoveredAvatar
                } else {
                    avatarDataUrl = nil
                }

                if let activeGame = activeGame(from: snapshot) {
                    games = [activeGame]
                    emptyStateMessage = ""
                    animateCards()
                } else {
                    games = []
                    emptyStateMessage = "Nessuna partita attiva al momento."
                }
            } catch {
                // Keep auth fallback values.
                games = []
                emptyStateMessage = "Impossibile leggere la partita attiva."
            }
        }
    }

    private func animateCards() {
        appearedCardIds = []
        for (index, game) in games.enumerated() {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(Double(index) * 0.08 * 1_000_000_000))
                _ = withAnimation(AnimationTokens.slideUp) {
                    appearedCardIds.insert(game.id)
                }
            }
        }
    }

    private func activeGame(from snapshot: MatchSnapshot) -> GameDefinition? {
        guard !snapshot.gameId.isEmpty else {
            return nil
        }
        return GameDefinition.fromBackendCode(snapshot.gameId)
            ?? GameDefinition.activeGamePlaceholder(forBackendCode: snapshot.gameId)
    }

    private func sanitizedNickname(from rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLikelyAvatarPayload(trimmed) else { return nil }

        let collapsed = trimmed
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return String(collapsed.prefix(maxNicknameLength))
    }

    private func sanitizedAvatar(from rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard isLikelyAvatarPayload(trimmed) else { return nil }
        return trimmed
    }

    private func isLikelyAvatarPayload(_ value: String) -> Bool {
        let lower = value.lowercased()
        if lower.hasPrefix("data:image/") || lower.hasPrefix("preset://") {
            return true
        }
        if lower.hasPrefix("https://") || lower.hasPrefix("http://") {
            return true
        }
        return value.count > 180
    }
}
