import SwiftUI

struct EliminationOverlay: View {
    let onClose: () -> Void

    @State private var phase = 0

    var body: some View {
        ZStack {
            BorderlandTheme.void.opacity(0.92).ignoresSafeArea()

            BorderlandTheme.crimson
                .opacity(phase == 0 ? 0.3 : 0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: phase)

            VStack(spacing: Spacing.lg) {
                if phase >= 1 {
                    Text("GAME OVER")
                        .font(AppTypography.display)
                        .foregroundStyle(BorderlandTheme.crimson)
                        .tracking(2)
                }

                if phase >= 2 {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(BorderlandTheme.crimson)
                        .transition(.scale.combined(with: .opacity))
                }

                if phase >= 3 {
                    Text("Sei stato eliminato")
                        .font(AppTypography.title3)
                        .foregroundStyle(BorderlandTheme.textMuted)
                    Text("I tuoi punti sono esauriti")
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.textDim)
                }

                if phase >= 4 {
                    BorderlandButton("Chiudi", variant: .ghost) {
                        onClose()
                    }
                    .frame(width: 140)
                }
            }
            .padding(Spacing.xxl)
        }
        .onAppear {
            HapticManager.elimination()

            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                phase = 1
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                phase = 2
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                phase = 3
                try? await Task.sleep(nanoseconds: 300_000_000)
                phase = 4
            }
        }
    }
}

#Preview("Elimination Overlay") {
    EliminationOverlay(onClose: {})
}
