import SwiftUI

struct AppTypography {
    static let display = Font.system(size: 34, weight: .black, design: .serif)
    static let title1 = Font.system(size: 28, weight: .bold, design: .serif)
    static let title2 = Font.system(size: 22, weight: .bold, design: .serif)
    static let title3 = Font.system(size: 18, weight: .semibold, design: .serif)
    static let headline = Font.system(size: 16, weight: .bold, design: .default)
    static let body = Font.system(size: 15, weight: .regular, design: .default)
    static let callout = Font.system(size: 14, weight: .medium, design: .default)
    static let caption = Font.system(size: 12, weight: .medium, design: .default)
    static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
    static let mono = Font.system(size: 14, weight: .bold, design: .monospaced)
    static let timer = Font.system(size: 48, weight: .heavy, design: .monospaced)
    static let score = Font.system(size: 56, weight: .black, design: .serif)
    static let cardRank = Font.system(size: 52, weight: .black, design: .serif)
    static let cardCorner = Font.system(size: 14, weight: .bold, design: .serif)
}
