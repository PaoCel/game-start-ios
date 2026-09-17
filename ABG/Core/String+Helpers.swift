import Foundation

extension String {
  /// Returns self if not empty after trimming; otherwise nil.
  var nonEmpty: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
