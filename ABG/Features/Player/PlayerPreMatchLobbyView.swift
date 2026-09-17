import SwiftUI

struct PlayerPreMatchLobbyView: View {
    @ObservedObject var viewModel: PlayerViewModel
    let canSwitchToAdmin: Bool
    let switchToAdminAction: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: Spacing.md) {
            headerCard
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared || reduceMotion ? 0 : 12)
                .animation(entranceAnimation.delay(0.1), value: hasAppeared)

            if viewModel.isAutonomousMatch {
                teamSelectionCard
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared || reduceMotion ? 0 : 12)
                    .animation(entranceAnimation.delay(0.2), value: hasAppeared)
            }

            teamsOverviewCard
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared || reduceMotion ? 0 : 12)
                .animation(entranceAnimation.delay(0.3), value: hasAppeared)

            if canSwitchToAdmin || viewModel.canShuffleTeams {
                creatorToolsCard
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared || reduceMotion ? 0 : 12)
                    .animation(entranceAnimation.delay(0.4), value: hasAppeared)
            }

            if viewModel.snapshot.isCurrentPlayerLeader {
                leaderSetupCard
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared || reduceMotion ? 0 : 12)
                    .animation(entranceAnimation.delay(0.5), value: hasAppeared)
            } else {
                waitingCard
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared || reduceMotion ? 0 : 12)
                    .animation(entranceAnimation.delay(0.5), value: hasAppeared)
            }

            if viewModel.isDistributionPhase {
                PlayerDistributionPanel(viewModel: viewModel)
                    .opacity(hasAppeared ? 1 : 0)
                    .animation(entranceAnimation.delay(0.6), value: hasAppeared)
            }

            if let lookup = viewModel.preMatchLookupResult {
                lookupResultCard(lookup)
            }
        }
        .onAppear {
            hasAppeared = true
        }
    }

    private var entranceAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.3) : AnimationTokens.dramaticReveal
    }

    private var headerCard: some View {
        BorderlandCard(variant: .elevated) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.isDistributionPhase ? "Lobby distribuzione" : "Lobby partita")
                            .font(AppTypography.title3)
                            .foregroundStyle(BorderlandTheme.gold)
                        Text(headerSubtitle)
                            .font(AppTypography.callout)
                            .foregroundStyle(BorderlandTheme.textMuted)
                    }
                    Spacer()
                    StatusBadge(
                        text: viewModel.currentTeamId.map(teamName(for:)) ?? "Senza team",
                        variant: viewModel.currentTeamId == nil ? .warn : .neutral
                    )
                }

                HStack(spacing: Spacing.sm) {
                    infoPill(title: "Modalità", value: viewModel.resolvedAutonomousSetup.hostMode.displayLabel)
                    infoPill(title: "Team", value: viewModel.resolvedAutonomousSetup.teamAssignmentMode.displayLabel)
                }

                if !viewModel.preMatchStatusMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(viewModel.preMatchStatusMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.textPrimary)
                }
            }
        }
    }

    @ViewBuilder
    private var teamSelectionCard: some View {
        BorderlandCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Squadre")
                        .font(AppTypography.title3)
                        .foregroundStyle(BorderlandTheme.gold)
                    Spacer()
                    if viewModel.resolvedAutonomousSetup.allowsManualTeamSelection {
                        Text("Scelta libera bilanciata")
                            .font(AppTypography.caption)
                            .foregroundStyle(BorderlandTheme.textMuted)
                    } else {
                        Text("Assegnazione casuale")
                            .font(AppTypography.caption)
                            .foregroundStyle(BorderlandTheme.textMuted)
                    }
                }

                if viewModel.resolvedAutonomousSetup.allowsManualTeamSelection {
                    HStack(spacing: Spacing.sm) {
                        selectableTeamCard(
                            teamId: "TEAM_A",
                            title: "Giocatori",
                            participants: viewModel.teamAParticipants,
                            tint: BorderlandTheme.teamA
                        )
                        selectableTeamCard(
                            teamId: "TEAM_B",
                            title: "Cittadini",
                            participants: viewModel.teamBParticipants,
                            tint: BorderlandTheme.teamB
                        )
                    }
                } else {
                    Text(
                        viewModel.currentTeamId == nil
                            ? "L'app sta assegnando la tua squadra in automatico."
                            : "Sei stato assegnato automaticamente a \(teamName(for: viewModel.currentTeamId!))."
                    )
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textMuted)
                }
            }
        }
    }

    private var teamsOverviewCard: some View {
        BorderlandCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Lobby squadre")
                    .font(AppTypography.title3)
                    .foregroundStyle(BorderlandTheme.gold)

                VStack(spacing: Spacing.sm) {
                    teamRosterBlock(title: "Giocatori", participants: viewModel.teamAParticipants, tint: BorderlandTheme.teamA)
                    teamRosterBlock(title: "Cittadini", participants: viewModel.teamBParticipants, tint: BorderlandTheme.teamB)

                    if !viewModel.unassignedParticipants.isEmpty {
                        teamRosterBlock(title: "In attesa", participants: viewModel.unassignedParticipants, tint: BorderlandTheme.gold)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var creatorToolsCard: some View {
        BorderlandCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Creator tools")
                    .font(AppTypography.title3)
                    .foregroundStyle(BorderlandTheme.gold)

                if canSwitchToAdmin, let switchToAdminAction {
                    BorderlandButton("Impostazioni partita", variant: .secondary) {
                        switchToAdminAction()
                    }
                }

                if viewModel.canShuffleTeams {
                    BorderlandButton(
                        "Mischia squadre",
                        variant: .primary,
                        isEnabled: !viewModel.isShufflingTeams,
                        isLoading: viewModel.isShufflingTeams
                    ) {
                        viewModel.shuffleTeams()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var leaderSetupCard: some View {
        BorderlandCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Setup leader")
                            .font(AppTypography.title3)
                            .foregroundStyle(BorderlandTheme.gold)
                        Text("Base e oggetti del tuo team vanno registrati qui prima del live.")
                            .font(AppTypography.caption)
                            .foregroundStyle(BorderlandTheme.textMuted)
                    }
                    Spacer()
                    StatusBadge(text: "Leader", variant: .warn)
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Base squadra")
                        .font(AppTypography.callout)
                        .foregroundStyle(BorderlandTheme.textPrimary)
                    HStack(spacing: Spacing.sm) {
                        infoPill(title: "Stato", value: viewModel.currentTeamBaseIsRegistered ? "Registrata" : "Da fare")
                        infoPill(title: "Tag", value: viewModel.currentTeamBaseTokenMasked)
                    }
                    HStack(spacing: Spacing.sm) {
                        BorderlandButton(
                            viewModel.currentTeamBaseIsRegistered ? "Sostituisci base" : "Registra base",
                            variant: .secondary,
                            isEnabled: viewModel.canScanPreMatchTags,
                            isLoading: viewModel.isScanningPreMatchTag
                        ) {
                            viewModel.scanCurrentTeamBaseToken()
                        }
                        BorderlandButton(
                            "Controlla tag",
                            variant: .ghost,
                            isEnabled: viewModel.canScanPreMatchTags && !viewModel.isScanningPreMatchTag
                        ) {
                            viewModel.checkPreMatchTag()
                        }
                    }
                }

                if viewModel.itemModeForPreMatch == .none {
                    Text("Oggetti non previsti per questa partita.")
                        .font(AppTypography.callout)
                        .foregroundStyle(BorderlandTheme.textMuted)
                } else {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Text("Oggetti da nascondere")
                                .font(AppTypography.callout)
                                .foregroundStyle(BorderlandTheme.textPrimary)
                            Spacer()
                            Text("\(viewModel.pendingCurrentTeamSetupItems.count) da collegare")
                                .font(AppTypography.caption)
                                .foregroundStyle(BorderlandTheme.textMuted)
                        }

                        if viewModel.currentTeamSetupItems.isEmpty {
                            Text("Il creator non ha ancora preconfigurato gli oggetti per il tuo team.")
                                .font(AppTypography.caption)
                                .foregroundStyle(BorderlandTheme.textMuted)
                        } else {
                            ForEach(viewModel.currentTeamSetupItems) { item in
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: item.icon)
                                        .foregroundStyle(BorderlandTheme.gold)
                                        .frame(width: 22)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(item.points) punti")
                                            .font(AppTypography.callout)
                                            .foregroundStyle(BorderlandTheme.textPrimary)
                                        Text(item.nfcToken == nil ? "Tag mancante" : "Tag collegato")
                                            .font(AppTypography.caption)
                                            .foregroundStyle(BorderlandTheme.textMuted)
                                    }

                                    Spacer()

                                    BorderlandButton(
                                        item.nfcToken == nil ? "Collega tag" : "Ricollega",
                                        variant: .ghost,
                                        isEnabled: viewModel.canScanPreMatchTags && !viewModel.isScanningPreMatchTag
                                    ) {
                                        viewModel.attachTokenToPreMatchItem(item)
                                    }
                                    .frame(width: 118)
                                }
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .background(BorderlandTheme.surface2)
                                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
                            }
                        }
                    }
                }
            }
        }
    }

    private var waitingCard: some View {
        BorderlandCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("In attesa del leader")
                    .font(AppTypography.title3)
                    .foregroundStyle(BorderlandTheme.gold)
                Text(
                    viewModel.isDistributionPhase
                        ? "Il leader del tuo team sta distribuendo i punti e completando il setup."
                        : "Aspetta che i team vengano completati e che inizi la fase di distribuzione."
                )
                .font(AppTypography.callout)
                .foregroundStyle(BorderlandTheme.textMuted)
            }
        }
    }

    private func lookupResultCard(_ lookup: AdminGameStatus.TagLookup) -> some View {
        BorderlandCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Controllo tag")
                        .font(AppTypography.title3)
                        .foregroundStyle(BorderlandTheme.gold)
                    Spacer()
                    Button {
                        HapticManager.lightTap()
                        viewModel.clearPreMatchLookup()
                    } label: {
                        Text("Chiudi")
                            .font(AppTypography.caption)
                            .foregroundStyle(BorderlandTheme.gold)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(PressableStyle())
                }

                infoPill(title: "Tipo", value: lookup.entityType.capitalized)
                if let teamId = lookup.teamId, !teamId.isEmpty {
                    infoPill(title: "Team", value: teamName(for: teamId))
                }
                if let playerNickname = lookup.playerNickname, !playerNickname.isEmpty {
                    infoPill(title: "Player", value: playerNickname)
                }
                if let itemPoints = lookup.itemPoints {
                    infoPill(title: "Oggetto", value: "\(itemPoints) pt")
                }
            }
        }
    }

    private func selectableTeamCard(
        teamId: String,
        title: String,
        participants: [MatchSnapshot.Participant],
        tint: Color
    ) -> some View {
        let isSelected = viewModel.currentTeamId == teamId
        let isJoinAllowed = viewModel.canJoinTeam(teamId)

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundStyle(BorderlandTheme.textPrimary)
                Spacer()
                Text("\(participants.count)")
                    .font(AppTypography.caption)
                    .foregroundStyle(tint)
            }

            Text(isSelected ? "Sei in questa squadra" : "Capienza bilanciata attiva")
                .font(AppTypography.caption)
                .foregroundStyle(BorderlandTheme.textMuted)

            BorderlandButton(
                isSelected ? "Selezionata" : "Entra",
                variant: isSelected ? .ghost : .primary,
                isEnabled: !isSelected && isJoinAllowed && !viewModel.isUpdatingOwnTeam,
                isLoading: viewModel.isUpdatingOwnTeam
            ) {
                viewModel.selectOwnTeam(teamId)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BorderlandTheme.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
                .stroke(isSelected ? tint : BorderlandTheme.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
    }

    private func teamRosterBlock(
        title: String,
        participants: [MatchSnapshot.Participant],
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(title)
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textPrimary)
                Spacer()
                Text("\(participants.count)")
                    .font(AppTypography.caption)
                    .foregroundStyle(tint)
            }

            if participants.isEmpty {
                Text("Nessun player")
                    .font(AppTypography.caption)
                    .foregroundStyle(BorderlandTheme.textMuted)
            } else {
                ForEach(participants) { participant in
                    HStack(spacing: Spacing.sm) {
                        AvatarView(
                            avatarDataUrl: participant.avatarDataUrl,
                            initials: initials(from: participant.nickname),
                            size: .small
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(participant.nickname)
                                    .font(AppTypography.callout)
                                    .foregroundStyle(BorderlandTheme.textPrimary)
                                if (participant.roleInTeam ?? "").uppercased() == "LEADER" {
                                    Text("Leader")
                                        .font(AppTypography.caption2)
                                        .foregroundStyle(BorderlandTheme.gold)
                                }
                            }
                            Text((participant.id == viewModel.profile.uid ? "Tu" : "Player"))
                                .font(AppTypography.caption)
                                .foregroundStyle(BorderlandTheme.textMuted)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BorderlandTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
    }

    private func infoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTypography.caption2)
                .foregroundStyle(BorderlandTheme.textDim)
            Text(value)
                .font(AppTypography.callout)
                .foregroundStyle(BorderlandTheme.textPrimary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(BorderlandTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
    }

    private var headerSubtitle: String {
        if viewModel.isDistributionPhase {
            return viewModel.snapshot.teamReadyForLive
                ? "Il tuo team è pronto. Appena anche l'altro conferma si parte."
                : "Completa setup, distribuzione punti e ready del team."
        }
        return viewModel.isAutonomousMatch
            ? "Scegli la squadra, prepara base e oggetti e resta pronto all'avvio."
            : "Aspetta il game master oppure usa le scorciatoie creator quando disponibili."
    }

    private func teamName(for teamId: String) -> String {
        switch teamId.uppercased() {
        case "TEAM_A", "A":
            return "Giocatori"
        case "TEAM_B", "B":
            return "Cittadini"
        default:
            return "Senza team"
        }
    }

    private func initials(from value: String) -> String {
        let letters = value.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        return letters.isEmpty ? "?" : letters
    }
}

struct BraceletRegistrationGateView: View {
    @ObservedObject var viewModel: PlayerViewModel
    var exitAction: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            SuitBackdrop(density: .full)

            ScrollView {
                gateContent
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .borderlandBackground()
        .onAppear {
            hasAppeared = true
        }
    }

    private var entranceAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.3) : AnimationTokens.dramaticReveal
    }

    private var gateContent: some View {
            VStack(spacing: Spacing.lg) {
                BorderlandCard(variant: .elevated) {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Registra il tuo braccialetto")
                            .font(AppTypography.title2)
                            .foregroundStyle(BorderlandTheme.gold)

                        Text("Prima di entrare in lobby devi associare il tag NFC personale. Finché non è registrato non puoi continuare.")
                            .font(AppTypography.callout)
                            .foregroundStyle(BorderlandTheme.textMuted)

                        if viewModel.canUseNFC {
                            BorderlandButton(
                                "Scansiona braccialetto",
                                variant: .primary,
                                isEnabled: !viewModel.isRegisteringBracelet,
                                isLoading: viewModel.isRegisteringBracelet
                            ) {
                                viewModel.registerBraceletFromNFC()
                            }
                        }

                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Oppure inserisci il codice manuale")
                                .font(AppTypography.caption)
                                .foregroundStyle(BorderlandTheme.textMuted)

                            TextField("Token braccialetto", text: $viewModel.manualToken)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(.horizontal, Spacing.sm)
                                .frame(height: 48)
                                .background(BorderlandTheme.surface2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
                                        .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))

                            BorderlandButton(
                                "Conferma tag",
                                variant: .secondary,
                                isEnabled: viewModel.canSubmitManualBraceletToken,
                                isLoading: viewModel.isRegisteringBracelet
                            ) {
                                viewModel.registerBraceletFromManualInput()
                            }
                        }

                        if !viewModel.statusMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(viewModel.statusMessage)
                                .font(AppTypography.caption)
                                .foregroundStyle(BorderlandTheme.textPrimary)
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared || reduceMotion ? 0 : 16)
                .animation(entranceAnimation.delay(0.15), value: hasAppeared)

                if let exitAction {
                    Button {
                        HapticManager.lightTap()
                        exitAction()
                    } label: {
                        Text("Non hai un braccialetto? Esci dalla partita")
                            .font(AppTypography.callout)
                            .foregroundStyle(BorderlandTheme.textMuted)
                            .underline()
                            .frame(minHeight: 44)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .opacity(hasAppeared ? 1 : 0)
                    .animation(entranceAnimation.delay(0.35), value: hasAppeared)
                }
            }
            .padding(.vertical, Spacing.xl)
    }
}
