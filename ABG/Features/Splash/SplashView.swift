import SwiftUI
import UIKit

struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var logoVisible = false
    @State private var bottomVisible = false
    @State private var dotIndex: Int = 0
    @State private var dotTask: Task<Void, Never>? = nil
    private let splashImage = SplashView.loadSplashImage()

    var body: some View {
        ZStack {
            if let splashImage {
                Image(uiImage: splashImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.38))
            }

            FloatingParticles()

            VStack {
                Spacer()

                heroLogo

                HStack(spacing: Spacing.sm) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(BorderlandTheme.gold)
                            .frame(width: 6, height: 6)
                            .opacity(dotIndex == index ? 1.0 : 0.35)
                            .scaleEffect(dotIndex == index ? 1.12 : 0.9)
                            .animation(AnimationTokens.standard, value: dotIndex)
                    }
                }
                .padding(.top, Spacing.xxxl)

                Spacer()

                Text("Preparati alla prossima partita")
                    .font(AppTypography.caption)
                    .foregroundStyle(BorderlandTheme.textDim)
                    .tracking(1)
                    .padding(.bottom, Spacing.lg)
                    .opacity(bottomVisible ? 1 : 0)
                    .animation(AnimationTokens.smooth.delay(1.2), value: bottomVisible)
            }
            .padding(.horizontal, Spacing.screenHorizontal)
        }
        .borderlandBackground()
        .onAppear {
            logoVisible = true
            bottomVisible = true
            startDotLoop()
        }
        .onDisappear {
            dotTask?.cancel()
            dotTask = nil
        }
    }

    private var entranceAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.3) : AnimationTokens.dramaticReveal
    }

    private var heroLogo: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                BorderlandTheme.focalGlow
                    .frame(width: 320, height: 320)

                Image("LogoCard")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 220)
                    .opacity(logoVisible ? 1 : 0)
                    .scaleEffect(logoVisible || reduceMotion ? 1 : 0.85)
                    .rotationEffect(.degrees(logoVisible || reduceMotion ? 0 : -5))
                    .animation(entranceAnimation, value: logoVisible)
            }

            VStack(spacing: Spacing.xs) {
                Image("LogoGame")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 50)
                    .opacity(logoVisible ? 1 : 0)
                    .offset(y: logoVisible || reduceMotion ? 0 : 14)
                    .animation(entranceAnimation.delay(0.25), value: logoVisible)

                Image("LogoStart")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)
                    .opacity(logoVisible ? 1 : 0)
                    .offset(y: logoVisible || reduceMotion ? 0 : 10)
                    .animation(entranceAnimation.delay(0.4), value: logoVisible)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Game Start!")
    }

    private func startDotLoop() {
        dotTask?.cancel()
        dotTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                dotIndex = (dotIndex + 1) % 3
            }
        }
    }

    private static func loadSplashImage() -> UIImage? {
        if let bundled = Bundle.main.url(
            forResource: "splash",
            withExtension: "png",
            subdirectory: "playing-cards-assets"
        ) {
            return UIImage(contentsOfFile: bundled.path)
        }

        if let flattened = Bundle.main.url(forResource: "splash", withExtension: "png") {
            return UIImage(contentsOfFile: flattened.path)
        }

        return nil
    }
}
