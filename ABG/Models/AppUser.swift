import Foundation

struct AppUser: Equatable {
  var uid: String
  var email: String?
  var displayName: String?
  var isGuest: Bool = false
}
