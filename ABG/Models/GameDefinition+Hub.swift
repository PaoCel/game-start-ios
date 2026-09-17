import SwiftUI

/// Metadati di presentazione usati dalla schermata di scelta gioco.
/// Sono derivati dal seme della carta: nel mazzo di Borderland ogni seme
/// identifica il tipo di prova.
extension GameDefinition {
    /// Nome asset della key art del gioco (formato 3:4).
    /// Se non esiste nel catalogo asset si usa il fallback con la carta.
    var coverAssetName: String { "cover-\(id)" }

    /// Nome asset dell'emblema quadrato del gioco (PNG trasparente).
    var emblemAssetName: String { "emblem-\(id)" }

    /// Tipo di prova legato al seme, come nel mazzo originale.
    var modeLabel: String {
        switch suit {
        case "clubs": return "Squadre"
        case "hearts": return "Tradimento"
        case "diamonds": return "Ingegno"
        case "spades": return "Fisico"
        default: return "Prova"
        }
    }

    var suitTint: Color {
        switch suit {
        case "hearts", "diamonds": return BorderlandTheme.crimson
        case "spades": return BorderlandTheme.violet
        default: return BorderlandTheme.emeraldLight
        }
    }

    var playersLabel: String {
        switch id {
        case "kings-of-clubs": return "8-40 giocatori"
        default: return "Da definire"
        }
    }

    var durationLabel: String {
        switch id {
        case "kings-of-clubs": return "20-45 min"
        default: return "Da definire"
        }
    }

    /// Riga di dettaglio mostrata sotto il titolo nel gioco disponibile.
    var hubDescription: String {
        switch id {
        case "kings-of-clubs":
            return "Due squadre, basi da difendere e braccialetti NFC da scansionare. Chi controlla il campo alla fine del tempo vince la mano."
        default:
            return subtitle
        }
    }
}
