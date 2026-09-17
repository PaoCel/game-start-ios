import SwiftUI

struct AnonymousChoiceView: View {
    @StateObject private var viewModel: AnonymousChoiceViewModel

    let nickname: String
    let avatarDataUrl: String?
    let isGuestSession: Bool
    let onJoined: (AnonymousChoiceViewModel.PlayMode) -> Void
    let onRequireAuthentication: () -> Void

    @State private var hasAppeared = false
    @State private var showAuthPrompt = false

    init(
        game: GameDefinition,
        gameService: GameService,
        nickname: String,
        avatarDataUrl: String?,
        isGuestSession: Bool,
        onRequireAuthentication: @escaping () -> Void,
        onJoined: @escaping (AnonymousChoiceViewModel.PlayMode) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: AnonymousChoiceViewModel(game: game, gameService: gameService))
        self.nickname = nickname
        self.avatarDataUrl = avatarDataUrl
        self.isGuestSession = isGuestSession
        self.onRequireAuthentication = onRequireAuthentication
        self.onJoined = onJoined
    }

    var body: some View {
        ZStack {
            SuitBackdrop(density: .full)

            BorderlandTheme.focalGlow
                .ignoresSafeArea()

            VStack(spacing: Spacing.xxl) {
                VStack(spacing: Spacing.xs) {
                    Text("Come vuoi giocare?")
                        .font(AppTypography.title2)
                        .foregroundStyle(BorderlandTheme.textPrimary)
                    Text(viewModel.game.name)
                        .font(AppTypography.callout)
                        .foregroundStyle(BorderlandTheme.gold)
                }
                .opacity(hasAppeared ? 1 : 0)
                .animation(AnimationTokens.smooth.delay(0.2), value: hasAppeared)

                HStack(spacing: Spacing.lg) {
                    optionCard(mode: .anonymous)
                        .offset(x: hasAppeared ? 0 : -30)
                    optionCard(mode: .withProfile)
                        .offset(x: hasAppeared ? 0 : 30)
                }
                .animation(AnimationTokens.slideUp, value: hasAppeared)

                BorderlandButton(
                    "Entra nel gioco",
                    variant: .primary,
                    isEnabled: viewModel.choice != nil,
                    isLoading: viewModel.isJoining
                ) {
                    guard let choice = viewModel.choice else { return }
                    if isGuestSession && choice == .withProfile {
                        showAuthPrompt = true
                        return
                    }
                    Task {
                        await viewModel.joinGame(as: choice)
                        if viewModel.errorMessage.isEmpty {
                            onJoined(choice)
                        }
                    }
                }

                if !viewModel.errorMessage.isEmpty {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(BorderlandTheme.statusDangerText)
                        Text(viewModel.errorMessage)
                            .font(AppTypography.callout)
                            .foregroundStyle(BorderlandTheme.statusDangerText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(BorderlandTheme.statusDanger.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
        }
        .borderlandBackground()
        .onAppear {
            hasAppeared = true
        }
        .alert("Accesso con profilo", isPresented: $showAuthPrompt) {
            Button("Vai al login") {
                onRequireAuthentication()
            }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Per partecipare con un profilo personale devi fare login o registrazione.")
        }
    }

    private func optionCard(mode: AnonymousChoiceViewModel.PlayMode) -> some View {
        let isSelected = viewModel.choice == mode
        let isOtherSelected = viewModel.choice != nil && !isSelected

        return Button {
            HapticManager.lightTap()
            withAnimation(AnimationTokens.standard) {
                viewModel.choice = mode
            }
        } label: {
            BorderlandCard {
                VStack(spacing: Spacing.md) {
                    if mode == .anonymous {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(BorderlandTheme.violet)
                        Text("Anonimo")
                            .font(AppTypography.headline)
                            .foregroundStyle(BorderlandTheme.textPrimary)
                        Text("Nessuno vedra chi sei")
                            .font(AppTypography.caption)
                            .foregroundStyle(BorderlandTheme.textMuted)
                    } else {
                        AvatarView(avatarDataUrl: avatarDataUrl, initials: initials(from: nickname), size: .medium)
                        Text("Con Profilo")
                            .font(AppTypography.headline)
                            .foregroundStyle(BorderlandTheme.textPrimary)
                        Text(nickname)
                            .font(AppTypography.caption)
                            .foregroundStyle(BorderlandTheme.gold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
            }
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                    .stroke(isSelected ? (mode == .anonymous ? BorderlandTheme.borderCrimson : BorderlandTheme.borderGold) : BorderlandTheme.borderSubtle, lineWidth: isSelected ? 2 : 1)
            )
            .glowEffect(
                color: isSelected ? (mode == .anonymous ? BorderlandTheme.violetGlow : BorderlandTheme.goldGlow) : .clear,
                radius: 16
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .opacity(isOtherSelected ? 0.5 : 1.0)
        }
        .buttonStyle(PressableStyle())
        .frame(width: 160)
    }

    private func initials(from value: String) -> String {
        let parts = value.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}
