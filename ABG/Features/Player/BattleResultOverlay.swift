import SwiftUI

struct BattleResultOverlay: View {
    let result: PlayerViewModel.BattleResult
    let battleSummary: ScanBattleSummary?
    let context: String?
    let onDismiss: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showParticles = false
    @State private var displayedAmount = 0
    @State private var displayedViewerTotal = 0
    @State private var displayedOpponentTotal = 0
    @State private var contentVisible = false

    var body: some View {
        ZStack {
            BorderlandTheme.void.opacity(0.88)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            Group {
                if let battleSummary {
                    battleSummaryPanel(summary: battleSummary)
                } else {
                    legacyResultPanel
                }
            }
            .padding(Spacing.xxl)
            .background(BorderlandTheme.surface1)
            .overlay(alignment: .topTrailing) {
                Button {
                    HapticManager.lightTap()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(BorderlandTheme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(BorderlandTheme.surface2.opacity(0.7), in: Circle())
                }
                .buttonStyle(PressableStyle())
                .padding(Spacing.sm)
            }
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                    .stroke(primaryColor.opacity(0.7), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous))
            .padding(.horizontal, Spacing.lg)
            .scaleEffect(contentVisible ? 1.0 : 0.84)
            .opacity(contentVisible ? 1.0 : 0.0)
            .animation(AnimationTokens.dramaticReveal, value: contentVisible)
            .onTapGesture {}

            if showParticles, particleValue != 0 {
                PointTransferEffect(value: particleValue)
            }
        }
        .onAppear {
            contentVisible = true
            triggerHaptic()
            runCounterIfNeeded()

            Task {
                try? await Task.sleep(nanoseconds: 280_000_000)
                showParticles = true
            }
        }
    }

