import SwiftUI

struct StoreHomeView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: StoreHomeViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let gameService: GameService
    private let authService: AuthService
    private let nfcService: NFCService
    private let logoutAction: () async -> Void
    private let selectedGame: GameDefinition?
    private let onChangeGame: () -> Void

    @State private var showCreateSheet = false
    @State private var showJoinSheet = false
    @State private var showProfileCompletion = false
    @State private var showProfileEditor = false
    @State private var showAvatarPreview = false
    @State private var selectedDestination: SelectedDestination?
    @State private var selectedPanel: HomePanelRoute?
    @State private var pendingInviteConfirmation: PendingInviteConfirmation?
    @State private var hasAppeared = false

    init(
        gameService: GameService,
        authService: AuthService,
        nfcService: NFCService,
        logoutAction: @escaping () async -> Void,
        selectedGame: GameDefinition? = nil,
        onChangeGame: @escaping () -> Void = {}
    ) {
        self.gameService = gameService
        self.authService = authService
        self.nfcService = nfcService
        self.logoutAction = logoutAction
        self.selectedGame = selectedGame
        self.onChangeGame = onChangeGame
        _viewModel = StateObject(wrappedValue: StoreHomeViewModel(authService: authService, gameService: gameService))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SuitBackdrop(density: .full)
                FloatingParticles()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        if let selectedGame {
                            gameContextBar(for: selectedGame)
                                .opacity(hasAppeared ? 1 : 0)
                                .animation(entranceAnimation.delay(0.05), value: hasAppeared)
                        }

                        header
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared || reduceMotion ? 0 : -10)
                            .animation(entranceAnimation.delay(0.1), value: hasAppeared)

                        if viewModel.isLoading {
                            loadingCard
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(y: hasAppeared || reduceMotion ? 0 : 12)
                                .animation(entranceAnimation.delay(0.25), value: hasAppeared)
                        }

                        if viewModel.needsProfileCompletion {
                            profileCompletionCard
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(y: hasAppeared || reduceMotion ? 0 : 12)
                                .animation(entranceAnimation.delay(0.25), value: hasAppeared)
                        }

                        if let liveGame = viewModel.preferredLiveGame {
                            liveEntryCard(for: liveGame)
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(y: hasAppeared || reduceMotion ? 0 : 12)
                                .animation(entranceAnimation.delay(0.25), value: hasAppeared)
                        }

                        actionHub
                            .padding(.top, actionHubTopInset)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared || reduceMotion ? 0 : 16)
                            .animation(entranceAnimation.delay(0.4), value: hasAppeared)

                        Text("Nel menu trovi partite attive, archivio, impostazioni e logout.")
                            .font(AppTypography.caption)
                            .foregroundStyle(BorderlandTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .opacity(hasAppeared ? 1 : 0)
                            .animation(entranceAnimation.delay(0.55), value: hasAppeared)

                        if !viewModel.errorMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(viewModel.errorMessage)
                                .font(AppTypography.caption)
                                .foregroundStyle(BorderlandTheme.statusDangerText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.vertical, Spacing.lg)
                }
            }
            .borderlandBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                hasAppeared = true
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateGameSheet(
                    canCreateGames: viewModel.canCreateGames,
                    catalog: viewModel.catalog
                ) { name, gameDefinitionId, config, itemMode, autonomousSetup in
                    let created = try await viewModel.createGame(
                        name: name,
                        gameDefinitionId: gameDefinitionId,
                        config: config,
                        itemMode: itemMode,
                        autonomousSetup: autonomousSetup
                    )
                    selectedDestination = .detail(id: created.id)
                }
            }
            .sheet(isPresented: $showJoinSheet) {
                JoinMatchView { codeOrLink in
                    let joined = try await viewModel.joinGame(codeOrLink: codeOrLink)
                    selectedDestination = destination(for: joined)
                }
                .presentationDetents([.large])
                .presentationBackground(BorderlandTheme.void)
            }
            .sheet(isPresented: $showProfileEditor) {
                ProfileEditorSheet(
                    gameService: gameService,
                    canDeleteAccount: !(authService.currentUser?.isGuest ?? false),
                    onSaved: {
                        Task { await viewModel.load() }
                    },
                    onDeleteAccount: {
                        try await container.deleteAccount()
                    }
                )
            }
            .sheet(isPresented: $showAvatarPreview) {
                AvatarPreviewSheet(
                    displayName: viewModel.displayName,
                    avatarDataUrl: viewModel.avatarDataUrl
                )
            }
            .fullScreenCover(isPresented: $showProfileCompletion) {
                ProfileCompletionView(
                    viewModel: ProfileCompletionViewModel(gameService: gameService)
                ) {
                    showProfileCompletion = false
                    container.didCompleteProfile()
                    Task {
                        await reloadHome()
                        await handlePendingInviteIfNeeded()
                    }
                }
                .interactiveDismissDisabled(true)
            }
            .alert(item: $pendingInviteConfirmation) { invite in
                Alert(
                    title: Text("Entra nella partita?"),
                    message: Text(invite.message),
                    primaryButton: .default(Text("Entra")) {
                        Task { await confirmPendingInvite(invite) }
                    },
                    secondaryButton: .cancel(Text("Non ora"))
                )
            }
            .navigationDestination(item: $selectedPanel) { panel in
                switch panel {
                case .organizedActive:
                    HomeGameCollectionView(
                        title: "Partite create attive",
                        subtitle: "Partite che organizzi o gestisci e che non sono ancora terminate.",
                        games: viewModel.organizedGames,
                        emptyMessage: "Nessuna partita creata attiva."
                    ) { game in
                        selectedDestination = destination(for: game)
                    }
                case .joinedActive:
                    HomeGameCollectionView(
                        title: "Partite partecipate attive",
                        subtitle: "Partite in cui sei gia entrato come player e che sono ancora attive.",
                        games: viewModel.joinedGames,
                        emptyMessage: "Nessuna partita partecipata attiva."
                    ) { game in
                        selectedDestination = destination(for: game)
                    }
                case .archive:
                    HomeArchiveView(
                        organizedGames: archivedOrganizedGames,
                        joinedGames: archivedJoinedGames
                    ) { game in
                        selectedDestination = destination(for: game)
                    }
                }
            }
            .navigationDestination(item: $selectedDestination) { destination in
                switch destination {
                case .detail(let gameId):
                    GameDetailView(
                        gameId: gameId,
                        gameService: gameService,
                        authService: authService,
                        nfcService: nfcService
                    )
                case .live(let gameId, let gameName, let canManageSensitive, let autonomousSetup):
                    ScopedGamePlayView(
                        gameId: gameId,
                        gameName: gameName,
                        gameService: gameService,
                        authService: authService,
                        nfcService: nfcService,
                        startInPlayerFlow: true,
                        canSwitchToAdmin: canManageSensitive,
                        initialAutonomousSetup: autonomousSetup
                    )
                }
            }
            .task {
                await reloadHome()
                await handlePendingInviteIfNeeded()
                if let intent = container.consumePendingEntryIntent() {
                    switch intent {
                    case .joinMatch:
                        showJoinSheet = true
                    case .createMatch:
                        showCreateSheet = true
                    }
                }
            }
            .refreshable {
                await reloadHome()
                await handlePendingInviteIfNeeded()
            }
            .onChange(of: container.pendingInvite) { _, _ in
                Task { await handlePendingInviteIfNeeded() }
            }
            .onChange(of: showCreateSheet) { _, isPresented in
                guard !isPresented else { return }
                Task { await handlePendingInviteIfNeeded() }
            }
            .onChange(of: showJoinSheet) { _, isPresented in
                guard !isPresented else { return }
                Task { await handlePendingInviteIfNeeded() }
            }
            .onChange(of: showProfileCompletion) { _, isPresented in
                guard !isPresented else { return }
                Task { await handlePendingInviteIfNeeded() }
            }
            .onChange(of: viewModel.needsProfileCompletion) { _, needsCompletion in
                showProfileCompletion = needsCompletion
                guard !needsCompletion else { return }
                Task { await handlePendingInviteIfNeeded() }
            }
        }
    }

    private var entranceAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.3) : AnimationTokens.dramaticReveal
    }

    /// Barra che ricorda quale gioco è stato scelto nella hub e permette di tornarci.
    private func gameContextBar(for game: GameDefinition) -> some View {
        HStack(spacing: Spacing.sm) {
            GameEmblemView(game: game, size: 38)

            VStack(alignment: .leading, spacing: 0) {
                Text("STAI GIOCANDO A")
                    .font(AppTypography.caption2)
                    .tracking(1.2)
                    .foregroundStyle(BorderlandTheme.textDim)
                Text(game.name)
                    .font(AppTypography.headline)
                    .foregroundStyle(BorderlandTheme.textPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                HapticManager.lightTap()
                onChangeGame()
            } label: {
                Text("Cambia")
                    .font(AppTypography.caption)
                    .foregroundStyle(BorderlandTheme.gold)
                    .padding(.horizontal, Spacing.md)
                    .frame(height: 44)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Cambia gioco")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(BorderlandTheme.surface1.opacity(0.85))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
                .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            Button {
                showAvatarPreview = true
            } label: {
                AvatarView(
                    avatarDataUrl: viewModel.avatarDataUrl,
                    initials: initials(from: viewModel.displayName),
                    size: .medium
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(viewModel.displayName)
                    .font(AppTypography.title2)
                    .foregroundStyle(BorderlandTheme.textPrimary)
                    .lineLimit(1)

                Text("Crea una partita o rientra subito in quella giusta.")
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Menu {
                Button {
                    selectedPanel = .organizedActive
                } label: {
                    HomeMenuRowLabel(
                        title: "Partite create attive",
                        count: viewModel.organizedGames.count,
                        systemImage: "flag.fill"
                    )
                }

                Button {
                    selectedPanel = .joinedActive
                } label: {
                    HomeMenuRowLabel(
                        title: "Partite partecipate attive",
                        count: viewModel.joinedGames.count,
                        systemImage: "person.3.fill"
                    )
                }

                Button {
                    selectedPanel = .archive
                } label: {
                    HomeMenuRowLabel(
                        title: "Archivio",
                        count: viewModel.archivedGames.count,
                        systemImage: "archivebox.fill"
                    )
                }

                Divider()

                Button {
                    onChangeGame()
                } label: {
                    Label("Cambia gioco", systemImage: "rectangle.on.rectangle.angled")
                }

                Button {
                    showProfileEditor = true
                } label: {
                    Label("Impostazioni", systemImage: "gearshape.fill")
                }

                Button(role: .destructive) {
                    Task { await logoutAction() }
                } label: {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(BorderlandTheme.gold)
                    .frame(width: 46, height: 46)
                    .background(BorderlandTheme.surface2.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
                            .stroke(BorderlandTheme.borderGold.opacity(0.5), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
            }
        }
    }

    private var loadingCard: some View {
        BorderlandCard {
            HStack(spacing: Spacing.sm) {
                ProgressView()
                    .tint(BorderlandTheme.gold)
                Text("Caricamento profilo e partite…")
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textMuted)
                Spacer(minLength: 0)
            }
        }
    }

    private var profileCompletionCard: some View {
        BorderlandCard(variant: .elevated) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Completa il profilo")
                    .font(AppTypography.title3)
                    .foregroundStyle(BorderlandTheme.gold)
                Text("Prima di entrare in una partita devi confermare nickname e avatar.")
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                BorderlandButton("Completa profilo", variant: .primary) {
                    showProfileCompletion = true
                }
            }
        }
    }

    private func liveEntryCard(for game: GameAccessSummary) -> some View {
        BorderlandCard(variant: .elevated) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Partita in corso")
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.gold)
                    Text(game.name)
                        .font(AppTypography.title3)
                        .foregroundStyle(BorderlandTheme.textPrimary)
                    Text("Rientri direttamente nella schermata di gioco.")
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.textMuted)
                }

                Spacer(minLength: 0)

                BorderlandButton("Rientra", variant: .secondary) {
                    selectedDestination = .live(
                        gameId: game.id,
                        gameName: game.name,
                        canManageSensitive: game.canManageSensitive,
                        autonomousSetup: game.autonomousSetup
                    )
                }
                .frame(width: 120)
            }
        }
    }

    private var actionHub: some View {
        BorderlandCard(variant: .elevated) {
            VStack(spacing: Spacing.md) {
                Text("Azioni principali")
                    .font(AppTypography.caption)
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                entryButton(
                    title: "Crea una partita",
                    subtitle: "Diventa game master",
                    icon: "plus.circle",
                    isPrimary: true,
                    isEnabled: viewModel.canStartCreateFlow
                ) {
                    openCreateFlow()
                }

                entryButton(
                    title: "Entra in una partita",
                    subtitle: "Hai un codice invito?",
                    icon: "arrow.right.circle",
                    isPrimary: false,
                    isEnabled: !viewModel.isBusy
                ) {
                    openJoinFlow()
                }

                if !viewModel.canCreateGames {
                    Text("L'accesso ospite puo entrare in partita, ma non crearne di nuove.")
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if viewModel.catalog.isEmpty && !viewModel.isLoading {
                    Text("Catalogo giochi non disponibile: riprova quando il backend risponde correttamente.")
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.statusDangerText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Entry CTAs

    private func entryButton(
        title: String,
        subtitle: String,
        icon: String,
        isPrimary: Bool,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.lightTap()
            action()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(isPrimary ? Color.white : BorderlandTheme.gold)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.headline)
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(isPrimary ? Color.white : BorderlandTheme.textPrimary)
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(isPrimary ? Color.white.opacity(0.82) : BorderlandTheme.textMuted)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isPrimary ? Color.white.opacity(0.7) : BorderlandTheme.textDim)
            }
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                Group {
                    if isPrimary {
                        LinearGradient(
                            colors: [BorderlandTheme.crimson, BorderlandTheme.crimson.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        BorderlandTheme.surface2.opacity(0.85)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                    .stroke(
                        isPrimary ? BorderlandTheme.crimson.opacity(0.6) : BorderlandTheme.borderSubtle,
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous))
            .opacity(isEnabled ? 1 : 0.55)
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled)
    }

    private var actionHubTopInset: CGFloat {
        if viewModel.isLoading || viewModel.needsProfileCompletion || viewModel.preferredLiveGame != nil {
            return Spacing.lg
        }
        return Spacing.huge
    }

    private var archivedOrganizedGames: [GameAccessSummary] {
        viewModel.archivedGames.filter { $0.role.isManager }
    }

    private var archivedJoinedGames: [GameAccessSummary] {
        viewModel.archivedGames.filter { $0.joinedAsPlayer || $0.role == .player || $0.isCurrentUserLockedGm }
    }

    private func openCreateFlow() {
        if viewModel.needsProfileCompletion {
            showProfileCompletion = true
        } else {
            showCreateSheet = true
        }
    }

    private func openJoinFlow() {
        if viewModel.needsProfileCompletion {
            showProfileCompletion = true
        } else {
            showJoinSheet = true
        }
    }

    private func destination(for game: GameAccessSummary) -> SelectedDestination {
        if game.joinedAsPlayer || game.role == .player || game.isCurrentUserLockedGm {
            return .live(
                gameId: game.id,
                gameName: game.name,
                canManageSensitive: game.canManageSensitive,
                autonomousSetup: game.autonomousSetup
            )
        }
        return .detail(id: game.id)
    }

    private func reloadHome() async {
        await viewModel.load()
        showProfileCompletion = viewModel.needsProfileCompletion
    }

    private func handlePendingInviteIfNeeded() async {
        guard pendingInviteConfirmation == nil else { return }
        guard !showCreateSheet && !showJoinSheet && !showProfileCompletion else { return }
        guard !viewModel.needsProfileCompletion else { return }
        guard let invite = container.consumePendingInvite() else { return }
        pendingInviteConfirmation = PendingInviteConfirmation(
            codeOrLink: invite.codeOrLink,
            isOperatorInvite: invite.isOperatorInvite
        )
    }

    private func confirmPendingInvite(_ invite: PendingInviteConfirmation) async {
        pendingInviteConfirmation = nil

        do {
            let joined = try await viewModel.joinGame(codeOrLink: invite.codeOrLink)
            selectedDestination = destination(for: joined)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func initials(from value: String) -> String {
        let parts = value.split(separator: " ").prefix(2)
        return parts.compactMap(\.first).map(String.init).joined().uppercased()
    }
}

private struct PendingInviteConfirmation: Identifiable {
    let codeOrLink: String
    let isOperatorInvite: Bool

    var id: String {
        "\(isOperatorInvite ? "operator" : "player"):\(codeOrLink)"
    }

    var message: String {
        let trimmedCode = codeOrLink.trimmingCharacters(in: .whitespacesAndNewlines)
        let accessLabel = isOperatorInvite ? "operatore" : "player"
        return "Abbiamo trovato un invito \(accessLabel). Vuoi usarlo adesso?\n\nCodice: \(trimmedCode)"
    }
}

private enum HomePanelRoute: Identifiable {
    case organizedActive
    case joinedActive
    case archive

    var id: String {
        switch self {
        case .organizedActive:
            return "organizedActive"
        case .joinedActive:
            return "joinedActive"
        case .archive:
            return "archive"
        }
    }
}

private enum SelectedDestination: Identifiable, Hashable {
    case detail(id: String)
    case live(gameId: String, gameName: String, canManageSensitive: Bool, autonomousSetup: AutonomousGameSetup)

    var id: String {
        switch self {
        case .detail(let id):
            return "detail:\(id)"
        case .live(let gameId, _, _, _):
            return "live:\(gameId)"
        }
    }
}

private struct HomeMenuRowLabel: View {
    let title: String
    let count: Int
    let systemImage: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: systemImage)
            Text(title)
            Spacer(minLength: 8)
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
    }
}

private struct AvatarPreviewSheet: View {
    let displayName: String
    let avatarDataUrl: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                AvatarView(
                    avatarDataUrl: avatarDataUrl,
                    initials: initials(from: displayName),
                    size: .large
                )

                Text(displayName)
                    .font(AppTypography.title2)
                    .foregroundStyle(BorderlandTheme.textPrimary)

                Text("Foto profilo usata in home, roster e battaglie.")
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Spacing.screenHorizontal)
            .borderlandBackground()
            .navigationTitle("Profilo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }

    private func initials(from value: String) -> String {
        let parts = value.split(separator: " ").prefix(2)
        return parts.compactMap(\.first).map(String.init).joined().uppercased()
    }
}

private struct HomeGameCollectionView: View {
    let title: String
    let subtitle: String
    let games: [GameAccessSummary]
    let emptyMessage: String
    let onSelect: (GameAccessSummary) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(subtitle)
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textMuted)

                if games.isEmpty {
                    BorderlandCard {
                        Text(emptyMessage)
                            .font(AppTypography.callout)
                            .foregroundStyle(BorderlandTheme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    VStack(spacing: Spacing.sm) {
                        ForEach(games) { game in
                            Button {
                                onSelect(game)
                            } label: {
                                GameAccessRow(game: game)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.lg)
        }
        .borderlandBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HomeArchiveView: View {
    let organizedGames: [GameAccessSummary]
    let joinedGames: [GameAccessSummary]
    let onSelect: (GameAccessSummary) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                archiveSection(
                    title: "Organizzate da te",
                    games: organizedGames,
                    emptyMessage: "Nessuna partita archiviata che hai organizzato.",
                    onSelect: onSelect
                )

                archiveSection(
                    title: "Partecipate come player",
                    games: joinedGames,
                    emptyMessage: "Nessuna partita archiviata a cui hai partecipato.",
                    onSelect: onSelect
                )
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.lg)
        }
        .borderlandBackground()
        .navigationTitle("Archivio")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func archiveSection(
        title: String,
        games: [GameAccessSummary],
        emptyMessage: String,
        onSelect: @escaping (GameAccessSummary) -> Void
    ) -> some View {
        BorderlandCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(title)
                    .font(AppTypography.title3)
                    .foregroundStyle(BorderlandTheme.gold)

                if games.isEmpty {
                    Text(emptyMessage)
                        .font(AppTypography.callout)
                        .foregroundStyle(BorderlandTheme.textMuted)
                } else {
                    VStack(spacing: Spacing.sm) {
                        ForEach(games) { game in
                            Button {
                                onSelect(game)
                            } label: {
                                GameAccessRow(game: game)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private struct GameAccessRow: View {
    let game: GameAccessSummary

    var body: some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(game.name)
                    .font(AppTypography.headline)
                    .foregroundStyle(BorderlandTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: Spacing.xs) {
                    pill(game.gameDefinitionName)
                    pill(game.roleLabel)
                    pill(game.stateLabel)
                    Text("\(game.playerCount) giocatori")
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.textMuted)
                }

                Text(game.itemMode.helperText)
                    .font(AppTypography.caption2)
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BorderlandTheme.textDim)
        }
        .padding(Spacing.md)
        .background(BorderlandTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
                .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func pill(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.caption2)
            .foregroundStyle(BorderlandTheme.gold)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(BorderlandTheme.surface3)
            .clipShape(Capsule())
    }
}

private struct CreateGameSheet: View {
    let canCreateGames: Bool
    let catalog: [GameCatalogEntry]
    let onSubmit: (String, String, GameplayConfigSnapshot, ItemMode, AutonomousGameSetup) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var hostMode: MatchHostingMode = .autonomous
    @State private var teamAssignmentMode: TeamAssignmentMode = .manual
    @State private var itemMode: ItemMode = .none
    @State private var selectedGameDefinitionId = ""
    @State private var config = GameplayConfigSnapshot.default
    @State private var isSubmitting = false
    @State private var submissionError = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Gioco") {
                    if let onlyGame = onlyCatalogEntry {
                        catalogCard(onlyGame, isSelected: true, allowsSelection: false)
                    } else {
                        ForEach(catalog) { game in
                            Button {
                                selectedGameDefinitionId = game.id
                                syncItemMode(with: game)
                            } label: {
                                catalogCard(game, isSelected: selectedGameDefinitionId == game.id, allowsSelection: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Nuova partita") {
                    TextField("Nome partita", text: $name)
                    Picker("Modalità partita", selection: $hostMode) {
                        ForEach(MatchHostingMode.allCases, id: \.self) { mode in
                            Text(mode.displayLabel).tag(mode)
                        }
                    }
                    Text(hostMode.helperText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if hostMode == .autonomous {
                        Picker("Assegnazione team", selection: $teamAssignmentMode) {
                            ForEach(TeamAssignmentMode.allCases, id: \.self) { mode in
                                Text(mode.displayLabel).tag(mode)
                            }
                        }
                        Text(teamAssignmentMode.helperText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Stepper(
                        "Durata: \(matchDurationMinutes) min",
                        value: Binding(
                            get: { matchDurationMinutes },
                            set: { config.matchDurationSec = max(5, $0) * 60 }
                        ),
                        in: 5...240,
                        step: 5
                    )
                }

                Section("Oggetti") {
                    Picker("Modalità oggetti", selection: $itemMode) {
                        ForEach(availableItemModes, id: \.self) { mode in
                            Text(mode.displayLabel).tag(mode)
                        }
                    }
                    Text(itemMode.helperText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if hostMode == .autonomous {
                        Text("In modalità autonoma sono disponibili solo nessun oggetto oppure cross-team.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let recommended = selectedCatalogEntry?.recommendedItemModeText {
                        Text("Consigliato per questo gioco: \(recommended).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Tempi e punti") {
                    configStepper("Countdown iniziale", value: $config.countdownSec, range: 5...600, step: 5, suffix: " s")
                    configStepper("Handshake", value: $config.handshakeWindowSec, range: 1...60, step: 1, suffix: " s")
                    configStepper("Sync team", value: $config.teamSyncWindowSec, range: 1...120, step: 1, suffix: " s")
                    configStepper("Cooldown coppia", value: $config.pairCooldownSec, range: 1...300, step: 1, suffix: " s")
                    configStepper("Cooldown player", value: $config.playerCooldownSec, range: 1...300, step: 1, suffix: " s")
                    configStepper("Penalty inattività", value: $config.inactivePenaltyBlockDurationSec, range: 30...1800, step: 30, suffix: " s")
                    configStepper("Punti iniziali", value: $config.startingPoints, range: 10...5000, step: 10, suffix: " pt")
                    configStepper("Duel transfer", value: $config.duelTransferPoints, range: 50...5000, step: 50, suffix: " pt")
                    configStepper("Cattura base", value: $config.baseCapturePoints, range: 100...50000, step: 100, suffix: " pt")
                    configStepper("Difesa base", value: $config.baseDefensePoints, range: 100...50000, step: 100, suffix: " pt")
                    configStepper("Moltiplicatore difesa", value: $config.baseDefenseMultiplier, range: 1...10, step: 1, suffix: "x")
                    configStepper("Durata difesa base", value: $config.baseDefenseDurationSec, range: 10...1200, step: 10, suffix: " s")
                    configStepper("Cooldown base", value: $config.baseDefenseCooldownSec, range: 10...1800, step: 10, suffix: " s")
                    configStepper("Finestra contatto base", value: $config.baseContactWindowSec, range: 1...60, step: 1, suffix: " s")
                }

                if !submissionError.isEmpty {
                    Section {
                        Text(submissionError)
                            .font(.footnote)
                            .foregroundStyle(BorderlandTheme.statusDangerText)
                    }
                }
            }
            .navigationTitle("Crea una partita")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(isSubmitting)
            .onAppear {
                if selectedGameDefinitionId.isEmpty, let first = catalog.first {
                    selectedGameDefinitionId = first.id
                    syncItemMode(with: first)
                }
                config.scanMode = .bracelet
            }
            .onChange(of: selectedGameDefinitionId) { _, newValue in
                guard let selected = catalog.first(where: { $0.id == newValue }) else { return }
                syncItemMode(with: selected)
            }
            .onChange(of: hostMode) { _, _ in
                if let selectedCatalogEntry {
                    syncItemMode(with: selectedCatalogEntry)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard let selectedCatalogEntry, !isSubmitting else { return }
                        isSubmitting = true
                        submissionError = ""
                        Task {
                            defer { isSubmitting = false }
                            do {
                                var normalizedConfig = config
                                normalizedConfig.scanMode = .bracelet
                                normalizedConfig.teamSyncWindowSec = max(
                                    normalizedConfig.teamSyncWindowSec,
                                    normalizedConfig.handshakeWindowSec
                                )
                                let setup = AutonomousGameSetup(
                                    hostMode: hostMode,
                                    teamAssignmentMode: teamAssignmentMode,
                                    creatorUid: nil
                                )
                                try await onSubmit(
                                    name,
                                    selectedCatalogEntry.id,
                                    normalizedConfig,
                                    itemMode,
                                    setup
                                )
                                dismiss()
                            } catch {
                                submissionError = error.localizedDescription
                            }
                        }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Crea")
                        }
                    }
                    .disabled(
                        isSubmitting ||
                        !canCreateGames ||
                        selectedCatalogEntry == nil ||
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }

    private var selectedCatalogEntry: GameCatalogEntry? {
        catalog.first(where: { $0.id == selectedGameDefinitionId }) ?? catalog.first
    }

    private var availableItemModes: [ItemMode] {
        let supportedModes = selectedCatalogEntry?.supportedItemModes ?? [.none]
        guard hostMode == .autonomous else { return supportedModes }
        let filtered = supportedModes.filter { $0 == .none || $0 == .crossTeam }
        return filtered.isEmpty ? [.none] : filtered
    }

    private var onlyCatalogEntry: GameCatalogEntry? {
        catalog.count == 1 ? catalog[0] : nil
    }

    private var matchDurationMinutes: Int {
        max(5, config.matchDurationSec / 60)
    }

    @ViewBuilder
    private func catalogCard(_ game: GameCatalogEntry, isSelected: Bool, allowsSelection: Bool) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(game.name)
                    .font(AppTypography.headline)
                    .foregroundStyle(BorderlandTheme.textPrimary)
                Text(game.shortDescription)
                    .font(AppTypography.caption)
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if allowsSelection {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? BorderlandTheme.gold : BorderlandTheme.textDim)
            }
        }
        .padding(.vertical, Spacing.xxs)
        .contentShape(Rectangle())
    }

    private func syncItemMode(with entry: GameCatalogEntry) {
        let candidateModes = hostMode == .autonomous
            ? entry.supportedItemModes.filter { $0 == .none || $0 == .crossTeam }
            : entry.supportedItemModes
        let safeModes = candidateModes.isEmpty ? [.none] : candidateModes
        if !safeModes.contains(itemMode) {
            itemMode = safeModes.contains(entry.defaultItemMode) ? entry.defaultItemMode : safeModes[0]
        }
    }

    @ViewBuilder
    private func configStepper(
        _ title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        suffix: String
    ) -> some View {
        Stepper(
            "\(title): \(value.wrappedValue)\(suffix)",
            value: value,
            in: range,
            step: step
        )
    }
}
