import SwiftUI

struct AdminHomeView: View {
    private enum AdminSection: String, CaseIterable, Identifiable {
        case overview, game, teams, logs
        var id: String { rawValue }
        var title: String {
            switch self {
            case .overview: return "Overview"
            case .game:     return "Game"
            case .teams:    return "Team"
            case .logs:     return "Log"
            }
        }
        var icon: String {
            switch self {
            case .overview: return "gauge.with.dots.needle.50percent"
            case .game:     return "slider.horizontal.3"
            case .teams:    return "person.3.fill"
            case .logs:     return "doc.text.magnifyingglass"
            }
        }
    }

    @StateObject private var viewModel: AdminViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedSection: AdminSection = .overview
    @State private var pendingGameDeletion: GameSummary? = nil
    @State private var hasAppeared = false
    let logoutAction: () async -> Void
    let switchToPlayerAction: (() -> Void)?
    let backAction: (() -> Void)?
    let initialGameId: String?

    init(
        viewModel: AdminViewModel,
        logoutAction: @escaping () async -> Void,
        switchToPlayerAction: (() -> Void)? = nil,
        backAction: (() -> Void)? = nil,
        initialGameId: String? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.logoutAction = logoutAction
        self.switchToPlayerAction = switchToPlayerAction
        self.backAction = backAction
        self.initialGameId = initialGameId
    }

