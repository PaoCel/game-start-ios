import Foundation

enum PlayerGameplayHUDState: Equatable {
    enum Category: Equatable {
        case idle
        case ready
        case scanning
        case resolving
        case success
        case invalid
        case cooldown
        case protected
        case blocked
        case eliminated
    }

    case idle(detail: String)
    case scanReady
    case baseRecovery(detail: String)
    case teamSyncPending(seconds: Int, detail: String)
    case scanning
    case tagDetected(detail: String)
    case success(title: String, detail: String, delta: Int?)
    case invalidTarget(detail: String)
    case cooldown(seconds: Int)
    case protectedTarget(detail: String)
    case actionBlocked(detail: String)
    case eliminated

    var category: Category {
        switch self {
        case .idle:
            return .idle
        case .scanReady:
            return .ready
        case .baseRecovery:
            return .ready
        case .teamSyncPending:
            return .ready
        case .scanning:
            return .scanning
        case .tagDetected:
            return .resolving
        case .success:
            return .success
        case .invalidTarget:
            return .invalid
        case .cooldown:
            return .cooldown
        case .protectedTarget:
            return .protected
        case .actionBlocked:
            return .blocked
        case .eliminated:
            return .eliminated
        }
    }

    var title: String {
        switch self {
        case .idle:
            return "STANDBY"
        case .scanReady:
            return "SCAN READY"
        case .baseRecovery:
            return "RETURN TO BASE"
        case .teamSyncPending:
            return "TEAM BATTLE"
        case .scanning:
            return "SCANNING"
        case .tagDetected:
            return "CALCULATING"
        case .success(let title, _, _):
            return title
        case .invalidTarget:
            return "INVALID TARGET"
        case .cooldown:
            return "COOLDOWN"
        case .protectedTarget:
            return "TARGET SHIELDED"
        case .actionBlocked:
            return "ACTION BLOCKED"
        case .eliminated:
            return "ELIMINATED"
        }
    }

    var subtitle: String {
        switch self {
        case .idle(let detail):
            return detail
        case .scanReady:
            return "Premi una volta e aggancia il tag di un avversario."
        case .baseRecovery(let detail):
            return detail
        case .teamSyncPending(let seconds, let detail):
            let timer = Self.formatClock(seconds)
            return "\(detail) Timer: \(timer)."
        case .scanning:
            return "Tieni l'iPhone vicino al tag. Una sola lettura."
        case .tagDetected(let detail):
            return detail
        case .success(_, let detail, _):
            return detail
        case .invalidTarget(let detail):
            return detail
        case .cooldown(let seconds):
            return "Rientro disponibile tra \(Self.formatDuration(seconds))."
        case .protectedTarget(let detail):
            return detail
        case .actionBlocked(let detail):
            return detail
        case .eliminated:
            return "Hai esaurito i punti. Il match continua senza di te."
        }
    }

    var shortBadge: String {
        switch self {
        case .idle:
            return "WAIT"
        case .scanReady:
            return "LIVE"
        case .baseRecovery:
            return "BASE"
        case .teamSyncPending:
            return "TEAM"
        case .scanning:
            return "NFC"
        case .tagDetected:
            return "SYNC"
        case .success:
            return "OK"
        case .invalidTarget:
            return "INVALID"
        case .cooldown:
            return "HOLD"
        case .protectedTarget:
            return "SHIELD"
        case .actionBlocked:
            return "BLOCK"
        case .eliminated:
            return "OUT"
        }
    }

    var ctaLabel: String {
        switch self {
        case .scanReady:
            return "TOCCA PER SCANSIONARE"
        case .baseRecovery:
            return "TOCCA LA TUA BASE"
        case .teamSyncPending:
            return "INGAGGIA AVVERSARIO"
        case .scanning:
            return "ANNULLA DAL SISTEMA NFC"
        case .tagDetected:
            return "CALCOLO ESITO"
        case .success(_, _, let delta):
            if let delta, delta > 0 {
                return "+\(delta) PUNTI"
            }
            return "AZIONE REGISTRATA"
        case .invalidTarget:
            return "RIPROVA"
        case .cooldown(let seconds):
            return Self.formatDuration(seconds).uppercased()
        case .protectedTarget:
            return "BERSAGLIO NON DISPONIBILE"
        case .actionBlocked:
            return "AZIONE NON DISPONIBILE"
        case .eliminated:
            return "MATCH CHIUSO"
        case .idle:
            return "IN ATTESA"
        }
    }

    var isActionEnabled: Bool {
        switch self {
        case .scanReady:
            return true
        case .baseRecovery:
            return true
        case .teamSyncPending:
            return true
        case .idle:
            return true
        default:
            return false
        }
    }

