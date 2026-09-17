import SwiftUI

struct RootView: View {
    @EnvironmentObject private var container: AppContainer

    @State private var showSplash = true
    @State private var hasBootstrapped = false
    @State private var showHubProfileEditor = false

    var body: some View {
        ZStack {
            mainContent

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            guard !hasBootstrapped else { return }
            hasBootstrapped = true

            await container.bootstrap()

            withAnimation(.easeOut(duration: 0.4)) {
                showSplash = false
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if !container.isAuthenticated {
            LoginView(
                viewModel: AuthViewModel(authService: container.authService) { role in
                    container.didSignIn(as: role)
                }
            )
        } else if container.isResolvingProfileGate {
            ZStack {
                FloatingParticles()

                VStack(spacing: Spacing.md) {
                    ProgressView()
                        .tint(BorderlandTheme.gold)
                        .scaleEffect(1.15)
                    Text("Prepariamo il tuo profilo…")
                        .font(AppTypography.callout)
                        .foregroundStyle(BorderlandTheme.textMuted)
                }
                .padding(Spacing.xl)
                .background(BorderlandTheme.surface2.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                        .stroke(BorderlandTheme.borderGold, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous))
                .padding(.horizontal, Spacing.screenHorizontal)
            }
            .borderlandBackground()
        } else if container.needsProfileCompletion {
            ProfileCompletionView(
                viewModel: ProfileCompletionViewModel(gameService: container.gameService)
            ) {
                container.didCompleteProfile()
            }
        } else if let selectedGame = container.selectedGameDefinition {
            StoreHomeView(
                gameService: container.gameService,
                authService: container.authService,
                nfcService: container.nfcService,
                logoutAction: { await container.logout() },
                selectedGame: selectedGame,
                onChangeGame: {
                    withAnimation(AnimationTokens.standard) {
                        container.selectedGameDefinitionId = nil
                    }
                }
            )
            .transition(.opacity)
        } else {
            GameHubView(
                displayName: hubDisplayName,
                onSelect: { game in
                    withAnimation(AnimationTokens.standard) {
                        container.selectedGameDefinitionId = game.id
                    }
                },
                onOpenSettings: { showHubProfileEditor = true },
                onLogout: { await container.logout() }
            )
            .transition(.opacity)
            // Un invito arrivato da link/QR non deve restare bloccato dietro la
            // scelta del gioco: si entra dritti nel gioco disponibile.
            .onAppear { autoSelectGameForPendingInvite() }
            .onChange(of: container.pendingInvite) { _, _ in
                autoSelectGameForPendingInvite()
            }
            .sheet(isPresented: $showHubProfileEditor) {
                ProfileEditorSheet(
                    gameService: container.gameService,
                    canDeleteAccount: !(container.authService.currentUser?.isGuest ?? false),
                    onSaved: {},
                    onDeleteAccount: {
                        try await container.deleteAccount()
                    }
                )
            }
        }
    }

    private func autoSelectGameForPendingInvite() {
        guard container.pendingInvite != nil,
              container.selectedGameDefinitionId == nil,
              let game = GameDefinition.allGames.first(where: \.isAvailable) else { return }
        container.selectedGameDefinitionId = game.id
    }

    private var hubDisplayName: String {
        let raw = container.authService.currentUser?.displayName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty, raw.count <= 24, !raw.contains("://") else { return "" }
        return raw
    }
}
