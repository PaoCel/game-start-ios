import Foundation

enum AutonomousGamePreferencesStore {
    private static let storageKey = "autonomous.game.preferences"

    static func save(_ setup: AutonomousGameSetup, for gameId: String) {
        let normalizedGameId = normalizeGameId(gameId)
        guard !normalizedGameId.isEmpty else { return }

        var stored = loadAll()
        stored[normalizedGameId] = setup
        persist(stored)
    }

    static func load(for gameId: String) -> AutonomousGameSetup? {
        let normalizedGameId = normalizeGameId(gameId)
        guard !normalizedGameId.isEmpty else { return nil }
        return loadAll()[normalizedGameId]
    }

    static func remove(for gameId: String) {
        let normalizedGameId = normalizeGameId(gameId)
        guard !normalizedGameId.isEmpty else { return }

        var stored = loadAll()
        stored.removeValue(forKey: normalizedGameId)
        persist(stored)
    }

    private static func loadAll() -> [String: AutonomousGameSetup] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([String: AutonomousGameSetup].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    private static func persist(_ values: [String: AutonomousGameSetup]) {
        guard let encoded = try? JSONEncoder().encode(values) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }

    private static func normalizeGameId(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