    private static func formatDuration(_ totalSeconds: Int) -> String {
        let bounded = max(0, totalSeconds)
        let minutes = bounded / 60
        let seconds = bounded % 60
        if minutes > 0 && seconds > 0 {
            return "\(minutes)m \(seconds)s"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(seconds)s"
    }

    private static func formatClock(_ totalSeconds: Int) -> String {
        let bounded = max(0, totalSeconds)
        return String(format: "%02d:%02d", bounded / 60, bounded % 60)
    }
}

extension PlayerViewModel {
    var gameplayHUDState: PlayerGameplayHUDState {
        let transientResultVisible = battleResult != nil || !pointsDeltaLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let battleStatus = snapshot.battleStatus.uppercased()

        if isMatchClosed {
            return .actionBlocked(detail: "Partita terminata. Il gameplay e chiuso.")
        }

        if battleStatus == "ELIMINATED" || matchesEliminatedStatus {
            return .eliminated
        }

        if isReadingNFC {
            return .scanning
        }

        if isResolvingScan {
            let detail = statusMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            return .tagDetected(detail: detail.isEmpty ? "Tag letto. Sto calcolando l'esito dello scontro." : detail)
        }

        if let lastScanStatus {
            switch lastScanStatus {
            case .pending:
                let detail = statusMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                return .tagDetected(detail: detail.isEmpty ? "Tag letto. Sto calcolando l'esito dello scontro." : detail)
            case .teamSyncPending(let seconds):
                let detail = statusMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                let remaining = max(0, teamSyncRemainingSec ?? seconds)
                return .teamSyncPending(
                    seconds: remaining,
                    detail: detail.isEmpty
                        ? "Sync squadra attivo. Ingaggia un avversario prima che scada la finestra."
                        : detail
                )
            case .completed(let delta):
                if transientResultVisible {
                    if delta > 0 {
                        return .success(
                            title: "HIT CONFIRMED",
                            detail: "Scambio chiuso. Guadagno \(signedHUDDelta(delta)).",
                            delta: delta
                        )
                    }
                    if delta < 0 {
                        return .success(
                            title: "TRADE LOST",
                            detail: "Scambio chiuso. Perdita \(signedHUDDelta(delta)).",
                            delta: delta
                        )
                    }
                    return .success(
                        title: "NO TRANSFER",
                        detail: "Scontro valido, nessuna variazione.",
                        delta: delta
                    )
                }
            case .invalidTarget(let reason):
                return .invalidTarget(detail: reason)
            case .cooldown(let seconds):
                let remaining = snapshot.cooldownRemainingSec ?? seconds
                if remaining > 0 {
                    return .cooldown(seconds: remaining)
                }
            case .protectedTarget(let reason):
                return .protectedTarget(detail: reason)
            case .actionBlocked(let reason):
                return .actionBlocked(detail: reason)
            case .baseCaptured(let amount):
                if transientResultVisible {
                    return .success(
                        title: "BASE CAPTURED",
                        detail: "Conquista registrata. Guadagno +\(max(0, amount)) punti.",
                        delta: amount
                    )
                }
            case .baseActivated:
                if transientResultVisible {
                    return .success(
                        title: "BASE ONLINE",
                        detail: "Difesa base attiva. Mantieni il vantaggio.",
                        delta: nil
                    )
                }
            case .eliminated:
                return .eliminated
            }
        }

        if let cooldown = snapshot.cooldownRemainingSec, cooldown > 0 {
            return .cooldown(seconds: cooldown)
        }

        if !snapshot.isJoined {
            return .idle(detail: "Entra nel match e attendi l'avvio live.")
        }

        if snapshot.state.uppercased() != "LIVE" {
            return .idle(detail: "Schermata armata, match non ancora live.")
        }

        if battleStatus == "ACTIVE" {
            return .scanReady
        }

        if canPerformBaseRecoveryAction {
            return .baseRecovery(detail: battleStateDetail)
        }

        return .actionBlocked(detail: battleStateDetail)
    }

    enum PreviewScenario: String, CaseIterable, Identifiable {
        case idle
        case ready
        case scanning
        case success
        case invalid
        case cooldown
        case protected
        case blocked
        case eliminated

        var id: String { rawValue }
    }

