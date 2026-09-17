import SwiftUI

struct TeamPill: View {
    let text: String
    let color: Color

    init(teamId: String?) {
        let normalized = (teamId ?? "-").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch normalized {
        case "A", "TEAM_A", "GIOCATORI":
            text = "Giocatori"
            color = BorderlandTheme.teamA
        case "B", "TEAM_B", "CITTADINI":
            text = "Cittadini"
            color = BorderlandTheme.teamB
        default:
            text = "Senza team"
            color = BorderlandTheme.textMuted
        }
    }

    var body: some View {
        Text(text)
            .font(AppTypography.caption)
            .foregroundStyle(color.opacity(0.9))
            .padding(.horizontal, Spacing.md)
            .frame(height: 28)
            .background(color.opacity(0.14))
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.28), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}
