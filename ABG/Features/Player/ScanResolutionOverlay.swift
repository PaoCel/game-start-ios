import SwiftUI

struct ScanResolutionOverlay: View {
    let message: String
    let context: String?

    @State private var spinning = false
    @State private var pulsing = false

    var body: some View {
        ZStack {
            BorderlandTheme.void.opacity(0.88)
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                ZStack {
                    Circle()
                        .stroke(BorderlandTheme.violet.opacity(0.28), lineWidth: 1.5)
                        .frame(width: 172, height: 172)
                        .scaleEffect(pulsing ? 1.08 : 0.92)

                    Circle()
                        .trim(from: 0.08, to: 0.84)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    BorderlandTheme.gold.opacity(0.18),
                                    BorderlandTheme.gold,
                                    BorderlandTheme.violet,
                                    BorderlandTheme.gold.opacity(0.18)
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 9, lineCap: .round)
                        )
                        .frame(width: 146, height: 146)
                        .rotationEffect(.degrees(spinning ? 360 : 0))

                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 54, weight: .black))
                        .foregroundStyle(BorderlandTheme.gold)
                        .shadow(color: BorderlandTheme.gold.opacity(0.35), radius: 18)
                }

                VStack(spacing: Spacing.sm) {
                    Text("RISOLUZIONE SCONTRO")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(BorderlandTheme.gold)
                        .tracking(2)

                    Text(message)
                        .font(AppTypography.title3)
                        .foregroundStyle(BorderlandTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    if let context, !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(context)
                            .font(AppTypography.callout)
                            .foregroundStyle(BorderlandTheme.textMuted)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: 320)
            }
            .padding(Spacing.xxl)
        }
        .onAppear {
            spinning = false
            pulsing = false

            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                spinning = true
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}

#Preview("Scan Resolution Overlay") {
    ScanResolutionOverlay(
        message: "Sfida in risoluzione",
        context: "Il backend sta confrontando i due lati e aggiornando i punteggi."
    )
}
