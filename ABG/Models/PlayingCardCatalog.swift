import Foundation

enum PlayingCardCatalog {
  static let allCodes: [String] = {
    let suits = ["S", "H", "D", "C"]
    let ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
    let standard = suits.flatMap { suit in ranks.map { "\($0)\(suit)" } }
    return standard + ["JOKER_RED", "JOKER_BLACK"]
  }()

  static func imageURLString(for code: String) -> String {
    let normalized = normalizeCode(code)

    if let localURL = localImageURL(for: normalized) {
      return localURL.absoluteString
    }

    if normalized == "JOKER_RED" {
      return "https://borderlandgames.it/images/cards/joker_red.png"
    }
    if normalized == "JOKER_BLACK" {
      return "https://borderlandgames.it/images/cards/joker_black.png"
    }

    guard normalized.count >= 2 else {
      return ""
    }

    let suitPart = String(normalized.suffix(1))
    let rankPart = String(normalized.dropLast(1))

    let suit: String
    switch suitPart {
    case "S": suit = "spade"
    case "H": suit = "heart"
    case "D": suit = "diamond"
    case "C": suit = "club"
    default: return ""
    }

    let rank: String
    switch rankPart {
    case "A": rank = "1"
    case "K": rank = "king"
    case "Q": rank = "queen"
    case "J": rank = "jack"
    default:
      rank = rankPart
    }

    return "https://borderlandgames.it/images/cards/\(suit)_\(rank.lowercased()).png"
  }

  static func localImageURL(for code: String) -> URL? {
    let normalized = normalizeCode(code)
    guard let fileName = localFileName(for: normalized) else {
      return nil
    }

    if let direct = Bundle.main.url(
      forResource: fileName,
      withExtension: "png",
      subdirectory: "playing-cards-assets/png"
    ) {
      return direct
    }

    if let flattened = Bundle.main.url(forResource: fileName, withExtension: "png") {
      return flattened
    }

    return nil
  }

  static func normalizeCode(_ value: String) -> String {
    let raw = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    if raw == "JOKER_RED" || raw == "JOKER_BLACK" {
      return raw
    }

    // Legacy iOS format compatibility: SPADE_A -> AS
    let legacy = raw.split(separator: "_")
    if legacy.count == 2 {
      let suitMap: [String: String] = [
        "SPADE": "S",
        "HEART": "H",
        "DIAMOND": "D",
        "CLUB": "C"
      ]
      if let suit = suitMap[String(legacy[0])] {
        return "\(legacy[1])\(suit)"
      }
    }

    return raw
  }

  private static func localFileName(for normalizedCode: String) -> String? {
    if normalizedCode == "JOKER_RED" {
      return "red_joker"
    }
    if normalizedCode == "JOKER_BLACK" {
      return "black_joker"
    }

    guard normalizedCode.count >= 2 else {
      return nil
    }

    let suitPart = String(normalizedCode.suffix(1))
    let rankPart = String(normalizedCode.dropLast(1))

    let rankLabel: String
    switch rankPart {
    case "A": rankLabel = "ace"
    case "K": rankLabel = "king"
    case "Q": rankLabel = "queen"
    case "J": rankLabel = "jack"
    default: rankLabel = rankPart
    }

    let suitLabel: String
    switch suitPart {
    case "S": suitLabel = "spades"
    case "H": suitLabel = "hearts"
    case "D": suitLabel = "diamonds"
    case "C": suitLabel = "clubs"
    default: return nil
    }

    return "\(rankLabel)_of_\(suitLabel)"
  }
}
