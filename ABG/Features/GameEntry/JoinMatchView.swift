import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Schermata di ingresso in partita: QR in primo piano, codice a 8 caratteri
/// come alternativa manuale. Sostituisce il vecchio form di sistema.
struct JoinMatchView: View {
    let onSubmit: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var code = ""
    @State private var isSubmitting = false
    @State private var submissionError = ""
    @State private var showScanner = false
    @State private var hasAppeared = false
    @FocusState private var isCodeFocused: Bool

    private var canSubmit: Bool {
        code.count == JoinCodeParser.codeLength && !isSubmitting
    }

    var body: some View {
        ZStack {
            SuitBackdrop(density: .full)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    topBar

                    header

                    scanCard
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared || reduceMotion ? 0 : 16)
                        .animation(entrance.delay(0.1), value: hasAppeared)

                    separator

                    codeSection
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared || reduceMotion ? 0 : 16)
                        .animation(entrance.delay(0.2), value: hasAppeared)

                    if !submissionError.isEmpty {
                        errorBanner
                    }

                    submitButton

                    Text("Il codice te lo passa il game master: lo trova nella schermata della partita, insieme al QR.")
                        .font(AppTypography.caption2)
                        .foregroundStyle(BorderlandTheme.textDim)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.xl)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .borderlandBackground()
        .onAppear { hasAppeared = true }
        .sheet(isPresented: $showScanner) {
            QRCodeScannerSheet(
                title: "Inquadra il QR della partita",
                subtitle: "Mostra il QR sullo schermo del game master. Puoi anche continuare con il codice manuale."
            ) { scannedValue in
                handleScan(scannedValue)
            }
        }
    }

    private var entrance: Animation {
        reduceMotion ? .easeOut(duration: 0.25) : AnimationTokens.slideUp
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .frame(width: 44, height: 44)
                    .background(BorderlandTheme.surface2.opacity(0.9), in: Circle())
                    .overlay(Circle().stroke(BorderlandTheme.borderSubtle, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Chiudi")

            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        VStack(spacing: Spacing.xs) {
            Text("ENTRA IN PARTITA")
                .font(AppTypography.title1)
                .tracking(1.2)
                .foregroundStyle(BorderlandTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text("Due modi per entrare: inquadra il QR o digita il codice invito.")
                .font(AppTypography.callout)
                .foregroundStyle(BorderlandTheme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.sm)
    }

    // MARK: - QR

    private var scanCard: some View {
        Button {
            HapticManager.lightTap()
            isCodeFocused = false
            showScanner = true
        } label: {
            HStack(spacing: Spacing.lg) {
                viewfinder

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("SCANSIONA IL QR")
                        .font(AppTypography.headline)
                        .tracking(1.2)
                        .foregroundStyle(BorderlandTheme.textPrimary)

                    Text("Il modo più veloce: zero codici da copiare.")
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BorderlandTheme.gold.opacity(0.8))
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [BorderlandTheme.surface2, BorderlandTheme.surface1],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                    .stroke(BorderlandTheme.borderGold, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous))
            .shadow(color: BorderlandTheme.shadowGoldGlow.color, radius: 16, y: 0)
        }
        .buttonStyle(PressableStyle())
        .disabled(isSubmitting)
    }

    /// Mirino stilizzato: quattro angoli dorati attorno all'icona QR.
    private var viewfinder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
                .fill(BorderlandTheme.void.opacity(0.6))

            Image(systemName: "qrcode")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(BorderlandTheme.gold)

            ViewfinderCorners()
                .stroke(BorderlandTheme.gold, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .padding(5)
        }
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
    }

    private var separator: some View {
        HStack(spacing: Spacing.sm) {
            Rectangle()
                .fill(BorderlandTheme.borderSubtle)
                .frame(height: 1)
            Text("oppure")
                .font(AppTypography.caption2)
                .foregroundStyle(BorderlandTheme.textDim)
            Rectangle()
                .fill(BorderlandTheme.borderSubtle)
                .frame(height: 1)
        }
    }

    // MARK: - Codice

    private var codeSection: some View {
        VStack(spacing: Spacing.md) {
            Text("CODICE INVITO")
                .font(AppTypography.caption)
                .tracking(1.6)
                .foregroundStyle(BorderlandTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            JoinCodeField(code: $code, isFocused: $isCodeFocused, isEnabled: !isSubmitting)

            HStack(spacing: Spacing.sm) {
                PasteButton(payloadType: String.self) { strings in
                    guard let pasted = strings.first else { return }
                    Task { @MainActor in
                        applyPasted(pasted)
                    }
                }
                .labelStyle(.titleAndIcon)
                .buttonBorderShape(.capsule)
                .tint(BorderlandTheme.surface3)
                .disabled(isSubmitting)

                Spacer(minLength: 0)

                if !code.isEmpty {
                    Button {
                        HapticManager.lightTap()
                        code = ""
                        submissionError = ""
                        isCodeFocused = true
                    } label: {
                        Text("Cancella")
                            .font(AppTypography.caption)
                            .foregroundStyle(BorderlandTheme.textMuted)
                            .frame(height: 44)
                            .padding(.horizontal, Spacing.sm)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .padding(Spacing.lg)
        .background(BorderlandTheme.surface1.opacity(0.85))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous))
    }

    private var errorBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(BorderlandTheme.statusDangerText)
            Text(submissionError)
                .font(AppTypography.caption)
                .foregroundStyle(BorderlandTheme.statusDangerText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .background(BorderlandTheme.statusDanger.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
                .stroke(BorderlandTheme.statusDangerText.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
        .transition(.opacity)
    }

    private var submitButton: some View {
        Button {
            HapticManager.lightTap()
            isCodeFocused = false
            Task { await submit(code) }
        } label: {
            ZStack {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: Spacing.sm) {
                        Text("ENTRA")
                            .font(AppTypography.headline)
                            .tracking(1.6)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                LinearGradient(
                    colors: [BorderlandTheme.crimson, BorderlandTheme.crimsonDeep],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
            .shadow(color: canSubmit ? BorderlandTheme.crimsonGlow : .clear, radius: 14, y: 5)
            .opacity(canSubmit ? 1 : 0.45)
        }
        .buttonStyle(PressableStyle())
        .disabled(!canSubmit)
    }

    // MARK: - Azioni

    private func applyPasted(_ value: String) {
        submissionError = ""
        if let extracted = JoinCodeParser.extract(from: value) {
            code = extracted
            HapticManager.lightTap()
            isCodeFocused = false
            Task { await submit(extracted) }
        } else {
            // Nessun codice riconosciuto: proviamo comunque col valore grezzo,
            // il backend accetta anche i link di invito completi.
            Task { await submit(value) }
        }
    }

    private func handleScan(_ scannedValue: String) {
        let trimmed = scannedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let extracted = JoinCodeParser.extract(from: trimmed) {
            code = extracted
        }
        Task { await submit(trimmed) }
    }

    private func submit(_ rawValue: String) async {
        let normalizedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedValue.isEmpty, !isSubmitting else { return }

        isSubmitting = true
        submissionError = ""
        defer { isSubmitting = false }

        do {
            try await onSubmit(normalizedValue)
            HapticManager.success()
            dismiss()
        } catch {
            withAnimation(AnimationTokens.quick) {
                submissionError = error.localizedDescription
            }
            HapticManager.error()
        }
    }
}

// MARK: - Campo codice

/// Otto caselle stile OTP con un TextField invisibile che raccoglie l'input.
struct JoinCodeField: View {
    @Binding var code: String
    var isFocused: FocusState<Bool>.Binding
    let isEnabled: Bool

    @State private var caretVisible = true

    var body: some View {
        ZStack {
            // La normalizzazione sta nel setter del binding: riscrivere `code`
            // dentro un onChange fa perdere i tasti battuti nel frattempo.
            TextField("", text: Binding(
                get: { code },
                set: { code = JoinCodeParser.normalize($0) }
            ))
            .keyboardType(.asciiCapable)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .textContentType(.oneTimeCode)
            .focused(isFocused)
            .tint(.clear)
            .frame(width: 1, height: 1)
            .opacity(0.01)

            boxes
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEnabled else { return }
            isFocused.wrappedValue = true
        }
        .accessibilityElement()
        .accessibilityLabel("Codice invito")
        .accessibilityValue(code.isEmpty ? "vuoto" : code.map(String.init).joined(separator: " "))
        .accessibilityAddTraits(.isButton)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                caretVisible = false
            }
        }
    }

    private var boxes: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<JoinCodeParser.codeLength, id: \.self) { index in
                box(at: index)

                if index == JoinCodeParser.codeLength / 2 - 1 {
                    Rectangle()
                        .fill(BorderlandTheme.borderMedium)
                        .frame(width: 10, height: 2)
                }
            }
        }
    }

    private func box(at index: Int) -> some View {
        let characters = Array(code)
        let character = index < characters.count ? String(characters[index]) : ""
        let isActive = isFocused.wrappedValue && index == min(characters.count, JoinCodeParser.codeLength - 1)
        let isFilled = !character.isEmpty

        return ZStack {
            RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
                .fill(isFilled ? BorderlandTheme.surface3 : BorderlandTheme.surface2.opacity(0.7))

            RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
                .stroke(
                    isActive ? BorderlandTheme.gold : (isFilled ? BorderlandTheme.borderGold : BorderlandTheme.borderSubtle),
                    lineWidth: isActive ? 2 : 1
                )

            if isFilled {
                Text(character)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(BorderlandTheme.goldLight)
            } else if isActive {
                Capsule()
                    .fill(BorderlandTheme.gold)
                    .frame(width: 2, height: 22)
                    .opacity(caretVisible ? 1 : 0.15)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .shadow(color: isActive ? BorderlandTheme.goldGlow : .clear, radius: 10, y: 0)
        .animation(AnimationTokens.quick, value: isFilled)
        .animation(AnimationTokens.quick, value: isActive)
    }
}

/// Quattro angoli di un mirino, disegnati come singolo path.
struct ViewfinderCorners: Shape {
    var length: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let arm = min(length, min(rect.width, rect.height) / 3)

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - arm))

        return path
    }
}

// MARK: - Parsing codici

enum JoinCodeParser {
    /// I codici generati dal backend sono 8 caratteri esadecimali maiuscoli.
    static let codeLength = 8

    static func normalize(_ rawValue: String) -> String {
        String(
            rawValue
                .uppercased()
                .filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
                .prefix(codeLength)
        )
    }

    /// Estrae il codice da testo incollato o da un QR: accetta il codice nudo,
    /// un link di invito con query string oppure un link con il codice nel path.
    static func extract(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            let queryKeys = ["code", "joinCode", "gameCode", "matchCode", "operatorCode", "inviteCode"]
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            for key in queryKeys {
                if let value = components?.queryItems?.first(where: { $0.name.caseInsensitiveCompare(key) == .orderedSame })?.value,
                   let candidate = candidate(from: value) {
                    return candidate
                }
            }
            for segment in url.pathComponents.reversed() {
                if let candidate = candidate(from: segment) {
                    return candidate
                }
            }
            return nil
        }

        return candidate(from: trimmed)
    }

    private static func candidate(from rawValue: String) -> String? {
        let normalized = rawValue
            .uppercased()
            .filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        guard normalized.count == codeLength else { return nil }
        return normalized
    }
}
