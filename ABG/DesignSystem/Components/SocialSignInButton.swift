import SwiftUI

/// Marchio "G" di Google disegnato con la geometria vettoriale ufficiale
/// (viewBox 48x48), quindi nitido a qualsiasi dimensione.
struct GoogleGMark: View {
    var body: some View {
        ZStack {
            VectorPathShape(Self.blue).fill(Color(hex: "#4285F4"))
            VectorPathShape(Self.green).fill(Color(hex: "#34A853"))
            VectorPathShape(Self.yellow).fill(Color(hex: "#FBBC05"))
            VectorPathShape(Self.red).fill(Color(hex: "#EA4335"))
        }
        .accessibilityHidden(true)
    }

    private static let blue = """
    M45.12 24.5c0-1.56-.14-3.06-.4-4.5H24v8.51h11.84c-.51 2.75-2.06 5.08-4.39 6.64v5.52h7.11\
    c4.16-3.83 6.56-9.47 6.56-16.17z
    """

    private static let green = """
    M24 46c5.94 0 10.92-1.97 14.56-5.33l-7.11-5.52c-1.97 1.32-4.49 2.1-7.45 2.1-5.73 0-10.58-3.87-12.31-9.07\
    l-7.35 5.7C7.96 41.07 15.4 46 24 46z
    """

    private static let yellow = """
    M11.69 28.18C11.25 26.86 11 25.45 11 24s.25-2.86.69-4.18l-7.35-5.7C2.85 17.09 2 20.45 2 24s.85 6.91 2.34 9.88\
    l7.35-5.7z
    """

    private static let red = """
    M24 9.5c3.23 0 6.13 1.11 8.41 3.29l6.31-6.31C34.91 2.18 29.93 0 24 0 15.4 0 7.96 4.93 4.34 12.12\
    l7.35 5.7C13.42 12.62 18.27 9.5 24 9.5z
    """
}

/// Logo Apple ottico: il simbolo di sistema è il marchio ufficiale, ma va
/// alzato leggermente per allinearsi alla x-height del testo affiancato.
struct AppleMark: View {
    var size: CGFloat = 21

    var body: some View {
        Image(systemName: "apple.logo")
            .font(.system(size: size, weight: .medium))
            .offset(y: -size * 0.06)
            .accessibilityHidden(true)
    }
}

/// Bottone di accesso con provider, conforme alle linee guida dei brand:
/// superficie chiara, marchio a sinistra, etichetta centrata otticamente.
struct SocialSignInButton: View {
    enum Provider {
        case apple
        case google
        case guest
    }

    let provider: Provider
    let title: String
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .tint(foreground)
                    } else {
                        mark
                    }
                }
                .frame(width: 26, height: 26)

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
            .shadow(color: .black.opacity(provider == .guest ? 0 : 0.35), radius: 10, y: 4)
            .opacity(isEnabled ? 1 : 0.55)
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var mark: some View {
        switch provider {
        case .apple:
            AppleMark(size: 22)
                .foregroundStyle(Color.black)
        case .google:
            GoogleGMark()
                .frame(width: 20, height: 20)
        case .guest:
            Image(systemName: "person.crop.circle.dashed")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(BorderlandTheme.gold)
        }
    }

    private var foreground: Color {
        switch provider {
        case .apple: return .black
        case .google: return Color(hex: "#1F1F1F")
        case .guest: return BorderlandTheme.textPrimary
        }
    }

    @ViewBuilder
    private var background: some View {
        switch provider {
        case .apple, .google: Color.white
        case .guest: BorderlandTheme.surface2.opacity(0.9)
        }
    }

    private var border: Color {
        switch provider {
        case .apple: return .clear
        case .google: return Color(hex: "#747775").opacity(0.5)
        case .guest: return BorderlandTheme.borderGold.opacity(0.7)
        }
    }
}

#Preview {
    VStack(spacing: Spacing.sm) {
        SocialSignInButton(provider: .apple, title: "Continua con Apple") {}
        SocialSignInButton(provider: .google, title: "Continua con Google") {}
        SocialSignInButton(provider: .guest, title: "Entra come ospite") {}
    }
    .padding()
    .background(BorderlandTheme.void)
}
