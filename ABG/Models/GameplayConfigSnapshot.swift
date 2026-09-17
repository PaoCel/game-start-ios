import Foundation

struct GameplayConfigSnapshot: Codable, Equatable {
    var scanMode: ScanMode
    var handshakeWindowSec: Int
    var pairCooldownSec: Int
    var playerCooldownSec: Int
    var inactivePenaltyBlockDurationSec: Int
    var teamSyncWindowSec: Int
    var baseContactWindowSec: Int
    var baseDefenseMultiplier: Int
    var baseDefenseDurationSec: Int
    var baseDefenseCooldownSec: Int
    var duelTransferPoints: Int
    var baseCapturePoints: Int
    var baseDefensePoints: Int
    var startingPoints: Int
    var countdownSec: Int
    var matchDurationSec: Int
    var timezone: String

    static let `default` = GameplayConfigSnapshot(
        scanMode: .bracelet,
        handshakeWindowSec: 8,
        pairCooldownSec: 20,
        playerCooldownSec: 8,
        inactivePenaltyBlockDurationSec: 600,
        teamSyncWindowSec: 12,
        baseContactWindowSec: 5,
        baseDefenseMultiplier: 3,
        baseDefenseDurationSec: 180,
        baseDefenseCooldownSec: 300,
        duelTransferPoints: 500,
        baseCapturePoints: 10_000,
        baseDefensePoints: 10_000,
        startingPoints: 100,
        countdownSec: 60,
        matchDurationSec: 7_200,
        timezone: "Europe/Rome"
    )
}
