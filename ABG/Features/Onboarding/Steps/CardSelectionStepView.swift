import SwiftUI

struct CardSelectionStepView: View {
    @ObservedObject var viewModel: ProfileCompletionViewModel

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(BorderlandTheme.gold)

            BorderlandPanel(title: "Identita di partita") {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    infoRow(
                        title: "Nome e avatar li scegli tu",
                        detail: "Sono i riferimenti che appariranno nel roster e nella UI della partita."
                    )

                    infoRow(
                        title: "La carta la assegna il server",
                        detail: "Quando entri in partita il backend ti assegna automaticamente una carta identita casuale."
                    )

                    infoRow(
                        title: "Perche te lo diciamo ora",
                        detail: "Cosi capisci subito quali elementi puoi controllare prima di iniziare: il tuo nome pubblico e il tuo avatar."
                    )
                }
            }
        }
    }

    private func infoRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTypography.headline)
                .foregroundStyle(BorderlandTheme.textPrimary)

            Text(detail)
                .font(AppTypography.callout)
                .foregroundStyle(BorderlandTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
