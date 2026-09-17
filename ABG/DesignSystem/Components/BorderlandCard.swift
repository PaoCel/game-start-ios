import SwiftUI

struct BorderlandCard<Content: View>: View {
    enum Variant {
        case standard
        case gold
        case elevated
    }

    let variant: Variant
    @ViewBuilder let content: Content

    init(variant: Variant = .standard, @ViewBuilder content: () -> Content) {
        self.variant = variant
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous))
            .shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
            .shadow(color: extraGlow, radius: 14, y: 0)
    }

    private var backgroundColor: Color {
        switch variant {
        case .standard, .gold: return BorderlandTheme.surface1
        case .elevated: return BorderlandTheme.surface2
        }
    }

    private var borderColor: Color {
        switch variant {
        case .gold: return BorderlandTheme.borderGold
        default: return BorderlandTheme.borderSubtle
        }
    }

    private var shadow: Shadow {
        switch variant {
        case .elevated: return BorderlandTheme.shadowLarge
        default: return BorderlandTheme.shadowMedium
        }
    }

    private var extraGlow: Color {
        variant == .gold ? BorderlandTheme.shadowGoldGlow.color : .clear
    }
}
