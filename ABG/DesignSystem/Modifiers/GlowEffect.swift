import SwiftUI

struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat
    let pulsing: Bool

    @State private var isAnimating = false

    init(color: Color = BorderlandTheme.crimsonGlow, radius: CGFloat = 20, pulsing: Bool = false) {
        self.color = color
        self.radius = radius
        self.pulsing = pulsing
    }

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(isAnimating ? 0.9 : 0.45), radius: isAnimating ? radius : radius * 0.65)
            .onAppear {
                guard pulsing else { return }
                withAnimation(AnimationTokens.glowPulse) {
                    isAnimating = true
                }
            }
    }
}

extension View {
    func glowEffect(color: Color = BorderlandTheme.crimsonGlow, radius: CGFloat = 20, pulsing: Bool = false) -> some View {
        modifier(GlowEffect(color: color, radius: radius, pulsing: pulsing))
    }
}
