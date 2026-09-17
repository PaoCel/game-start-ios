import Foundation

struct AdminGameStatus: Codable, Equatable {
    struct Participant: Codable, Equatable, Identifiable {
        var id: String
        var nickname: String
        var teamId: String?
        var roleInTeam: String?
        var playingCard: String?
        var avatarDataUrl: String?

        var isLeader: Bool {
            (roleInTeam ?? "").uppercased() == "LEADER"
        }
    }

    struct TeamBase: Codable, Equatable {
        var teamId: String
        var token: String?
        var qrToken: String?
        var qrUrl: String?
    }

    struct GameItem: Codable, Equatable, Identifiable {
        var id: String
        var icon: String        // SF Symbol name, unique per game
        var points: Int
        var collectorTeamId: String?
        var nfcToken: String?
        var qrToken: String?
        var qrUrl: String?
        var registeredAt: Date

        init(
            id: String,
            icon: String,
            points: Int,
            collectorTeamId: String? = nil,
            nfcToken: String? = nil,
            qrToken: String? = nil,
            qrUrl: String? = nil,
            registeredAt: Date = Date()
        ) {
            self.id = id
            self.icon = icon
            self.points = points
            self.collectorTeamId = collectorTeamId
            self.nfcToken = nfcToken
            self.qrToken = qrToken
            self.qrUrl = qrUrl
            self.registeredAt = registeredAt
        }
    }

    struct TagLookup: Codable, Equatable {
        var tagId: String
        var entityType: String
        var bindingId: String?
        var ownerId: String?
        var teamId: String?
        var itemId: String?
        var playerUid: String?
        var playerNickname: String?
        var itemIcon: String?
        var itemPoints: Int?
    }

    var name: String
    var gameId: String
    var gameDefinitionId: String
    var gameDefinitionName: String
    var state: String
    var config: GameplayConfigSnapshot
    /// True when the backend payload actually included config fields.
    var hasConfigSnapshot: Bool
    /// True when the backend payload actually included base token fields.
    var hasBaseSnapshot: Bool
    var participants: [Participant]
    var teamABaseToken: String?
    var teamBBaseToken: String?
    var teamABaseQrToken: String?
    var teamBBaseQrToken: String?
    var itemMode: ItemMode
    var gameItems: [GameItem]
    var autonomousSetup: AutonomousGameSetup
    var hasAutonomousSetup: Bool

    var scanMode: ScanMode { config.scanMode }
    var matchDurationSec: Int { config.matchDurationSec }

    static let empty = AdminGameStatus(
        name: "",
        gameId: "",
        gameDefinitionId: "borderland-classic",
        gameDefinitionName: "Borderland Classic",
        state: "N/A",
        config: .default,
        hasConfigSnapshot: false,
        hasBaseSnapshot: false,
        participants: [],
        teamABaseToken: nil,
        teamBBaseToken: nil,
        teamABaseQrToken: nil,
        teamBBaseQrToken: nil,
        itemMode: .none,
        gameItems: [],
        autonomousSetup: .gameMasterDefault,
        hasAutonomousSetup: false
    )
}
