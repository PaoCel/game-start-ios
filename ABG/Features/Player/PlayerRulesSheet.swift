import SwiftUI

struct PlayerRulesSheet: View {
    let gameName: String
    let snapshot: MatchSnapshot

    @Environment(\.dismiss) private var dismiss

    private var config: GameplayConfigSnapshot { snapshot.config }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sheetHeader

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing.md) {
                        heroCard
                        statusLegendCard
                        flowCard
                        scoringCard
                        timingCard
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
                    .frame(width: 90)
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

            Text("Regole")
                .font(AppTypography.title3)
                .foregroundStyle(BorderlandTheme.gold)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Spacing.xs)
    }

    private var heroCard: some View {
        BorderlandCard(variant: .gold) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(gameName)
                    .font(AppTypography.title2)
                    .foregroundStyle(BorderlandTheme.textPrimary)

                Text("Questa scheda legge le regole attive del match in tempo reale, quindi resta allineata se la configurazione cambia.")
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textMuted)

                HStack(spacing: Spacing.sm) {
                    PlayerRuleStatChip(
                        title: "Scan",
                        value: scanModeLabel,
                        tint: BorderlandTheme.emeraldLight
                    )
                    PlayerRuleStatChip(
                        title: "Match",
                        value: formatDuration(config.matchDurationSec),
                        tint: BorderlandTheme.goldLight
                    )
                    PlayerRuleStatChip(
                        title: "Start",
                        value: "\(config.startingPoints.formatted()) pt",
                        tint: BorderlandTheme.violet
                    )
                }
            }
        }
    }

    private var statusLegendCard: some View {
        BorderlandCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                sectionHeader(
                    title: "Colori Schermata",
                    symbol: "lightspectrum.horizontal",
                    tint: BorderlandTheme.goldLight
                )

                PlayerStateLegendRow(
                    title: "Verde",
                    detail: "Puoi giocare subito: premi Gioca e aggancia un bersaglio valido.",
                    tint: BorderlandTheme.emeraldLight
                )

                PlayerStateLegendRow(
                    title: "Giallo",
                    detail: "Sei inattivo: dopo uno scontro o dopo una base conquistata devi tornare alla tua base per rientrare.",
                    tint: BorderlandTheme.goldLight
                )

                PlayerStateLegendRow(
                    title: "Rosso",
                    detail: "Sei bloccato o in penalty: niente ingaggi finche il timer non scade.",
                    tint: BorderlandTheme.crimson
                )
            }
        }
    }

    private var flowCard: some View {
        BorderlandCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                sectionHeader(
                    title: "Flusso Di Gioco",
                    symbol: "figure.run",
                    tint: BorderlandTheme.emeraldLight
                )

                PlayerRuleBullet(text: "Quando la schermata e verde puoi usare \(scanModeActionLabel) per iniziare uno scontro.")
                PlayerRuleBullet(text: "Dopo ogni scontro o dopo una base conquistata torni inattivo e devi toccare la tua base per riattivarti.")
                PlayerRuleBullet(text: "Se il backend applica la penalty inattivita resti bloccato per \(formatDuration(config.inactivePenaltyBlockDurationSec)).")
                PlayerRuleBullet(text: "Se conquisti la base avversaria, quella base resta bloccata per \(formatDuration(config.baseDefenseCooldownSec)) e non puo essere attaccata di nuovo finche il timer non scade.")

                if config.teamSyncWindowSec > 0 {
                    PlayerRuleBullet(text: "Le azioni di squadra devono chiudersi entro \(formatDuration(config.teamSyncWindowSec)).")
                }
            }
        }
    }

    private var scoringCard: some View {
        BorderlandCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                sectionHeader(
                    title: "Punti E Basi",
                    symbol: "target",
                    tint: BorderlandTheme.goldLight
                )

                PlayerRuleBullet(text: "Ogni player parte con \(config.startingPoints.formatted()) punti.")
                PlayerRuleBullet(text: "Uno scontro valido trasferisce fino a \(config.duelTransferPoints.formatted()) punti.")
                PlayerRuleBullet(text: "La cattura della base avversaria vale \(config.baseCapturePoints.formatted()) punti.")
                PlayerRuleBullet(text: "La difesa base dura \(formatDuration(config.baseDefenseDurationSec)); dopo resta in cooldown per \(formatDuration(config.baseDefenseCooldownSec)).")
                PlayerRuleBullet(text: "Una base appena conquistata entra subito nello stesso cooldown: resta bloccata, puo riattivare i suoi player, ma non puo essere riattaccata a ripetizione.")
                PlayerRuleBullet(text: "Quando la base e potenziata, la sua forza vale x\(config.baseDefenseMultiplier) dei tuoi punti.")
            }
        }
    }

    private var timingCard: some View {
        BorderlandCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                sectionHeader(
                    title: "Finestre E Protezioni",
                    symbol: "timer",
                    tint: BorderlandTheme.violet
                )

                PlayerRuleBullet(text: "La finestra handshake di uno scontro dura \(formatDuration(config.handshakeWindowSec)).")
                PlayerRuleBullet(text: "La stessa coppia di player non puo riaffrontarsi per \(formatDuration(config.pairCooldownSec)).")
                PlayerRuleBullet(text: "Il cooldown personale standard dura \(formatDuration(config.playerCooldownSec)).")
                PlayerRuleBullet(text: "La finestra di contatto base dura \(formatDuration(config.baseContactWindowSec)).")
            }
        }
    }

    private var scanModeLabel: String {
        snapshot.scanMode.isQREnabled ? "NFC + QR" : "Solo NFC"
    }

    private var scanModeActionLabel: String {
        snapshot.scanMode.isQREnabled ? "NFC o QR" : "NFC"
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

    private func sectionHeader(title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)

            Text(title)
                .font(AppTypography.headline)
                .foregroundStyle(BorderlandTheme.textPrimary)
        }
    }
}

private struct PlayerRuleStatChip: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTypography.caption2)
                .foregroundStyle(BorderlandTheme.textDim)
            Text(value)
                .font(AppTypography.caption)
                .foregroundStyle(tint)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BorderlandTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
    }
}

private struct PlayerStateLegendRow: View {
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.callout)
                    .foregroundStyle(tint)
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PlayerRuleBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(BorderlandTheme.goldLight)
                .padding(.top, 2)

            Text(text)
                .font(AppTypography.callout)
                .foregroundStyle(BorderlandTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
