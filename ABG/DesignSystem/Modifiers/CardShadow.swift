import SwiftUI

struct CardShadow: ViewModifier {
    let glowColor: Color

    init(glowColor: Color = BorderlandTheme.goldGlow) {
        self.glowColor = glowColor
    }

    func body(content: Content) -> some View {
        content
            .shadow(color: BorderlandTheme.shadowLarge.color, radius: BorderlandTheme.shadowLarge.radius, y: BorderlandTheme.shadowLarge.y)
            .shadow(color: glowColor, radius: 14, y: 0)
    }
}

extension View {
    func cardShadow(glowColor: Color = BorderlandTheme.goldGlow) -> some View {
        modifier(CardShadow(glowColor: glowColor))
    }
}
