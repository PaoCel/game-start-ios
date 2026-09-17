import Foundation

enum ScanMode: String, Codable {
  case qr = "QR"
  case bracelet = "BRACELET"

  var isQREnabled: Bool {
    self == .qr
  }
}
