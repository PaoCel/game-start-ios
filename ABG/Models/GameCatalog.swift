import Foundation

struct GameCatalogEntry: Identifiable, Equatable {
    let id: String
    let name: String
    let shortDescription: String
    let supportedItemModes: [ItemMode]
    let recommendedItemModes: [ItemMode]
    let defaultItemMode: ItemMode
    let isActive: Bool

    var recommendedItemModeText: String? {
        guard !recommendedItemModes.isEmpty else { return nil }
        return recommendedItemModes
            .map(\.displayLabel)
            .joined(separator: ", ")
    }
}
