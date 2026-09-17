import SwiftUI

struct PlayerHomeView: View {
    @StateObject private var viewModel: PlayerViewModel
    let gameName: String?
    let logoutAction: () async -> Void
    let exitMatchAction: (() -> Void)?
    let switchToAdminAction: (() -> Void)?
    let canSwitchToAdmin: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showScoreboardSheet = false
    @State private var showBaseDetailSheet = false
    @State private var showQRCodeScanner = false
    @State private var showRulesSheet = false
    @State private var impactBanner: ImpactBanner?
    @State private var impactTask: Task<Void, Never>?
    @State private var hasAppeared = false

    init(
        viewModel: PlayerViewModel,
        gameName: String? = nil,
        logoutAction: @escaping () async -> Void,
        exitMatchAction: (() -> Void)? = nil,
        switchToAdminAction: (() -> Void)? = nil,
        canSwitchToAdmin: Bool = false
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.gameName = gameName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.logoutAction = logoutAction
        self.exitMatchAction = exitMatchAction
        self.switchToAdminAction = switchToAdminAction
        self.canSwitchToAdmin = canSwitchToAdmin
    }

    var body: some View {
        GeometryReader { geo in
            let hudState = viewModel.gameplayHUDState

            ZStack(alignment: .top) {
                PlayerGameplayBackground(state: hudState)
                SuitBackdrop(density: .light)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: contentSpacing(for: geo.size.height)) {
                        PlayerGameplayHeader(
                            remainingSec: viewModel.snapshot.remainingSec,
                            matchLabel: viewModel.snapshot.state.uppercased(),
                            phaseLabel: viewModel.battleStateTitle.uppercased(),
                            phaseTint: hudState.signal.headerTint,
                            identityLabel: headerIdentity,
                            supportText: headerSupportText
                        )
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared || reduceMotion ? 0 : 10)
                        .animation(entranceAnimation.delay(0.15), value: hasAppeared)

                        if shouldShowBraceletQuickAccess {
                            braceletQuickAccessPanel
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(y: hasAppeared || reduceMotion ? 0 : 12)
                                .animation(entranceAnimation.delay(0.25), value: hasAppeared)
                        }

                        Group {
                            if viewModel.isPreMatchPhase {
                                PlayerPreMatchLobbyView(
                                    viewModel: viewModel,
                                    canSwitchToAdmin: canSwitchToAdmin,
                                    switchToAdminAction: switchToAdminAction
                                )
                                .frame(maxWidth: .infinity)
                            } else {
                                PlayerActionSurface(
                                    state: hudState,
                                    actionTitle: hudStateActionTitle(for: hudState),
                                    isPrimaryEnabled: primaryActionEnabled(for: hudState),
                                    onPrimaryAction: { viewModel.performPrimaryAction() },
                                    isSecondaryEnabled: viewModel.canScanWithQRCode,
                                    onSecondaryAction: viewModel.isQRCodeEnabled && viewModel.snapshot.isJoined
                                        ? { showQRCodeScanner = true }
                                        : nil
                                )
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: actionSurfaceMinHeight(for: geo.size.height))
                            }
                        }
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared || reduceMotion ? 0 : 14)
                        .animation(entranceAnimation.delay(0.4), value: hasAppeared)

