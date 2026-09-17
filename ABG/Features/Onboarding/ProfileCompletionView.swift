import SwiftUI

struct ProfileCompletionView: View {
    @ObservedObject var viewModel: ProfileCompletionViewModel
    let onCompleted: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            SuitBackdrop(density: .full)

            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.sm) {
                    stepIndicator

                    Text("Passo \(viewModel.currentStep.rawValue + 1) di \(viewModel.totalSteps)")
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.textMuted)

                    Text("Completa il profilo prima di entrare in partita. Nome e avatar saranno visibili davvero durante il gioco.")
                        .font(AppTypography.callout)
                        .foregroundStyle(BorderlandTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.screenHorizontal)
                }
                .padding(.top, Spacing.xxl)
                .opacity(hasAppeared ? 1 : 0)
                .animation(entranceAnimation.delay(0.15), value: hasAppeared)

                Spacer()

                if viewModel.isLoadingProfile {
                    VStack(spacing: Spacing.sm) {
                        ProgressView()
                            .tint(BorderlandTheme.gold)
                        Text("Caricamento profilo…")
                            .font(AppTypography.caption)
                            .foregroundStyle(BorderlandTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                }

                currentStepView
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared || reduceMotion ? 0 : 14)
                    .animation(entranceAnimation.delay(0.35), value: hasAppeared)

                Spacer()

                HStack(spacing: Spacing.md) {
                    if viewModel.currentStep != .nickname {
                        BorderlandButton("Indietro", variant: .ghost) {
                            viewModel.goBackStep()
                        }
                    }

                    BorderlandButton(
                        primaryButtonTitle,
                        variant: .primary,
                        isEnabled: canProceed,
                        isLoading: viewModel.isSaving
                    ) {
                        if viewModel.currentStep == .review {
                            Task { await viewModel.saveProfile() }
                        } else {
                            viewModel.advanceStep()
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.xxl)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared || reduceMotion ? 0 : 16)
                .animation(entranceAnimation.delay(0.5), value: hasAppeared)
            }

            if !viewModel.errorMessage.isEmpty {
                VStack {
                    Spacer()
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
                        .background(BorderlandTheme.statusDanger.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
                                .stroke(BorderlandTheme.statusDanger.opacity(0.45), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
                        .padding(.bottom, Spacing.lg)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
            }
        }
        .borderlandBackground()
        .allowsHitTesting(!viewModel.isLoadingProfile && !viewModel.isSaving)
        .onAppear {
            hasAppeared = true
            Task { await viewModel.loadCurrentProfileIfNeeded() }
        }
        .onChange(of: viewModel.isCompleted) { _, completed in
            if completed {
                onCompleted()
            }
        }
    }

    private var entranceAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.3) : AnimationTokens.dramaticReveal
    }

    private var primaryButtonTitle: String {
        switch viewModel.currentStep {
        case .nickname:
            return "Scegli avatar"
        case .avatar:
            return "Vedi anteprima"
        case .review:
            return "Conferma profilo"
        }
    }

    private var canProceed: Bool {
        switch viewModel.currentStep {
        case .nickname:
            return viewModel.canProceedFromNickname
        case .avatar:
            return viewModel.hasChosenAvatar
        case .review:
            return viewModel.canSaveProfile
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch viewModel.currentStep {
        case .nickname:
            NicknameStepView(viewModel: viewModel)
        case .avatar:
            AvatarStepView(viewModel: viewModel)
        case .review:
            ProfileReviewStepView(viewModel: viewModel)
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: Spacing.md) {
            ForEach(ProfileCompletionViewModel.Step.allCases, id: \.rawValue) { step in
                if step.rawValue < viewModel.currentStep.rawValue {
                    ZStack {
                        Circle()
                            .fill(BorderlandTheme.gold.opacity(0.28))
                            .frame(width: 10, height: 10)
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(BorderlandTheme.gold)
                    }
                } else if step == viewModel.currentStep {
                    Circle()
                        .fill(BorderlandTheme.gold)
                        .frame(width: 12, height: 12)
                        .glowEffect(color: BorderlandTheme.goldGlow, radius: 10)
                        .scaleEffect(1.05)
                } else {
                    Circle()
                        .fill(BorderlandTheme.textDim)
                        .frame(width: 8, height: 8)
                }
            }
        }
    }
}

private struct ProfileReviewStepView: View {
    @ObservedObject var viewModel: ProfileCompletionViewModel

    var body: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.xs) {
                Text("Controlla come entrerai in partita")
                    .font(AppTypography.title2)
                    .foregroundStyle(BorderlandTheme.textPrimary)

                Text("Questa e l'anteprima finale prima di salvare il profilo.")
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .multilineTextAlignment(.center)
            }

            BorderlandPanel(title: "Anteprima battaglia") {
                HStack(spacing: Spacing.md) {
                    AvatarView(
                        avatarDataUrl: viewModel.avatarDataUrl,
                        initials: viewModel.previewInitials,
                        size: .large
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.previewNickname)
                            .font(AppTypography.title3)
                            .foregroundStyle(BorderlandTheme.textPrimary)

                        Text("Nome pubblico")
                            .font(AppTypography.caption)
                            .foregroundStyle(BorderlandTheme.gold)

                        Text("Gli altri giocatori lo leggeranno durante battaglie, roster e notifiche.")
                            .font(AppTypography.caption)
                            .foregroundStyle(BorderlandTheme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
            }

            BorderlandPanel(title: "Checklist") {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    checklistRow(
                        icon: "checkmark.seal.fill",
                        title: "Nickname confermato",
                        detail: "Usa un nome facile da riconoscere al volo: \(viewModel.previewNickname)"
                    )
                    checklistRow(
                        icon: "person.crop.circle.fill",
                        title: "Avatar pronto",
                        detail: "L'avatar verra mostrato in lobby, roster e riepiloghi."
                    )
                }
            }
        }
    }

    private func checklistRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(BorderlandTheme.gold)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundStyle(BorderlandTheme.textPrimary)

                Text(detail)
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
