import SwiftUI

/// Semi delle carte in filigrana sullo sfondo, statici: atmosfera senza costo.
/// `density` regola quanti semi appaiono (schermate dense → .light).
struct SuitBackdrop: View {
    enum Density {
        case full   // schermate hero (welcome, splash, home)
        case light  // schermate operative (HUD, admin, liste)
    }

    var density: Density = .full

    var body: some View {
        GeometryReader { geo in
            ZStack {
                suit("suit.spade.fill", size: 220, x: -40, y: 60, opacity: 0.05)
                suit("suit.club.fill", size: 180, x: 10, y: geo.size.height - 160, opacity: 0.045)
                if density == .full {
                    suit("suit.heart.fill", size: 150, x: geo.size.width - 50, y: 160, opacity: 0.04)
                    suit("suit.diamond.fill", size: 130, x: geo.size.width - 30, y: geo.size.height - 260, opacity: 0.04)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func suit(_ name: String, size: CGFloat, x: CGFloat, y: CGFloat, opacity: Double) -> some View {
        Image(systemName: name)
            .font(.system(size: size))
            .foregroundStyle(BorderlandTheme.gold.opacity(opacity))
            .position(x: x, y: y)
    }
}
