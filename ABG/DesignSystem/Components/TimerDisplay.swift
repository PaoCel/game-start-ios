import SwiftUI

struct TimerDisplay: View {
    enum TimerState {
        case normal
        case urgency
        case critical
    }

    let remainingSec: Int

    @State private var borderPulse = false
    @State private var criticalPulse = false
    @State private var flashUrgency = false
    @State private var zeroFlare = false
    @State private var lastCriticalSecond: Int = -1

    private var timerState: TimerState {
        if remainingSec <= 10 { return .critical }
        if remainingSec <= 60 { return .urgency }
        return .normal
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            Text(formattedTime)
                .font(AppTypography.timer)
                .foregroundStyle(textColor)
                .scaleEffect(textScale)
                .frame(maxWidth: .infinity)
                .frame(width: 260)
                .frame(minHeight: 78)
                .background(background)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                        .stroke(borderColor.opacity(borderOpacity), lineWidth: 1.2)
                )
                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous))
                .shadow(color: shadowColor, radius: shadowRadius, y: 4)
                .scaleEffect(containerScale)
        }
        .animation(AnimationTokens.standard, value: timerState)
        .onChange(of: remainingSec) { _, newValue in
            handleTick(second: max(0, newValue))
        }
        .onAppear {
            configureStateAnimations()
            handleTick(second: max(0, remainingSec))
        }
    }

    private var formattedTime: String {
        let bounded = max(0, remainingSec)
        return String(format: "%02d:%02d", bounded / 60, bounded % 60)
    }

    @ViewBuilder
    private var background: some View {
        switch timerState {
        case .normal:
            BorderlandTheme.surface1
        case .urgency:
            BorderlandTheme.surface1
                .overlay(BorderlandTheme.crimson.opacity(flashUrgency ? 0.15 : 0.05))
        case .critical:
            BorderlandTheme.crimsonDeep.opacity(0.15)
                .overlay(BorderlandTheme.crimson.opacity(zeroFlare ? 0.18 : 0))
        }
    }

    private var textColor: Color {
        switch timerState {
        case .normal: return BorderlandTheme.gold
        case .urgency, .critical: return BorderlandTheme.crimson
        }
    }

    private var borderColor: Color {
        switch timerState {
        case .normal: return BorderlandTheme.borderGold
        case .urgency, .critical: return BorderlandTheme.borderCrimson
        }
    }

    private var borderOpacity: Double {
        switch timerState {
        case .normal:
            return 1
        case .urgency:
            return borderPulse ? 0.7 : 0.35
        case .critical:
            return 1
        }
    }

    private var shadowColor: Color {
        switch timerState {
        case .normal: return BorderlandTheme.shadowGoldGlow.color
        case .urgency: return BorderlandTheme.shadowGlow.color
        case .critical: return BorderlandTheme.crimson.opacity(0.25)
        }
    }

    private var shadowRadius: CGFloat {
        timerState == .critical ? 30 : 16
    }

    private var textScale: CGFloat {
        timerState == .critical ? 1.05 : 1.0
    }

    private var containerScale: CGFloat {
        timerState == .critical ? (criticalPulse ? 1.02 : 1.0) : 1.0
    }

    private func configureStateAnimations() {
        switch timerState {
        case .normal:
            borderPulse = false
            criticalPulse = false
        case .urgency:
            withAnimation(AnimationTokens.pulse) {
                borderPulse = true
            }
        case .critical:
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                criticalPulse = true
            }
        }
    }

    private func handleTick(second: Int) {
        configureStateAnimations()

        if timerState == .urgency, second > 0, second.isMultiple(of: 5) {
            withAnimation(.easeInOut(duration: 0.15)) {
                flashUrgency = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                flashUrgency = false
            }
        }

        if timerState == .critical, second != lastCriticalSecond {
            lastCriticalSecond = second
            HapticManager.timerTick()
        }

        if second == 0 {
            HapticManager.heavyImpact()
            withAnimation(.easeInOut(duration: 0.3)) {
                zeroFlare = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                zeroFlare = false
            }
        }
    }
}
