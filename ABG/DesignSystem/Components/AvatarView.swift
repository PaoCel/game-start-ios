import SwiftUI

enum AvatarSize {
    case small
    case medium
    case large

    var dimension: CGFloat {
        switch self {
        case .small: return 32
        case .medium: return 44
        case .large: return 64
        }
    }
}

struct AvatarView: View {
    let avatarDataUrl: String?
    let initials: String
    let size: AvatarSize

    init(avatarDataUrl: String?, initials: String = "?", size: AvatarSize = .medium) {
        self.avatarDataUrl = avatarDataUrl
        self.initials = initials
        self.size = size
    }

    var body: some View {
        ZStack {
            if let presetSymbol = presetSymbol(from: avatarDataUrl) {
                Circle()
                    .fill(BorderlandTheme.surface3)
                Image(systemName: presetSymbol)
                    .font(.system(size: size.dimension * 0.42, weight: .semibold))
                    .foregroundStyle(BorderlandTheme.gold)
            } else if let uiImage = decodeBase64Image(from: avatarDataUrl) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let url = URL(string: avatarDataUrl ?? ""), url.scheme != nil {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().scaledToFill()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .clipShape(Circle())
        .overlay(Circle().stroke(BorderlandTheme.borderGold, lineWidth: 1.2))
    }

    private var fallback: some View {
        ZStack {
            Circle()
                .fill(BorderlandTheme.surface3)
            Text(initials)
                .font(AppTypography.caption)
                .foregroundStyle(BorderlandTheme.textPrimary)
        }
    }

    private func decodeBase64Image(from rawValue: String?) -> UIImage? {
        guard let rawValue, !rawValue.isEmpty else { return nil }
        let payload = rawValue.components(separatedBy: ",").last ?? rawValue
        guard let data = Data(base64Encoded: payload) else { return nil }
        return UIImage(data: data)
    }

    private func presetSymbol(from value: String?) -> String? {
        guard let value, value.hasPrefix("preset://") else { return nil }
        let rawIndex = value.replacingOccurrences(of: "preset://", with: "")
        guard let index = Int(rawIndex), presetSymbols.indices.contains(index) else {
            return nil
        }
        return presetSymbols[index]
    }

    private var presetSymbols: [String] {
        [
            "person.fill", "person.fill.badge.plus", "person.2.fill", "flame.fill",
            "bolt.fill", "star.fill", "crown.fill", "moon.stars.fill"
        ]
    }
}