                        PlayerGameplayFooter(
                            events: Array(viewModel.activityLog.prefix(2)),
                            supportItem: footerSupportItem(for: hudState),
                            isPointsVisible: $viewModel.isPointsVisible,
                            privatePoints: viewModel.snapshot.points ?? viewModel.profile.points,
                            scoreboardAction: !viewModel.scoreboardTeams.isEmpty
                                ? { showScoreboardSheet = true }
                                : nil,
                            qrCodeAction: viewModel.canShowPersonalQRCode
                                ? { viewModel.showPersonalQRCode() }
                                : nil,
                            baseDetailAction: viewModel.canShowBaseDetails
                                ? { showBaseDetailSheet = true }
                                : nil,
                            menuContent: { overflowMenu }
                        )
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared || reduceMotion ? 0 : 14)
                        .animation(entranceAnimation.delay(0.55), value: hasAppeared)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(
                        minHeight: minimumContentHeight(
                            for: geo.size,
                            safeAreaInsets: geo.safeAreaInsets
                        ),
                        alignment: .top
                    )
                    .padding(.horizontal, 22)
                    .padding(.top, max(geo.safeAreaInsets.top, 18))
                    .padding(.bottom, max(geo.safeAreaInsets.bottom + 18, 28))
                }

                PlayerFloatingInfoButton(
                    tint: hudState.signal.tint,
                    action: { showRulesSheet = true }
                )
                .padding(.top, max(geo.safeAreaInsets.top + 12, 22))
                .padding(.trailing, 22)
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .zIndex(2)

                if let impactBanner {
                    PlayerImpactBanner(banner: impactBanner)
                        .padding(.top, max(geo.safeAreaInsets.top + 8, 18))
                        .padding(.horizontal, 34)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(3)
                }

                if viewModel.isOffline {
                    OfflineStatusBanner()
                        .padding(.top, max(geo.safeAreaInsets.top + 8, 18))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.opacity)
                        .zIndex(3.4)
                }

                if let engagement = viewModel.incomingEngagement {
                    IncomingEngagementBanner(engagement: engagement)
                        .padding(.top, max(geo.safeAreaInsets.top + 8, 18))
                        .padding(.horizontal, 22)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(3.5)
                }

                if let battleResult = viewModel.battleResult {
                    BattleResultOverlay(
                        result: battleResult,
                        battleSummary: viewModel.currentBattleSummary,
                        context: viewModel.lastScanContextLabel
                    ) {
                        viewModel.clearBattleResult()
                    }
                    .zIndex(4)
                }

                if shouldShowResolutionOverlay {
                    ScanResolutionOverlay(
                        message: resolutionOverlayMessage,
                        context: viewModel.lastScanContextLabel
                    )
                    .zIndex(5)
                }

                if viewModel.showEliminationOverlay {
                    EliminationOverlay {
                        viewModel.dismissEliminationOverlay()
                    }
                    .zIndex(6)
                }

                if let matchEndSummary = viewModel.matchEndSummary {
                    MatchEndOverlay(summary: matchEndSummary) {
                        if let exitMatchAction {
                            exitMatchAction()
                        } else {
                            viewModel.dismissMatchEndSummary()
                        }
                    }
                    .zIndex(7)
                }

                if viewModel.requiresBraceletRegistrationGate {
                    BraceletRegistrationGateView(viewModel: viewModel, exitAction: exitMatchAction)
                        .zIndex(8)
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showRulesSheet) {
                PlayerRulesSheet(
                    gameName: resolvedGameName,
                    snapshot: viewModel.snapshot
                )
                .presentationDetents([.large])
                .presentationBackground(BorderlandTheme.surface1)
            }
            .sheet(isPresented: $viewModel.settingsPresented) {
                PlayerSettingsSheet(
                    viewModel: viewModel,
                    logoutAction: { await logoutAction() }
                )
                .presentationDetents([.medium, .large])
                .presentationBackground(BorderlandTheme.surface1)
            }
            .sheet(isPresented: $showScoreboardSheet) {
                TeamScoreSheet(
                    teamId: viewModel.profile.teamId ?? "-",
                    playerPoints: viewModel.snapshot.points ?? viewModel.profile.points,
                    battleStatus: viewModel.snapshot.battleStatus,
                    teamStandings: viewModel.scoreboardTeams,
                    isMatchClosed: viewModel.isMatchClosed
                )
                .presentationDetents([.medium, .large])
                .presentationBackground(BorderlandTheme.surface1)
            }
            .sheet(isPresented: $showBaseDetailSheet) {
                PlayerBaseDetailSheet(
                    snapshot: viewModel.snapshot,
                    teamId: viewModel.baseDetailTeamId ?? "-"
                )
                .presentationDetents([.medium, .large])
                .presentationBackground(BorderlandTheme.surface1)
            }
            .sheet(isPresented: $showQRCodeScanner) {
                QRCodeScannerSheet(
                    title: "Scansiona QR",
                    subtitle: "Usa la fotocamera per leggere il codice di base, oggetto o giocatore."
                ) { value in
                    viewModel.playWithQRCode(value)
                }
            }
            .sheet(item: Binding(
                get: { viewModel.qrCodePreview },
                set: { if $0 == nil { viewModel.qrCodePreview = nil } }
            )) { preview in
                QRCodeSheet(title: preview.title, subtitle: preview.subtitle, token: preview.token)
            }
            .task { viewModel.onAppear() }
            .onAppear {
                hasAppeared = true
            }
            .onDisappear {
                impactTask?.cancel()
                impactTask = nil
                viewModel.onDisappear()
            }
            .onChange(of: hudState) { oldState, newState in
                if oldState.category != newState.category {
                    triggerHaptic(for: newState.category)
                    presentImpactBannerIfNeeded(for: newState)
                }
            }
        }
    }

    private var entranceAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.3) : AnimationTokens.dramaticReveal
    }

    private var headerIdentity: String {
        let nickname = viewModel.profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeNickname = nickname.isEmpty ? "Giocatore" : nickname
        let team = teamDisplayName(for: viewModel.profile.teamId)
        return "\(team) • \(safeNickname)"
    }

    private var resolvedGameName: String {
        if let gameName, !gameName.isEmpty {
            return gameName
        }

        let snapshotGameId = viewModel.snapshot.gameId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !snapshotGameId.isEmpty {
            let displayName = GameDefinition.displayName(forBackendCode: snapshotGameId)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !displayName.isEmpty {
                return displayName
            }
        }

        return "Borderland Classic"
    }

    private var headerSupportText: String {
        if viewModel.isPreMatchPhase {
            if viewModel.snapshot.allTeamsReadyForLive {
                return "Entrambe le squadre sono pronte. Avvio live imminente."
            }
            if viewModel.snapshot.teamReadyForLive {
                return "Il tuo team e pronto. Si aspetta l'altra squadra."
            }
            if viewModel.isLobbyPhase {
                return viewModel.isAutonomousMatch
                    ? "Completa squadra, base e setup prima di iniziare."
                    : "Attendi l'apertura della distribuzione o usa i controlli creator."
            }
            return viewModel.canEditTeamDistribution
                ? "Distribuisci i punti del team e conferma quando siete pronti."
                : "Il leader del team sta completando la distribuzione."
        }

        switch viewModel.gameplayHUDState {
        case .scanReady:
            return viewModel.hasBaseDefenseWindow
                ? "Base potenziata attiva per il tuo team"
                : "Pronto all'ingaggio"
        case .baseRecovery:
            return "Tocca la tua base per rientrare"
        case .teamSyncPending:
            return "Sync squadra attivo: ingaggia un avversario prima che scada il timer"
        case .scanning:
            return "Lettura NFC in corso"
        case .tagDetected:
            return "Calcolo esito in corso"
        case .success:
            return "Azione registrata"
        case .invalidTarget:
            return "Target non valido"
        case .cooldown:
            return "Attendi il rientro"
        case .protectedTarget:
            return "Bersaglio protetto, cambia target"
        case .actionBlocked:
            return viewModel.isMatchClosed ? "Partita terminata" : "Serve una nuova attivazione"
        case .eliminated:
            return "Fuori dal match"
        case .idle:
            return viewModel.isMatchClosed ? "Partita terminata" : "In attesa"
        }
    }

    private var shouldShowBraceletQuickAccess: Bool {
        viewModel.snapshot.isJoined &&
        !viewModel.isMatchClosed &&
        viewModel.canUseNFC &&
        viewModel.canRegisterPlayerTag &&
        viewModel.snapshot.state.uppercased() != "LIVE" &&
        !viewModel.requiresBraceletRegistrationGate
    }

    private var braceletQuickAccessPanel: some View {
        BorderlandPanel(title: "Braccialetto NFC") {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Collegalo ora dalla home: cosi arrivi in live con il tag gia pronto e non devi cercarlo nelle impostazioni.")
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textMuted)

                BorderlandButton(
                    "Collega braccialetto con NFC",
                    variant: .secondary,
                    isEnabled: !viewModel.isRegisteringBracelet,
                    isLoading: viewModel.isRegisteringBracelet
                ) {
                    viewModel.registerBraceletFromNFC()
                }
            }
        }
    }

    private var overflowMenu: some View {
        Menu {
            Button("Classifica") {
                showScoreboardSheet = true
            }

            Button("Impostazioni") {
                viewModel.settingsPresented = true
            }

            if canSwitchToAdmin, let switchToAdminAction {
                Button("Apri Admin") {
                    switchToAdminAction()
                }
            }

            if let exitMatchAction {
                Button("Esci dal match", role: .destructive) {
                    exitMatchAction()
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(BorderlandTheme.textMuted)
                .frame(width: 44, height: 44)
                .background(BorderlandTheme.surface2.opacity(0.85), in: Circle())
        }
    }

    private func footerSupportItem(for state: PlayerGameplayHUDState) -> PlayerFooterSupportItem? {
        if viewModel.isDistributionPhase {
            return .init(
                title: "Team",
                value: viewModel.snapshot.teamReadyForLive ? "Pronto" : "Setup",
                symbol: "person.3.fill",
                tint: BorderlandTheme.goldLight
            )
        }

        if viewModel.hasBaseDefenseWindow {
            return .init(
                title: "Base",
                value: formatDuration(viewModel.snapshot.baseDefenseRemainingSec ?? 0),
                symbol: "shield.fill",
                tint: BorderlandTheme.violet
            )
        }

        switch state {
        case .teamSyncPending(let seconds, _):
            return .init(
                title: "Sync",
                value: formatDuration(seconds),
                symbol: "person.2.wave.2.fill",
                tint: BorderlandTheme.emeraldLight
            )

        case .cooldown(let seconds):
            return .init(
                title: "Cooldown",
                value: formatDuration(seconds),
                symbol: "timer",
                tint: BorderlandTheme.crimson
            )

        case .protectedTarget:
            return .init(
                title: "Target",
                value: "Protetto",
                symbol: "shield.fill",
                tint: BorderlandTheme.violet
            )

        case .scanReady:
            return .init(
                title: "Stato",
                value: "Pronto",
                symbol: "dot.radiowaves.left.and.right",
                tint: BorderlandTheme.emeraldLight
            )

        case .baseRecovery:
            return .init(
                title: "Rientro",
                value: "Base",
                symbol: "house.fill",
                tint: BorderlandTheme.goldLight
            )

        case .scanning:
            return .init(
                title: "Stato",
                value: "Scanning",
                symbol: "wave.3.right",
                tint: BorderlandTheme.emeraldLight
            )

        case .tagDetected:
            return .init(
                title: "Stato",
                value: "Calcolo",
                symbol: "hourglass",
                tint: BorderlandTheme.emeraldLight
            )

        case .eliminated:
            return .init(
                title: "Stato",
                value: "Eliminato",
                symbol: "flame.fill",
                tint: BorderlandTheme.crimson
            )

        default:
            return nil
        }
    }

    private func hudStateActionTitle(for state: PlayerGameplayHUDState) -> String {
        switch state {
        case .scanReady:
            return "Gioca"
        case .baseRecovery:
            return "Tocca base"
        case .teamSyncPending:
            return "Gioca"
        case .idle:
            return viewModel.primaryActionTitle.capitalized
        case .invalidTarget:
            return "Gioca"
        case .protectedTarget:
            return "Gioca"
        case .actionBlocked:
            return viewModel.canTriggerPrimaryAction ? "Gioca" : "Bloccato"
        default:
            return state.ctaLabel.capitalized
        }
    }

    private func primaryActionEnabled(for state: PlayerGameplayHUDState) -> Bool {
        switch state {
        case .scanReady:
            return viewModel.canTriggerPrimaryAction
        case .baseRecovery:
            return viewModel.canTriggerPrimaryAction
        case .teamSyncPending:
            return viewModel.canTriggerPrimaryAction
        case .idle:
            return viewModel.canTriggerPrimaryAction
        case .invalidTarget:
            return viewModel.canTriggerPrimaryAction
        case .protectedTarget:
            return viewModel.canTriggerPrimaryAction
        case .actionBlocked:
            return viewModel.canTriggerPrimaryAction
        default:
            return false
        }
    }

    private func presentImpactBannerIfNeeded(for state: PlayerGameplayHUDState) {
        guard let banner = impactBannerModel(for: state) else { return }

        impactTask?.cancel()
        withAnimation(AnimationTokens.slideUp) {
            impactBanner = banner
        }

        impactTask = Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(AnimationTokens.standard) {
                    impactBanner = nil
                }
            }
        }
    }

    private func impactBannerModel(for state: PlayerGameplayHUDState) -> ImpactBanner? {
        switch state {
        case .invalidTarget:
            return .init(title: "Target non valido", symbol: "xmark.circle.fill", tint: BorderlandTheme.crimson)
        case .cooldown(let seconds):
            return .init(title: "Cooldown \(formatDuration(seconds))", symbol: "timer", tint: BorderlandTheme.crimson)
        case .protectedTarget:
            return .init(title: "Target protetto", symbol: "shield.fill", tint: BorderlandTheme.violet)
        case .actionBlocked:
            return .init(title: "Azione bloccata", symbol: "hand.raised.fill", tint: BorderlandTheme.crimson)
        case .eliminated:
            return .init(title: "Eliminato", symbol: "flame.fill", tint: BorderlandTheme.crimson)
        default:
            return nil
        }
    }

    private func triggerHaptic(for category: PlayerGameplayHUDState.Category) {
        switch category {
        case .ready:
            HapticManager.lightTap()
        case .scanning:
            HapticManager.scanPulse()
        case .resolving:
            HapticManager.mediumImpact()
        case .success:
            HapticManager.success()
        case .invalid, .cooldown, .protected, .blocked:
            HapticManager.warning()
        case .eliminated:
            HapticManager.elimination()
        case .idle:
            break
        }
    }

    private func contentSpacing(for height: CGFloat) -> CGFloat {
        height < 760 ? 16 : 22
    }

    private func actionSurfaceMinHeight(for height: CGFloat) -> CGFloat {
        min(max(height * 0.39, 320), 430)
    }

    private func minimumContentHeight(for size: CGSize, safeAreaInsets: EdgeInsets) -> CGFloat {
        max(size.height - safeAreaInsets.top - safeAreaInsets.bottom - 12, 0)
    }

    private func formatDuration(_ totalSeconds: Int) -> String {
        let bounded = max(0, totalSeconds)
        let minutes = bounded / 60
        let seconds = bounded % 60
        if minutes > 0 && seconds > 0 {
            return "\(minutes)m \(seconds)s"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(seconds)s"
    }

    private func teamDisplayName(for value: String?) -> String {
        let normalized = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch normalized {
        case "A", "TEAM_A", "GIOCATORI":
            return "Giocatori"
        case "B", "TEAM_B", "CITTADINI":
            return "Cittadini"
        default:
            return "Senza team"
        }
    }

    private var shouldShowResolutionOverlay: Bool {
        if viewModel.isPreMatchPhase {
            return false
        }
        return viewModel.battleResult == nil &&
            viewModel.matchEndSummary == nil &&
            (viewModel.isResolvingScan || isPendingScan)
    }

    private var isPendingScan: Bool {
        if case .some(.pending) = viewModel.lastScanStatus {
            return true
        }
        return false
    }

    private var resolutionOverlayMessage: String {
        let trimmed = viewModel.statusMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return "Tag letto. Sto calcolando l'esito dello scontro."
    }
}

