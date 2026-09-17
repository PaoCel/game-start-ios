import Foundation

struct AdminGameEventExport: Codable, Equatable {
    struct Entry: Codable, Equatable, Identifiable {
        var id: String
        var sequence: Int?
        var type: String
        var scope: String?
        var createdAt: String?
        var actorUid: String?
        var actorNickname: String?
        var severity: String
        var message: String
        var payloadJson: String

        var timestampLabel: String {
            guard let createdAt, !createdAt.isEmpty else { return "--:--:--" }
            if createdAt.count >= 19 {
                let start = createdAt.index(createdAt.startIndex, offsetBy: 11)
                let end = createdAt.index(start, offsetBy: 8, limitedBy: createdAt.endIndex) ?? createdAt.endIndex
                return String(createdAt[start..<end])
            }
            return createdAt
        }
    }

    var gameId: String
    var gameName: String
    var state: String
    var exportedAt: String
    var totalEventCount: Int
    var truncated: Bool
    var entries: [Entry]

    var rawText: String {
        let header = [
            "GAME \(gameId) · \(gameName)",
            "STATE \(state)",
            "EXPORTED \(exportedAt)",
            truncated
                ? "EVENTS \(entries.count)/\(totalEventCount) (ultimi eventi)"
                : "EVENTS \(entries.count)/\(totalEventCount)"
        ].joined(separator: "\n")

        let body = entries.map { entry in
            var lines: [String] = []
            lines.append("[\(entry.timestampLabel)] \(entry.type) · \(entry.message)")
            if let sequence = entry.sequence {
                lines.append("sequence: \(sequence)")
            }
            if let actorNickname = entry.actorNickname, !actorNickname.isEmpty {
                lines.append("actor: \(actorNickname)")
            }
            lines.append(entry.payloadJson)
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")

        return "\(header)\n\n\(body)"
    }
}
