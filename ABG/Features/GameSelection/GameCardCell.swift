import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct GameCardCell: View {
    let game: GameDefinition
    let isVisible: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                .fill(BorderlandTheme.surface1)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                        .stroke(game.isAvailable ? BorderlandTheme.borderGold : BorderlandTheme.borderSubtle, lineWidth: 1)
                )

            artwork
                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous))

            LinearGradient(
                colors: [
                    Color.clear,
                    BorderlandTheme.void.opacity(0.22),
                    BorderlandTheme.void.opacity(0.82)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous))

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(game.name)
                    .font(AppTypography.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: Spacing.xs) {
                    Text("Card \(game.cardNumber)\(game.suitSymbol)")
                        .font(AppTypography.caption2)
                        .foregroundStyle(BorderlandTheme.gold)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(BorderlandTheme.surface2.opacity(0.92), in: Capsule())

                    Spacer()
                }
            }
            .padding(Spacing.md)

            if !game.isAvailable {
                unavailableOverlay
            }
        }
        .aspectRatio(2.5 / 3.5, contentMode: .fit)
        .shadow(color: BorderlandTheme.shadowMedium.color, radius: BorderlandTheme.shadowMedium.radius, y: BorderlandTheme.shadowMedium.y)
        .scaleEffect(isVisible ? 1.0 : 0.93)
        .offset(y: isVisible ? 0 : 24)
        .opacity(isVisible ? 1.0 : 0.0)
    }

    @ViewBuilder
    private var artwork: some View {
        cardArtworkStage {
        #if canImport(UIKit)
        if let localURL = PlayingCardCatalog.localImageURL(for: game.cardCode),
           let image = UIImage(contentsOfFile: localURL.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(Spacing.sm)
        } else {
            remoteArtwork
        }
        #else
        remoteArtwork
        #endif
        }
    }

    @ViewBuilder
    private var remoteArtwork: some View {
        if let remoteURL = URL(string: PlayingCardCatalog.imageURLString(for: game.cardCode)) {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .tint(BorderlandTheme.gold)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(BorderlandTheme.surface2)
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(Spacing.sm)
                case .failure:
                    fallbackArtwork
                @unknown default:
                    fallbackArtwork
                }
            }
        } else {
            fallbackArtwork
        }
    }

    private var fallbackArtwork: some View {
        ZStack {
            BorderlandTheme.cardFace.opacity(0.92)
            Text(game.suitSymbol)
                .font(.system(size: 52, weight: .black))
                .foregroundStyle((game.suit == "hearts" || game.suit == "diamonds") ? BorderlandTheme.cardInkRed : BorderlandTheme.cardInk)
                .opacity(0.5)
        }
    }

    private func cardArtworkStage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [BorderlandTheme.cardFace.opacity(0.98), BorderlandTheme.cardFace.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
                        .stroke(BorderlandTheme.borderMedium, lineWidth: 1)
                )
            content()
        }
        .padding(Spacing.sm)
    }

    private var unavailableOverlay: some View {
        RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
            .fill(BorderlandTheme.void.opacity(0.72))
            .overlay {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(BorderlandTheme.textDim)
                    Text("COMING SOON")
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.textDim)
                        .tracking(1)
                }
            }
    }
}