private struct ImpactBanner {
    let title: String
    let symbol: String
    let tint: Color
}

private struct PlayerFooterSupportItem {
    let title: String
    let value: String
    let symbol: String
    let tint: Color
}

private enum PlayerStatusSignal {
    case ready
    case inactive
    case blocked
    case protected
    case neutral

    var tint: Color {
        switch self {
        case .ready:
            return BorderlandTheme.emeraldLight
        case .inactive:
            return BorderlandTheme.goldLight
        case .blocked:
            return BorderlandTheme.crimson
        case .protected:
            return BorderlandTheme.violet
        case .neutral:
            return BorderlandTheme.textMuted
        }
    }

    var headerTint: Color {
        switch self {
        case .neutral:
            return Color.white.opacity(0.14)
        default:
            return tint.opacity(0.9)
        }
    }

    var ambientTopTint: Color {
        switch self {
        case .ready:
            return BorderlandTheme.emeraldLight.opacity(0.16)
        case .inactive:
            return BorderlandTheme.gold.opacity(0.12)
        case .blocked:
            return BorderlandTheme.crimson.opacity(0.14)
        case .protected:
            return BorderlandTheme.violet.opacity(0.12)
        case .neutral:
            return BorderlandTheme.gold.opacity(0.08)
        }
    }

