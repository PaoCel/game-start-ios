import SwiftUI

struct PlayerBaseDetailSheet: View {
    let snapshot: MatchSnapshot
    let teamId: String

    @Environment(\.dismiss) private var dismiss

    private var isBaseBoostActive: Bool {
        (snapshot.baseDefenseRemainingSec ?? 0) > 0
    }

    private var isBaseCooldownActive: Bool {
        (snapshot.baseDefenseCooldownRemainingSec ?? 0) > 0
    }

    private var activeDefensePoints: Int? {
        guard isBaseBoostActive else { return nil }
        return snapshot.baseDefensePoints
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sheetHeader

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        BorderlandCard(variant: isBaseBoostActive ? .gold : .standard) {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text(teamDisplayName)
                                    .font(AppTypography.title2)
                                    .foregroundStyle(BorderlandTheme.gold)

                                Text("Dettaglio base")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(BorderlandTheme.textMuted)

                                Text(baseStatusTitle)
                                    .font(AppTypography.title3)
                                    .foregroundStyle(BorderlandTheme.textPrimary)

                                Text(baseStatusDetail)
                                    .font(AppTypography.callout)
                                    .foregroundStyle(BorderlandTheme.textMuted)

                                if let activeDefensePoints {
                                    Divider()
                                        .overlay(BorderlandTheme.borderSubtle)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Difesa attuale")
                                            .font(AppTypography.caption)
                                            .foregroundStyle(BorderlandTheme.textMuted)

                                        Text("\(activeDefensePoints.formatted()) pt")
                                            .font(AppTypography.score)
                                            .foregroundStyle(BorderlandTheme.gold)
                                    }
                                }
                            }
                        }

                        BorderlandPanel(title: "Timer") {
                            if isBaseBoostActive || isBaseCooldownActive {
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    if let activeSec = snapshot.baseDefenseRemainingSec, activeSec > 0 {
                                        BaseDetailRow(
                                            title: "Potenziata ancora per",
                                            value: formatDuration(activeSec)
                                        )
                                    }

                                    if let cooldownSec = snapshot.baseDefenseCooldownRemainingSec, cooldownSec > 0 {
                                        BaseDetailRow(
                                            title: isBaseBoostActive ? "Cooldown dopo il boost" : "Riattivabile tra",
                                            value: formatDuration(cooldownSec)
                                        )
                                    }
                                }
                            } else {
                                Text("Nessun timer attivo. Al prossimo tocco valido la base puo essere potenziata.")
                                    .font(AppTypography.callout)
                                    .foregroundStyle(BorderlandTheme.textMuted)
                            }
                        }

                        BorderlandPanel(title: "Regole attive") {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                BaseDetailRow(
                                    title: "Difesa base",
                                    value: "x\(snapshot.config.baseDefenseMultiplier) dei tuoi punti"
                                )
                                BaseDetailRow(
                                    title: "Durata boost",
                                    value: formatDuration(snapshot.config.baseDefenseDurationSec)
                                )
                                BaseDetailRow(
                                    title: "Cooldown riattivazione",
                                    value: formatDuration(snapshot.config.baseDefenseCooldownSec)
                                )
                                BaseDetailRow(
                                    title: "Premio/Penalita assalto",
                                    value: "\(snapshot.config.baseCapturePoints.formatted()) pt"
                                )
                            }
                        }

                        BorderlandPanel(title: "Nota") {
                            Text("Dopo uno scontro, il tocco sulla tua base ti riattiva ma non applica un nuovo potenziamento. Se una base e in cooldown, puo sbloccare i propri player ma non puo essere riattaccata o ripotenziata finche il timer non scade.")
                                .font(AppTypography.callout)
                                .foregroundStyle(BorderlandTheme.textMuted)
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

            Text("BASE")
                .font(AppTypography.title3)
                .foregroundStyle(BorderlandTheme.gold)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Spacing.xs)
    }

    private var baseStatusTitle: String {
        if isBaseBoostActive {
            return "Base potenziata"
        }
        if isBaseCooldownActive {
            return "Base in cooldown"
        }
        return "Base pronta"
    }

    private var baseStatusDetail: String {
        if isBaseBoostActive {
            return "Gli assalti alla base vengono confrontati con la difesa attualmente attiva del tuo team."
        }
        if isBaseCooldownActive {
            return "La base puo ancora servirti per rientrare in gioco, ma il potenziamento non e ancora riattivabile e gli avversari non possono riattaccarla finche il timer non scade."
        }
        return "Se non sei appena uscito da uno scontro, il prossimo tocco valido attivera la difesa della base."
    }

    private var teamDisplayName: String {
        switch teamId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "A", "TEAM_A", "GIOCATORI":
            return "Base Giocatori"
        case "B", "TEAM_B", "CITTADINI":
            return "Base Cittadini"
        default:
            return "Base squadra"
        }
    }

    private func formatDuration(_ totalSeconds: Int) -> String {
        let safeValue = max(0, totalSeconds)
        let minutes = safeValue / 60
        let seconds = safeValue % 60
        if minutes > 0 && seconds > 0 {
            return "\(minutes)m \(seconds)s"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(seconds)s"
    }
}

private struct BaseDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            Text(title)
                .font(AppTypography.callout)
                .foregroundStyle(BorderlandTheme.textMuted)

            Spacer(minLength: 0)

            Text(value)
                .font(AppTypography.headline)
                .foregroundStyle(BorderlandTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview("Dettaglio Base") {
    PlayerBaseDetailSheet(
        snapshot: MatchSnapshot(
            gameId: "KOC-042",
            state: "LIVE",
            config: GameplayConfigSnapshot(
                scanMode: .bracelet,
                handshakeWindowSec: 6,
                pairCooldownSec: 20,
                playerCooldownSec: 10,
                inactivePenaltyBlockDurationSec: 180,
                teamSyncWindowSec: 4,
                baseContactWindowSec: 5,
                baseDefenseMultiplier: 3,
                baseDefenseDurationSec: 180,
                baseDefenseCooldownSec: 300,
                duelTransferPoints: 250,
                baseCapturePoints: 10_000,
                baseDefensePoints: 500,
                startingPoints: 3_500,
                countdownSec: 10,
                matchDurationSec: 2_700,
                timezone: "Europe/Rome"
            ),
            remainingSec: 1_245,
            liveEndsAtMs: nil,
            serverNowMs: nil,
            isJoined: true,
            joinAllowed: true,
            battleStatus: "ACTIVE",
            playingCard: "KC",
            identityDeckIndex: 2,
            inactiveReason: nil,
            cooldownRemainingSec: nil,
            baseDefenseRemainingSec: 142,
            baseDefenseCooldownRemainingSec: 300,
            baseDefensePoints: 6_000,
            teamDistributionSubmitted: false,
            teamDistributionTotal: nil,
            teamDistributionRemaining: nil,
            teamReadyForLive: false,
            opponentTeamReadyForLive: false,
            allTeamsReadyForLive: false,
            isCurrentPlayerLeader: false,
            points: 2_000,
            roleInTeam: "RUNNER",
            participants: [],
            teamId: "TEAM_A",
            braceletToken: "A1B2C3D4E5F6",
            qrToken: nil,
            qrUrl: nil,
            lastBattleSummary: nil,
            autonomousSetup: .autonomousDefault,
            hasAutonomousSetup: true
        ),
        teamId: "TEAM_A"
    )
}
