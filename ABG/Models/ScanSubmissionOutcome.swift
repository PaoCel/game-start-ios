import Foundation

struct ScanBattleSummary: Codable, Equatable {
  struct Participant: Codable, Equatable, Identifiable {
    var id: String
    var nickname: String
    var teamId: String?
    var teamName: String?
    var isPrimary: Bool
  }

  struct Side: Codable, Equatable, Identifiable {
    var id: String { key }
    var key: String
    var teamId: String?
    var teamName: String?
    var label: String
    var participants: [Participant]
    var totalBefore: Int
    var totalAfter: Int
    var isGroup: Bool

    var participantLine: String? {
      let values = participants
        .map(\.nickname)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
      guard !values.isEmpty else { return nil }
      return values.joined(separator: " • ")
    }

    var primaryName: String {
      participants.first(where: \.isPrimary)?.nickname
        ?? participants.first?.nickname
        ?? label
    }
  }

  var summaryId: String
  var status: String
  var winnerSide: String
  var resolutionMode: String
  var viewerSide: String?
  var amount: Int
  var penaltyApplied: Bool
  var scannerWasInactive: Bool
  var opponentWasInactive: Bool
  var scannerSide: Side
  var opponentSide: Side

  var normalizedViewerSide: String {
    let value = viewerSide?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
    return value == "OPPONENT" ? "OPPONENT" : "SCANNER"
  }

  var viewerSideData: Side {
    normalizedViewerSide == "OPPONENT" ? opponentSide : scannerSide
  }

  var opposingSideData: Side {
    normalizedViewerSide == "OPPONENT" ? scannerSide : opponentSide
  }

  var isTie: Bool {
    status.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "COMPLETED_TIE" ||
    winnerSide.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "TIE"
  }

  var viewerDidWin: Bool {
    !isTie && winnerSide.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == normalizedViewerSide
  }

  var viewerDidLose: Bool {
    !isTie && !viewerDidWin
  }

  var viewerDelta: Int {
    viewerSideData.totalAfter - viewerSideData.totalBefore
  }

  var opposingDelta: Int {
    opposingSideData.totalAfter - opposingSideData.totalBefore
  }

  var contextLabel: String {
    "\(viewerSideData.label) vs \(opposingSideData.label)"
  }
}

struct ScanSubmissionOutcome: Codable, Equatable {
  var status: String
  var ownPoints: Int?
  var opponentUid: String?
  var amount: Int?
  var transferId: String?
  var itemId: String?
  var effectType: String?
  var reason: String?
  var cooldownRemainingSec: Int?
  var cooldownScope: String?
  var availableInSec: Int?
  var battleStatus: String?
  var inactiveReason: String?
  var baseDefenseRemainingSec: Int?
  var baseDefenseCooldownRemainingSec: Int?
  var baseDefensePoints: Int?
  var battleSummary: ScanBattleSummary?
}
