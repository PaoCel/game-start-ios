import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @EnvironmentObject private var container: AppContainer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hasAppeared = false
    @State private var showAuthSheet = false

    var body: some View {
        ZStack {
            SuitBackdrop()

            ScrollView {
                VStack(spacing: 0) {
                    heroLogo
                        .padding(.top, Spacing.xl)

                    Text("Il party game dal vivo\ndi strategia, azione e carte.")
                        .font(AppTypography.callout)
                        .foregroundStyle(BorderlandTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.top, Spacing.lg)
                        .opacity(hasAppeared ? 1 : 0)
                        .animation(entranceAnimation.delay(0.55), value: hasAppeared)

                    featureRow
                        .padding(.top, Spacing.xl)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared || reduceMotion ? 0 : 12)
                        .animation(entranceAnimation.delay(0.7), value: hasAppeared)

                    startButton
                        .padding(.top, Spacing.xl)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared || reduceMotion ? 0 : 16)
                        .animation(entranceAnimation.delay(0.85), value: hasAppeared)
                        .frame(maxWidth: 460)

                    Text("Accedi con Apple, Google o entra come ospite.")
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.textDim)
                        .multilineTextAlignment(.center)
                        .padding(.top, Spacing.md)
                        .opacity(hasAppeared ? 1 : 0)
                        .animation(entranceAnimation.delay(0.95), value: hasAppeared)

                    Text("Borderland Games")
                        .font(AppTypography.caption2)
                        .foregroundStyle(BorderlandTheme.textDim)
                        .padding(.top, Spacing.xl)
                        .padding(.bottom, Spacing.lg)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .frame(maxWidth: .infinity)
            }
        }
        .borderlandBackground()
        .onAppear {
            hasAppeared = true
        }
        .sheet(isPresented: $showAuthSheet) {
            authSheet
                .presentationDetents([.height(viewModel.errorMessage.isEmpty ? 360 : 440)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(BorderlandTheme.surface1)
        }
    }

    private var entranceAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.3) : AnimationTokens.dramaticReveal
    }

    // MARK: - Hero

    private var heroLogo: some View {
        VStack(spacing: Spacing.md) {
            Image("LogoCard")
                .resizable()
                .scaledToFit()
                .frame(height: 200)
                .opacity(hasAppeared ? 1 : 0)
                .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.85)
                .rotationEffect(.degrees(hasAppeared || reduceMotion ? 0 : -5))
                .animation(entranceAnimation, value: hasAppeared)

            VStack(spacing: Spacing.xs) {
                Image("LogoGame")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 46)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared || reduceMotion ? 0 : 14)
                    .animation(entranceAnimation.delay(0.25), value: hasAppeared)

                Image("LogoStart")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 26)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared || reduceMotion ? 0 : 10)
                    .animation(entranceAnimation.delay(0.4), value: hasAppeared)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Game Start!")
    }

    // MARK: - Feature row

    private var featureRow: some View {
        HStack(spacing: Spacing.sm) {
            featureCard(
                icon: "person.2.fill",
                iconTint: BorderlandTheme.crimson,
                title: "Gioca in squadra",
                caption: "Collabora, colpisci, cattura."
            )
            featureCard(
                icon: "dot.radiowaves.right",
                iconTint: BorderlandTheme.gold,
                title: "NFC & QR",
                caption: "Scansiona i braccialetti o usa il QR."
            )
            featureCard(
                icon: "suit.spade.fill",
                iconTint: BorderlandTheme.textPrimary,
                title: "La tua identità",
                caption: "Scegli carta e avatar."
            )
        }
    }

    private func featureCard(
        icon: String,
        iconTint: Color,
        title: String,
        caption: String
    ) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(iconTint)
                .frame(height: 34)

            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(BorderlandTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(caption)
                .font(AppTypography.caption2)
                .foregroundStyle(BorderlandTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .top)
        .background(BorderlandTheme.surface2.opacity(0.65))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
                .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - CTA

    private var startButton: some View {
        Button {
            HapticManager.lightTap()
            viewModel.errorMessage = ""
            showAuthSheet = true
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("INIZIA A GIOCARE")
                        .font(AppTypography.headline)
                        .tracking(1.4)
                        .foregroundStyle(.white)
                    Text("Scegli il gioco dopo l'accesso")
                        .font(AppTypography.caption)
                        .foregroundStyle(.white.opacity(0.82))
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                LinearGradient(
                    colors: [BorderlandTheme.crimson, BorderlandTheme.crimson.opacity(0.75)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                    .stroke(BorderlandTheme.crimson.opacity(0.6), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous))
            .shadow(color: BorderlandTheme.crimsonGlow, radius: 18, y: 6)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Auth sheet

    private var authSheet: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(BorderlandTheme.borderSubtle)
                .frame(width: 38, height: 4)
                .padding(.top, Spacing.sm)

            VStack(spacing: Spacing.xxs) {
                Text("Accedi")
                    .font(AppTypography.title2)
                    .foregroundStyle(BorderlandTheme.gold)

                Text("Ti serve solo un secondo: il profilo ti segue in ogni partita.")
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, Spacing.lg)
            .padding(.horizontal, Spacing.sm)

            VStack(spacing: Spacing.sm) {
                SocialSignInButton(
                    provider: .apple,
                    title: "Continua con Apple",
                    isLoading: viewModel.isLoading
                ) {
                    HapticManager.lightTap()
                    viewModel.signInWithApple()
                }

                SocialSignInButton(
                    provider: .google,
                    title: "Continua con Google",
                    isLoading: viewModel.isLoading
                ) {
                    HapticManager.lightTap()
                    viewModel.signInWithGoogle()
                }

                HStack(spacing: Spacing.sm) {
                    Rectangle()
                        .fill(BorderlandTheme.borderSubtle)
                        .frame(height: 1)
                    Text("oppure")
                        .font(AppTypography.caption2)
                        .foregroundStyle(BorderlandTheme.textDim)
                    Rectangle()
                        .fill(BorderlandTheme.borderSubtle)
                        .frame(height: 1)
                }
                .padding(.vertical, Spacing.xxs)

                SocialSignInButton(
                    provider: .guest,
                    title: "Entra come ospite",
                    isLoading: viewModel.isLoading
                ) {
                    HapticManager.lightTap()
                    viewModel.signInAsGuest()
                }
            }
            .padding(.top, Spacing.lg)

            if viewModel.errorMessage.isEmpty {
                Text("L'ospite può entrare in partita ma non crearne.")
                    .font(AppTypography.caption2)
                    .foregroundStyle(BorderlandTheme.textDim)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.md)
            } else {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(BorderlandTheme.statusDangerText)
                    Text(viewModel.errorMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.statusDangerText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Spacing.md)
                .background(BorderlandTheme.statusDanger.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
                .padding(.top, Spacing.md)
            }

            Spacer(minLength: Spacing.sm)
        }
        .padding(.horizontal, Spacing.screenHorizontal)
    }
}
