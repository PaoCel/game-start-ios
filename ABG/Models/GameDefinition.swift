import Foundation

struct GameDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let suit: String
    let suitSymbol: String
    let difficulty: Int
    let cardNumber: String
    let isAvailable: Bool

    var backendCode: String {
        id.uppercased().replacingOccurrences(of: "-", with: "_")
    }

    var cardCode: String {
        let suitCode: String
        switch suit {
        case "clubs": suitCode = "C"
        case "hearts": suitCode = "H"
        case "diamonds": suitCode = "D"
        case "spades": suitCode = "S"
        default: suitCode = "C"
        }
        return "\(cardNumber.uppercased())\(suitCode)"
    }

    static let allGames: [GameDefinition] = [
        GameDefinition(id: "kings-of-clubs", name: "Re di Fiori", subtitle: "Conquista le basi nemiche", suit: "clubs", suitSymbol: "♣", difficulty: 10, cardNumber: "K", isAvailable: true),
        GameDefinition(id: "queen-of-hearts", name: "Regina di Cuori", subtitle: "Croquet mortale", suit: "hearts", suitSymbol: "♥", difficulty: 10, cardNumber: "Q", isAvailable: false),
        GameDefinition(id: "jack-of-diamonds", name: "Fante di Quadri", subtitle: "Scopri il traditore", suit: "diamonds", suitSymbol: "♦", difficulty: 8, cardNumber: "J", isAvailable: false),
        GameDefinition(id: "ten-of-spades", name: "Dieci di Picche", subtitle: "Sopravvivi nella citta", suit: "spades", suitSymbol: "♠", difficulty: 10, cardNumber: "10", isAvailable: false),
        GameDefinition(id: "seven-of-hearts", name: "Sette di Cuori", subtitle: "Fiducia cieca", suit: "hearts", suitSymbol: "♥", difficulty: 7, cardNumber: "7", isAvailable: false),
        GameDefinition(id: "five-of-spades", name: "Cinque di Picche", subtitle: "Caccia nella foresta", suit: "spades", suitSymbol: "♠", difficulty: 5, cardNumber: "5", isAvailable: false)
    ]

    static func fromBackendCode(_ code: String) -> GameDefinition? {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return allGames.first(where: { $0.backendCode == normalized })
    }

    static func displayName(forBackendCode code: String) -> String {
        if let game = fromBackendCode(code) {
            return game.name
        }
        let cleaned = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
        return cleaned.capitalized
    }

    static func activeGamePlaceholder(forBackendCode code: String) -> GameDefinition {
        let normalizedCode = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()

        return GameDefinition(
            id: normalizedCode.isEmpty ? "active-game" : normalizedCode,
            name: displayName(forBackendCode: code),
            subtitle: "Partita attiva dal backend",
            suit: "clubs",
            suitSymbol: "♣",
            difficulty: 10,
            cardNumber: "A",
            isAvailable: true
        )
    }
}
