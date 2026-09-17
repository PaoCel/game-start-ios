import SwiftUI

struct NFCScanOverlay: View {
    let onCancel: () -> Void

    @State private var animate = false
    @State private var pulseTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            BorderlandTheme.void.opacity(0.8)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack {
                Spacer()

                ZStack {
                    ring(size: 80, color: BorderlandTheme.crimson, lineWidth: 2, delay: 0)
                    ring(size: 140, color: BorderlandTheme.violet, lineWidth: 1.5, delay: 0.3)
                    ring(size: 200, color: BorderlandTheme.crimson.opacity(0.5), lineWidth: 1, delay: 0.6)

                    Image(systemName: "wave.3.right")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(BorderlandTheme.gold)
                        .rotationEffect(.degrees(animate ? 5 : -5))
                        .animation(AnimationTokens.glowPulse, value: animate)
                }

                Text("Avvicina il braccialetto")
                    .font(AppTypography.title3)
                    .foregroundStyle(BorderlandTheme.textPrimary)
                    .padding(.top, Spacing.xl)

                Text("Cerca il braccialetto NFC dell'avversario")
                    .font(AppTypography.caption)
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .padding(.top, Spacing.xs)

                Spacer()

                BorderlandButton("Annulla", variant: .ghost) {
                    onCancel()
                }
                .frame(width: 140)
                .padding(.bottom, Spacing.xxl)
            }
            .padding(.horizontal, Spacing.screenHorizontal)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            animate = true
            HapticManager.mediumImpact()
            startPulseLoop()
        }
        .onDisappear {
            pulseTask?.cancel()
            pulseTask = nil
        }
    }

    private func ring(size: CGFloat, color: Color, lineWidth: CGFloat, delay: Double) -> some View {
        Circle()
            .stroke(color, lineWidth: lineWidth)
            .frame(width: size, height: size)
            .scaleEffect(animate ? 1.4 : 1.0)
            .opacity(animate ? 0.0 : 0.9)
            .animation(AnimationTokens.glowPulse.delay(delay), value: animate)
            .glowEffect(color: color.opacity(0.35), radius: 14)
    }

    private func startPulseLoop() {
        pulseTask?.cancel()
        pulseTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                HapticManager.lightTap()
            }
        }
    }
}

#Preview("NFC Scan Overlay") {
    NFCScanOverlay(onCancel: {})
}
