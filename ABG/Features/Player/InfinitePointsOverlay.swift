import SwiftUI

struct InfinitePointsOverlay: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            EnergyAura()

            ForEach(0..<6, id: \.self) { idx in
                Text("♦")
                    .font(.system(size: CGFloat(10 + idx), weight: .bold))
                    .foregroundStyle(BorderlandTheme.gold.opacity(0.6))
                    .offset(
                        x: CGFloat(idx * 24 - 60),
                        y: animate ? CGFloat(-50 - idx * 14) : CGFloat(-20 - idx * 12)
                    )
                    .opacity(0.7)
                    .animation(
                        .easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(Double(idx) * 0.1),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
        .allowsHitTesting(false)
    }
}

#Preview("Infinite Points Overlay") {
    ZStack {
        Color.black.ignoresSafeArea()
        InfinitePointsOverlay()
    }
}
