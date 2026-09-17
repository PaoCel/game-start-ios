import Foundation

struct MatchSnapshot: Codable, Equatable {
  struct IncomingEngagement: Codable, Equatable {
    var attackerId: String
    var attackerName: String
    var expiresAtMs: Int
  }

  struct Participant: Codable, Equatable, Identifiable {
    var id: String
    var nickname: String
    var avatarDataUrl: String?
    var teamId: String?
    var roleInTeam: String?
    var playingCard: String?
    var identityDeckIndex: Int?
    var points: Int?

    var resolvedCardCode: String {
      PlayingCardCatalog.normalizeCode(playingCard ?? "")
    }
  }

  var gameId: String
  var state: String
  var config: GameplayConfigSnapshot
  var scanMode: ScanMode { config.scanMode }
  var matchDurationSec: Int { config.matchDurationSec }
  var remainingSec: Int
  var liveEndsAtMs: Int?
  var serverNowMs: Int?
  var isJoined: Bool
  var joinAllowed: Bool
  var battleStatus: String
  var playingCard: String?
  var identityDeckIndex: Int?
  var inactiveReason: String?
  var cooldownRemainingSec: Int?
  var baseDefenseRemainingSec: Int?
  var baseDefenseCooldownRemainingSec: Int?
  var baseDefensePoints: Int?
  var teamDistributionSubmitted: Bool
  var teamDistributionTotal: Int?
  var teamDistributionRemaining: Int?
  var teamReadyForLive: Bool
  var opponentTeamReadyForLive: Bool
  var allTeamsReadyForLive: Bool
  var isCurrentPlayerLeader: Bool
  var points: Int?
  var roleInTeam: String?
  var participants: [Participant]
  // Current player's team assignment (returned at top level by playerGetActiveGameStatus)
  var teamId: String?
  var braceletToken: String?
  var qrToken: String?
  var qrUrl: String?
  var lastBattleSummary: ScanBattleSummary?
  var incomingEngagement: IncomingEngagement? = nil
  var autonomousSetup: AutonomousGameSetup
  var hasAutonomousSetup: Bool

  static let placeholder = MatchSnapshot(
    gameId: "",
    state: "NOT_STARTED",
    config: .default,
    remainingSec: 0,
    liveEndsAtMs: nil,
    serverNowMs: nil,
    isJoined: false,
    joinAllowed: false,
    battleStatus: "INACTIVE",
    playingCard: nil,
    identityDeckIndex: nil,
    inactiveReason: nil,
    cooldownRemainingSec: nil,
    baseDefenseRemainingSec: nil,
    baseDefenseCooldownRemainingSec: nil,
    baseDefensePoints: nil,
    teamDistributionSubmitted: false,
    teamDistributionTotal: nil,
    teamDistributionRemaining: nil,
    teamReadyForLive: false,
    opponentTeamReadyForLive: false,
    allTeamsReadyForLive: false,
    isCurrentPlayerLeader: false,
    points: nil,
    roleInTeam: nil,
    participants: [],
    teamId: nil,
    braceletToken: nil,
    qrToken: nil,
    qrUrl: nil,
    lastBattleSummary: nil,
    incomingEngagement: nil,
    autonomousSetup: .gameMasterDefault,
    hasAutonomousSetup: false
  )
}
