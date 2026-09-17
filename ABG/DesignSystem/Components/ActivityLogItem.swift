import SwiftUI

struct ActivityLogItem: View {
    enum Variant {
        case ok
        case warn
        case error
    }

    let timestamp: String
    let message: String
    let variant: Variant

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text(timestamp)
                .font(AppTypography.mono)
                .foregroundStyle(BorderlandTheme.textDim)
                .frame(width: 72, alignment: .leading)
            Text(message)
                .font(AppTypography.callout)
                .foregroundStyle(textColor)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(BorderlandTheme.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
                .stroke(BorderlandTheme.borderDim, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
    }

    private var textColor: Color {
        switch variant {
        case .ok: return BorderlandTheme.statusOkText
        case .warn: return BorderlandTheme.statusWarnText
        case .error: return BorderlandTheme.statusDangerText
        }
    }
}
