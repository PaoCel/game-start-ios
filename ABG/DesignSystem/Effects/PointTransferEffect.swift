import SwiftUI

struct PointTransferEffect: View {
    let value: Int

    @State private var particles: [Particle] = []
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Text(label)
                    .font(.system(size: particle.fontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .offset(
                        x: animate ? particle.targetX : 0,
                        y: animate ? particle.targetY : 0
                    )
                    .scaleEffect(animate ? 0.6 : 1.0)
                    .opacity(animate ? 0.0 : 1.0)
                    .animation(
                        AnimationTokens.pointFly
                            .speed(0.85)
                            .delay(particle.delay),
                        value: animate
                    )
            }
        }
        .onAppear {
            particles = (0..<Int.random(in: 6...8)).map { _ in Particle.random() }
            animate = false
            DispatchQueue.main.async {
                animate = true
            }
        }
        .allowsHitTesting(false)
    }

    private var label: String {
        value >= 0 ? "+\(abs(value))" : "-\(abs(value))"
    }

    private var color: Color {
        value >= 0 ? BorderlandTheme.gold : BorderlandTheme.crimson
    }
}

private struct Particle: Identifiable {
    let id = UUID()
    let targetX: CGFloat
    let targetY: CGFloat
    let delay: Double
    let fontSize: CGFloat

    static func random() -> Particle {
        let angle = Double.random(in: 0...(2 * Double.pi))
        let distance = CGFloat.random(in: 80...180)
        return Particle(
            targetX: cos(angle) * distance,
            targetY: sin(angle) * distance,
            delay: Double.random(in: 0...0.15),
            fontSize: CGFloat.random(in: 14...24)
        )
    }
}
