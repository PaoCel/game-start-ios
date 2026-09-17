import SwiftUI

struct ScoreCardView: View {
    let rank: String
    let suitSymbol: String
    let isRedSuit: Bool
    let cardImageURL: URL?
    let points: Int
    @Binding var isRevealed: Bool
    var pointsDelta: Int? = nil
    var width: CGFloat = 240

    @State private var rotationAngle: Double = 0
    @State private var showDelta: Bool = false
    @State private var deltaOpacity: Double = 0
    @State private var autoHideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            frontFace
                .opacity(rotationAngle < 90 ? 1 : 0)

            backFace
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0), perspective: 1.0 / 1200.0)
                .opacity(rotationAngle >= 90 ? 1 : 0)
        }
        .frame(width: width, height: width * 3.5 / 2.5)
        .rotation3DEffect(.degrees(rotationAngle), axis: (x: 0, y: 1, z: 0), perspective: 1.0 / 1200.0)
        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
        .shadow(color: BorderlandTheme.goldGlow, radius: 12, y: 0)
        .onTapGesture {
            HapticManager.lightTap()
            isRevealed.toggle()
        }
        .onChange(of: isRevealed) { _, newValue in
            withAnimation(AnimationTokens.cardFlip) {
                rotationAngle = newValue ? 180 : 0
            }
            if newValue {
                startAutoHideTimer()
            }
        }
        .onChange(of: pointsDelta) { _, newValue in
            guard let newValue, newValue != 0 else { return }
            showDeltaBadge()
        }
        .onDisappear {
            autoHideTask?.cancel()
        }
    }

    private var frontFace: some View {
        RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        BorderlandTheme.cardFace,
                        BorderlandTheme.cardFace.opacity(0.97),
                        Color.white.opacity(0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                    .stroke(BorderlandTheme.borderGold, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusCard - 4, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 0.6)
                    .padding(4)
            )
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.24), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
            }
            .overlay {
                ZStack {
                    if let cardImageURL {
                        AsyncImage(url: cardImageURL) { phase in
                            switch phase {
                            case .empty:
                                ProgressView().tint(BorderlandTheme.gold)
                            case let .success(image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .padding(Spacing.md)
                            case .failure:
                                Text(suitSymbol)
                                    .font(AppTypography.cardRank)
                                    .foregroundStyle(isRedSuit ? BorderlandTheme.cardInkRed : BorderlandTheme.cardInk)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Text(suitSymbol)
                            .font(AppTypography.cardRank)
                            .foregroundStyle(isRedSuit ? BorderlandTheme.cardInkRed : BorderlandTheme.cardInk)
                    }

                    if cardImageURL == nil {
                        VStack {
                            HStack {
                                cornerLabel
                                Spacer()
                            }
                            Spacer()
                            HStack {
                                Spacer()
                                cornerLabel
                                    .rotationEffect(.degrees(180))
                            }
                        }
                        .padding(Spacing.sm)
                    }
                }
            }
    }

    private var backFace: some View {
        RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [BorderlandTheme.surface2, BorderlandTheme.surface1, BorderlandTheme.surface3],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                    .stroke(BorderlandTheme.borderGold, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusCard - 5, style: .continuous)
                    .stroke(BorderlandTheme.borderSubtle, lineWidth: 0.8)
                    .padding(5)
            )
            .overlay {
                VStack(spacing: Spacing.sm) {
                    Text("PUNTI")
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.textMuted)
                        .tracking(2)
                    Text("\(points)")
                        .font(AppTypography.score)
                        .foregroundStyle(BorderlandTheme.gold)

                    if showDelta, let pointsDelta, pointsDelta != 0 {
                        Text(pointsDelta > 0 ? "+\(pointsDelta)" : "\(pointsDelta)")
                            .font(AppTypography.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.md)
                            .frame(height: 24)
                            .background(pointsDelta > 0 ? BorderlandTheme.statusOk : BorderlandTheme.statusDanger)
                            .clipShape(Capsule())
                            .offset(y: deltaOpacity > 0 ? -8 : 0)
                            .opacity(deltaOpacity)
                    }
                }
            }
    }

    private var cornerLabel: some View {
        VStack(spacing: 0) {
            Text(rank)
            Text(suitSymbol)
        }
        .font(AppTypography.cardCorner)
        .foregroundStyle(isRedSuit ? BorderlandTheme.cardInkRed : BorderlandTheme.cardInk)
    }

    private func showDeltaBadge() {
        withAnimation(AnimationTokens.dramaticReveal) {
            showDelta = true
            deltaOpacity = 1
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(.easeOut(duration: 0.5)) {
                deltaOpacity = 0
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            showDelta = false
        }
    }

    private func startAutoHideTimer() {
        autoHideTask?.cancel()
        autoHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            isRevealed = false
        }
    }
}
