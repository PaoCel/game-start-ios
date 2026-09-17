import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit
#endif

struct QRCodeSheet: View {
    let title: String
    let subtitle: String?
    let token: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                BorderlandTheme.surface1.ignoresSafeArea()

                VStack(spacing: Spacing.xl) {
                    VStack(spacing: Spacing.sm) {
                        Text(title)
                            .font(AppTypography.title3)
                            .foregroundStyle(BorderlandTheme.textPrimary)
                            .multilineTextAlignment(.center)
                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(AppTypography.caption)
                                .foregroundStyle(BorderlandTheme.textMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Spacing.lg)
                        }
                    }
                    .padding(.top, Spacing.xl)

                    QRCodeSymbolView(token: token)
                        .frame(maxWidth: 280)

                    Text(maskedToken)
                        .font(AppTypography.caption)
                        .foregroundStyle(BorderlandTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, Spacing.lg)

                    Spacer()

                    VStack(spacing: Spacing.sm) {
                        BorderlandButton("Chiudi", variant: .secondary) {
                            dismiss()
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, Spacing.xl)
                }
            }
            .navigationBarHidden(true)
        }
    }

    // Il token QR è credenziale personale: mai in chiaro sotto il codice.
    private var maskedToken: String {
        guard token.count > 12 else { return "••••" }
        return "\(token.prefix(4))••••\(token.suffix(4))"
    }
}

private struct QRCodeSymbolView: View {
    let token: String

    var body: some View {
        Group {
            if let image = qrImage {
                image
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(Spacing.lg)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                            .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                    .fill(BorderlandTheme.surface2)
                    .overlay(
                        Image(systemName: "qrcode")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(BorderlandTheme.textDim)
                    )
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var qrImage: Image? {
        guard let uiImage = QRCodeRenderer.shared.makeImage(from: token) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
}

private final class QRCodeRenderer {
    static let shared = QRCodeRenderer()

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    func makeImage(from token: String) -> UIImage? {
        guard !token.isEmpty else { return nil }
        filter.message = Data(token.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }

        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
