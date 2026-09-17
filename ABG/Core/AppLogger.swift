import Foundation

enum AppLogger {
  static func info(_ message: String) {
    print("[INFO] \(message)")
  }

  static func error(_ message: String) {
    print("[ERROR] \(message)")
  }
}
