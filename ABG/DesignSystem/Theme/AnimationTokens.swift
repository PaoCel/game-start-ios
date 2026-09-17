import SwiftUI

enum AnimationTokens {
    static let quick: Animation = .easeOut(duration: 0.15)
    static let standard: Animation = .easeInOut(duration: 0.25)
    static let smooth: Animation = .easeInOut(duration: 0.35)
    static let cardFlip: Animation = .timingCurve(0.4, 0, 0.2, 1, duration: 0.62)
    static let dramaticReveal: Animation = .spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.1)
    static let pulse: Animation = .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
    static let glowPulse: Animation = .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
    static let pointFly: Animation = .interpolatingSpring(stiffness: 80, damping: 12)
    static let elimination: Animation = .easeIn(duration: 0.8)
    static let slideUp: Animation = .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
}
