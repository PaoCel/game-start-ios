import SwiftUI

struct BorderlandBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            BorderlandTheme.backgroundGradient
                .ignoresSafeArea()
            content
        }
        .preferredColorScheme(.dark)
    }
}

extension View {
    func borderlandBackground() -> some View {
        modifier(BorderlandBackground())
    }
}
