import Foundation

struct PlayerProfile: Codable, Equatable {
  var uid: String
  var nickname: String
  var avatarDataUrl: String?
  var playingCard: String
  var identityCardCode: String?
  var identityDeckIndex: Int?
  var points: Int
  var teamId: String?
  var roleInTeam: String?
  var preferredBraceletToken: String?
  var profileCompleted: Bool

  var resolvedCardCode: String {
    let normalizedIdentity = PlayingCardCatalog.normalizeCode(identityCardCode ?? "")
    if !normalizedIdentity.isEmpty {
      return normalizedIdentity
    }
    return PlayingCardCatalog.normalizeCode(playingCard)
  }

  static let empty = PlayerProfile(
    uid: "",
    nickname: "",
    avatarDataUrl: nil,
    playingCard: "AS",
    identityCardCode: nil,
    identityDeckIndex: nil,
    points: 0,
    teamId: nil,
    roleInTeam: nil,
    preferredBraceletToken: nil,
    profileCompleted: false
  )
}
