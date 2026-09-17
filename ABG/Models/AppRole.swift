import Foundation

enum AppRole: String, Codable, CaseIterable {
  case admin = "ADMIN"
  case player = "PLAYER"
  case announcer = "ANNOUNCER"
  case unknown = "UNKNOWN"
}
