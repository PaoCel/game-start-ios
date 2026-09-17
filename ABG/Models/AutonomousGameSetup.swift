import Foundation

enum MatchHostingMode: String, Codable, CaseIterable, Hashable {
    case gameMaster = "GAME_MASTER"
    case autonomous = "AUTONOMOUS"

    var displayLabel: String {
        switch self {
        case .gameMaster:
            return "Con game master"
        case .autonomous:
            return "Autonoma"
        }
    }

    var helperText: String {
        switch self {
        case .gameMaster:
            return "La partita continua a usare il flusso classico con regia dedicata."
        case .autonomous:
            return "Il creator puo entrare come player e la lobby gestisce team, setup e ready direttamente dall'app."
        }
    }
}

enum TeamAssignmentMode: String, Codable, CaseIterable, Hashable {
    case manual = "MANUAL"
    case random = "RANDOM"

    var displayLabel: String {
        switch self {
        case .manual:
            return "Scelta libera"
        case .random:
            return "Casuale"
        }
    }

    var helperText: String {
        switch self {
        case .manual:
            return "Ogni player sceglie la squadra, ma l'app blocca squadre sbilanciate."
        case .random:
            return "L'app assegna le squadre in automatico e il creator puo rimescolarle."
        }
    }
}

struct AutonomousGameSetup: Codable, Equatable, Hashable {
    var hostMode: MatchHostingMode
    var teamAssignmentMode: TeamAssignmentMode
    var creatorUid: String?

    static let gameMasterDefault = AutonomousGameSetup(
        hostMode: .gameMaster,
        teamAssignmentMode: .manual,
        creatorUid: nil
    )

    static let autonomousDefault = AutonomousGameSetup(
        hostMode: .autonomous,
        teamAssignmentMode: .manual,
        creatorUid: nil
    )

    var isAutonomous: Bool {
        hostMode == .autonomous
    }

    var allowsManualTeamSelection: Bool {
        isAutonomous && teamAssignmentMode == .manual
    }

    var allowsRandomTeamAssignment: Bool {
        isAutonomous && teamAssignmentMode == .random
    }
}
