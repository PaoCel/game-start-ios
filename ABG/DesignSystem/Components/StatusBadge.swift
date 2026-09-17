import SwiftUI

struct StatusBadge: View {
    enum Variant {
        case ok
        case warn
        case error
        case neutral
    }

    let text: String
    let variant: Variant

    var body: some View {
        Text(text)
            .font(AppTypography.caption)
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(background)
            .overlay(
                Capsule()
                    .stroke(border, lineWidth: 1)
            )
            .clipShape(Capsule())
    }

    private var foreground: Color {
        switch variant {
        case .ok: return BorderlandTheme.statusOkText
        case .warn: return BorderlandTheme.statusWarnText
        case .error: return BorderlandTheme.statusDangerText
        case .neutral: return BorderlandTheme.textMuted
        }
    }

    private var background: Color {
        switch variant {
        case .ok: return BorderlandTheme.statusOk.opacity(0.20)
        case .warn: return BorderlandTheme.statusWarn.opacity(0.20)
        case .error: return BorderlandTheme.statusDanger.opacity(0.20)
        case .neutral: return BorderlandTheme.surface3
        }
    }

    private var border: Color {
        foreground.opacity(0.55)
    }
}