    private var legacyResultPanel: some View {
        VStack(spacing: Spacing.md) {
            Text(title)
                .font(AppTypography.title1)
                .foregroundStyle(primaryColor)

            if case .win = result {
                Text("+\(displayedAmount)")
                    .font(AppTypography.score)
                    .foregroundStyle(BorderlandTheme.gold)
            } else if case .lose = result {
                Text("-\(displayedAmount)")
                    .font(AppTypography.score)
                    .foregroundStyle(BorderlandTheme.crimson)
            } else if case .baseCaptured(let amount) = result {
                Text("+\(amount)")
                    .font(AppTypography.score)
                    .foregroundStyle(BorderlandTheme.gold)
            } else if case .baseActivated = result {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(BorderlandTheme.statusOkText)
            }

            Text(subtitle)
                .font(AppTypography.callout)
                .foregroundStyle(BorderlandTheme.textMuted)
                .multilineTextAlignment(.center)

            if let context, !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(context)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(BorderlandTheme.textPrimary.opacity(0.86))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func battleSummaryPanel(summary: ScanBattleSummary) -> some View {
        let viewerSide = summary.viewerSideData
        let opponentSide = summary.opposingSideData
        let viewerAccent = summary.viewerDidWin
            ? BorderlandTheme.gold
            : (summary.viewerDidLose ? BorderlandTheme.crimson : BorderlandTheme.violet)
        let opponentAccent = summary.viewerDidLose
            ? BorderlandTheme.gold
            : (summary.viewerDidWin ? BorderlandTheme.crimson : BorderlandTheme.violet)
        let viewerStatus = summary.viewerDidWin ? "WIN" : (summary.viewerDidLose ? "LOSE" : "DRAW")
        let opponentStatus = summary.viewerDidLose ? "WIN" : (summary.viewerDidWin ? "LOSE" : "DRAW")

        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text(summaryTag(for: summary))
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(primaryColor)
                        .tracking(2)

                    Text(title)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(primaryColor)
                }

                Spacer(minLength: 0)

                if summary.penaltyApplied {
                    Text("PENALTY")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(BorderlandTheme.crimson)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(BorderlandTheme.crimson.opacity(0.12), in: Capsule())
                }
            }

            if usesCompactSummaryLayout {
                VStack(spacing: Spacing.sm) {
                    compactSummarySideCard(
                        side: viewerSide,
                        displayedTotal: displayedViewerTotal,
                        accent: viewerAccent,
                        statusLabel: viewerStatus
                    )

                    summaryMidBadge

                    compactSummarySideCard(
                        side: opponentSide,
                        displayedTotal: displayedOpponentTotal,
                        accent: opponentAccent,
                        statusLabel: opponentStatus
                    )
                }
            } else {
                HStack(alignment: .center, spacing: Spacing.sm) {
                    regularSummarySideCard(
                        side: viewerSide,
                        displayedTotal: displayedViewerTotal,
                        accent: viewerAccent,
                        statusLabel: viewerStatus,
                        isLeading: true
                    )

                    summaryMidBadge

                    regularSummarySideCard(
                        side: opponentSide,
                        displayedTotal: displayedOpponentTotal,
                        accent: opponentAccent,
                        statusLabel: opponentStatus,
                        isLeading: false
                    )
                }
            }

            Text(summaryFootnote(for: summary))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(BorderlandTheme.textMuted)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: usesCompactSummaryLayout ? .infinity : 620)
    }

    private func regularSummarySideCard(
        side: ScanBattleSummary.Side,
        displayedTotal: Int,
        accent: Color,
        statusLabel: String,
        isLeading: Bool
    ) -> some View {
        VStack(alignment: isLeading ? .leading : .trailing, spacing: 10) {
            Text(side.label.uppercased())
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(BorderlandTheme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("\(displayedTotal)")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(BorderlandTheme.textPrimary)

            Text(statusLabel)
                .font(.system(size: 24, weight: .heavy, design: .monospaced))
                .foregroundStyle(accent)

            Text(deltaLabel(for: side))
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(accent)

            Rectangle()
                .fill(accent.opacity(0.42))
                .frame(height: 1)

            Text("PRIMA \(side.totalBefore)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(BorderlandTheme.textMuted)

            if let identityLine = identityLine(for: side) {
                Text(identityLine)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(BorderlandTheme.textPrimary.opacity(0.84))
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                    .multilineTextAlignment(isLeading ? .leading : .trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: isLeading ? .leading : .trailing)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                .fill(BorderlandTheme.surface2.opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        )
    }

    private func compactSummarySideCard(
        side: ScanBattleSummary.Side,
        displayedTotal: Int,
        accent: Color,
        statusLabel: String
    ) -> some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 8) {
                Text(side.label.uppercased())
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let identityLine = identityLine(for: side) {
                    Text(identityLine)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(BorderlandTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                }

                Text("PRIMA \(side.totalBefore)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(BorderlandTheme.textMuted)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 6) {
                Text(statusLabel)
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .foregroundStyle(accent)

                Text("\(displayedTotal)")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(BorderlandTheme.textPrimary)

                Text(deltaLabel(for: side))
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                .fill(BorderlandTheme.surface2.opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        )
    }

    private var summaryMidBadge: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(BorderlandTheme.borderSubtle)
                .frame(height: 1)

            Text("VS")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(BorderlandTheme.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(BorderlandTheme.surface2, in: Capsule())
                .overlay(Capsule().stroke(BorderlandTheme.borderSubtle, lineWidth: 1))

            Capsule()
                .fill(BorderlandTheme.borderSubtle)
                .frame(height: 1)
        }
    }

    private var usesCompactSummaryLayout: Bool {
        horizontalSizeClass == .compact
    }

    private func summaryIdentityLine(for side: ScanBattleSummary.Side) -> String {
        if let participantLine = side.participantLine, side.isGroup {
            return participantLine
        }
        return side.primaryName
    }

    private func identityLine(for side: ScanBattleSummary.Side) -> String? {
        let value = summaryIdentityLine(for: side)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        guard normalizedSummaryText(value) != normalizedSummaryText(side.label) else {
            return nil
        }
        return value
    }

    private func normalizedSummaryText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private var title: String {
        switch result {
        case .win: return "VITTORIA"
        case .lose: return "SCONFITTA"
        case .tie: return "PARITA"
        case .baseCaptured: return "BASE CATTURATA"
        case .baseActivated: return "BASE ATTIVATA"
        case .eliminated: return "ELIMINATO"
        }
    }

    private var subtitle: String {
        switch result {
        case .win(let delta): return "Hai guadagnato \(delta) punti"
        case .lose(let delta): return "Hai perso \(delta) punti"
        case .tie: return "Nessuna variazione"
        case .baseCaptured(let amount): return "Conquista riuscita: +\(amount)"
        case .baseActivated: return "Difesa base attivata lato server"
        case .eliminated: return "I tuoi punti sono esauriti"
        }
    }

    private var primaryColor: Color {
        switch result {
        case .win, .baseCaptured, .baseActivated:
            return BorderlandTheme.gold
        case .lose, .eliminated:
            return BorderlandTheme.crimson
        case .tie:
            return BorderlandTheme.textMuted
        }
    }

    private var particleValue: Int {
        if let battleSummary {
            return battleSummary.viewerDelta
        }
        switch result {
        case .win(let delta): return delta
        case .lose(let delta): return -delta
        case .baseCaptured(let amount): return amount
        default: return 0
        }
    }

    private func summaryTag(for summary: ScanBattleSummary) -> String {
        switch summary.resolutionMode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "BASE_DEFENSE":
            return "BASE DEFENSE"
        case "BASE_DEFENSE_TIE":
            return "BASE STANDOFF"
        default:
            return "BATTLE RESULT"
        }
    }

    private func summaryFootnote(for summary: ScanBattleSummary) -> String {
        let participantLines = [
            summary.viewerSideData.isGroup ? "\(summary.viewerSideData.label): \(summaryIdentityLine(for: summary.viewerSideData))" : nil,
            summary.opposingSideData.isGroup ? "\(summary.opposingSideData.label): \(summaryIdentityLine(for: summary.opposingSideData))" : nil
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? $0 : nil }

        let baseMessage: String
        if summary.penaltyApplied {
            baseMessage = "Blocco inattivita applicato dopo lo scontro. Serve attendere la fine penalty prima del rientro."
        } else {
            switch summary.resolutionMode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
            case "BASE_DEFENSE":
                baseMessage = "Lo scontro e stato chiuso dalla finestra difesa base lato server."
            case "BASE_DEFENSE_TIE":
                baseMessage = "Difesa base attiva su entrambi i lati: nessun trasferimento."
            default:
                baseMessage = "Torna alla tua base per giocare ancora."
            }
        }

        guard !participantLines.isEmpty else {
            return baseMessage
        }
        return ([baseMessage] + participantLines).joined(separator: "\n")
    }

    private func triggerHaptic() {
        switch result {
        case .win, .baseCaptured:
            HapticManager.battleWin()
        case .lose:
            HapticManager.battleLose()
        case .baseActivated:
            HapticManager.success()
        case .tie:
            HapticManager.lightTap()
        case .eliminated:
            HapticManager.elimination()
        }
    }

    private func runCounterIfNeeded() {
        if let battleSummary {
            displayedViewerTotal = battleSummary.viewerSideData.totalBefore
            displayedOpponentTotal = battleSummary.opposingSideData.totalBefore
            animateValue(
                from: battleSummary.viewerSideData.totalBefore,
                to: battleSummary.viewerSideData.totalAfter
            ) { value in
                displayedViewerTotal = value
            }
            animateValue(
                from: battleSummary.opposingSideData.totalBefore,
                to: battleSummary.opposingSideData.totalAfter
            ) { value in
                displayedOpponentTotal = value
            }
            return
        }

        switch result {
        case .win(let delta), .lose(let delta):
            animateValue(from: 0, to: delta) { value in
                displayedAmount = value
            }
        default:
            break
        }
    }

    private func animateValue(
        from start: Int,
        to end: Int,
        update: @escaping @MainActor (Int) -> Void
    ) {
        let delta = end - start
        let steps = max(1, min(24, abs(delta)))

        Task {
            for step in 0...steps {
                let progress = Double(step) / Double(steps)
                let nextValue = start + Int((Double(delta) * progress).rounded())
                await MainActor.run {
                    update(nextValue)
                }
                try? await Task.sleep(nanoseconds: 44_000_000)
            }
        }
    }

    private func deltaLabel(for side: ScanBattleSummary.Side) -> String {
        let delta = side.totalAfter - side.totalBefore
        if delta > 0 {
            return "+\(delta)"
        }
        if delta < 0 {
            return "\(delta)"
        }
        return "+0"
    }
}

private struct BattleResultOverlayPreviewScene: View {
    let result: PlayerViewModel.BattleResult
    let summary: ScanBattleSummary

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            BattleResultOverlay(
                result: result,
                battleSummary: summary,
                context: nil,
                onDismiss: {}
            )
        }
    }
}

