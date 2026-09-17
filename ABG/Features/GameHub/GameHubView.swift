import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Prima schermata dopo il login: si sceglie il gioco del mazzo.
/// Solo "Re di Fiori" è giocabile, gli altri restano come teaser del mazzo.
struct GameHubView: View {
    let displayName: String
    let onSelect: (GameDefinition) -> Void
    let onOpenSettings: () -> Void
    let onLogout: () async -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    private var availableGames: [GameDefinition] {
        GameDefinition.allGames.filter(\.isAvailable)
    }

    private var lockedGames: [GameDefinition] {
        GameDefinition.allGames.filter { !$0.isAvailable }
    }

    var body: some View {
        ZStack {
            SuitBackdrop(density: .full)
            FloatingParticles()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    topBar
                        .opacity(hasAppeared ? 1 : 0)
                        .animation(entrance.delay(0.05), value: hasAppeared)

                    titleBlock
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared || reduceMotion ? 0 : 10)
                        .animation(entrance.delay(0.15), value: hasAppeared)

                    ForEach(Array(availableGames.enumerated()), id: \.element.id) { index, game in
                        FeaturedGameCard(game: game) {
                            HapticManager.lightTap()
                            onSelect(game)
                        }
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared || reduceMotion ? 0 : 22)
                        .animation(entrance.delay(0.28 + Double(index) * 0.08), value: hasAppeared)
                    }

                    if !lockedGames.isEmpty {
                        lockedSection
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared || reduceMotion ? 0 : 22)
                            .animation(entrance.delay(0.42), value: hasAppeared)
                    }

                    Text("Il mazzo si completa a ogni festa. Nuove carte, nuove regole.")
                        .font(AppTypography.caption2)
                        .foregroundStyle(BorderlandTheme.textDim)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, Spacing.lg)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.md)
            }
        }
        .borderlandBackground()
        .onAppear { hasAppeared = true }
    }

    private var entrance: Animation {
        reduceMotion ? .easeOut(duration: 0.25) : AnimationTokens.dramaticReveal
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: Spacing.md) {
            Image("LogoGame")
                .resizable()
                .scaledToFit()
                .frame(height: 26)
                .accessibilityHidden(true)

            Spacer(minLength: 0)

            Menu {
                Button {
                    onOpenSettings()
                } label: {
                    Label("Impostazioni", systemImage: "gearshape.fill")
                }

                Button(role: .destructive) {
                    Task { await onLogout() }
                } label: {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(BorderlandTheme.gold)
                    .frame(width: 46, height: 46)
                    .background(BorderlandTheme.surface2.opacity(0.9))
                    .overlay(
                        Circle().stroke(BorderlandTheme.borderGold.opacity(0.5), lineWidth: 1)
                    )
                    .clipShape(Circle())
            }
            .accessibilityLabel("Menu")
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if !displayName.isEmpty {
                Text("Ciao, \(displayName)")
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.gold)
                    .lineLimit(1)
            }

            Text("Scegli il gioco")
                .font(AppTypography.title1)
                .foregroundStyle(BorderlandTheme.textPrimary)

            Text("Ogni carta del mazzo è un gioco diverso. Scegli la prova, poi crea o entra in una partita.")
                .font(AppTypography.callout)
                .foregroundStyle(BorderlandTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Locked games

    private var lockedSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Text("IL RESTO DEL MAZZO")
                    .font(AppTypography.caption)
                    .tracking(1.6)
                    .foregroundStyle(BorderlandTheme.textMuted)

                Rectangle()
                    .fill(BorderlandTheme.borderSubtle)
                    .frame(height: 1)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible(), spacing: Spacing.md)],
                spacing: Spacing.md
            ) {
                ForEach(lockedGames) { game in
                    LockedGameCard(game: game)
                }
            }
        }
    }
}

// MARK: - Featured card

private struct FeaturedGameCard: View {
    let game: GameDefinition
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                GameCoverArtwork(game: game)

                LinearGradient(
                    colors: [BorderlandTheme.void.opacity(0.55), .clear, BorderlandTheme.surface1],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                HStack {
                    statusPill

                    Spacer(minLength: 0)

                    // Targhetta scura: quella chiara rubava l'occhio alla key art.
                    Text("\(game.cardNumber)\(game.suitSymbol)")
                        .font(AppTypography.cardCorner)
                        .foregroundStyle(BorderlandTheme.goldLight)
                        .frame(width: 34, height: 44)
                        .background(
                            BorderlandTheme.void.opacity(0.72),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(BorderlandTheme.borderGold, lineWidth: 1)
                        )
                }
                .padding(Spacing.md)
            }
            // La key art è 3:2: teniamo l'aspetto così non viene tagliata.
            .aspectRatio(3.0 / 2.0, contentMode: .fit)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(game.name)
                    .font(AppTypography.title1)
                    .foregroundStyle(BorderlandTheme.textPrimary)