    var ambientBottomTint: Color {
        switch self {
        case .ready:
            return BorderlandTheme.emerald.opacity(0.12)
        case .inactive:
            return BorderlandTheme.goldLight.opacity(0.10)
        case .blocked:
            return BorderlandTheme.crimsonDeep.opacity(0.16)
        case .protected:
            return BorderlandTheme.violet.opacity(0.10)
        case .neutral:
            return BorderlandTheme.violet.opacity(0.10)
        }
    }
}

private extension PlayerGameplayHUDState {
    var signal: PlayerStatusSignal {
        switch self {
        case .scanReady, .teamSyncPending, .scanning, .tagDetected, .success:
            return .ready
        case .baseRecovery:
            return .inactive
        case .cooldown, .invalidTarget, .actionBlocked, .eliminated:
            return .blocked
        case .protectedTarget:
            return .protected
        case .idle:
            return .neutral
        }
    }
}

private struct PlayerGameplayBackground: View {
    let state: PlayerGameplayHUDState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#08090B"),
                    Color(hex: "#111216"),
                    Color(hex: "#08090B")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    state.signal.ambientTopTint,
                    .clear
                ],
                center: .top,
                startRadius: 18,
                endRadius: 260
            )
            .ignoresSafeArea()
            .offset(y: -90)

            RadialGradient(
                colors: [
                    state.signal.ambientBottomTint,
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 260
            )
            .ignoresSafeArea()
            .offset(x: 80, y: 140)
        }
    }
}

