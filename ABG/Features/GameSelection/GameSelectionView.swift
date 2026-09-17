import SwiftUI

struct GameSelectionView: View {
    let selectedGameId: String?
    let gameService: GameService
    let onSelectGame: (String) -> Void
    let onLogout: () async -> Void

    @StateObject private var viewModel: GameSelectionViewModel
    @State private var showProfileEditor = false

    init(
        selectedGameId: String?,
        gameService: GameService,
        authService: AuthService,
        onSelectGame: @escaping (String) -> Void,
        onLogout: @escaping () async -> Void
    ) {
        self.selectedGameId = selectedGameId
        self.gameService = gameService
        self.onSelectGame = onSelectGame
        self.onLogout = onLogout
        _viewModel = StateObject(wrappedValue: GameSelectionViewModel(authService: authService, gameService: gameService))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SuitBackdrop(density: .full)
                FloatingParticles()

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        header

                        Text("PARTITA ATTIVA")
                            .font(AppTypography.title3)
                            .foregroundStyle(BorderlandTheme.gold)
                            .tracking(1)

                        if viewModel.games.isEmpty {
                            BorderlandCard {
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    Text("Nessuna partita pronta")
                                        .font(AppTypography.headline)
                                        .foregroundStyle(BorderlandTheme.textPrimary)
                                    Text(viewModel.emptyStateMessage)
                                        .font(AppTypography.callout)
                                        .foregroundStyle(BorderlandTheme.textMuted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible())], spacing: Spacing.lg) {
                                ForEach(viewModel.games) { game in
                                    Button {
                                        guard game.isAvailable else { return }
                                        HapticManager.lightTap()
                                        onSelectGame(game.backendCode)
                                    } label: {
                                        GameCardCell(game: game, isVisible: viewModel.appearedCardIds.contains(game.id))
                                    }
                                    .buttonStyle(PressableStyle())
                                    .disabled(!game.isAvailable)
                                }
                            }
                        }

                        BorderlandCard {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text("Ingresso rapido")
                                    .font(AppTypography.headline)
                                    .foregroundStyle(BorderlandTheme.textPrimary)
                                infoRow(icon: "bolt.fill", text: "L'app legge la partita attiva dal backend")
                                infoRow(icon: "person.crop.square", text: "Completa solo nickname e avatar")
                                infoRow(icon: "rectangle.inset.filled.and.person.filled", text: "La tua carta viene assegnata automaticamente al join")
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.vertical, Spacing.lg)
                }
            }
            .borderlandBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Logout") {
                        Task { await onLogout() }
                    }
                    .foregroundStyle(BorderlandTheme.gold)
                }
            }
            .onAppear {
                viewModel.onAppear()
            }
            .sheet(isPresented: $showProfileEditor) {
                ProfileEditorSheet(gameService: gameService) {
                    viewModel.onAppear()
                }
                .presentationDetents([.large])
                .presentationBackground(BorderlandTheme.surface1)
            }
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            AvatarView(
                avatarDataUrl: viewModel.avatarDataUrl,
                initials: initials(from: viewModel.nickname),
                size: .small
            )
            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text("Ciao, \(viewModel.nickname)")
                    .font(AppTypography.headline)
                    .foregroundStyle(BorderlandTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .truncationMode(.tail)
                Text("Apri la partita attiva")
                    .font(AppTypography.caption)
                    .foregroundStyle(BorderlandTheme.textMuted)
            }
            Spacer()
            Button {
                HapticManager.lightTap()
                showProfileEditor = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PressableStyle())
        }
        .padding(Spacing.md)
        .background(BorderlandTheme.surface1.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                .stroke(selectedGameId == nil ? BorderlandTheme.borderSubtle : BorderlandTheme.borderGold, lineWidth: 1)
        )
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BorderlandTheme.gold)
                .frame(width: 20)
            Text(text)
                .font(AppTypography.callout)
                .foregroundStyle(BorderlandTheme.textMuted)
        }
    }

    private func initials(from value: String) -> String {
        let chunks = value.split(separator: " ").prefix(2)
        return chunks.compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}
