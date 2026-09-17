import Foundation
import Combine

#if canImport(UIKit)
import SwiftUI
import UIKit
#endif

@MainActor
final class ProfileCompletionViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case nickname = 0
        case avatar = 1
        case review = 2
    }

    @Published var currentStep: Step = .nickname
    @Published var nickname: String = ""
    @Published var avatarDataUrl: String? = nil
    @Published var selectedPresetSymbol: String? = nil
    @Published var isLoadingProfile: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String = ""
    @Published var isCompleted: Bool = false

    private let gameService: GameService
    private let maxNicknameLength = 20

    init(gameService: GameService) {
        self.gameService = gameService
    }

    var totalSteps: Int {
        Step.allCases.count
    }

    var normalizedNickname: String {
        sanitizeNickname(nickname)
    }

    var previewNickname: String {
        let value = normalizedNickname
        return value.isEmpty ? "Giocatore" : value
    }

    var previewInitials: String {
        initials(from: previewNickname)
    }

    var canProceedFromNickname: Bool {
        normalizedNickname.count >= 2
    }

    var hasChosenAvatar: Bool {
        normalizedAvatarDataURL(from: avatarDataUrl) != nil
    }

    var canSaveProfile: Bool {
        canProceedFromNickname && hasChosenAvatar
    }

    func loadCurrentProfileIfNeeded() async {
        guard nickname.isEmpty else { return }
        isLoadingProfile = true
        defer { isLoadingProfile = false }
        do {
            let profile = try await gameService.fetchOwnProfile()
            nickname = sanitizeNickname(profile.nickname)
            avatarDataUrl = normalizedAvatarDataURL(from: profile.avatarDataUrl)
            selectedPresetSymbol = nil
        } catch {
            // Allow manual completion even when profile fetch fails.
        }
    }

    func advanceStep() {
        switch currentStep {
        case .nickname:
            guard canProceedFromNickname else { return }
            currentStep = .avatar
        case .avatar:
            guard hasChosenAvatar else { return }
            currentStep = .review
        case .review:
            break
        }
    }

    func goBackStep() {
        switch currentStep {
        case .nickname:
            break
        case .avatar:
            currentStep = .nickname
        case .review:
            currentStep = .avatar
        }
    }

    func selectPresetAvatar(symbol: String) {
        #if canImport(UIKit)
        guard let encoded = makePresetAvatarDataURL(symbol: symbol) else {
            errorMessage = "Impossibile preparare l'avatar selezionato."
            return
        }
        selectedPresetSymbol = symbol
        avatarDataUrl = encoded
        errorMessage = ""
        #else
        _ = symbol
        #endif
    }

    func setPickedAvatarDataURL(_ value: String?) {
        avatarDataUrl = normalizedAvatarDataURL(from: value)
        selectedPresetSymbol = nil
        errorMessage = ""
    }

    func saveProfile() async {
        guard !isSaving else { return }
        guard canProceedFromNickname else {
            errorMessage = "Inserisci almeno 2 caratteri per il nickname."
            return
        }
        guard hasChosenAvatar else {
            errorMessage = "Scegli un avatar prima di completare il profilo."
            currentStep = .avatar
            return
        }

        isSaving = true
        errorMessage = ""

        do {
            var profile = try await gameService.fetchOwnProfile()
            profile.nickname = normalizedNickname
            profile.avatarDataUrl = normalizedAvatarDataURL(from: avatarDataUrl)
            profile.profileCompleted = true
            try await gameService.savePlayerProfile(profile)
            isCompleted = true
        } catch {
            errorMessage = "Errore salvataggio: \(error.localizedDescription)"
        }

        isSaving = false
    }

    private func sanitizeNickname(_ value: String) -> String {
        let chunks = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let collapsed = chunks.joined(separator: " ")
        return String(collapsed.prefix(maxNicknameLength))
    }

    private func normalizedAvatarDataURL(from value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func initials(from value: String) -> String {
        let result = value
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()
        return result.isEmpty ? "?" : result
    }

    #if canImport(UIKit)
    private func makePresetAvatarDataURL(symbol: String) -> String? {
        let canvasSize = CGSize(width: 280, height: 280)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let image = renderer.image { _ in
            let rect = CGRect(origin: .zero, size: canvasSize)
            let insetRect = rect.insetBy(dx: 12, dy: 12)

            UIColor(BorderlandTheme.surface3).setFill()
            UIBezierPath(ovalIn: insetRect).fill()

            UIColor(BorderlandTheme.borderGold).setStroke()
            let outline = UIBezierPath(ovalIn: insetRect)
            outline.lineWidth = 6
            outline.stroke()

            let configuration = UIImage.SymbolConfiguration(pointSize: 122, weight: .semibold)
            let tinted = UIImage(systemName: symbol, withConfiguration: configuration)?
                .withTintColor(UIColor(BorderlandTheme.gold), renderingMode: .alwaysOriginal)

            let symbolSize = CGSize(width: 132, height: 132)
            let symbolOrigin = CGPoint(
                x: (canvasSize.width - symbolSize.width) / 2,
                y: (canvasSize.height - symbolSize.height) / 2
            )
            tinted?.draw(in: CGRect(origin: symbolOrigin, size: symbolSize))
        }

        guard let pngData = image.pngData() else { return nil }
        return "data:image/png;base64,\(pngData.base64EncodedString())"
    }
    #endif

    static let minimalAvatarDataURL =
        "data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="
}
