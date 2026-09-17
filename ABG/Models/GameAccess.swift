import Foundation

enum MatchScopedRole: String, Codable, CaseIterable {
    case owner
    case `operator`
    case player
    case none

    var displayLabel: String {
        switch self {
        case .owner:
            return "Organizzatore"
        case .operator:
            return "Operatore"
        case .player:
            return "Player"
        case .none:
            return "Nessun ruolo"
        }
    }

    var isManager: Bool {
        self == .owner || self == .operator
    }
}

enum ItemMode: String, Codable, CaseIterable {
    case none
    case shared
    case crossTeam = "cross_team"

    var displayLabel: String {
        switch self {
        case .none:
            return "Nessun oggetto"
        case .shared:
            return "Oggetti condivisi"
        case .crossTeam:
            return "Oggetti cross-team"
        }
    }

    var helperText: String {
        switch self {
        case .none:
            return "La partita non usa oggetti fisici."
        case .shared:
            return "Gli oggetti sono registrati a livello partita e possono essere raccolti da tutti."
        case .crossTeam:
            return "Ogni squadra nasconde oggetti raccoglibili solo dagli avversari."
        }
    }
}

struct GameAccessSummary: Identifiable, Equatable {
    let id: String
    let name: String
    let gameDefinitionId: String
    let gameDefinitionName: String
    let state: String
    let role: MatchScopedRole
    let playerCount: Int
    let itemMode: ItemMode
    let joinedAsPlayer: Bool
    let canManageSensitive: Bool
    let canManageOperations: Bool
    let isCurrentUserLockedGm: Bool
    let gmPlayerLockEnabled: Bool
    let joinCode: String?
    let operatorInviteCode: String?
    let updatedAt: Date?
    let autonomousSetup: AutonomousGameSetup
    let hasAutonomousSetup: Bool

    var stateLabel: String {
        switch state.uppercased() {
        case "LIVE":
            return "In corso"
        case "PAUSED":
            return "In pausa"
        case "LOBBY":
            return "Lobby"
        case "DISTRIBUTION":
            return "Distribuzione"
        case "ENDED":
            return "Terminata"
        case "ARCHIVED":
            return "Archiviata"
        default:
            return state.capitalized
        }
    }

    var roleLabel: String {
        if isCurrentUserLockedGm {
            return "GM-player lock"
        }
        return role.displayLabel
    }

    var isArchived: Bool {
        state.uppercased() == "ARCHIVED"
    }

    var isEnded: Bool {
        state.uppercased() == "ENDED"
    }

    var isArchivedOrEnded: Bool {
        isArchived || isEnded
    }

    var recommendedItemModeNote: String? {
        guard isCurrentUserLockedGm else { return nil }
        if itemMode == .shared {
            return "Con GM-player lock attivo è più sicuro usare nessun oggetto oppure cross-team."
        }
        return nil
    }

    var isAutonomous: Bool {
        autonomousSetup.isAutonomous
    }

    var allowsManualTeamSelection: Bool {
        autonomousSetup.allowsManualTeamSelection
    }

    var allowsRandomTeamAssignment: Bool {
        autonomousSetup.allowsRandomTeamAssignment
    }

    func applyingAutonomousSetup(_ setup: AutonomousGameSetup, markAsRemote: Bool = false) -> GameAccessSummary {
        GameAccessSummary(
            id: id,
            name: name,
            gameDefinitionId: gameDefinitionId,
            gameDefinitionName: gameDefinitionName,
            state: state,
            role: role,
            playerCount: playerCount,
            itemMode: itemMode,
            joinedAsPlayer: joinedAsPlayer,
            canManageSensitive: canManageSensitive,
            canManageOperations: canManageOperations,
            isCurrentUserLockedGm: isCurrentUserLockedGm,
            gmPlayerLockEnabled: gmPlayerLockEnabled,
            joinCode: joinCode,
            operatorInviteCode: operatorInviteCode,
            updatedAt: updatedAt,
            autonomousSetup: setup,
            hasAutonomousSetup: markAsRemote || hasAutonomousSetup
        )
    }
}
