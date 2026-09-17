import Foundation

extension Data {
  var hexStringUppercased: String {
    map { String(format: "%02X", $0) }.joined()
  }
}
