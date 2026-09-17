import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PlayingCardView: View {
    let rank: String
    let suit: String
    let cardImageURL: URL?
    let showFront: Bool
    let width: CGFloat

    private static let cardBackImage: Image? = {
        #if canImport(UIKit)
        if let url = Bundle.main.url(
            forResource: "card_back",
            withExtension: "png"
        ), let image = UIImage(contentsOfFile: url.path) {
            return Image(uiImage: image)
        }
        if let url = Bundle.main.url(
            forResource: "card_back",
            withExtension: "png",
            subdirectory: "playing-cards-assets"
        ), let image = UIImage(contentsOfFile: url.path) {
            return Image(uiImage: image)
        }
        #endif
        return nil
    }()

    init(rank: String, suit: String, cardImageURL: URL?, showFront: Bool = true, width: CGFloat = 240) {
        self.rank = rank
        self.suit = suit
        self.cardImageURL = cardImageURL
        self.showFront = showFront
        self.width = width
    }

    private var isRedSuit: Bool {
        suit == "♥" || suit == "♦"
    }

    var body: some View {
        ZStack {
            frontFace
                .opacity(showFront ? 1 : 0)

            backFace
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0), perspective: 1.0 / 1200.0)
                .opacity(showFront ? 0 : 1)
        }
        .frame(width: width, height: width * 3.5 / 2.5)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous))
        .rotation3DEffect(.degrees(showFront ? 0 : 180), axis: (x: 0, y: 1, z: 0), perspective: 1.0 / 1200.0)
        .shadow(color: BorderlandTheme.shadowLarge.color, radius: BorderlandTheme.shadowLarge.radius, y: BorderlandTheme.shadowLarge.y)
        .animation(AnimationTokens.cardFlip, value: showFront)
    }

    private var frontFace: some View {
        RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
            .fill(BorderlandTheme.cardFace)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                    .stroke(BorderlandTheme.borderGold, lineWidth: 1)
            )
            .overlay(cardFrontContent)
    }

    private var cardFrontContent: some View {
        ZStack {
            loadedCardImage

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

    @ViewBuilder
    private var loadedCardImage: some View {
        #if canImport(UIKit)
        if let cardImageURL,
           cardImageURL.isFileURL,
           let image = UIImage(contentsOfFile: cardImageURL.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(Spacing.md)
        } else {
            asyncCardImage
        }
        #else
        asyncCardImage
        #endif
    }

    @ViewBuilder
    private var asyncCardImage: some View {
        if let cardImageURL {
            AsyncImage(url: cardImageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .tint(BorderlandTheme.gold)
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(Spacing.md)
                case .failure:
                    suitFallback
                @unknown default:
                    suitFallback
                }
            }
        } else {
            suitFallback
        }
    }

    private var suitFallback: some View {
        Text(suit)
            .font(AppTypography.cardRank)
            .foregroundStyle(isRedSuit ? BorderlandTheme.cardInkRed : BorderlandTheme.cardInk)
    }

    private var cornerLabel: some View {
        VStack(spacing: 0) {
            Text(rank)
            Text(suit)
        }
        .font(AppTypography.cardCorner)
        .foregroundStyle(isRedSuit ? BorderlandTheme.cardInkRed : BorderlandTheme.cardInk)
    }

    private var backFace: some View {
        ZStack {
            if let back = Self.cardBackImage {
                back
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: width * 3.5 / 2.5)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [BorderlandTheme.violetDeep, BorderlandTheme.crimsonDeep, BorderlandTheme.violetDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                .stroke(BorderlandTheme.borderGold, lineWidth: 1)
        )
    }
}
