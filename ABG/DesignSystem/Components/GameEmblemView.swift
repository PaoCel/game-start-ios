import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Marchio del gioco in formato compatto: usa l'emblema dedicato
/// (`emblem-<id>`) se presente nel catalogo asset, altrimenti ripiega
/// sulla targhetta con rango e seme della carta.
struct GameEmblemView: View {
    let game: GameDefinition
    var size: CGFloat = 34

    var body: some View {
        if let emblem {
            emblem
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            cardChip
        }
    }

    private var emblem: Image? {
        #if canImport(UIKit)
        guard UIImage(named: game.emblemAssetName) != nil else { return nil }
        return Image(game.emblemAssetName)
        #else
        return nil
        #endif
    }

    private var cardChip: some View {
        Text("\(game.cardNumber)\(game.suitSymbol)")
            .font(AppTypography.cardCorner)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .foregroundStyle(BorderlandTheme.cardInk)
            .frame(width: size * 0.76, height: size)
            .background(
                BorderlandTheme.cardFace,
                in: RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}
