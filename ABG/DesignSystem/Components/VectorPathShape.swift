import SwiftUI

/// Shape costruita da una stringa di path SVG (attributo `d`).
///
/// Serve per disegnare marchi vettoriali ufficiali (es. la G di Google) senza
/// importare asset raster: il path viene riscalato dentro il rect mantenendo
/// le proporzioni della viewBox originale.
///
/// Supporta i comandi M/L/H/V/C/S/Q/T/Z (assoluti e relativi). Gli archi
/// ellittici (A/a) non sono supportati: i marchi usati nell'app non li usano.
struct VectorPathShape: Shape {
    let pathData: String
    let viewBox: CGSize

    init(_ pathData: String, viewBox: CGSize = CGSize(width: 48, height: 48)) {
        self.pathData = pathData
        self.viewBox = viewBox
    }

    func path(in rect: CGRect) -> Path {
        guard viewBox.width > 0, viewBox.height > 0 else { return Path() }

        let parsed = SVGPathParser.path(from: pathData)
        let scale = min(rect.width / viewBox.width, rect.height / viewBox.height)
        let offsetX = rect.minX + (rect.width - viewBox.width * scale) / 2
        let offsetY = rect.minY + (rect.height - viewBox.height * scale) / 2

        let transform = CGAffineTransform(translationX: offsetX, y: offsetY)
            .scaledBy(x: scale, y: scale)
        return parsed.applying(transform)
    }
}

enum SVGPathParser {
    static func path(from data: String) -> Path {
        var path = Path()
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastCubicControl: CGPoint?
        var lastQuadControl: CGPoint?

        for token in tokenize(data) {
            let isRelative = token.command.isLowercase
            let command = Character(token.command.uppercased())
            let values = token.values
            var index = 0

            func nextPoint() -> CGPoint {
                let x = values[index]
                let y = values[index + 1]
                index += 2
                return isRelative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
            }

            switch command {
            case "M":
                guard values.count >= 2 else { break }
                let point = nextPoint()
                path.move(to: point)
                current = point
                subpathStart = point
                // Coppie extra dopo una M valgono come lineTo implicite.
                while index + 1 < values.count {
                    let next = nextPoint()
                    path.addLine(to: next)
                    current = next
                }
                lastCubicControl = nil
                lastQuadControl = nil

            case "L":
                while index + 1 < values.count {
                    let point = nextPoint()
                    path.addLine(to: point)
                    current = point
                }
                lastCubicControl = nil
                lastQuadControl = nil

            case "H":
                while index < values.count {
                    let x = isRelative ? current.x + values[index] : values[index]
                    index += 1
                    let point = CGPoint(x: x, y: current.y)
                    path.addLine(to: point)
                    current = point
                }
                lastCubicControl = nil
                lastQuadControl = nil

            case "V":
                while index < values.count {
                    let y = isRelative ? current.y + values[index] : values[index]
                    index += 1
                    let point = CGPoint(x: current.x, y: y)
                    path.addLine(to: point)
                    current = point
                }
                lastCubicControl = nil
                lastQuadControl = nil

            case "C":
                while index + 5 < values.count {
                    let control1 = nextPoint()
                    let control2 = nextPoint()
                    let end = nextPoint()
                    path.addCurve(to: end, control1: control1, control2: control2)
                    current = end
                    lastCubicControl = control2
                    lastQuadControl = nil
                }

            case "S":
                while index + 3 < values.count {
                    let control1 = reflected(lastCubicControl, around: current)
                    let control2 = nextPoint()
                    let end = nextPoint()
                    path.addCurve(to: end, control1: control1, control2: control2)
                    current = end
                    lastCubicControl = control2
                    lastQuadControl = nil
                }

            case "Q":
                while index + 3 < values.count {
                    let control = nextPoint()
                    let end = nextPoint()
                    path.addQuadCurve(to: end, control: control)
                    current = end
                    lastQuadControl = control
                    lastCubicControl = nil
                }

            case "T":
                while index + 1 < values.count {
                    let control = reflected(lastQuadControl, around: current)
                    let end = nextPoint()
                    path.addQuadCurve(to: end, control: control)
                    current = end
                    lastQuadControl = control
                    lastCubicControl = nil
                }

            case "Z":
                path.closeSubpath()
                current = subpathStart
                lastCubicControl = nil
                lastQuadControl = nil

            default:
                break
            }
        }

        return path
    }

    private static func reflected(_ control: CGPoint?, around point: CGPoint) -> CGPoint {
        guard let control else { return point }
        return CGPoint(x: 2 * point.x - control.x, y: 2 * point.y - control.y)
    }

    private struct Token {
        let command: Character
        let values: [CGFloat]
    }

    private static func tokenize(_ data: String) -> [Token] {
        var tokens: [Token] = []
        var command: Character?
        var values: [CGFloat] = []
        var buffer = ""

        func flushNumber() {
            guard !buffer.isEmpty, let value = Double(buffer) else {
                buffer = ""
                return
            }
            values.append(CGFloat(value))
            buffer = ""
        }

        func flushCommand() {
            flushNumber()
            if let command {
                tokens.append(Token(command: command, values: values))
            }
            values = []
        }

        for character in data {
            if character == "e" || character == "E", !buffer.isEmpty {
                buffer.append(character)          // esponente, non un comando
            } else if character.isLetter {
                flushCommand()
                command = character
            } else if character == "-" || character == "+" {
                if buffer.isEmpty || buffer.lowercased().hasSuffix("e") {
                    buffer.append(character)
                } else {
                    flushNumber()
                    buffer.append(character)
                }
            } else if character == "." {
                if buffer.contains(".") {
                    flushNumber()
                }
                buffer.append(character)
            } else if character.isNumber {
                buffer.append(character)
            } else {
                flushNumber()                     // spazio, virgola o altro separatore
            }
        }

        flushCommand()
        return tokens
    }
}
