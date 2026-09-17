import Foundation
import UIKit

enum HapticManager {
    static func lightTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func mediumImpact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func heavyImpact() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func battleWin() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    static func battleLose() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    static func elimination() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            try? await Task.sleep(nanoseconds: 80_000_000)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    static func scanPulse() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func timerTick() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
