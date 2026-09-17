import SwiftUI

struct TeamScoreSheet: View {
    let teamId: String
    let playerPoints: Int
    let battleStatus: String
    let teamStandings: [PlayerViewModel.MatchEndSummary.TeamStanding]
    let isMatchClosed: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sheetHeader

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        BorderlandCard(variant: .gold) {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                HStack(alignment: .top, spacing: Spacing.md) {
                                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                                        Text(isMatchClosed ? "Classifica finale" : "Classifica live")
                                            .font(AppTypography.caption)
                                            .foregroundStyle(BorderlandTheme.textMuted)

                                        Text(teamDisplayName)
                                            .font(AppTypography.title2)
                                            .foregroundStyle(BorderlandTheme.gold)
                                    }

                                    Spacer(minLength: 0)

                                    VStack(alignment: .trailing, spacing: Spacing.xxs) {
                                        Text("Tu")
                                            .font(AppTypography.caption)
                                            .foregroundStyle(BorderlandTheme.textMuted)
                                        Text("\(playerPoints)")
                                            .font(AppTypography.score)
                                            .foregroundStyle(BorderlandTheme.gold)
                                    }
                                }

                                Text("Stato battaglia: \(battleStatus)")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(BorderlandTheme.textMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if teamStandings.isEmpty {
                            BorderlandPanel(title: "Punteggi") {
                                Text("La classifica non è ancora disponibile.")
                                    .font(AppTypography.callout)
                                    .foregroundStyle(BorderlandTheme.textMuted)
                            }
                        } else {
                            ForEach(teamStandings) { standing in
                                BorderlandPanel(title: standing.teamName.uppercased()) {
                                    VStack(alignment: .leading, spacing: Spacing.md) {
                                        HStack(spacing: Spacing.md) {
                                            scoreboardMetric(
                                                title: "Totale",
                                                value: "\(standing.totalPoints)",
                                                tint: BorderlandTheme.gold
                                            )
                                            scoreboardMetric(
                                                title: "Attivi",
                                                value: "\(standing.activePlayers)",
                                                tint: BorderlandTheme.statusOkText
                                            )
                                            scoreboardMetric(
                                                title: "Eliminati",
                                                value: "\(standing.eliminatedPlayers)",
                                                tint: BorderlandTheme.crimson
                                            )
                                        }

                                        VStack(spacing: Spacing.sm) {
                                            ForEach(standing.players) { player in
                                                playerRow(player, isOwnTeam: standing.teamId == normalizedTeamId(teamId))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.vertical, Spacing.lg)
                }
            }
            .borderlandBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BorderlandButton("Chiudi", variant: .ghost) {
                        dismiss()
                    }
                    .frame(width: 88)
                }
            }
        }
    }

    private var sheetHeader: some View {
        VStack(spacing: Spacing.xxs) {
            Capsule()
                .fill(BorderlandTheme.borderSubtle)
                .frame(width: 38, height: 4)
                .padding(.top, Spacing.sm)

            Text("PUNTEGGI")
                .font(AppTypography.title3)
                .foregroundStyle(BorderlandTheme.gold)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Spacing.xs)
    }

    @ViewBuilder
    private func scoreboardMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(BorderlandTheme.textMuted)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func playerRow(
        _ player: PlayerViewModel.MatchEndSummary.PlayerStanding,
        isOwnTeam: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.nickname)
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textPrimary)

                HStack(spacing: 8) {
                    if let role = player.roleInTeam, !role.isEmpty {
                        Text(role.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(isOwnTeam ? BorderlandTheme.goldLight : BorderlandTheme.textMuted)
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
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(player.isEliminated ? BorderlandTheme.crimson : BorderlandTheme.textPrimary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
                .fill(BorderlandTheme.surface2.opacity(isOwnTeam ? 0.85 : 0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
                .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var teamDisplayName: String {
        switch normalizedTeamId(teamId) {
        case "A", "TEAM_A", "GIOCATORI":
            return "Giocatori"
        case "B", "TEAM_B", "CITTADINI":
            return "Cittadini"
        default:
            return "Senza team"
        }
    }

    private func normalizedTeamId(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}

#Preview("Team Score Sheet") {
    TeamScoreSheet(
        teamId: "TEAM_B",
        playerPoints: 920,
        battleStatus: "INACTIVE",
        teamStandings: [
            .init(
                id: "TEAM_B",
                teamId: "TEAM_B",
                teamName: "Cittadini",
                totalPoints: 2180,
                activePlayers: 2,
                eliminatedPlayers: 1,
                players: [
                    .init(id: "p1", nickname: "Paolo", teamId: "TEAM_B", teamName: "Cittadini", roleInTeam: "Leader", points: 920, isEliminated: false),
                    .init(id: "p2", nickname: "Chiara", teamId: "TEAM_B", teamName: "Cittadini", roleInTeam: nil, points: 810, isEliminated: false),
                    .init(id: "p3", nickname: "Michele", teamId: "TEAM_B", teamName: "Cittadini", roleInTeam: nil, points: 450, isEliminated: true)
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
        isMatchClosed: false
    )
}