    var body: some View {
        ZStack {
            SuitBackdrop(density: .light)
            FloatingParticles()
            Group {
                if viewModel.showingGamePicker {
                    if initialGameId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        consoleLoadingScreen
                    } else {
                        gamePickerScreen
                    }
                } else {
                    consoleScreen
                }
            }
            .opacity(hasAppeared ? 1 : 0)
            .animation(entranceAnimation, value: hasAppeared)
        }
        .borderlandBackground()
        .onDisappear { viewModel.stopRealtimeUpdates() }
        .onAppear { hasAppeared = true }
        .task {
            guard let initialGameId, !initialGameId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            viewModel.loadGame(gameId: initialGameId)
        }
    }

    private var entranceAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.3) : AnimationTokens.dramaticReveal
    }

    // MARK: – Game picker screen

    private var consoleLoadingScreen: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .tint(BorderlandTheme.gold)
                .scaleEffect(1.1)
            Text("Apro la console partita…")
                .font(AppTypography.callout)
                .foregroundStyle(BorderlandTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var gamePickerScreen: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Admin Console")
                        .font(AppTypography.title3)
                        .foregroundStyle(BorderlandTheme.gold)
                    Text("Seleziona o crea una partita")
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.textMuted)
                }
                Spacer()
                topBarButton("Logout") { Task { await logoutAction() } }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.sm)
            .background(BorderlandTheme.surface1.opacity(0.92))

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.md) {
                    // Games list
                    AdminPanel(title: "Le tue partite") {
                        if viewModel.isLoadingGames {
                            HStack(spacing: Spacing.sm) {
                                ProgressView().tint(BorderlandTheme.textMuted)
                                Text("Caricamento…").font(AppTypography.callout).foregroundStyle(BorderlandTheme.textMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, Spacing.sm)
                        } else if viewModel.availableGames.isEmpty {
                            Text("Nessuna partita trovata. Creane una nuova.")
                                .font(AppTypography.callout)
                                .foregroundStyle(BorderlandTheme.textMuted)
                                .padding(.vertical, Spacing.sm)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            gamePickerList
                        }

                        HStack {
                            Text("Swipe a sinistra per eliminare una partita dopo conferma.")
                                .font(AppTypography.caption2)
                                .foregroundStyle(BorderlandTheme.textMuted)
                            Spacer()
                            topBarButton("Aggiorna") {
                                viewModel.loadGamePicker()
                            }
                        }
                    }

                    // Create new game
                    AdminPanel(title: "Nuova Partita") {
                        VStack(spacing: Spacing.sm) {
                            TextField("Nome partita", text: $viewModel.gameName).adminField()
                            Picker("Modalità scan", selection: $viewModel.selectedScanMode) {
                                Text("Solo NFC").tag(ScanMode.bracelet)
                                Text("NFC + QR").tag(ScanMode.qr)
                            }
                            .pickerStyle(.segmented)
                            HStack {
                                Text("Durata").font(AppTypography.callout).foregroundStyle(BorderlandTheme.textMuted)
                                Spacer()
                                Stepper(value: $viewModel.matchDurationSec, in: 300...21600, step: 300) {
                                    Text("\(viewModel.matchDurationSec / 60) min")
                                        .font(AppTypography.callout)
                                        .foregroundStyle(BorderlandTheme.textPrimary)
                                }.fixedSize()
                            }
                            Button {
                                viewModel.createGameAndEnter()
                                HapticManager.lightTap()
                            } label: {
                                HStack(spacing: Spacing.xs) {
                                    if viewModel.isBusy {
                                        ProgressView().tint(.white).scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "plus.circle.fill").font(.system(size: 14))
                                    }
                                    Text(viewModel.isBusy ? "Creazione…" : "Crea partita")
                                        .font(AppTypography.callout)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(BorderlandTheme.surface3)
                                .overlay(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous).stroke(BorderlandTheme.borderGold, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
                                .opacity(viewModel.isBusy ? 0.6 : 1)
                            }
                            .buttonStyle(PressableStyle())
                            .disabled(viewModel.isBusy)
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        .task { viewModel.loadGamePicker() }
        .alert("Elimina partita", isPresented: Binding(
            get: { pendingGameDeletion != nil },
            set: { if !$0 { pendingGameDeletion = nil } }
        )) {
            Button("Elimina", role: .destructive) {
                if let game = pendingGameDeletion {
                    viewModel.deleteGame(game)
                }
                pendingGameDeletion = nil
            }
            Button("Annulla", role: .cancel) {
                pendingGameDeletion = nil
            }
        } message: {
            if let game = pendingGameDeletion {
                Text("Eliminare definitivamente dalla lista admin il game \"\(game.name)\" (\(game.id))? L'operazione archivia il game sul backend.")
            }
        }
    }

    private var gamePickerList: some View {
        List {
            ForEach(viewModel.availableGames) { game in
                Button {
                    viewModel.selectGame(game)
                    HapticManager.lightTap()
                } label: {
                    gamePickerRow(game)
                }
                .buttonStyle(PressableStyle())
                .disabled(viewModel.isBusy)
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        pendingGameDeletion = game
                    } label: {
                        Label("Elimina", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDisabled(viewModel.availableGames.count < 5)
        .frame(height: min(CGFloat(max(viewModel.availableGames.count, 1)) * 84, 360))
        .background(Color.clear)
    }

    private func gamePickerRow(_ game: GameSummary) -> some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(game.name)
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textPrimary)
                    .lineLimit(1)
                Text("\(game.id) · \(game.playerCount) giocatori")
                    .font(AppTypography.caption2)
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                if game.isActive {
                    Text("ATTIVO")
                        .font(AppTypography.caption2)
                        .foregroundStyle(BorderlandTheme.gold)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(BorderlandTheme.gold.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(BorderlandTheme.borderGold, lineWidth: 1))
                }
                Text(game.stateLabel)
                    .font(AppTypography.caption)
                    .foregroundStyle(gameStateColor(game.state))
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(gameStateColor(game.state).opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(gameStateColor(game.state).opacity(0.3), lineWidth: 1))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(BorderlandTheme.textDim)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(BorderlandTheme.surface3)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
    }

    private func gameStateColor(_ state: String) -> Color {
        switch state.uppercased() {
        case "LIVE":         return BorderlandTheme.statusOkText
        case "LOBBY":        return BorderlandTheme.gold
        case "DISTRIBUTION": return Color(hex: "#6BAED6")
        case "ARCHIVED":     return BorderlandTheme.crimson
        default:             return BorderlandTheme.textMuted
        }
    }

    // MARK: – Console screen (game selezionato)

    private var consoleScreen: some View {
        VStack(spacing: 0) {
            topBar
            sectionPills
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.sm)
                .background(BorderlandTheme.surface1.opacity(0.95))
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    sectionContent
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        // Player action sheet
        .confirmationDialog(
            viewModel.selectedPlayer.map { "\($0.nickname)" } ?? "",
            isPresented: $viewModel.showPlayerActions,
            titleVisibility: .visible
        ) {
            playerActionButtons
        }
        // Base NFC conflict
        .alert("Tag già assegnato", isPresented: Binding(
            get: { viewModel.baseConflict != nil },
            set: { if !$0 { viewModel.baseConflict = nil } }
        )) {
            Button("Sovrascrivi", role: .destructive) { viewModel.resolveBaseConflict(overwrite: true) }
            Button("Ignora", role: .cancel) { viewModel.resolveBaseConflict(overwrite: false) }
        } message: {
            if let c = viewModel.baseConflict {
                Text("Questo tag è già usato come base \(c.sourceTeamId). Vuoi spostarne l'assegnazione?")
            }
        }
        // Cross-identity conflict (base <-> item)
        .alert("Tag già associato", isPresented: Binding(
            get: { viewModel.tokenIdentityConflict != nil },
            set: { if !$0 { viewModel.tokenIdentityConflict = nil } }
        )) {
            Button("Sovrascrivi", role: .destructive) { viewModel.resolveTokenIdentityConflict(overwrite: true) }
            Button("Annulla", role: .cancel) { viewModel.resolveTokenIdentityConflict(overwrite: false) }
        } message: {
            if let conflict = viewModel.tokenIdentityConflict {
                Text(conflict.alertMessage)
            }
        }
        // Item already registered alert
        .alert("Oggetto già registrato", isPresented: Binding(
            get: { viewModel.pendingItemConflict != nil && viewModel.showItemPointsPrompt == false },
            set: { if !$0 { viewModel.pendingItemConflict = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.pendingItemConflict = nil }
        } message: {
            if let item = viewModel.pendingItemConflict {
                Text("quest'oggetto è già stato assegnato (\(item.icon) · \(item.points)pt)")
            }
        }
        // Item points prompt
        .sheet(isPresented: $viewModel.showItemPointsPrompt) {
            ItemPointsSheet(token: viewModel.pendingItemToken, points: $viewModel.newItemPoints) { pts in
                viewModel.confirmRegisterItem(token: viewModel.pendingItemToken, points: pts)
            }
        }
        // Tag lookup result sheet
        .sheet(item: Binding(
            get: { viewModel.scanResult },
            set: { if $0 == nil { viewModel.clearScanResult() } }
        )) { result in
            TagLookupSheet(result: result, onAddItem: {
                viewModel.clearScanResult()
                viewModel.scanAndAddItem()
            })
        }
        .sheet(item: Binding(
            get: { viewModel.qrCodePreview },
            set: { if $0 == nil { viewModel.qrCodePreview = nil } }
        )) { preview in
            QRCodeSheet(title: preview.title, subtitle: preview.subtitle, token: preview.token)
        }
    }

    // MARK: – Top bar

    private var topBar: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                if let backAction {
                    backAction()
                } else {
                    viewModel.backToGamePicker()
                }
                HapticManager.lightTap()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                    Text("Game").font(AppTypography.caption)
                }
                .foregroundStyle(BorderlandTheme.textMuted)
            }
            .buttonStyle(PressableStyle())

            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.gameName.isEmpty ? "Console" : viewModel.gameName)
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.gold)
                    .lineLimit(1)
                if !viewModel.activeGameId.isEmpty {
                    Text(viewModel.activeGameId)
                        .font(AppTypography.caption2)
                        .foregroundStyle(BorderlandTheme.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: Spacing.xs) {
                gameStatePill
                if let switchToPlayerAction {
                    topBarButton("Gioca") { switchToPlayerAction() }
                }
                topBarButton("Logout") { Task { await logoutAction() } }
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.vertical, Spacing.sm)
        .background(BorderlandTheme.surface1.opacity(0.92))
    }

    private func topBarButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.lightTap()
            action()
        } label: {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(BorderlandTheme.textMuted)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(BorderlandTheme.surface2, in: Capsule())
                .overlay(Capsule().stroke(BorderlandTheme.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private var gameStatePill: some View {
        Text(viewModel.gameState)
            .font(AppTypography.caption)
            .foregroundStyle(stateColor)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(stateColor.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(stateColor.opacity(0.30), lineWidth: 1))
    }

    private var stateColor: Color {
        switch viewModel.gameState.uppercased() {
        case "LIVE":         return BorderlandTheme.statusOkText
        case "LOBBY":        return BorderlandTheme.gold
        case "DISTRIBUTION": return Color(hex: "#6BAED6")
        default:             return BorderlandTheme.textMuted
        }
    }

    // MARK: – Section pills

    private var sectionPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(AdminSection.allCases) { section in
                    pillButton(section)
                }
            }
        }
    }

    private func pillButton(_ section: AdminSection) -> some View {
        let isSelected = section == selectedSection
        return Button {
            selectedSection = section
            HapticManager.lightTap()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: section.icon).font(.system(size: 12, weight: .semibold))
                Text(section.title).font(AppTypography.caption)
            }
            .foregroundStyle(isSelected ? BorderlandTheme.textPrimary : BorderlandTheme.textMuted)
            .padding(.horizontal, Spacing.md)
            .frame(height: 32)
            .background(isSelected ? BorderlandTheme.surface3 : BorderlandTheme.surface2, in: Capsule())
            .overlay(Capsule().stroke(isSelected ? BorderlandTheme.borderGold : BorderlandTheme.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: – Section router

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .overview: OverviewSectionView(viewModel: viewModel)
        case .game:     GameSectionView(viewModel: viewModel)
        case .teams:    TeamsSectionView(viewModel: viewModel)
        case .logs:     LogsSectionView(viewModel: viewModel)
        }
    }

    // MARK: – Player context menu buttons

    @ViewBuilder
    private var playerActionButtons: some View {
        if let player = viewModel.selectedPlayer {
            Button("Imposta Leader") { viewModel.setLeader(player) }

            if let teamId = player.teamId, !teamId.isEmpty {
                let other = teamId.uppercased() == "TEAM_A" ? "TEAM_B" : "TEAM_A"
                let otherLabel = other == "TEAM_A" ? "Giocatori" : "Cittadini"
                Button("Sposta in \(otherLabel)") { viewModel.assignPlayer(player, toTeam: other) }
                Button("Rimuovi da team") { viewModel.assignPlayer(player, toTeam: nil) }
            } else {
                Button("Aggiungi a Giocatori") { viewModel.assignPlayer(player, toTeam: "TEAM_A") }
                Button("Aggiungi a Cittadini") { viewModel.assignPlayer(player, toTeam: "TEAM_B") }
            }
            Button("Rimuovi dal game", role: .destructive) { viewModel.removePlayer(player) }
        }
    }
}

// MARK: – Overview section

private struct OverviewSectionView: View {
    @ObservedObject var viewModel: AdminViewModel
    @State private var showEndMatchConfirmation = false

    var body: some View {
        VStack(spacing: Spacing.md) {
            statusPanel
            accessPanel
            actionsPanel
            tagCheckPanel
        }
        .task { viewModel.loadGameItemsIfNeeded() }
    }

    private var statusPanel: some View {
        AdminPanel(title: "Stato Partita") {
            VStack(spacing: Spacing.sm) {
                statusRow("Partita", value: viewModel.gameName.isEmpty ? "Nessuna" : viewModel.gameName)
                statusRow("Stato", value: viewModel.gameState)
                statusRow("Modalità scan", value: "Braccialetto / tag NFC")
                statusRow("Durata", value: "\(viewModel.matchDurationSec / 60) min")
                HStack(spacing: Spacing.sm) {
                    counterChip("Giocatori", count: viewModel.teamAPlayers.count, color: BorderlandTheme.teamA)
                    counterChip("Cittadini", count: viewModel.teamBPlayers.count, color: BorderlandTheme.teamB)
                    counterChip("No team", count: viewModel.unassignedPlayers.count, color: BorderlandTheme.gold)
                }
            }
        }
    }

    private var accessPanel: some View {
        AdminPanel(title: "Accessi condivisibili") {
            VStack(spacing: Spacing.sm) {
                if !viewModel.playerJoinCode.isEmpty {
                    inviteRow(
                        title: "Player",
                        value: viewModel.playerJoinCode,
                        url: inviteURL(code: viewModel.playerJoinCode, isOperator: false),
                        shareText: inviteShareText(code: viewModel.playerJoinCode, isOperator: false),
                        onShowQRCode: {
                            viewModel.showInviteQRCode(code: viewModel.playerJoinCode, isOperator: false)
                        }
                    )
                }

                if !viewModel.operatorInviteCode.isEmpty {
                    inviteRow(
                        title: "Operatore",
                        value: viewModel.operatorInviteCode,
                        url: inviteURL(code: viewModel.operatorInviteCode, isOperator: true),
                        shareText: inviteShareText(code: viewModel.operatorInviteCode, isOperator: true),
                        onShowQRCode: {
                            viewModel.showInviteQRCode(code: viewModel.operatorInviteCode, isOperator: true)
                        }
                    )
                }

                if viewModel.playerJoinCode.isEmpty && viewModel.operatorInviteCode.isEmpty {
                    Text("I codici condivisibili non sono disponibili per questa partita.")
                        .font(AppTypography.callout)
                        .foregroundStyle(BorderlandTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var actionsPanel: some View {
        AdminPanel(title: "Azioni") {
            VStack(spacing: Spacing.sm) {
                if !viewModel.errorMessage.isEmpty {
                    errorBanner(viewModel.errorMessage)
                }
                HStack(spacing: Spacing.sm) {
                    BorderlandButton("Distribution", variant: .secondary, isEnabled: !viewModel.activeGameId.isEmpty && !viewModel.isBusy && (viewModel.isLobbyState || viewModel.isLiveState)) {
                        viewModel.transitionToDistribution()
                    }
                    BorderlandButton("Start Live", variant: .secondary, isEnabled: !viewModel.activeGameId.isEmpty && !viewModel.isBusy) {
                        viewModel.startLive()
                    }
                }
                HStack(spacing: Spacing.sm) {
                    BorderlandButton("End Match", variant: .danger, isEnabled: !viewModel.activeGameId.isEmpty && !viewModel.isBusy && viewModel.isLiveState) {
                        showEndMatchConfirmation = true
                    }
                    BorderlandButton("Leader Random", variant: .secondary, isEnabled: !viewModel.activeGameId.isEmpty && !viewModel.isBusy) {
                        viewModel.pickRandomLeaders()
                    }
                }
            }
            .confirmationDialog(
                "Terminare il match?",
                isPresented: $showEndMatchConfirmation,
                titleVisibility: .visible
            ) {
                Button("Termina per tutti", role: .destructive) {
                    viewModel.endMatch()
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("La partita finirà per tutti i giocatori. L'azione è irreversibile.")
            }
        }
    }

    private var tagCheckPanel: some View {
        AdminPanel(title: "Controllo Tag") {
            VStack(spacing: Spacing.sm) {
                Text("Scansiona qualsiasi tag per scoprire a cosa è associato nel game corrente.")
                    .font(AppTypography.caption)
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    viewModel.scanAndLookupTag()
                    HapticManager.lightTap()
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: viewModel.isScanning ? "antenna.radiowaves.left.and.right" : "wave.3.right")
                            .font(.system(size: 15, weight: .semibold))
                            .symbolEffect(.variableColor, isActive: viewModel.isScanning)
                        Text(viewModel.isScanning ? "Scansione in corso…" : "Controlla tag")
                            .font(AppTypography.callout)
                    }
                    .foregroundStyle(viewModel.canUseNFC ? BorderlandTheme.textPrimary : BorderlandTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(BorderlandTheme.surface3)
                    .overlay(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous).stroke(BorderlandTheme.borderSubtle, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
                    .opacity(viewModel.canUseNFC ? 1 : 0.5)
                }
                .buttonStyle(PressableStyle())
                .disabled(!viewModel.canUseNFC || viewModel.isBusy)
            }
        }
    }

    private func statusRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(AppTypography.caption).foregroundStyle(BorderlandTheme.textMuted)
            Spacer()
            Text(value).font(AppTypography.callout).foregroundStyle(BorderlandTheme.textPrimary).lineLimit(1)
        }
    }

    private func counterChip(_ label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 1) {
            Text("\(count)").font(AppTypography.title3).foregroundStyle(color)
            Text(label).font(AppTypography.caption2).foregroundStyle(BorderlandTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xs)
        .background(color.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous).stroke(color.opacity(0.20), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
    }

    private func inviteRow(
        title: String,
        value: String,
        url: URL?,
        shareText: String,
        onShowQRCode: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundStyle(BorderlandTheme.textPrimary)
                Spacer()
                HStack(spacing: Spacing.sm) {
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
                }
            }

            Text(value)
                .font(AppTypography.callout)
                .foregroundStyle(BorderlandTheme.gold)
                .textSelection(.enabled)

            if let url {
                Text(url.absoluteString)
                    .font(AppTypography.caption2)
                    .foregroundStyle(BorderlandTheme.textDim)
                    .textSelection(.enabled)
            }
        }
        .padding(Spacing.sm)
        .background(BorderlandTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
    }

    private func inviteURL(code: String, isOperator: Bool) -> URL? {
        AppConfig.inviteLandingURL(
            code: code,
            isOperatorInvite: isOperator
        )
    }

    private func inviteShareText(code: String, isOperator: Bool) -> String {
        AppConfig.inviteShareText(
            code: code,
            isOperatorInvite: isOperator
        )
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(BorderlandTheme.statusDangerText)
            Text(msg)
                .font(AppTypography.caption)
                .foregroundStyle(BorderlandTheme.statusDangerText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.sm)
        .background(BorderlandTheme.statusDanger.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
    }
}

// MARK: – Game section

private struct GameSectionView: View {
    @ObservedObject var viewModel: AdminViewModel

    private enum GameTab: String, Identifiable {
        case config = "Configurazione"
        case objects = "Oggetti del game"

        var id: String { rawValue }
    }

    @State private var selectedTab: GameTab = .config

    var body: some View {
        VStack(spacing: Spacing.md) {
            if availableTabs.count > 1 {
                subPills
            }
            tabContent
        }
        .onAppear {
            viewModel.loadGameItemsIfNeeded()
            normalizeSelectedTab()
        }
        .onChange(of: viewModel.itemMode) { _, _ in
            normalizeSelectedTab()
        }
    }

    private var availableTabs: [GameTab] {
        viewModel.itemMode == .shared ? [.config, .objects] : [.config]
    }

    private var subPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(availableTabs) { tab in
                    subPill(tab)
                }
            }
        }
    }

    private func subPill(_ tab: GameTab) -> some View {
        let isSelected = tab == selectedTab
        return Button {
            selectedTab = tab
            HapticManager.lightTap()
        } label: {
            Text(tab.rawValue)
                .font(AppTypography.caption)
                .foregroundStyle(isSelected ? BorderlandTheme.textPrimary : BorderlandTheme.textMuted)
                .padding(.horizontal, Spacing.sm)
                .frame(height: 28)
                .background(isSelected ? BorderlandTheme.surface3 : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(isSelected ? BorderlandTheme.borderGold : BorderlandTheme.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .config:
            configTab
        case .objects:
            sharedObjectsTab
        }
    }

    private var configTab: some View {
        AdminPanel(title: "Configurazione") {
            VStack(spacing: Spacing.sm) {
                configSection(
                    title: "Partita",
                    subtitle: "Informazioni fisse e non modificabili del game corrente."
                ) {
                    infoRow("Nome partita", value: viewModel.gameName.isEmpty ? "Nessuna" : viewModel.gameName)
                    infoRow("ID partita", value: viewModel.activeGameId.isEmpty ? "Nessuno" : viewModel.activeGameId)
                    infoRow("Modalità scan", value: viewModel.scanModeStatusLabel)
                }

                configSection(
                    title: "Setup match",
                    subtitle: "Tempi e modalità realmente usati dal gioco."
                ) {
                    Picker("Modalità scan", selection: $viewModel.selectedScanMode) {
                        Text("Solo NFC").tag(ScanMode.bracelet)
                        Text("NFC + QR").tag(ScanMode.qr)
                    }
                    .pickerStyle(.segmented)

                    Text("Solo NFC mantiene il comportamento attuale. NFC + QR aggiunge QR per basi, oggetti e giocatori.")
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.textMuted)

                    Picker("Modalità oggetti", selection: $viewModel.itemMode) {
                        ForEach(ItemMode.allCases, id: \.self) { mode in
                            Text(mode.displayLabel).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(viewModel.itemMode.helperText)
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.textMuted)

                    ruleAdjusterRow(
                        title: "Durata match",
                        value: $viewModel.matchDurationSec,
                        range: 300...21_600,
                        step: 300,
                        formatter: { "\($0 / 60) min" }
                    )

                    ruleAdjusterRow(
                        title: "Countdown pre-live",
                        value: $viewModel.countdownSec,
                        range: 1...600,
                        step: 5,
                        formatter: { "\($0) s" }
                    )

                    TextField("Timezone", text: $viewModel.timezone)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .adminField()
                }

                configSection(
                    title: "Scontri",
                    subtitle: "Finestre e blocchi usati dal backend durante il gameplay."
                ) {
                    ruleAdjusterRow(
                        title: "Punti scontro",
                        value: $viewModel.duelTransferPoints,
                        range: 100...20_000,
                        step: 100,
                        formatter: { "\($0) pt" }
                    )
                    ruleAdjusterRow(
                        title: "Handshake reciproco",
                        value: $viewModel.handshakeWindowSec,
                        range: 1...30,
                        step: 1,
                        formatter: { "\($0) s" }
                    )
                    ruleAdjusterRow(
                        title: "Cooldown stessa coppia",
                        value: $viewModel.pairCooldownSec,
                        range: 1...120,
                        step: 1,
                        formatter: { "\($0) s" }
                    )
                    ruleAdjusterRow(
                        title: "Cooldown player",
                        value: $viewModel.playerCooldownSec,
                        range: 1...120,
                        step: 1,
                        formatter: { "\($0) s" }
                    )
                    ruleAdjusterRow(
                        title: "Blocco inattivo",
                        value: $viewModel.inactivePenaltyBlockDurationSec,
                        range: 60...3_600,
                        step: 60,
                        formatter: { "\($0 / 60) min" }
                    )
                }

                configSection(
                    title: "Gruppi, basi e distribuzione",
                    subtitle: "Setup reale di sync team, base potenziata e punti iniziali."
                ) {
                    ruleAdjusterRow(
                        title: "Finestra gruppo",
                        value: $viewModel.teamSyncWindowSec,
                        range: 1...30,
                        step: 1,
                        formatter: { "\($0) s" }
                    )
                    ruleAdjusterRow(
                        title: "Moltiplicatore difesa base",
                        value: $viewModel.baseDefenseMultiplier,
                        range: 1...10,
                        step: 1,
                        formatter: { "\($0)x" }
                    )
                    ruleAdjusterRow(
                        title: "Durata potenziamento base",
                        value: $viewModel.baseDefenseDurationSec,
                        range: 30...900,
                        step: 30,
                        formatter: { $0 % 60 == 0 ? "\($0 / 60) min" : "\($0) s" }
                    )
                    ruleAdjusterRow(
                        title: "Cooldown riattivazione base",
                        value: $viewModel.baseDefenseCooldownSec,
                        range: 60...1800,
                        step: 60,
                        formatter: { "\($0 / 60) min" }
                    )
                    ruleAdjusterRow(
                        title: "Reward base nemica",
                        value: $viewModel.baseCapturePoints,
                        range: 100...50_000,
                        step: 500,
                        formatter: { "\($0) pt" }
                    )
                    ruleAdjusterRow(
                        title: "Punti iniziali player",
                        value: $viewModel.startingPoints,
                        range: 1...10_000,
                        step: 100,
                        formatter: { "\($0) pt" }
                    )
                }

                if viewModel.itemMode == .crossTeam {
                    infoNote("Gli oggetti cross-team si gestiscono dentro le tab dei team, non qui.")
                }

                HStack(spacing: Spacing.sm) {
                    BorderlandButton("Ripristina configurazione iniziale", variant: .ghost, isEnabled: !viewModel.isBusy) {
                        viewModel.resetConfigToLoaded()
                    }
                    BorderlandButton("Salva", variant: .secondary, isEnabled: !viewModel.activeGameId.isEmpty && !viewModel.isBusy) {
                        viewModel.saveGameConfig()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func configSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundStyle(BorderlandTheme.textPrimary)
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(BorderlandTheme.textMuted)
            }
            content()
        }
        .padding(Spacing.md)
        .background(BorderlandTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func ruleAdjusterRow(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        formatter: @escaping (Int) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(title)
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textMuted)
                Spacer(minLength: Spacing.md)
                Text(formatter(value.wrappedValue))
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textPrimary)
            }

            HStack(spacing: Spacing.xs) {
                adjustButton(
                    systemImage: "minus",
                    amount: -step,
                    value: value,
                    range: range,
                    fastOptions: [-step * 5, -step * 10]
                )

                adjustButton(
                    systemImage: "plus",
                    amount: step,
                    value: value,
                    range: range,
                    fastOptions: [step * 5, step * 10]
                )
            }
        }
    }

    private func adjustButton(
        systemImage: String,
        amount: Int,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        fastOptions: [Int]
    ) -> some View {
        Button {
            HapticManager.lightTap()
            value.wrappedValue = min(max(value.wrappedValue + amount, range.lowerBound), range.upperBound)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(BorderlandTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(BorderlandTheme.surface3)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
                        .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(PressableStyle())
        .contextMenu {
            ForEach(fastOptions, id: \.self) { option in
                let signedLabel = option > 0 ? "+\(option)" : "\(option)"
                Button(signedLabel) {
                    value.wrappedValue = min(
                        max(value.wrappedValue + option, range.lowerBound),
                        range.upperBound
                    )
                }
            }
        }
    }

    private var sharedObjectsTab: some View {
        AdminPanel(title: "Oggetti del game · \(viewModel.gameItems.count)") {
            if viewModel.gameItems.isEmpty {
                Text("Nessun oggetto registrato in questo game.")
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .padding(.vertical, Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(viewModel.gameItems) { item in
                        AdminGameItemCard(
                            item: item,
                            accent: BorderlandTheme.gold,
                            teamLabel: item.collectorTeamId.flatMap { teamId in
                                teamId.isEmpty ? nil : viewModel.teamLabel(for: teamId)
                            },
                            showsQRCodeAction: viewModel.isQREnabled,
                            canUseNFC: viewModel.canUseNFC,
                            isBusy: viewModel.isBusy,
                            onShowQRCode: { viewModel.showItemQRCode(item) },
                            onAttachNFC: { viewModel.attachNFCToken(to: item) }
                        )
                    }
                }
            }
            VStack(spacing: Spacing.sm) {
                if viewModel.isQREnabled {
                    infoNote("In NFC + QR gli oggetti vengono creati subito e il tag NFC puo essere collegato dopo.")
                }

                nfcActionButton(
                    label: "Aggiungi oggetto",
                    loadingLabel: "Scansione in corso…",
                    icon: viewModel.isQREnabled ? "qrcode.viewfinder" : "wave.3.right",
                    isLoading: viewModel.isScanning,
                    isEnabled: !viewModel.isBusy && !viewModel.activeGameId.isEmpty && viewModel.canRegisterItems && (viewModel.isQREnabled || viewModel.canUseNFC)
                ) {
                    viewModel.startAddItemFlow()
                }

                nfcActionButton(
                    label: "Controlla tag oggetto",
                    loadingLabel: "Verifica in corso…",
                    icon: "wave.3.right",
                    isLoading: viewModel.isScanning,
                    isEnabled: viewModel.canUseNFC && !viewModel.isBusy && !viewModel.activeGameId.isEmpty
                ) {
                    viewModel.scanCheckItem()
                }

                if !viewModel.canUseNFC && !viewModel.isQREnabled {
                    nfcUnavailableNote
                } else if viewModel.activeGameId.isEmpty {
                    infoNote("Crea o carica un game prima di registrare oggetti.")
                }
            }
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(label)
                .font(AppTypography.callout)
                .foregroundStyle(BorderlandTheme.textMuted)
            Spacer()
            Text(value)
                .font(AppTypography.callout)
                .foregroundStyle(BorderlandTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func normalizeSelectedTab() {
        if !availableTabs.contains(selectedTab) {
            selectedTab = .config
        }
    }

    private func nfcActionButton(label: String, loadingLabel: String, icon: String, isLoading: Bool, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticManager.lightTap()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: isLoading ? "antenna.radiowaves.left.and.right" : icon)
                    .font(.system(size: 15, weight: .semibold))
                    .symbolEffect(.variableColor, isActive: isLoading)
                Text(isLoading ? loadingLabel : label).font(AppTypography.callout)
            }
            .foregroundStyle(isEnabled ? BorderlandTheme.textPrimary : BorderlandTheme.textMuted)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(BorderlandTheme.surface3)
            .overlay(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous).stroke(BorderlandTheme.borderSubtle, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled)
    }

    private var nfcUnavailableNote: some View {
        infoNote("NFC non disponibile su questo dispositivo.")
    }

    private func infoNote(_ text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "info.circle").font(.system(size: 13))
            Text(text).font(AppTypography.caption)
        }
        .foregroundStyle(BorderlandTheme.textMuted)
        .padding(Spacing.sm)
        .background(BorderlandTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
    }
}

// MARK: – Teams section

private struct TeamsSectionView: View {
    @ObservedObject var viewModel: AdminViewModel

    private enum TeamTab: String, CaseIterable, Identifiable {
        case teamA = "Giocatori"
        case teamB = "Cittadini"
        case unassigned = "Senza team"
        var id: String { rawValue }
        var teamId: String? {
            switch self { case .teamA: return "TEAM_A"; case .teamB: return "TEAM_B"; case .unassigned: return nil }
        }
        var accent: Color {
            switch self { case .teamA: return BorderlandTheme.teamA; case .teamB: return BorderlandTheme.teamB; case .unassigned: return BorderlandTheme.gold }
        }
    }

    @State private var selectedTab: TeamTab = .teamA

    var body: some View {
        VStack(spacing: Spacing.md) {
            subPills
            teamContent
        }
        .onAppear { normalizeSelectedTab() }
        .onChange(of: viewModel.unassignedPlayers.count) { _, _ in normalizeSelectedTab() }
    }

    private var subPills: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(displayedTabs) { tab in
                teamPill(tab)
            }
        }
    }

    private var displayedTabs: [TeamTab] {
        if viewModel.unassignedPlayers.isEmpty {
            return [.teamA, .teamB]
        }
        return TeamTab.allCases
    }

    private func teamPill(_ tab: TeamTab) -> some View {
        let isSelected = tab == selectedTab
        let count = playerCount(for: tab)
        return Button {
            selectedTab = tab
            HapticManager.lightTap()
        } label: {
            HStack(spacing: 4) {
                Circle().fill(tab.accent).frame(width: 7, height: 7)
                Text(tab.rawValue).font(AppTypography.caption).lineLimit(1)
                Text("·").font(AppTypography.caption).foregroundStyle(BorderlandTheme.textDim)
                Text("\(count)").font(AppTypography.caption)
            }
            .foregroundStyle(isSelected ? BorderlandTheme.textPrimary : BorderlandTheme.textMuted)
            .padding(.horizontal, Spacing.sm)
            .frame(height: 30)
            .frame(maxWidth: .infinity)
            .background(isSelected ? BorderlandTheme.surface3 : Color.clear, in: RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous).stroke(isSelected ? tab.accent.opacity(0.4) : BorderlandTheme.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private func playerCount(for tab: TeamTab) -> Int {
        switch tab {
        case .teamA: return viewModel.teamAPlayers.count
        case .teamB: return viewModel.teamBPlayers.count
        case .unassigned: return viewModel.unassignedPlayers.count
        }
    }

    @ViewBuilder
    private var teamContent: some View {
        switch selectedTab {
        case .teamA:
            teamPanel(tab: .teamA, players: viewModel.teamAPlayers, baseToken: viewModel.teamABaseToken, baseQrToken: viewModel.teamABaseQrToken, baseBinding: $viewModel.teamABaseToken)
        case .teamB:
            teamPanel(tab: .teamB, players: viewModel.teamBPlayers, baseToken: viewModel.teamBBaseToken, baseQrToken: viewModel.teamBBaseQrToken, baseBinding: $viewModel.teamBBaseToken)
        case .unassigned:
            unassignedPanel
        }
    }

    private func teamPanel(tab: TeamTab, players: [AdminGameStatus.Participant], baseToken: String, baseQrToken: String, baseBinding: Binding<String>) -> some View {
        VStack(spacing: Spacing.md) {
            // Base assignment card
            AdminPanel(title: viewModel.isQREnabled ? "Base · NFC + QR" : "Base NFC") {
                VStack(spacing: Spacing.sm) {
                    if viewModel.isQREnabled, !baseQrToken.isEmpty {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "qrcode")
                                .foregroundStyle(tab.accent)
                                .font(.system(size: 15, weight: .semibold))
                            Text("QR pronto")
                                .font(AppTypography.callout)
                                .foregroundStyle(BorderlandTheme.textPrimary)
                            Spacer()
                            capsuleActionButton("QR code", tint: tab.accent) {
                                viewModel.showBaseQRCode(teamId: tab.teamId ?? "")
                            }
                        }
                    }

                    if baseToken.isEmpty {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "mappin.slash").foregroundStyle(BorderlandTheme.textMuted).font(.system(size: 14))
                            Text(viewModel.isQREnabled ? "tag NFC opzionale non assegnato" : "non assegnata")
                                .font(AppTypography.callout)
                                .foregroundStyle(BorderlandTheme.textMuted)
                            Spacer()
                            Button {
                                viewModel.scanBaseToken(teamId: tab.teamId ?? "")
                                HapticManager.lightTap()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "wave.3.right").font(.system(size: 11, weight: .semibold))
                                    Text(viewModel.isQREnabled ? "Assegna tag NFC" : "Assegna base").font(AppTypography.caption)
                                }
                                .foregroundStyle(tab.accent)
                                .padding(.horizontal, Spacing.sm)
                                .frame(height: 28)
                                .background(tab.accent.opacity(0.10), in: Capsule())
                                .overlay(Capsule().stroke(tab.accent.opacity(0.30), lineWidth: 1))
                            }
                            .buttonStyle(PressableStyle())
                            .disabled(!viewModel.canUseNFC || viewModel.isBusy)
                        }
                    } else {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "mappin.circle.fill").foregroundStyle(tab.accent).font(.system(size: 16))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(baseToken)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(BorderlandTheme.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text("Tag NFC")
                                    .font(AppTypography.caption2)
                                    .foregroundStyle(BorderlandTheme.textMuted)
                            }
                            Spacer()
                            capsuleActionButton("Cambia", tint: BorderlandTheme.textMuted) {
                                viewModel.scanBaseToken(teamId: tab.teamId ?? "")
                            }
                            .disabled(!viewModel.canUseNFC || viewModel.isBusy)
                        }
                    }

                    if viewModel.isScanning && viewModel.pendingNFCTeamId == tab.teamId {
                        HStack(spacing: Spacing.xs) {
                            ProgressView().scaleEffect(0.7)
                            Text("Avvicina il tag NFC…").font(AppTypography.caption).foregroundStyle(BorderlandTheme.textMuted)
                        }
                    }
                }
            }

            // Players list
            AdminPanel(title: "Giocatori · \(players.count)") {
                if players.isEmpty {
                    Text("Nessun giocatore assegnato")
                        .font(AppTypography.callout)
                        .foregroundStyle(BorderlandTheme.textMuted)
                        .padding(.vertical, Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    VStack(spacing: Spacing.xs) {
                        ForEach(players) { player in
                            playerRow(player, accent: tab.accent)
                        }
                    }
                }
            }

            if viewModel.itemMode == .crossTeam, let teamId = tab.teamId {
                crossTeamItemsPanel(teamId: teamId, accent: tab.accent)
            }
        }
    }

    private var unassignedPanel: some View {
        AdminPanel(title: "Senza team · \(viewModel.unassignedPlayers.count)") {
            if viewModel.unassignedPlayers.isEmpty {
                Text("Tutti i giocatori sono stati assegnati a un team.")
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .padding(.vertical, Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(viewModel.unassignedPlayers) { player in
                        playerRow(player, accent: BorderlandTheme.gold)
                    }
                }
            }
        }
    }

    private func playerRow(_ player: AdminGameStatus.Participant, accent: Color) -> some View {
        Button {
            HapticManager.lightTap()
            viewModel.selectPlayer(player)
        } label: {
            HStack(spacing: Spacing.sm) {
                ZStack(alignment: .topTrailing) {
                    AvatarView(
                        avatarDataUrl: player.avatarDataUrl,
                        initials: initials(from: player.nickname),
                        size: .small
                    )
                    if player.isLeader {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(BorderlandTheme.gold)
                            .padding(3)
                            .background(BorderlandTheme.surface1, in: Circle())
                            .offset(x: 5, y: -5)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xxs) {
                        Text(player.nickname)
                            .font(AppTypography.callout)
                            .foregroundStyle(BorderlandTheme.textPrimary)
                        if player.isLeader {
                            Text("Leader").font(AppTypography.caption2).foregroundStyle(BorderlandTheme.gold)
                        }
                    }
                    if let card = player.playingCard, !card.isEmpty {
                        Text(card).font(AppTypography.caption2).foregroundStyle(BorderlandTheme.textMuted)
                    }
                }

                Spacer()

                Image(systemName: "ellipsis").font(.system(size: 13)).foregroundStyle(BorderlandTheme.textDim)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(BorderlandTheme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
            .overlay(
                player.isLeader ?
                RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous).stroke(BorderlandTheme.gold.opacity(0.25), lineWidth: 1)
                : nil
            )
        }
        .buttonStyle(PressableStyle())
    }

    private func crossTeamItemsPanel(teamId: String, accent: Color) -> some View {
        let items = viewModel.gameItems.filter { ($0.collectorTeamId ?? "").uppercased() == teamId.uppercased() }

        return AdminPanel(title: "Oggetti della squadra · \(items.count)") {
            VStack(spacing: Spacing.sm) {
                Button {
                    HapticManager.lightTap()
                    viewModel.selectedItemCollectorTeamId = teamId
                    viewModel.startAddItemFlow()
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Aggiungi oggetto")
                            .font(AppTypography.callout)
                    }
                    .foregroundStyle((viewModel.isQREnabled || viewModel.canUseNFC) ? BorderlandTheme.textPrimary : BorderlandTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(BorderlandTheme.surface3)
                    .overlay(
                        RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
                            .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
                    .opacity((viewModel.isQREnabled || viewModel.canUseNFC) && !viewModel.isBusy ? 1 : 0.45)
                }
                .buttonStyle(PressableStyle())
                .disabled((!viewModel.isQREnabled && !viewModel.canUseNFC) || viewModel.isBusy || viewModel.activeGameId.isEmpty)

                if items.isEmpty {
                    Text("Nessun oggetto assegnato a questa squadra.")
                        .font(AppTypography.callout)
                        .foregroundStyle(BorderlandTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: Spacing.xs) {
                        ForEach(items) { item in
                            AdminGameItemCard(
                                item: item,
                                accent: accent,
                                teamLabel: item.collectorTeamId.flatMap { collectorTeamId in
                                    collectorTeamId.isEmpty ? nil : viewModel.teamLabel(for: collectorTeamId)
                                },
                                showsQRCodeAction: viewModel.isQREnabled,
                                canUseNFC: viewModel.canUseNFC,
                                isBusy: viewModel.isBusy,
                                onShowQRCode: { viewModel.showItemQRCode(item) },
                                onAttachNFC: { viewModel.attachNFCToken(to: item) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func capsuleActionButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.lightTap()
            action()
        } label: {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(tint)
                .padding(.horizontal, Spacing.sm)
                .frame(height: 26)
                .background(BorderlandTheme.surface3, in: Capsule())
                .overlay(Capsule().stroke(BorderlandTheme.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
    

    private func initials(from value: String) -> String {
        let letters = value.split(separator: " ").compactMap { $0.first }
        let compact = letters.prefix(2).map(String.init).joined().uppercased()
        return compact.isEmpty ? "?" : compact
    }

    private func normalizeSelectedTab() {
        if !displayedTabs.contains(selectedTab) {
            selectedTab = .teamA
        }
    }
}

// MARK: – Logs section

private struct LogsSectionView: View {
    @ObservedObject var viewModel: AdminViewModel

    var body: some View {
        AdminPanel(title: "Log Eventi") {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Timeline backend")
                            .font(AppTypography.callout)
                            .foregroundStyle(BorderlandTheme.textPrimary)
                        if let export = viewModel.backendEventExport {
                            Text(export.truncated
                                 ? "Mostro \(export.entries.count) eventi su \(export.totalEventCount)."
                                 : "\(export.entries.count) eventi esportati.")
                                .font(AppTypography.caption2)
                                .foregroundStyle(BorderlandTheme.textMuted)
                        } else {
                            Text("Scarica l’export completo del game dal backend.")
                                .font(AppTypography.caption2)
                                .foregroundStyle(BorderlandTheme.textMuted)
                        }
                    }

                    Spacer(minLength: 0)

                    logActionButton(
                        viewModel.isLoadingBackendEventExport ? "Aggiorno..." : "Aggiorna"
                    ) {
                        viewModel.refreshBackendEventExport()
                    }
                    .disabled(viewModel.isLoadingBackendEventExport)

                    logActionButton("Copia export") {
                        viewModel.copyBackendEventExport()
                    }
                    .disabled(viewModel.backendEventExport == nil)
                }

                if viewModel.isLoadingBackendEventExport && viewModel.backendEventExport == nil {
                    HStack(spacing: Spacing.sm) {
                        ProgressView().tint(BorderlandTheme.textMuted)
                        Text("Caricamento timeline backend…")
                            .font(AppTypography.callout)
                            .foregroundStyle(BorderlandTheme.textMuted)
                    }
                    .padding(.vertical, Spacing.sm)
                } else if let export = viewModel.backendEventExport, !export.entries.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        ForEach(Array(export.entries.reversed().prefix(60))) { entry in
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                ActivityLogItem(
                                    timestamp: entry.timestampLabel,
                                    message: "[\(entry.type)] \(entry.message)",
                                    variant: backendVariant(for: entry.severity)
                                )

                                Text(entry.payloadJson)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(BorderlandTheme.textDim)
                                    .lineLimit(4)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.bottom, 2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(BorderlandTheme.surface3.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
                        }
                    }
                } else {
                    Text("Nessun evento backend esportato per questo game.")
                        .font(AppTypography.callout)
                        .foregroundStyle(BorderlandTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, Spacing.md)
                }

                Divider()
                    .overlay(BorderlandTheme.borderSubtle)
                    .padding(.vertical, 2)

                Text("Console locale")
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textPrimary)

                if viewModel.logLines.isEmpty {
                    Text("Nessun evento locale registrato")
                        .font(AppTypography.callout)
                        .foregroundStyle(BorderlandTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, Spacing.sm)
                } else {
                    VStack(spacing: Spacing.xs) {
                        ForEach(Array(viewModel.logLines.prefix(30).enumerated()), id: \.offset) { _, line in
                            let parsed = parseLogLine(line)
                            ActivityLogItem(timestamp: parsed.time, message: parsed.message, variant: logVariant(for: parsed.message))
                        }
                    }
                }
            }
        }
        .onAppear {
            if viewModel.backendEventExport == nil && !viewModel.activeGameId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.refreshBackendEventExport()
            }
        }
    }

    private func parseLogLine(_ line: String) -> (time: String, message: String) {
        guard line.hasPrefix("["), let close = line.firstIndex(of: "]") else { return ("--:--:--", line) }
        let time = String(line[line.index(after: line.startIndex)..<close])
        let msg = line[line.index(after: close)...].trimmingCharacters(in: .whitespacesAndNewlines)
        return (time, msg.isEmpty ? line : msg)
    }

    private func logVariant(for message: String) -> ActivityLogItem.Variant {
        let lower = message.lowercased()
        if lower.contains("errore") || lower.contains("fallita") || lower.contains("failed") { return .error }
        if lower.contains("mancante") || lower.contains("warning") { return .warn }
        return .ok
    }

    private func backendVariant(for severity: String) -> ActivityLogItem.Variant {
        switch severity.uppercased() {
        case "ERROR":
            return .error
        case "WARNING":
            return .warn
        default:
            return .ok
        }
    }

    private func logActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.lightTap()
            action()
        } label: {
            Text(title)
                .font(AppTypography.caption2)
                .foregroundStyle(BorderlandTheme.textMuted)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(BorderlandTheme.surface3, in: Capsule())
                .overlay(Capsule().stroke(BorderlandTheme.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

private struct AdminGameItemCard: View {
    let item: AdminGameStatus.GameItem
    let accent: Color
    let teamLabel: String?
    let showsQRCodeAction: Bool
    let canUseNFC: Bool
    let isBusy: Bool
    let onShowQRCode: () -> Void
    let onAttachNFC: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 32, height: 32)
                    .background(BorderlandTheme.surface3)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.id)
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.textPrimary)
                        .lineLimit(1)
                    if let teamLabel, !teamLabel.isEmpty {
                        Text("Raccoglibile da \(teamLabel)")
                            .font(AppTypography.caption2)
                            .foregroundStyle(accent)
                    }
                    if let nfcToken = item.nfcToken, !nfcToken.isEmpty {
                        Text("NFC: \(nfcToken)")
                            .font(AppTypography.caption2)
                            .foregroundStyle(BorderlandTheme.textMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("NFC non collegato")
                            .font(AppTypography.caption2)
                            .foregroundStyle(BorderlandTheme.textMuted)
                    }
                }

                Spacer()

                Text("\(item.points)pt")
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textPrimary)
            }

            HStack(spacing: Spacing.xs) {
                if showsQRCodeAction, let qrToken = item.qrToken, !qrToken.isEmpty {
                    smallActionButton("QR code", systemImage: "qrcode", tint: accent, isEnabled: true, action: onShowQRCode)
                }
                if canUseNFC {
                    smallActionButton(
                        item.nfcToken == nil ? "Collega tag NFC" : "Aggiorna tag NFC",
                        systemImage: "wave.3.right",
                        tint: BorderlandTheme.textMuted,
                        isEnabled: !isBusy,
                        action: onAttachNFC
                    )
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(BorderlandTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
    }

    private func smallActionButton(
        _ title: String,
        systemImage: String,
        tint: Color,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.lightTap()
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(AppTypography.caption2)
            }
            .foregroundStyle(isEnabled ? tint : BorderlandTheme.textDim)
            .padding(.horizontal, Spacing.sm)
            .frame(height: 28)
            .background(BorderlandTheme.surface3, in: Capsule())
            .overlay(Capsule().stroke(BorderlandTheme.borderSubtle, lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled)
    }
}

// MARK: – Item points sheet

private struct ItemPointsSheet: View {
    let token: String?
    @Binding var points: Int
    let onConfirm: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                BorderlandTheme.surface1.ignoresSafeArea()
                VStack(spacing: Spacing.xl) {
                    Capsule()
                        .fill(BorderlandTheme.borderSubtle)
                        .frame(width: 38, height: 4)
                        .padding(.top, Spacing.sm)

                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(BorderlandTheme.gold)
                        Text("Nuovo oggetto")
                            .font(AppTypography.title3)
                            .foregroundStyle(BorderlandTheme.textPrimary)
                        if let token, !token.isEmpty {
                            Text(token)
                                .font(AppTypography.caption)
                                .foregroundStyle(BorderlandTheme.textMuted)
                        } else {
                            Text("Viene creato subito con QR dedicato. Il tag NFC potra essere collegato dopo.")
                                .font(AppTypography.caption)
                                .foregroundStyle(BorderlandTheme.textMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Spacing.xl)
                        }
                    }

                    VStack(spacing: Spacing.sm) {
                        Text("Quanti punti vale questo oggetto?")
                            .font(AppTypography.callout)
                            .foregroundStyle(BorderlandTheme.textMuted)

                        Text("\(points) pt")
                            .font(AppTypography.title2)
                            .foregroundStyle(BorderlandTheme.gold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(BorderlandTheme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))

                        Text("Il valore non e limitato a 1000: usa i controlli rapidi finche serve.")
                            .font(AppTypography.caption)
                            .foregroundStyle(BorderlandTheme.textDim)
                            .multilineTextAlignment(.center)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: Spacing.sm),
                                GridItem(.flexible(), spacing: Spacing.sm)
                            ],
                            spacing: Spacing.sm
                        ) {
                            ForEach([10, 100, 500, 1000, 5000, 10000], id: \.self) { value in
                                quickAdjustControl(step: value)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.xl)

                    Spacer()

                    VStack(spacing: Spacing.sm) {
                        BorderlandButton("Registra oggetto", variant: .secondary) {
                            onConfirm(points)
                            dismiss()
                        }
                        BorderlandButton("Annulla", variant: .ghost) { dismiss() }
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, Spacing.xl)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func quickAdjustControl(step: Int) -> some View {
        HStack(spacing: Spacing.xs) {
            Button {
                HapticManager.lightTap()
                adjustPoints(by: -step)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BorderlandTheme.textPrimary)
                    .frame(width: 28, height: 28)
                    .background(BorderlandTheme.surface3)
                    .clipShape(Circle())
            }
            .buttonStyle(PressableStyle())

            Text("\(step)")
                .font(AppTypography.callout)
                .foregroundStyle(BorderlandTheme.textPrimary)
                .frame(maxWidth: .infinity)

            Button {
                HapticManager.lightTap()
                adjustPoints(by: step)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BorderlandTheme.textPrimary)
                    .frame(width: 28, height: 28)
                    .background(BorderlandTheme.surface3)
                    .clipShape(Circle())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, Spacing.sm)
        .frame(height: 40)
        .background(BorderlandTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
                .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func adjustPoints(by delta: Int) {
        points = max(1, points + delta)
    }
}

// MARK: – Tag lookup sheet

private struct TagLookupSheet: View {
    let result: TagLookupResult
    let onAddItem: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                BorderlandTheme.surface1.ignoresSafeArea()
                VStack(spacing: Spacing.xl) {
                    Capsule()
                        .fill(BorderlandTheme.borderSubtle)
                        .frame(width: 38, height: 4)
                        .padding(.top, Spacing.sm)

                    // Entity icon
                    VStack(spacing: Spacing.sm) {
                        ZStack {
                            Circle()
                                .fill(entityColor.opacity(0.15))
                                .frame(width: 72, height: 72)
                            Image(systemName: entityIcon)
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(entityColor)
                        }
                        Text(result.entityLabel)
                            .font(AppTypography.title3)
                            .foregroundStyle(result.entityType == "free" ? BorderlandTheme.textMuted : BorderlandTheme.textPrimary)
                            .multilineTextAlignment(.center)
                        if let team = result.teamLabel {
                            Text(team == "TEAM_A" ? "Giocatori" : "Cittadini")
                                .font(AppTypography.caption)
                                .foregroundStyle(team == "TEAM_A" ? BorderlandTheme.teamA : BorderlandTheme.teamB)
                        }
                    }

                    // Tag ID
                    if !result.tagId.isEmpty {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "creditcard.fill").font(.system(size: 12)).foregroundStyle(BorderlandTheme.textDim)
                            Text(result.tagId).font(AppTypography.caption).foregroundStyle(BorderlandTheme.textMuted).lineLimit(1).truncationMode(.middle)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.xs)
                        .background(BorderlandTheme.surface2)
                        .clipShape(Capsule())
                    }

                    Spacer()

                    VStack(spacing: Spacing.sm) {
                        if result.entityType == "free" {
                            BorderlandButton("Aggiungi come oggetto", variant: .secondary) {
                                dismiss()
                                onAddItem()
                            }
                        }
                        BorderlandButton("Chiudi", variant: .ghost) { dismiss() }
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, Spacing.xl)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var entityIcon: String {
        switch result.entityType {
        case "base": return "mappin.circle.fill"
        case "item": return result.itemIcon ?? "tag.fill"
        case "player": return "person.crop.circle.fill"
        case "error": return "exclamationmark.triangle.fill"
        default: return "wave.3.right"
        }
    }

    private var entityColor: Color {
        switch result.entityType {
        case "base": return Color(hex: "#6BAED6")
        case "item": return BorderlandTheme.gold
        case "player": return result.teamLabel == "TEAM_B" ? BorderlandTheme.teamB : BorderlandTheme.teamA
        case "error": return BorderlandTheme.statusDangerText
        default: return BorderlandTheme.textMuted
        }
    }
}

// MARK: – Reusable admin panel

private struct AdminPanel<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(BorderlandTheme.textMuted)
                .tracking(1.2)
                .textCase(.uppercase)
            content()
        }
        .padding(Spacing.md)
        .background(BorderlandTheme.surface2.opacity(0.65))
        .overlay(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous).stroke(BorderlandTheme.borderSubtle, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
    }
}

// MARK: – Extensions

private extension View {
    func adminField() -> some View {
        self
            .font(AppTypography.callout)
            .foregroundStyle(BorderlandTheme.textPrimary)
            .padding(.horizontal, Spacing.sm)
            .frame(height: 44)
            .background(BorderlandTheme.surface3)
            .overlay(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous).stroke(BorderlandTheme.borderSubtle, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
    }
}

extension TagLookupResult: Identifiable {
    var id: String { tagId + entityType }
}

#Preview("Admin Logs") {
    let viewModel = AdminViewModel(
        gameService: MockGameService(),
        authService: MockAuthService(),
        nfcService: UnsupportedNFCService()
    )
    viewModel.activeGameId = "preview-game"
    viewModel.logLines = [
        "[18:40:11] Config gameplay salvata",
        "[18:41:03] Base TEAM_A impostata: AAAA1111"
    ]
    viewModel.backendEventExport = AdminGameEventExport(
        gameId: "preview-game",
        gameName: "Preview Match",
        state: "LIVE",
        exportedAt: "2026-03-11T18:45:00Z",
        totalEventCount: 3,
        truncated: false,
        entries: [
            .init(
                id: "event-1",
                sequence: 21,
                type: "TEAM_SYNC_PENDING",
                scope: "TEAM",
                createdAt: "2026-03-11T18:42:01Z",
                actorUid: "a",
                actorNickname: "Paolo",
                severity: "INFO",
                message: "Sync team: Paolo collega Luca (5s)",
                payloadJson: "{\n  \"scannerUid\": \"a\",\n  \"targetUid\": \"b\",\n  \"windowSec\": 5\n}"
            ),
            .init(
                id: "event-2",
                sequence: 22,
                type: "SCAN_PENDING",
                scope: "PLAYER",
                createdAt: "2026-03-11T18:42:07Z",
                actorUid: "a",
                actorNickname: "Paolo",
                severity: "WARNING",
                message: "Ingaggio aperto: Paolo -> Marta (8s per la reciproca)",
                payloadJson: "{\n  \"scannerUid\": \"a\",\n  \"opponentUid\": \"x\",\n  \"handshakeWindowSec\": 8\n}"
            ),
            .init(
                id: "event-3",
                sequence: 23,
                type: "POINT_TRANSFER",
                scope: "GLOBAL",
                createdAt: "2026-03-11T18:42:11Z",
                actorUid: "a",
                actorNickname: "Paolo",
                severity: "SUCCESS",
                message: "Cittadini vince contro Giocatori (+500)",
                payloadJson: "{\n  \"amount\": 500,\n  \"winnerSide\": \"OPPONENT\"\n}"
            )
        ]
    )
    return ZStack {
        Color.black.ignoresSafeArea()
        LogsSectionView(viewModel: viewModel)
            .padding()
    }
    .borderlandBackground()
}