private struct PlayerGameplayHeader: View {
    let remainingSec: Int
    let matchLabel: String
    let phaseLabel: String
    let phaseTint: Color
    let identityLabel: String
    let supportText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        PlayerHeaderTag(text: matchLabel, tint: BorderlandTheme.gold.opacity(0.85))
                        PlayerHeaderTag(text: phaseLabel, tint: phaseTint)
                    }

                    Text(identityLabel)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(BorderlandTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("TIMER")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(BorderlandTheme.textMuted)

                    Text(formattedTime)
                        .font(.system(size: 40, weight: .heavy, design: .monospaced))
                        .foregroundStyle(timerTint)
                }
            }

            Text(supportText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(BorderlandTheme.textMuted)
                .lineLimit(1)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(BorderlandTheme.surface2.opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var formattedTime: String {
        let bounded = max(0, remainingSec)
        return String(format: "%02d:%02d", bounded / 60, bounded % 60)
    }

    private var timerTint: Color {
        if remainingSec <= 30 {
            return BorderlandTheme.crimson
        }
        if remainingSec <= 120 {
            return BorderlandTheme.goldLight
        }
        return BorderlandTheme.textPrimary
    }
}

private struct PlayerActionSurface: View {
    let state: PlayerGameplayHUDState
    let actionTitle: String
    let isPrimaryEnabled: Bool
    let onPrimaryAction: () -> Void
    let isSecondaryEnabled: Bool
    let onSecondaryAction: (() -> Void)?

    @State private var spinning = false
    @State private var breathing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text(state.title)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.tint)

                Spacer(minLength: 0)

                PlayerSurfacePill(
                    text: pillText,
                    tint: theme.tint
                )
            }

            Spacer(minLength: 26)

            symbolStage
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(state.subtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(BorderlandTheme.textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

            Spacer(minLength: 28)

            bottomControl
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(theme.background)
        )
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(theme.tint)
                .frame(width: 72, height: 4)
                .padding(.top, 12)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(theme.stroke, lineWidth: 1)
        )
        .animation(AnimationTokens.dramaticReveal, value: state.category)
        .onAppear {
            configureAnimations()
        }
        .onChange(of: state.category) { _, _ in
            configureAnimations()
        }
    }

    @ViewBuilder
    private var symbolStage: some View {
        switch state {
        case .cooldown(let seconds):
            VStack(spacing: 22) {
                PlayerScannerGlyph(
                    tint: theme.tint,
                    symbol: "timer",
                    style: .cooldown,
                    isScanning: false,
                    isBreathing: false
                )

                Text(formattedCooldown(seconds))
                    .font(.system(size: 44, weight: .heavy, design: .monospaced))
                    .foregroundStyle(theme.tint)
            }

        case .success(_, _, let delta):
            VStack(spacing: 22) {
                PlayerScannerGlyph(
                    tint: theme.tint,
                    symbol: "checkmark",
                    style: .success,
                    isScanning: false,
                    isBreathing: false
                )

                if let delta {
                    Text(successValueText(delta: delta))
                        .font(.system(size: successValueFontSize(delta: delta), weight: .black, design: .rounded))
                        .foregroundStyle(theme.tint)
                }
            }

        case .scanReady:
            PlayerScannerGlyph(
                tint: theme.tint,
                symbol: "dot.radiowaves.left.and.right",
                style: .ready,
                isScanning: false,
                isBreathing: breathing
            )

        case .baseRecovery:
            PlayerScannerGlyph(
                tint: theme.tint,
                symbol: "house.fill",
                style: .ready,
                isScanning: false,
                isBreathing: breathing
            )

        case .teamSyncPending(let seconds, _):
            VStack(spacing: 22) {
                PlayerScannerGlyph(
                    tint: theme.tint,
                    symbol: "person.2.fill",
                    style: .ready,
                    isScanning: false,
                    isBreathing: breathing
                )

                Text(formattedCooldown(seconds))
                    .font(.system(size: 44, weight: .heavy, design: .monospaced))
                    .foregroundStyle(theme.tint)
            }

        case .scanning:
            PlayerScannerGlyph(
                tint: theme.tint,
                symbol: "iphone.radiowaves.left.and.right",
                style: .scanning,
                isScanning: spinning,
                isBreathing: false
            )

        case .tagDetected:
            PlayerScannerGlyph(
                tint: theme.tint,
                symbol: "hourglass.circle.fill",
                style: .detected,
                isScanning: spinning,
                isBreathing: breathing
            )

        case .invalidTarget:
            PlayerScannerGlyph(
                tint: theme.tint,
                symbol: "xmark",
                style: .error,
                isScanning: false,
                isBreathing: false
            )

        case .protectedTarget:
            PlayerScannerGlyph(
                tint: theme.tint,
                symbol: "shield",
                style: .protected,
                isScanning: false,
                isBreathing: false
            )

        case .actionBlocked:
            PlayerScannerGlyph(
                tint: theme.tint,
                symbol: "hand.raised.fill",
                style: .error,
                isScanning: false,
                isBreathing: false
            )

        case .eliminated:
            PlayerScannerGlyph(
                tint: theme.tint,
                symbol: "flame.fill",
                style: .error,
                isScanning: false,
                isBreathing: false
            )

        case .idle:
            PlayerScannerGlyph(
                tint: theme.tint,
                symbol: "pause.fill",
                style: .idle,
                isScanning: false,
                isBreathing: false
            )
        }
    }

    @ViewBuilder
    private var bottomControl: some View {
        switch state {
        case .scanReady, .baseRecovery, .teamSyncPending, .idle, .invalidTarget, .protectedTarget, .actionBlocked:
            if let onSecondaryAction {
                HStack(spacing: 12) {
                    PlayerPrimaryActionButton(
                        title: actionTitle,
                        tint: theme.tint,
                        isEnabled: isPrimaryEnabled,
                        action: onPrimaryAction
                    )

                    PlayerSecondaryActionButton(
                        systemImage: "camera.fill",
                        tint: theme.tint,
                        isEnabled: isSecondaryEnabled,
                        action: onSecondaryAction
                    )
                }
            } else {
                PlayerPrimaryActionButton(
                    title: actionTitle,
                    tint: theme.tint,
                    isEnabled: isPrimaryEnabled,
                    action: onPrimaryAction
                )
            }

        case .scanning:
            PlayerSecondaryStatusBar(text: "Mantieni il tag vicino all'iPhone", tint: theme.tint)

        case .tagDetected:
            PlayerSecondaryStatusBar(text: "Calcolo esito in corso", tint: theme.tint)

        case .success(_, _, let delta):
            PlayerSecondaryStatusBar(text: successFooterText(delta: delta), tint: theme.tint)

        case .cooldown(let seconds):
            PlayerSecondaryStatusBar(text: "Disponibile tra \(formattedCooldown(seconds))", tint: theme.tint)

        case .eliminated:
            PlayerSecondaryStatusBar(text: "Vista bloccata", tint: theme.tint)
        }
    }

    private var pillText: String {
        switch state {
        case .scanReady:
            return "Live"
        case .baseRecovery:
            return "Base"
        case .teamSyncPending:
            return "Team"
        case .scanning:
            return "NFC"
        case .tagDetected:
            return "Resolving"
        case .success:
            return "OK"
        case .invalidTarget:
            return "Invalid"
        case .cooldown:
            return "Cooldown"
        case .protectedTarget:
            return "Protected"
        case .actionBlocked:
            return "Blocked"
        case .eliminated:
            return "Out"
        case .idle:
            return "Idle"
        }
    }

    private func configureAnimations() {
        switch state.category {
        case .ready:
            breathing = false
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                breathing = true
            }
            spinning = false

        case .scanning:
            spinning = false
            withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                spinning = true
            }
            breathing = false

        case .resolving:
            spinning = false
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                spinning = true
            }
            breathing = false
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                breathing = true
            }

        default:
            spinning = false
            breathing = false
        }
    }

    private func formattedCooldown(_ seconds: Int) -> String {
        let bounded = max(0, seconds)
        return String(format: "%02d:%02d", bounded / 60, bounded % 60)
    }

    private func successValueText(delta: Int?) -> String {
        guard let delta else { return "OK" }
        if delta > 0 { return "+\(delta)" }
        if delta < 0 { return "\(delta)" }
        return "OK"
    }

    private func successValueFontSize(delta: Int?) -> CGFloat {
        delta == nil ? 30 : 52
    }

    private func successFooterText(delta: Int?) -> String {
        guard let delta else { return "Azione registrata" }
        if delta > 0 { return "Guadagno +\(delta)" }
        if delta < 0 { return "Variazione \(delta)" }
        return "Nessuna variazione"
    }

    private var theme: ActionTheme {
        switch state {
        case .scanReady:
            return .init(
                tint: BorderlandTheme.emeraldLight,
                background: LinearGradient(
                    colors: [Color(hex: "#102018"), Color(hex: "#0D1411")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                stroke: BorderlandTheme.borderEmerald
            )

        case .baseRecovery:
            return .init(
                tint: BorderlandTheme.goldLight,
                background: LinearGradient(
                    colors: [Color(hex: "#1A1710"), Color(hex: "#111214")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                stroke: BorderlandTheme.borderGold
            )

        case .teamSyncPending:
            return .init(
                tint: BorderlandTheme.emeraldLight,
                background: LinearGradient(
                    colors: [Color(hex: "#112119"), Color(hex: "#0D1411")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                stroke: BorderlandTheme.borderEmerald
            )

        case .scanning:
            return .init(
                tint: BorderlandTheme.emeraldLight,
                background: LinearGradient(
                    colors: [Color(hex: "#102018"), Color(hex: "#0E1712")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                stroke: BorderlandTheme.borderEmerald
            )

        case .tagDetected:
            return .init(
                tint: BorderlandTheme.emeraldLight,
                background: LinearGradient(
                    colors: [Color(hex: "#112018"), Color(hex: "#0D1511")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                stroke: BorderlandTheme.borderEmerald
            )

        case .success:
            return .init(
                tint: BorderlandTheme.emeraldLight,
                background: LinearGradient(
                    colors: [Color(hex: "#122018"), Color(hex: "#0D1411")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                stroke: BorderlandTheme.borderEmerald
            )

        case .cooldown:
            return .init(
                tint: BorderlandTheme.crimson,
                background: LinearGradient(
                    colors: [Color(hex: "#1A1214"), Color(hex: "#111214")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                stroke: BorderlandTheme.crimson.opacity(0.24)
            )

        case .invalidTarget, .actionBlocked, .eliminated:
            return .init(
                tint: BorderlandTheme.crimson,
                background: LinearGradient(
                    colors: [Color(hex: "#181214"), Color(hex: "#111214")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                stroke: BorderlandTheme.crimson.opacity(0.24)
            )

        case .protectedTarget:
            return .init(
                tint: BorderlandTheme.violet,
                background: LinearGradient(
                    colors: [Color(hex: "#16141C"), Color(hex: "#111216")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                stroke: BorderlandTheme.violet.opacity(0.25)
            )

        case .idle:
            return .init(
                tint: BorderlandTheme.textMuted,
                background: LinearGradient(
                    colors: [Color(hex: "#161719"), Color(hex: "#111214")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                stroke: Color.white.opacity(0.08)
            )
        }
    }
}

private struct ActionTheme {
    let tint: Color
    let background: LinearGradient
    let stroke: Color
}

struct PlayerDistributionPanel: View {
    @ObservedObject var viewModel: PlayerViewModel
    @State private var editingMember: PlayerViewModel.DistributionMember?

    var body: some View {
        VStack(spacing: Spacing.md) {
            BorderlandCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Distribuzione punti")
                                .font(AppTypography.headline)
                                .foregroundStyle(BorderlandTheme.textPrimary)
                            Text("La partita parte automaticamente quando entrambe le squadre sono pronte.")
                                .font(AppTypography.caption)
                                .foregroundStyle(BorderlandTheme.textMuted)
                        }
                        Spacer()
                        statusChip(
                            title: "Team",
                            value: viewModel.snapshot.teamReadyForLive ? "Pronto" : "Setup",
                            tint: viewModel.snapshot.teamReadyForLive ? BorderlandTheme.gold : BorderlandTheme.textDim
                        )
                    }

                    HStack(spacing: Spacing.sm) {
                        statusChip(
                            title: "Assegnati",
                            value: "\(viewModel.distributionAllocatedPoints) pt",
                            tint: BorderlandTheme.gold
                        )
                        statusChip(
                            title: "Rimanenti",
                            value: "\(viewModel.distributionRemainingPoints) pt",
                            tint: viewModel.distributionRemainingPoints >= 0 ? BorderlandTheme.violet : BorderlandTheme.crimson
                        )
                    }

                    HStack(spacing: Spacing.sm) {
                        readinessPill(title: "Il tuo team", isReady: viewModel.snapshot.teamReadyForLive)
                        readinessPill(title: "Altra squadra", isReady: viewModel.snapshot.opponentTeamReadyForLive)
                    }
                }
            }

            BorderlandCard {
                VStack(spacing: Spacing.xs) {
                    ForEach(viewModel.distributionMembers) { member in
                        HStack(spacing: Spacing.sm) {
                            AvatarView(
                                avatarDataUrl: member.avatarDataUrl,
                                initials: initials(from: member.nickname),
                                size: .small
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: Spacing.xxs) {
                                    Text(member.nickname)
                                        .font(AppTypography.callout)
                                        .foregroundStyle(BorderlandTheme.textPrimary)
                                    if member.isLeader {
                                        Text("Leader")
                                            .font(AppTypography.caption2)
                                            .foregroundStyle(BorderlandTheme.gold)
                                    }
                                }
                                Text("\(member.assignedPoints) pt")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(BorderlandTheme.textMuted)
                            }

                            Spacer()

                            if viewModel.canEditTeamDistribution {
                                Button {
                                    HapticManager.lightTap()
                                    editingMember = member
                                } label: {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(BorderlandTheme.gold)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(BorderlandTheme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
                    }
                }
            }

            if !viewModel.distributionErrorMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(viewModel.distributionErrorMessage)
                    .font(AppTypography.caption)
                    .foregroundStyle(BorderlandTheme.statusDangerText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !viewModel.distributionSuccessMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(viewModel.distributionSuccessMessage)
                    .font(AppTypography.caption)
                    .foregroundStyle(BorderlandTheme.statusOkText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.canEditTeamDistribution {
                HStack(spacing: Spacing.sm) {
                    BorderlandButton(
                        viewModel.snapshot.teamDistributionSubmitted ? "Salva redistribuzione" : "Conferma distribuzione",
                        variant: .secondary,
                        isEnabled: viewModel.canSubmitTeamDistribution,
                        isLoading: viewModel.isSubmittingDistribution
                    ) {
                        viewModel.submitTeamDistribution()
                    }

                    BorderlandButton(
                        viewModel.snapshot.teamReadyForLive ? "Annulla pronto" : "Pronto",
                        variant: .primary,
                        isEnabled: viewModel.canToggleTeamReady,
                        isLoading: viewModel.isSettingTeamReady
                    ) {
                        viewModel.setTeamReady(!viewModel.snapshot.teamReadyForLive)
                    }
                }
            }

            if viewModel.shouldShowTeamReadyReminder {
                BorderlandButton(
                    "Sollecita altra squadra",
                    variant: .ghost,
                    isEnabled: viewModel.canSendTeamReadyReminder,
                    isLoading: viewModel.isSendingTeamReadyReminder
                ) {
                    viewModel.sendTeamReadyReminder()
                }
            }
        }
        .sheet(item: $editingMember) { member in
            PlayerDistributionEditorSheet(
                member: member,
                totalPool: viewModel.distributionTotalPool,
                onSave: { points in
                    viewModel.updateDistributionDraft(for: member.id, points: points)
                }
            )
            .presentationDetents([.medium])
            .presentationBackground(BorderlandTheme.surface1)
        }
    }

    private func statusChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTypography.caption2)
                .foregroundStyle(BorderlandTheme.textDim)
            Text(value)
                .font(AppTypography.callout)
                .foregroundStyle(tint)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BorderlandTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
    }

    private func readinessPill(title: String, isReady: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isReady ? BorderlandTheme.gold : BorderlandTheme.textDim)
                .frame(width: 7, height: 7)
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(BorderlandTheme.textMuted)
            Spacer(minLength: 0)
            Text(isReady ? "Pronto" : "Attesa")
                .font(AppTypography.caption)
                .foregroundStyle(isReady ? BorderlandTheme.gold : BorderlandTheme.textDim)
        }
        .padding(.horizontal, Spacing.sm)
        .frame(height: 34)
        .background(BorderlandTheme.surface2)
        .clipShape(Capsule())
    }

    private func initials(from value: String) -> String {
        let tokens = value.split(separator: " ").prefix(2)
        let initials = tokens.compactMap { $0.first }.map(String.init).joined().uppercased()
        return initials.isEmpty ? "?" : initials
    }
}

struct PlayerDistributionEditorSheet: View {
    let member: PlayerViewModel.DistributionMember
    let totalPool: Int
    let onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pointsText: String

    init(
        member: PlayerViewModel.DistributionMember,
        totalPool: Int,
        onSave: @escaping (Int) -> Void
    ) {
        self.member = member
        self.totalPool = totalPool
        self.onSave = onSave
        _pointsText = State(initialValue: "\(member.assignedPoints)")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.md) {
                AvatarView(
                    avatarDataUrl: member.avatarDataUrl,
                    initials: initials(from: member.nickname),
                    size: .large
                )

                Text(member.nickname)
                    .font(AppTypography.title3)
                    .foregroundStyle(BorderlandTheme.textPrimary)

                TextField("Punti", text: $pointsText)
                    .keyboardType(.numberPad)
                    .font(AppTypography.title2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.sm)
                    .frame(height: 52)
                    .background(BorderlandTheme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
                    .onChange(of: pointsText) { _, newValue in
                        let digits = newValue.filter(\.isNumber)
                        if digits != newValue {
                            pointsText = digits
                        }
                    }

                HStack(spacing: Spacing.sm) {
                    quickAdjustButton("-500") { adjustPoints(by: -500) }
                    quickAdjustButton("-100") { adjustPoints(by: -100) }
                    quickAdjustButton("+100") { adjustPoints(by: 100) }
                    quickAdjustButton("+500") { adjustPoints(by: 500) }
                }

                HStack(spacing: Spacing.sm) {
                    BorderlandButton("Azzera", variant: .ghost) {
                        pointsText = "0"
                    }
                    BorderlandButton("Salva", variant: .primary) {
                        onSave(clampedPoints)
                        dismiss()
                    }
                }

                Text("Massimo teorico \(totalPool) pt. La conferma finale resta bloccata se il totale del team supera il pool disponibile.")
                    .font(AppTypography.caption)
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.lg)
            .borderlandBackground()
            .navigationTitle("Assegna punti")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BorderlandButton("Chiudi", variant: .ghost) {
                        dismiss()
                    }
                    .frame(width: 90)
                }
            }
        }
    }

    private var clampedPoints: Int {
        min(max(Int(pointsText) ?? 0, 0), totalPool)
    }

    private func adjustPoints(by delta: Int) {
        let nextValue = min(max(clampedPoints + delta, 0), totalPool)
        pointsText = "\(nextValue)"
    }

    private func quickAdjustButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.lightTap()
            action()
        } label: {
            Text(title)
                .font(AppTypography.callout)
                .foregroundStyle(BorderlandTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(BorderlandTheme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private func initials(from value: String) -> String {
        let tokens = value.split(separator: " ").prefix(2)
        let initials = tokens.compactMap { $0.first }.map(String.init).joined().uppercased()
        return initials.isEmpty ? "?" : initials
    }
}

private struct PlayerScannerGlyph: View {
    enum Style {
        case ready
        case scanning
        case detected
        case success
        case protected
        case error
        case cooldown
        case idle
    }

    let tint: Color
    let symbol: String
    let style: Style
    let isScanning: Bool
    let isBreathing: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(tint.opacity(backgroundOpacity))
                .frame(width: 214, height: 214)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
                .frame(width: 214, height: 214)

            PlayerScannerCorners(tint: tint)
                .frame(width: 214, height: 214)

            Circle()
                .stroke(tint.opacity(0.14), lineWidth: 12)
                .frame(width: 144, height: 144)

            Circle()
                .stroke(tint.opacity(0.18), lineWidth: 1)
                .frame(width: 94, height: 94)

            if style == .scanning || style == .detected {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, tint.opacity(0.55), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 136, height: 3)
                    .blur(radius: 2)
                    .offset(y: isScanning ? 48 : -12)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isScanning)
            }

            if style == .scanning || style == .detected {
                Circle()
                    .trim(from: 0.05, to: 0.73)
                    .stroke(
                        tint.opacity(style == .detected ? 0.82 : 1),
                        style: StrokeStyle(
                            lineWidth: style == .detected ? 6 : 8,
                            lineCap: .round
                        )
                    )
                    .frame(width: 144, height: 144)
                    .rotationEffect(.degrees(isScanning ? 360 : 0))
                    .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: isScanning)
            }

            Image(systemName: symbol)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(tint)
                .scaleEffect(isBreathing ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isBreathing)

            if style == .success {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 74, height: 74)
            }
        }
        .overlay {
            if style == .success {
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.82))
            }
        }
    }

    private var symbolSize: CGFloat {
        switch style {
        case .ready:
            return 56
        case .scanning:
            return 52
        case .detected:
            return 48
        case .success:
            return 0
        case .protected, .error, .cooldown:
            return 50
        case .idle:
            return 44
        }
    }

    private var backgroundOpacity: Double {
        switch style {
        case .ready:
            return 0.08
        case .scanning:
            return 0.10
        case .detected:
            return 0.08
        case .success:
            return 0.12
        case .protected:
            return 0.10
        case .error:
            return 0.08
        case .cooldown:
            return 0.10
        case .idle:
            return 0.06
        }
    }
}

private struct PlayerScannerCorners: View {
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let inset: CGFloat = 16
            let length: CGFloat = 22

            Path { path in
                path.move(to: CGPoint(x: inset, y: inset + length))
                path.addLine(to: CGPoint(x: inset, y: inset))
                path.addLine(to: CGPoint(x: inset + length, y: inset))

                path.move(to: CGPoint(x: width - inset - length, y: inset))
                path.addLine(to: CGPoint(x: width - inset, y: inset))
                path.addLine(to: CGPoint(x: width - inset, y: inset + length))

                path.move(to: CGPoint(x: inset, y: height - inset - length))
                path.addLine(to: CGPoint(x: inset, y: height - inset))
                path.addLine(to: CGPoint(x: inset + length, y: height - inset))

                path.move(to: CGPoint(x: width - inset - length, y: height - inset))
                path.addLine(to: CGPoint(x: width - inset, y: height - inset))
                path.addLine(to: CGPoint(x: width - inset, y: height - inset - length))
            }
            .stroke(tint.opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct PlayerGameplayFooter<MenuContent: View>: View {
    let events: [PlayerViewModel.ActivityEntry]
    let supportItem: PlayerFooterSupportItem?
    @Binding var isPointsVisible: Bool
    let privatePoints: Int
    let scoreboardAction: (() -> Void)?
    let qrCodeAction: (() -> Void)?
    let baseDetailAction: (() -> Void)?
    @ViewBuilder let menuContent: () -> MenuContent

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Text("Recenti")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(BorderlandTheme.textPrimary)

                Spacer(minLength: 0)

                if let supportItem {
                    PlayerFooterSupportBadge(item: supportItem)
                }

                if let qrCodeAction {
                    PlayerFooterQRButton(action: qrCodeAction)
                }

                menuContent()
            }

            VStack(spacing: 12) {
                if events.isEmpty {
                    PlayerFooterEventRow(
                        title: "Sistema",
                        message: "Nessun evento recente.",
                        tint: BorderlandTheme.textMuted
                    )
                } else {
                    ForEach(events) { event in
                        PlayerFooterEventRow(
                            title: event.timestamp,
                            message: event.message,
                            tint: eventTint(for: event.kind)
                        )
                    }
                }
            }

            HStack(spacing: 12) {
                if let baseDetailAction {
                    PlayerFooterActionButton(
                        title: "Dettaglio base",
                        systemImage: "shield.fill",
                        action: baseDetailAction
                    )
                }

                if let scoreboardAction {
                    PlayerFooterActionButton(
                        title: "Classifica",
                        systemImage: "chart.bar.fill",
                        action: scoreboardAction
                    )
                }

                Spacer(minLength: 0)

                PlayerPrivateScoreReveal(
                    isVisible: $isPointsVisible,
                    points: privatePoints
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(BorderlandTheme.surface2.opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func eventTint(for kind: PlayerViewModel.ActivityEntry.Kind) -> Color {
        switch kind {
        case .ok:
            return BorderlandTheme.goldLight
        case .warn:
            return BorderlandTheme.violet
        case .error:
            return BorderlandTheme.crimson
        }
    }
}

private struct PlayerFooterEventRow: View {
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)

                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(BorderlandTheme.textMuted)

                Spacer(minLength: 0)
            }

            Text(message)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(BorderlandTheme.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PlayerFooterActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.lightTap()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(BorderlandTheme.textPrimary)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(BorderlandTheme.surface2.opacity(0.85), in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

private struct PlayerFooterSupportBadge: View {
    let item: PlayerFooterSupportItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.symbol)
                .font(.system(size: 11, weight: .bold))
            Text(item.title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
            Text(item.value.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(item.tint)
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(item.tint.opacity(0.12), in: Capsule())
    }
}

private struct PlayerPrivateScoreReveal: View {
    @Binding var isVisible: Bool
    let points: Int

    var body: some View {
        HStack(spacing: 10) {
            Text(isVisible ? "\(points)" : "••••")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(BorderlandTheme.goldLight)
                .blur(radius: isVisible ? 0 : 8)

            Text(isVisible ? "Visibile" : "Hold")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(BorderlandTheme.textPrimary)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(BorderlandTheme.surface2.opacity(0.85), in: Capsule())
        .overlay(
            Capsule()
                .stroke(BorderlandTheme.gold.opacity(isVisible ? 0.32 : 0.14), lineWidth: 1)
        )
        .contentShape(Capsule())
        .onLongPressGesture(minimumDuration: 0.15, maximumDistance: 32, pressing: { pressing in
            withAnimation(AnimationTokens.standard) {
                isVisible = pressing
            }
        }, perform: {})
    }
}

private struct PlayerHeaderTag: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(BorderlandTheme.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(tint.opacity(0.16), in: Capsule())
    }
}

private struct PlayerSurfacePill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct PlayerFloatingInfoButton: View {
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.lightTap()
            action()
        } label: {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(tint.opacity(0.28), lineWidth: 1)
                )
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Regole")
    }
}

private struct PlayerPrimaryActionButton: View {
    let title: String
    let tint: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.lightTap()
            action()
        } label: {
            Text(title.uppercased())
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(isEnabled ? Color.black : BorderlandTheme.textMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(buttonBackground)
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled)
    }

    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(isEnabled ? AnyShapeStyle(tint) : AnyShapeStyle(Color.white.opacity(0.05)))
    }
}

private struct PlayerSecondaryActionButton: View {
    let systemImage: String
    let tint: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.lightTap()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isEnabled ? tint : BorderlandTheme.textMuted)
                .frame(width: 58, height: 58)
                .background(buttonBackground)
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled)
    }

    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(isEnabled ? AnyShapeStyle(tint.opacity(0.14)) : AnyShapeStyle(Color.white.opacity(0.05)))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isEnabled ? tint.opacity(0.34) : Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

private struct PlayerSecondaryStatusBar: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
            Spacer(minLength: 0)
        }
        .frame(height: 52)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PlayerFooterQRButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.lightTap()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "qrcode")
                    .font(.system(size: 11, weight: .bold))
                Text("QR Code")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(BorderlandTheme.gold)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(BorderlandTheme.gold.opacity(0.12), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(BorderlandTheme.gold.opacity(0.30), lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
    }
}

private struct PlayerImpactBanner: View {
    let banner: ImpactBanner

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: banner.symbol)
                .font(.system(size: 15, weight: .semibold))
            Text(banner.title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundStyle(banner.tint)
        .padding(.horizontal, 16)
        .frame(height: 42)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(banner.tint.opacity(0.22), lineWidth: 1)
        )
    }
}

#Preview("Gameplay Ready") {
    PlayerHomeView(
        viewModel: .preview(scenario: .ready),
        logoutAction: { await Task.yield() },
        exitMatchAction: {},
        switchToAdminAction: {},
        canSwitchToAdmin: true
    )
}

#Preview("Gameplay States") {
    ScrollView {
        VStack(spacing: 24) {
            ForEach(PlayerViewModel.PreviewScenario.allCases) { scenario in
                VStack(alignment: .leading, spacing: 10) {
                    Text(scenario.rawValue.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(BorderlandTheme.textMuted)

                    PlayerHomeView(
                        viewModel: .preview(scenario: scenario),
                        logoutAction: { await Task.yield() },
                        exitMatchAction: {},
                        switchToAdminAction: {},
                        canSwitchToAdmin: true
                    )
                    .frame(height: 860)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                }
            }
        }
        .padding()
        .background(Color.black)
    }
}

private struct OfflineStatusBanner: View {
    var body: some View {
        Text("Offline — riconnessione…")
            .font(AppTypography.caption)
            .foregroundStyle(BorderlandTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.75), in: Capsule())
    }
}

private struct IncomingEngagementBanner: View {
    let engagement: MatchSnapshot.IncomingEngagement

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let remaining = max(0, Double(engagement.expiresAtMs) / 1000 - context.date.timeIntervalSince1970)
            if remaining > 0 {
                VStack(spacing: 4) {
                    Text("⚔️ \(engagement.attackerName) ti ha ingaggiato!")
                        .font(AppTypography.title3)
                        .foregroundStyle(.white)
                    Text("Scansiona il suo tag entro \(Int(remaining.rounded(.up)))s")
                        .font(AppTypography.callout)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .multilineTextAlignment(.center)
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(BorderlandTheme.crimson.opacity(0.92))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
                .accessibilityElement(children: .combine)
            }
        }
    }
}
