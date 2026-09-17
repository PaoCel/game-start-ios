import SwiftUI

struct MatchEndOverlay: View {
    let summary: PlayerViewModel.MatchEndSummary
    let onExit: () -> Void

    @State private var contentVisible = false

    var body: some View {
        ZStack {
            BorderlandTheme.void.opacity(0.94).ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    Text("MATCH TERMINATO")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(BorderlandTheme.textMuted)
                        .tracking(2)

                    Text(summary.title)
                        .font(AppTypography.title1)
                        .foregroundStyle(BorderlandTheme.gold)
                        .multilineTextAlignment(.center)

                    Text(summary.subtitle)
                        .font(AppTypography.callout)
                        .foregroundStyle(BorderlandTheme.textMuted)
                        .multilineTextAlignment(.center)

                    if let scoreline = summary.scoreline, !scoreline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(scoreline)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(BorderlandTheme.textPrimary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: Spacing.xs) {
                        Text(summary.personalLabel)
                            .font(AppTypography.caption)
                            .foregroundStyle(BorderlandTheme.textMuted)

                        Text("\(summary.personalPoints)")
                            .font(AppTypography.score)
                            .foregroundStyle(BorderlandTheme.gold)
                    }
                    .padding(.top, Spacing.xs)

                    if !summary.teamStandings.isEmpty {
                        VStack(spacing: Spacing.md) {
                            ForEach(summary.teamStandings) { team in
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    HStack {
                                        Text(team.teamName.uppercased())
                                            .font(.system(size: 12, weight: .black, design: .monospaced))
                                            .foregroundStyle(BorderlandTheme.textMuted)

                                        Spacer(minLength: 0)

                                        Text("\(team.totalPoints)")
                                            .font(.system(size: 22, weight: .black, design: .monospaced))
                                            .foregroundStyle(BorderlandTheme.gold)
                                    }

                                    VStack(spacing: 8) {
                                        ForEach(team.players) { player in
                                            HStack(spacing: 12) {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(player.nickname)
                                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                        .foregroundStyle(BorderlandTheme.textPrimary)

                                                    HStack(spacing: 8) {
                                                        if let role = player.roleInTeam, !role.isEmpty {
                                                            Text(role.uppercased())
                                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                                .foregroundStyle(BorderlandTheme.textMuted)
                                                        }
                                                        if player.isEliminated {
                                                            Text("ELIMINATO")
                                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                                .foregroundStyle(BorderlandTheme.crimson)
                                                        }
                                                    }
                                                }

                                                Spacer(minLength: 0)

                                                Text("\(player.points)")
                                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(player.isEliminated ? BorderlandTheme.crimson : BorderlandTheme.textPrimary)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 9)
                                            .background(BorderlandTheme.surface2.opacity(0.65), in: RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
                                        }
                                    }
                                }
                                .padding(Spacing.md)
                                .background(BorderlandTheme.surface2.opacity(0.5), in: RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                                        .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
                                )
                            }
                        }
                    }

                    BorderlandButton("Esci dalla partita", variant: .primary) {
                        onExit()
                    }
                    .frame(width: 220)
                    .padding(.top, Spacing.xs)
                }
                .padding(Spacing.xxl)
            }
            .frame(maxWidth: 460, maxHeight: min(UIScreen.main.bounds.height * 0.82, 720))
            .background(BorderlandTheme.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                    .stroke(BorderlandTheme.borderGold, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous))
            .scaleEffect(contentVisible ? 1 : 0.92)
            .opacity(contentVisible ? 1 : 0)
        }
        .onAppear {
            HapticManager.success()
            withAnimation(AnimationTokens.dramaticReveal) {
                contentVisible = true
            }
        }
    }
}

#Preview("Match End Overlay") {
    MatchEndOverlay(
        summary: .init(
            title: "CITTADINI VINCONO",
            subtitle: "Il timer server è scaduto. Cittadini chiude davanti.",
            scoreline: "Cittadini 2180 • Giocatori 1640",
            personalLabel: "Punteggio finale",
            personalPoints: 1320,
            teamStandings: [
                .init(
                    id: "TEAM_B",
                    teamId: "TEAM_B",
                    teamName: "Cittadini",
                    totalPoints: 2180,
                    activePlayers: 2,
                    eliminatedPlayers: 1,
                    players: [
                        .init(id: "p1", nickname: "Paolo", teamId: "TEAM_B", teamName: "Cittadini", roleInTeam: "Leader", points: 1320, isEliminated: false),
                        .init(id: "p2", nickname: "Chiara", teamId: "TEAM_B", teamName: "Cittadini", roleInTeam: nil, points: 860, isEliminated: false),
                        .init(id: "p3", nickname: "Marco", teamId: "TEAM_B", teamName: "Cittadini", roleInTeam: nil, points: 0, isEliminated: true)
                    ]
                ),
                .init(
                    id: "TEAM_A",
                    teamId: "TEAM_A",
                    teamName: "Giocatori",
                    totalPoints: 1640,
                    activePlayers: 2,
                    eliminatedPlayers: 0,
                    players: [
                        .init(id: "p4", nickname: "Luca", teamId: "TEAM_A", teamName: "Giocatori", roleInTeam: "Leader", points: 900, isEliminated: false),
                        .init(id: "p5", nickname: "Anna", teamId: "TEAM_A", teamName: "Giocatori", roleInTeam: nil, points: 740, isEliminated: false)
                    ]
                )
            ],
            playerRanking: [],
            endedByElimination: false
        ),
        onExit: {}
    )
}
