import SwiftUI

struct EnergyAura: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { idx in
                Circle()
                    .stroke(idx.isMultiple(of: 2) ? BorderlandTheme.crimson.opacity(0.4) : BorderlandTheme.violet.opacity(0.35), lineWidth: 2)
                    .frame(width: 120 + CGFloat(idx) * 34, height: 120 + CGFloat(idx) * 34)
                    .scaleEffect(animate ? 1.2 : 0.9)
                    .opacity(animate ? 0.0 : 0.55)
                    .animation(
                        AnimationTokens.glowPulse.delay(Double(idx) * 0.15),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
        .allowsHitTesting(false)
    }
}
