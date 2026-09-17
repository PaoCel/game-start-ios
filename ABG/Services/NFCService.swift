import Foundation

struct NFCTagRead: Equatable {
  let primaryToken: String
  let candidates: [String]
  let payloadToken: String?
  let uidToken: String?
}

private let hexSerialCharacters = CharacterSet(charactersIn: "0123456789ABCDEFabcdef:- ")
private let hexOnlyCharacters = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")

private func extractURLToken(_ raw: String) -> String {
  let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty else { return "" }

  if let direct = URL(string: trimmed), let token = direct.path.split(separator: "/").last {
    return String(token).removingPercentEncoding ?? String(token)
  }

  if let base = URL(string: "https://codex.local"),
     let relative = URL(string: trimmed, relativeTo: base),
     let token = relative.path.split(separator: "/").last {
    return String(token).removingPercentEncoding ?? String(token)
  }

  return ""
}

private func normalizeHexSerialToken(_ raw: String) -> String {
  let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty else { return "" }
  guard trimmed.unicodeScalars.allSatisfy({ hexSerialCharacters.contains($0) }) else {
    return ""
  }

  let compact = trimmed
    .replacingOccurrences(of: ":", with: "")
    .replacingOccurrences(of: "-", with: "")
    .replacingOccurrences(of: " ", with: "")

  guard !compact.isEmpty,
        compact.count.isMultiple(of: 2),
        compact.unicodeScalars.allSatisfy({ hexOnlyCharacters.contains($0) }) else {
    return ""
  }

  return compact.uppercased()
}

private func reverseHexByteOrder(_ hex: String) -> String {
  guard hex.count.isMultiple(of: 2), !hex.isEmpty else { return "" }
  var bytes: [String] = []
  var index = hex.startIndex
  while index < hex.endIndex {
    let next = hex.index(index, offsetBy: 2)
    bytes.append(String(hex[index..<next]))
    index = next
  }
  return bytes.reversed().joined()
}

func normalizeTagToken(_ raw: String?) -> String {
  let candidates = normalizeTagTokenCandidates([raw ?? ""])
  return candidates.first ?? ""
}

func normalizeTagTokenCandidates(_ values: [String]) -> [String] {
  var result: [String] = []
  var seen = Set<String>()

  for value in values {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { continue }

    let urlToken = extractURLToken(trimmed)
    if !urlToken.isEmpty, seen.insert(urlToken).inserted {
      result.append(urlToken)
    }

    let hexToken = normalizeHexSerialToken(trimmed)
    if !hexToken.isEmpty {
      if seen.insert(hexToken).inserted {
        result.append(hexToken)
      }
      let reversed = reverseHexByteOrder(hexToken)
      if !reversed.isEmpty, reversed != hexToken, seen.insert(reversed).inserted {
        result.append(reversed)
      }
    }

    if urlToken.isEmpty && hexToken.isEmpty, seen.insert(trimmed).inserted {
      result.append(trimmed)
    }
  }

  return result
}

func buildNFCTagRead(payloadToken: String?, uidToken: String?) -> NFCTagRead {
  let normalizedPayload = normalizeTagToken(payloadToken)
  let normalizedUID = normalizeTagToken(uidToken)
  let candidates = normalizeTagTokenCandidates(
    [normalizedPayload, normalizedUID].filter { !$0.isEmpty }
  )
  return NFCTagRead(
    primaryToken: candidates.first ?? "",
    candidates: candidates,
    payloadToken: normalizedPayload.isEmpty ? nil : normalizedPayload,
    uidToken: normalizedUID.isEmpty ? nil : normalizedUID
  )
}

protocol NFCService {
  var isSupported: Bool { get }
  func readTag(prompt: String) async throws -> NFCTagRead
  func cancelReading()
}

extension NFCService {
  func readToken(prompt: String) async throws -> String {
    try await readTag(prompt: prompt).primaryToken
  }
}

enum NFCServiceFactory {
  static func make() -> NFCService {
    #if canImport(CoreNFC)
    return CoreNFCService()
    #else
    return UnsupportedNFCService()
    #endif
  }
}

final class UnsupportedNFCService: NFCService {
  var isSupported: Bool { false }

  func readTag(prompt: String) async throws -> NFCTagRead {
    _ = prompt
    throw NSError(domain: "nfc", code: 1, userInfo: [NSLocalizedDescriptionKey: "NFC non disponibile su questo device/build"]) 
  }

  func cancelReading() {
    // no-op
  }
}