    static func preview(scenario: PreviewScenario) -> PlayerViewModel {
        let viewModel = PlayerViewModel(
            gameService: MockGameService(),
            authService: MockAuthService(),
            nfcService: PreviewNFCService(),
            initialGameCode: "KOC-042",
            isPreviewMode: true
        )

        viewModel.profile = previewProfile
        viewModel.snapshot = previewSnapshot
        viewModel.activityLog = previewActivityLog
        viewModel.statusMessage = "Sistema pronto."

        switch scenario {
        case .idle:
            viewModel.snapshot.state = "LOBBY"
            viewModel.snapshot.isJoined = false
            viewModel.statusMessage = "In attesa avvio match."

        case .ready:
            viewModel.statusMessage = "Zona libera. Puoi ingaggiare."

        case .scanning:
            viewModel.isReadingNFC = true
            viewModel.statusMessage = "Ricerca tag in corso."

        case .success:
            viewModel.lastScanStatus = .completed(delta: 320)
            viewModel.pointsDeltaLabel = "+320"
            viewModel.profile.points = 3_820
            viewModel.snapshot.points = 3_820
            viewModel.statusMessage = "Scambio completato. Variazione: +320 punti."

        case .invalid:
            viewModel.lastScanStatus = .invalidTarget(reason: "Tag non valido per questa partita.")
            viewModel.statusMessage = "Scansione rifiutata: tag non valido."

        case .cooldown:
            viewModel.lastScanStatus = .cooldown(seconds: 14)
            viewModel.snapshot.cooldownRemainingSec = 14
            viewModel.statusMessage = "Cooldown attivo."

        case .protected:
            viewModel.lastScanStatus = .protectedTarget(reason: "Bersaglio protetto dalla finestra difensiva.")
            viewModel.snapshot.baseDefenseRemainingSec = 7
            viewModel.statusMessage = "Bersaglio protetto."

        case .blocked:
            viewModel.snapshot.battleStatus = "INACTIVE"
            viewModel.snapshot.inactiveReason = "POST_BATTLE_NEEDS_BASE_TOUCH"
            viewModel.lastScanStatus = .actionBlocked(reason: "Tocca la tua base per tornare attivo.")
            viewModel.statusMessage = "Serve un rientro base."

        case .eliminated:
            viewModel.snapshot.battleStatus = "ELIMINATED"
            viewModel.lastScanStatus = .eliminated
            viewModel.statusMessage = "Sei eliminato."
        }

        return viewModel
    }

    private var matchesEliminatedStatus: Bool {
        if case .some(.eliminated) = lastScanStatus {
            return true
        }
        return false
    }

    private func signedHUDDelta(_ value: Int) -> String {
        value >= 0 ? "+\(value) punti" : "\(value) punti"
    }

    private func formatHUDDuration(_ totalSeconds: Int) -> String {
        let bounded = max(0, totalSeconds)
        let minutes = bounded / 60
        let seconds = bounded % 60
        if minutes > 0 && seconds > 0 {
            return "\(minutes)m \(seconds)s"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(seconds)s"
    }
}

private let previewProfile = PlayerProfile(
    uid: "preview-player",
    nickname: "Paolo",
    avatarDataUrl: nil,
    playingCard: "KC",
    identityCardCode: "KC",
    identityDeckIndex: 2,
    points: 3_500,
    teamId: "TEAM_A",
    roleInTeam: "RUNNER",
    preferredBraceletToken: "A1B2C3D4E5F6",
    profileCompleted: true
)

private let previewSnapshot = MatchSnapshot(
    gameId: "KOC-042",
    state: "LIVE",
    config: GameplayConfigSnapshot(
        scanMode: .bracelet,
        handshakeWindowSec: 6,
        pairCooldownSec: 20,
        playerCooldownSec: 10,
        inactivePenaltyBlockDurationSec: 180,
        teamSyncWindowSec: 4,
        baseContactWindowSec: 5,
        baseDefenseMultiplier: 3,
        baseDefenseDurationSec: 180,
        baseDefenseCooldownSec: 300,
        duelTransferPoints: 250,
        baseCapturePoints: 2_000,
        baseDefensePoints: 500,
        startingPoints: 3_500,
        countdownSec: 10,
        matchDurationSec: 2_700,
        timezone: "Europe/Rome"
    ),
    remainingSec: 1_245,
    liveEndsAtMs: nil,
    serverNowMs: nil,
    isJoined: true,
    joinAllowed: true,
    battleStatus: "ACTIVE",
    playingCard: "KC",
    identityDeckIndex: 2,
    inactiveReason: nil,
    cooldownRemainingSec: nil,
    baseDefenseRemainingSec: nil,
    baseDefenseCooldownRemainingSec: nil,
    baseDefensePoints: nil,
    teamDistributionSubmitted: false,
    teamDistributionTotal: nil,
    teamDistributionRemaining: nil,
    teamReadyForLive: false,
    opponentTeamReadyForLive: false,
    allTeamsReadyForLive: false,
    isCurrentPlayerLeader: false,
    points: 3_500,
    roleInTeam: "RUNNER",
    participants: [],
    teamId: "TEAM_A",
    braceletToken: "A1B2C3D4E5F6",
    qrToken: nil,
    qrUrl: nil,
    lastBattleSummary: nil,
    autonomousSetup: .autonomousDefault,
    hasAutonomousSetup: true
)

private let previewActivityLog: [PlayerViewModel.ActivityEntry] = [
    .init(timestamp: "18:24:09", message: "Difesa base disponibile per 7s.", kind: .warn),
    .init(timestamp: "18:23:54", message: "Tag giocatore collegato.", kind: .ok),
    .init(timestamp: "18:23:12", message: "Ingresso nel game completato.", kind: .ok)
]

private final class PreviewNFCService: NFCService {
    var isSupported: Bool { true }

    func readTag(prompt: String) async throws -> NFCTagRead {
        _ = prompt
        return buildNFCTagRead(payloadToken: "04AABB11CC22", uidToken: "22CC11BBAA04")
    }

    func cancelReading() {}
}