private enum BattleResultOverlayPreviewData {
    static let duelSummary = ScanBattleSummary(
        summaryId: "summary-1",
        status: "COMPLETED",
        winnerSide: "OPPONENT",
        resolutionMode: "POINTS",
        viewerSide: "SCANNER",
        amount: 500,
        penaltyApplied: false,
        scannerWasInactive: false,
        opponentWasInactive: false,
        scannerSide: .init(
            key: "SCANNER",
            teamId: "TEAM_A",
            teamName: "Giocatori",
            label: "Giocatori",
            participants: [
                .init(id: "a", nickname: "paolo.celestini97", teamId: "TEAM_A", teamName: "Giocatori", isPrimary: true)
            ],
            totalBefore: 810,
            totalAfter: 310,
            isGroup: false
        ),
        opponentSide: .init(
            key: "OPPONENT",
            teamId: "TEAM_B",
            teamName: "Cittadini",
            label: "Cittadini",
            participants: [
                .init(id: "b", nickname: "igT3bkqQlgVd", teamId: "TEAM_B", teamName: "Cittadini", isPrimary: true)
            ],
            totalBefore: 5710,
            totalAfter: 6210,
            isGroup: false
        )
    )

    static let groupSummary = ScanBattleSummary(
        summaryId: "summary-2",
        status: "COMPLETED",
        winnerSide: "SCANNER",
        resolutionMode: "POINTS",
        viewerSide: "SCANNER",
        amount: 500,
        penaltyApplied: true,
        scannerWasInactive: true,
        opponentWasInactive: false,
        scannerSide: .init(
            key: "SCANNER",
            teamId: "TEAM_B",
            teamName: "Cittadini",
            label: "Cittadini",
            participants: [
                .init(id: "a", nickname: "Paolo", teamId: "TEAM_B", teamName: "Cittadini", isPrimary: true),
                .init(id: "b", nickname: "Luca", teamId: "TEAM_B", teamName: "Cittadini", isPrimary: false)
            ],
            totalBefore: 1600,
            totalAfter: 2100,
            isGroup: true
        ),
        opponentSide: .init(
            key: "OPPONENT",
            teamId: "TEAM_A",
            teamName: "Giocatori",
            label: "Giocatori",
            participants: [
                .init(id: "c", nickname: "Marta", teamId: "TEAM_A", teamName: "Giocatori", isPrimary: true),
                .init(id: "d", nickname: "Sofia", teamId: "TEAM_A", teamName: "Giocatori", isPrimary: false)
            ],
            totalBefore: 1900,
            totalAfter: 1400,
            isGroup: true
        )
    )
}

#Preview("Battle Result · Duel") {
    BattleResultOverlayPreviewScene(
        result: .lose(delta: 500),
        summary: BattleResultOverlayPreviewData.duelSummary
    )
}

#Preview("Battle Result · Group") {
    BattleResultOverlayPreviewScene(
        result: .win(delta: 250),
        summary: BattleResultOverlayPreviewData.groupSummary
    )
}
