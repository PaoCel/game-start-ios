import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct GameDetailView: View {
    @StateObject private var viewModel: GameDetailViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var qrCodePreview: QRCodePreview?
    @State private var openPlayerFlow = false
    @State private var showArchiveConfirmation = false
    @State private var showEndMatchConfirmation = false
    @State private var hasAppeared = false

    private let gameId: String
    private let gameService: GameService
    private let authService: AuthService
    private let nfcService: NFCService

    init(
        gameId: String,
        gameService: GameService,
        authService: AuthService,
        nfcService: NFCService
    ) {
        self.gameId = gameId
        self.gameService = gameService
        self.authService = authService
        self.nfcService = nfcService
        _viewModel = StateObject(
            wrappedValue: GameDetailViewModel(
                gameId: gameId,
                gameService: gameService,
                authService: authService
            )
        )
    }

    var body: some View {
        ZStack {
            SuitBackdrop(density: .light)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    identityCard
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared || reduceMotion ? 0 : -10)
                        .animation(entranceAnimation.delay(0.1), value: hasAppeared)

                    if let summary = viewModel.summary {
                        quickActionsGrid(summary: summary)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared || reduceMotion ? 0 : 12)
                            .animation(entranceAnimation.delay(0.25), value: hasAppeared)
                    }
                    if let summary = viewModel.summary, summary.isCurrentUserLockedGm {
                        lockedOperations(summary: summary)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared || reduceMotion ? 0 : 12)
                            .animation(entranceAnimation.delay(0.35), value: hasAppeared)
                    }
                    liveStatus
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared || reduceMotion ? 0 : 12)
                        .animation(entranceAnimation.delay(0.4), value: hasAppeared)
                    if !viewModel.errorMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        messageCard(viewModel.errorMessage, isError: true)
                    }
                    if !viewModel.infoMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        messageCard(viewModel.infoMessage, isError: false)
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.lg)
            }
        }
        .borderlandBackground()
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hasAppeared = true
        }
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
        .navigationDestination(isPresented: $openPlayerFlow) {
            ScopedGamePlayView(
                gameId: gameId,
                gameName: viewModel.title,
                gameService: gameService,
                authService: authService,
                nfcService: nfcService,
                startInPlayerFlow: true,
                canSwitchToAdmin: viewModel.summary?.canManageSensitive == true,
                initialAutonomousSetup: viewModel.summary?.autonomousSetup
            )
        }
        .sheet(item: $qrCodePreview) { preview in
            QRCodeSheet(title: preview.title, subtitle: preview.subtitle, token: preview.token)
        }
    }

    private var entranceAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.3) : AnimationTokens.dramaticReveal
    }

    private var identityCard: some View {
        BorderlandCard(variant: .elevated) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(viewModel.title)
                    .font(AppTypography.title2)
                    .foregroundStyle(BorderlandTheme.gold)
                Text(viewModel.gameDefinitionName)
                    .font(AppTypography.caption)
                    .foregroundStyle(BorderlandTheme.textMuted)
                HStack(spacing: Spacing.xs) {
                    detailPill(viewModel.summary?.roleLabel ?? "Partita")
                    detailPill(viewModel.summary?.stateLabel ?? snapshotState)
                    if let summary = viewModel.summary {
                        detailPill(summary.itemMode.displayLabel)
                    }
                }
            }
        }
    }

    private func quickActionsGrid(summary: GameAccessSummary) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 158), spacing: Spacing.md)],
            spacing: Spacing.md
        ) {
            if let joinCode = summary.joinCode, !joinCode.isEmpty {
                inviteCard(
                    title: "Codice player",
                    value: joinCode,
                    helper: "Condividi landing iOS e codice player della partita.",
                    url: viewModel.inviteURL(for: joinCode, kind: .player),
                    shareText: viewModel.inviteShareText(for: joinCode, kind: .player),
                    onShowQRCode: {
                        qrCodePreview = viewModel.inviteQRCodePreview(for: joinCode, kind: .player)
                    }
                )
            }

            if let operatorCode = summary.operatorInviteCode, !operatorCode.isEmpty {
                inviteCard(
                    title: "Codice operatore",
                    value: operatorCode,
                    helper: "Condividi landing iOS e codice operatore della stessa partita.",
                    url: viewModel.inviteURL(for: operatorCode, kind: .operator),
                    shareText: viewModel.inviteShareText(for: operatorCode, kind: .operator),
                    onShowQRCode: {
                        qrCodePreview = viewModel.inviteQRCodePreview(for: operatorCode, kind: .operator)
                    }
                )
            }

            if viewModel.canOpenPlayerFlow {
                NavigationLink {
                    ScopedGamePlayView(
                        gameId: gameId,
                        gameName: viewModel.title,
                        gameService: gameService,
                        authService: authService,
                        nfcService: nfcService,
                        startInPlayerFlow: true,
                        canSwitchToAdmin: summary.canManageSensitive,
                        initialAutonomousSetup: summary.autonomousSetup
                    )
                } label: {
                    shortcutCard(
                        title: "Apri partita",
                        subtitle: "Vai subito alla schermata di gioco.",
                        systemImage: "play.fill"
                    )
                }
                .buttonStyle(.plain)
            } else if viewModel.canJoinAsLockedGameMaster || summary.role == .player {
                Button {
                    HapticManager.lightTap()
                    Task {
                        if await viewModel.joinAsPlayer() {
                            openPlayerFlow = true
                        }
                    }
                } label: {
                    shortcutCard(
                        title: viewModel.canJoinAsLockedGameMaster ? "Entra come creator" : "Entra come player",
                        subtitle: viewModel.canJoinAsLockedGameMaster
                            ? "Condividi il codice e poi entra in lobby senza perdere i controlli creator."
                            : "Vai direttamente nella schermata di gioco.",
                        systemImage: viewModel.canJoinAsLockedGameMaster ? "lock.fill" : "person.fill"
                    )
                }
                .buttonStyle(PressableStyle())
                .disabled(viewModel.isPerformingAction)
            }

            if summary.canManageSensitive {
                NavigationLink {
                    ScopedControlRoomView(
                        gameId: gameId,
                        gameService: gameService,
                        authService: authService,
                        nfcService: nfcService
                    )
                } label: {
                    shortcutCard(
                        title: "Control room",
                        subtitle: "Apri regia, team, basi e configurazione.",
                        systemImage: "slider.horizontal.3"
                    )
                }
                .buttonStyle(.plain)
            }

            if viewModel.canArchiveGame {
                Button {
                    HapticManager.lightTap()
                    showArchiveConfirmation = true
                } label: {
                    shortcutCard(
                        title: "Archivia partita",
                        subtitle: "Rimuove la partita dall'elenco attivo.",
                        systemImage: "archivebox.fill",
                        tint: BorderlandTheme.crimson
                    )
                }
                .buttonStyle(PressableStyle())
                .disabled(viewModel.isPerformingAction)
                .confirmationDialog(
                    "Archiviare la partita?",
                    isPresented: $showArchiveConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Archivia", role: .destructive) {
                        Task { await viewModel.archiveGame() }
                    }
                    Button("Annulla", role: .cancel) {}
                } message: {
                    Text("La partita sparirà dall'elenco attivo per tutti.")
                }
            }

            if summary.role == .owner, viewModel.adminStatus != nil {
                Button {
                    HapticManager.lightTap()
                    Task { await viewModel.reuseGame() }
                } label: {
                    shortcutCard(
                        title: "Riusa configurazione",
                        subtitle: "Crea una nuova partita con setup gia pronto.",
                        systemImage: "arrow.trianglehead.2.clockwise.rotate.90"
                    )
                }
                .buttonStyle(PressableStyle())
                .disabled(viewModel.isPerformingAction)
            }
        }
    }

    private func lockedOperations(summary: GameAccessSummary) -> some View {
        BorderlandCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("GM-player lock")
                    .font(AppTypography.title3)
                    .foregroundStyle(BorderlandTheme.gold)
                Text("Hai ancora solo i controlli minimi: distribuzione, live, pausa emergenza e fine partita.")
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textMuted)

                if summary.state.uppercased() == "LOBBY" {
                    BorderlandButton("Vai in distribuzione", variant: .secondary, isEnabled: !viewModel.isPerformingAction) {
                        Task { await viewModel.transitionToDistribution() }
                    }
                }
                if summary.state.uppercased() == "DISTRIBUTION" {
                    BorderlandButton("Porta in live", variant: .primary, isEnabled: !viewModel.isPerformingAction) {
                        Task { await viewModel.startMatch() }
                    }
                }
                if summary.state.uppercased() == "LIVE" {
                    BorderlandButton("Pausa emergenza", variant: .secondary, isEnabled: !viewModel.isPerformingAction) {
                        Task { await viewModel.pauseMatch() }
                    }
                }
                if summary.state.uppercased() == "PAUSED" {
                    BorderlandButton("Riprendi live", variant: .secondary, isEnabled: !viewModel.isPerformingAction) {
                        Task { await viewModel.resumeMatch() }
                    }
                }
                if summary.state.uppercased() == "LIVE" || summary.state.uppercased() == "PAUSED" || summary.state.uppercased() == "DISTRIBUTION" {
                    BorderlandButton("Termina partita", variant: .ghost, isEnabled: !viewModel.isPerformingAction) {
                        showEndMatchConfirmation = true
                    }
                    .confirmationDialog(
                        "Terminare la partita?",
                        isPresented: $showEndMatchConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Termina per tutti", role: .destructive) {
                            Task { await viewModel.endMatch() }
                        }
                        Button("Annulla", role: .cancel) {}
                    } message: {
                        Text("La partita finirà per tutti i giocatori. L'azione è irreversibile.")
                    }
                }
            }
        }
    }

    private var liveStatus: some View {
        BorderlandCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Stato pubblico")
                    .font(AppTypography.title3)
                    .foregroundStyle(BorderlandTheme.gold)
                Text("Fase: \(snapshotState)")
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textPrimary)
                if viewModel.snapshot.liveEndsAtMs != nil {
                    Text("Timer residuo: \(viewModel.snapshot.remainingSec)s")
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.textMuted)
                }
                if let summary = viewModel.summary, let note = summary.recommendedItemModeNote {
                    Text(note)
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.statusDangerText)
                }
            }
        }
    }

    private func inviteCard(
        title: String,
        value: String,
        helper: String,
        url: URL?,
        shareText: String,
        onShowQRCode: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundStyle(BorderlandTheme.textPrimary)
                Spacer(minLength: 8)
                HStack(spacing: Spacing.xs) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(BorderlandTheme.gold)
                            .frame(width: 44, height: 44)
                    }
                    Button {
                        HapticManager.lightTap()
                        onShowQRCode()
                    } label: {
                        Image(systemName: "qrcode")
                            .foregroundStyle(BorderlandTheme.textPrimary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(PressableStyle())
                    Button {
                        HapticManager.lightTap()
                        #if canImport(UIKit)
                        UIPasteboard.general.string = value
                        #endif
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(BorderlandTheme.textMuted)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            Text(value)
                .font(AppTypography.title3)
                .foregroundStyle(BorderlandTheme.gold)
                .textSelection(.enabled)

            if let url {
                Text(url.absoluteString)
                    .font(AppTypography.caption2)
                    .foregroundStyle(BorderlandTheme.textDim)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }

            Text(helper)
                .font(AppTypography.caption)
                .foregroundStyle(BorderlandTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
        .background(BorderlandTheme.surface2.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
                .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func shortcutCard(title: String, subtitle: String, systemImage: String, tint: Color = BorderlandTheme.gold) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)

            Text(title)
                .font(AppTypography.headline)
                .foregroundStyle(BorderlandTheme.textPrimary)

            Text(subtitle)
                .font(AppTypography.caption)
                .foregroundStyle(BorderlandTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
        .background(BorderlandTheme.surface2.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
                .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func detailPill(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.caption2)
            .foregroundStyle(BorderlandTheme.gold)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(BorderlandTheme.surface3)
            .clipShape(Capsule())
    }

    private func messageCard(_ message: String, isError: Bool) -> some View {
        let tint = isError ? BorderlandTheme.statusDangerText : BorderlandTheme.statusOkText
        let background = isError ? BorderlandTheme.statusDanger.opacity(0.12) : BorderlandTheme.statusOk.opacity(0.12)
        let icon = isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"

        return HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(message)
                .font(AppTypography.caption)
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.md)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
    }

    private var snapshotState: String {
        let raw = viewModel.snapshot.state.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "N/A" : raw
    }
}
