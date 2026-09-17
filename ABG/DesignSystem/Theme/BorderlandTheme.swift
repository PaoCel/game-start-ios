import Observation
import SwiftUI

struct Shadow {
    let color: Color
    let radius: CGFloat
    let y: CGFloat
}

@Observable
final class BorderlandTheme {
    static let void = Color(hex: "#0D0810")
    static let surface1 = Color(hex: "#151018")
    static let surface2 = Color(hex: "#1E1525")
    static let surface3 = Color(hex: "#2A2033")

    static let crimson = Color(hex: "#DC143C")
    static let crimsonDeep = Color(hex: "#8B0A1A")
    static let crimsonGlow = Color(hex: "#DC143C").opacity(0.25)

    static let violet = Color(hex: "#7B2D8E")
    static let violetDeep = Color(hex: "#4A1259")
    static let violetGlow = Color(hex: "#7B2D8E").opacity(0.20)

    static let emerald = Color(hex: "#1E7F4E")
    static let emeraldLight = Color(hex: "#4DCA8A")
    static let emeraldDeep = Color(hex: "#0F3D2A")
    static let emeraldGlow = Color(hex: "#4DCA8A").opacity(0.20)

    static let gold = Color(hex: "#C9A037")
    static let goldLight = Color(hex: "#E5C158")
    static let goldGlow = Color(hex: "#C9A037").opacity(0.15)

    static let cardFace = Color(hex: "#F5F0E8")
    static let cardInk = Color(hex: "#1A1A1A")
    static let cardInkRed = Color(hex: "#B81C1C")

    static let textPrimary = Color(hex: "#F0EDE5")
    static let textMuted = Color(hex: "#888888")
    static let textDim = Color(hex: "#6E6878")

    static let statusOk = Color(hex: "#1E7F4E")
    static let statusOkText = Color(hex: "#4DCA8A")
    static let statusWarn = Color(hex: "#A07800")
    static let statusWarnText = Color(hex: "#E5C158")
    static let statusDanger = Color(hex: "#B52020")
    static let statusDangerText = Color(hex: "#F07070")

    static let teamA = Color(hex: "#CC2222")
    static let teamB = Color(hex: "#3355CC")

    static let borderDim = Color.white.opacity(0.06)
    static let borderSubtle = Color.white.opacity(0.10)
    static let borderMedium = Color.white.opacity(0.18)
    static let borderGold = Color(hex: "#C9A037").opacity(0.35)
    static let borderCrimson = Color(hex: "#DC143C").opacity(0.35)
    static let borderEmerald = Color(hex: "#4DCA8A").opacity(0.35)

    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "#0D0810"), Color(hex: "#120A18"), Color(hex: "#0D0810")],
        startPoint: .top,
        endPoint: .bottom
    )

    static let focalGlow = RadialGradient(
        colors: [Color(hex: "#DC143C").opacity(0.08), Color(hex: "#7B2D8E").opacity(0.04), .clear],
        center: .center,
        startRadius: 20,
        endRadius: 300
    )

    static let panelGradient = LinearGradient(
        colors: [Color(hex: "#1A1220"), Color(hex: "#151018")],
        startPoint: .top,
        endPoint: .bottom
    )

    static let urgencyGradient = LinearGradient(
        colors: [Color(hex: "#DC143C"), Color(hex: "#8B0A1A")],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let shadowSmall = Shadow(color: .black.opacity(0.4), radius: 8, y: 4)
    static let shadowMedium = Shadow(color: .black.opacity(0.5), radius: 16, y: 8)
    static let shadowLarge = Shadow(color: .black.opacity(0.6), radius: 32, y: 12)
    static let shadowGlow = Shadow(color: Color(hex: "#DC143C").opacity(0.15), radius: 20, y: 0)
    static let shadowGoldGlow = Shadow(color: Color(hex: "#C9A037").opacity(0.12), radius: 16, y: 0)
}

private struct BorderlandThemeKey: EnvironmentKey {
    static let defaultValue = BorderlandTheme()
}

extension EnvironmentValues {
    var theme: BorderlandTheme {
        get { self[BorderlandThemeKey.self] }
        set { self[BorderlandThemeKey.self] = newValue }
    }
}
