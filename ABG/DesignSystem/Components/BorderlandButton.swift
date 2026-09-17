import SwiftUI

struct BorderlandButton: View {
    enum Variant {
        case primary
        case secondary
        case ghost
        case danger
        case action
    }

    let title: String
    let variant: Variant
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    init(
        _ title: String,
        variant: Variant = .primary,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button {
            HapticManager.lightTap()
            action()
        } label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else {
                    Text(title)
                        .font(font)
                        .tracking(variant == .action ? 0.6 : 0)
                }
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(background)
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
            .opacity(isEnabled ? 1 : 0.55)
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled || isLoading)
        .frame(minHeight: 44)
    }

    private var height: CGFloat {
        variant == .action ? 88 : 52
    }

    private var font: Font {
        switch variant {
        case .action: return AppTypography.title2
        default: return AppTypography.headline
        }
    }

    private var cornerRadius: CGFloat {
        variant == .action ? Spacing.radiusLarge : Spacing.radiusMedium
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary, .danger, .action: return .white
        case .secondary: return BorderlandTheme.gold
        case .ghost: return BorderlandTheme.textPrimary
        }
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .primary:
            BorderlandTheme.crimson
        case .secondary:
            BorderlandTheme.surface2
        case .ghost:
            Color.clear
        case .danger:
            BorderlandTheme.statusDanger
        case .action:
            BorderlandTheme.surface1
        }
    }

    @ViewBuilder
    private var border: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(borderColor, lineWidth: borderWidth)
    }

    private var borderColor: Color {
        switch variant {
        case .primary: return BorderlandTheme.borderCrimson
        case .secondary: return BorderlandTheme.borderGold
        case .ghost: return .clear
        case .danger: return BorderlandTheme.statusDangerText.opacity(0.45)
        case .action: return BorderlandTheme.crimsonGlow
        }
    }

    private var borderWidth: CGFloat {
        variant == .ghost ? 0 : 1
    }

    private var shadowColor: Color {
        switch variant {
        case .primary, .action: return BorderlandTheme.shadowGlow.color
        case .secondary: return BorderlandTheme.shadowGoldGlow.color
        case .danger: return BorderlandTheme.statusDanger.opacity(0.24)
        case .ghost: return .clear
        }
    }

    private var shadowRadius: CGFloat {
        switch variant {
        case .action: return 16
        case .ghost: return 0
        default: return 10
        }
    }

    private var shadowY: CGFloat {
        variant == .ghost ? 0 : 4
    }
}