                Text(game.hubDescription)
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Spacing.xs) {
                    metaChip(icon: "person.2.fill", text: game.modeLabel)
                    metaChip(icon: "person.3.fill", text: game.playersLabel)
                    metaChip(icon: "clock.fill", text: game.durationLabel)
                }
                .padding(.top, Spacing.xxs)

                Button(action: action) {
                    HStack(spacing: Spacing.sm) {
                        Spacer(minLength: 0)
                        Text("GIOCA")
                            .font(AppTypography.headline)
                            .tracking(1.6)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [BorderlandTheme.crimson, BorderlandTheme.crimsonDeep],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
                    .shadow(color: BorderlandTheme.crimsonGlow, radius: 14, y: 5)
                }
                .buttonStyle(PressableStyle())
                .padding(.top, Spacing.xxs)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BorderlandTheme.surface1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                .stroke(BorderlandTheme.borderGold, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous))
        .shadow(color: BorderlandTheme.shadowLarge.color, radius: BorderlandTheme.shadowLarge.radius, y: BorderlandTheme.shadowLarge.y)
        .shadow(color: BorderlandTheme.shadowGoldGlow.color, radius: 18, y: 0)
        .contentShape(RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous))
        .onTapGesture(perform: action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Apre le opzioni per creare o entrare in una partita")
    }

    private var statusPill: some View {
        HStack(spacing: Spacing.xxs) {
            Circle()
                .fill(BorderlandTheme.emeraldLight)
                .frame(width: 6, height: 6)
            Text("DISPONIBILE")
                .font(AppTypography.caption2)
                .tracking(1.2)
                .foregroundStyle(BorderlandTheme.emeraldLight)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(BorderlandTheme.void.opacity(0.72), in: Capsule())
        .overlay(Capsule().stroke(BorderlandTheme.borderEmerald, lineWidth: 1))
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(AppTypography.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(BorderlandTheme.textMuted)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(BorderlandTheme.surface2.opacity(0.9), in: Capsule())
        .overlay(Capsule().stroke(BorderlandTheme.borderSubtle, lineWidth: 1))
    }
}

// MARK: - Locked card

private struct LockedGameCard: View {
    let game: GameDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                GameCoverArtwork(game: game)
                    .grayscale(0.9)
                    .opacity(0.4)

                BorderlandTheme.void.opacity(0.45)

                Image(systemName: "lock.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(BorderlandTheme.textMuted)
            }
            .frame(height: 130)
            .clipped()

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(game.name)
                    .font(AppTypography.caption)
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("PROSSIMAMENTE")
                    .font(AppTypography.caption2)
                    .tracking(1)
                    .foregroundStyle(BorderlandTheme.textDim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .background(BorderlandTheme.surface1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
                .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(game.name), prossimamente")
    }
}

// MARK: - Artwork

/// Key art del gioco. Se esiste l'asset dedicato (`cover-<id>`) viene usato
/// quello, altrimenti si ripiega sulla carta da gioco corrispondente.
struct GameCoverArtwork: View {
    let game: GameDefinition

    var body: some View {
        // Il fondo detta la dimensione: filigrana e artwork stanno in overlay,
        // così non gonfiano il layout e restano dentro il riquadro.
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [BorderlandTheme.surface3, BorderlandTheme.surface1],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Text(game.suitSymbol)
                    .font(.system(size: 220, weight: .black))
                    .foregroundStyle(game.suitTint.opacity(0.10))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 70, y: 10)
            }
            .overlay {
                if let cover = customCover {
                    cover
                        .resizable()
                        .scaledToFill()
                } else {
                    cardArtwork
                }
            }
            .clipped()
    }

    private var customCover: Image? {
        #if canImport(UIKit)
        guard UIImage(named: game.coverAssetName) != nil else { return nil }
        return Image(game.coverAssetName)
        #else
        return nil
        #endif
    }

    @ViewBuilder
    private var cardArtwork: some View {
        #if canImport(UIKit)
        if let localURL = PlayingCardCatalog.localImageURL(for: game.cardCode),
           let image = UIImage(contentsOfFile: localURL.path) {
            cardFrame { Image(uiImage: image).resizable().scaledToFit() }
        } else {
            remoteCardArtwork
        }
        #else
        remoteCardArtwork
        #endif
    }

    @ViewBuilder
    private var remoteCardArtwork: some View {
        if let remoteURL = URL(string: PlayingCardCatalog.imageURLString(for: game.cardCode)) {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case let .success(image):
                    cardFrame { image.resizable().scaledToFit() }
                case .failure:
                    suitFallback
                case .empty:
                    ProgressView().tint(BorderlandTheme.gold)
                @unknown default:
                    suitFallback
                }
            }
        } else {
            suitFallback
        }
    }

    private func cardFrame<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(Spacing.xs)
            .background(BorderlandTheme.cardFace, in: RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
                    .stroke(BorderlandTheme.borderMedium, lineWidth: 1)
            )
            .padding(.vertical, Spacing.md)
            .rotationEffect(.degrees(-4))
            .shadow(color: .black.opacity(0.55), radius: 16, y: 8)
    }

    private var suitFallback: some View {
        Text(game.suitSymbol)
            .font(.system(size: 64, weight: .black))
            .foregroundStyle(game.suitTint.opacity(0.6))
    }
}
