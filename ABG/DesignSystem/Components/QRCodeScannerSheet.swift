import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

struct QRCodeScannerSheet: View {
    let title: String
    let subtitle: String
    let onScan: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var permissionState: CameraPermissionState = .checking
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                BorderlandTheme.surface1.ignoresSafeArea()

                VStack(spacing: Spacing.lg) {
                    VStack(spacing: Spacing.xs) {
                        Text(title)
                            .font(AppTypography.title3)
                            .foregroundStyle(BorderlandTheme.textPrimary)
                        Text(subtitle)
                            .font(AppTypography.caption)
                            .foregroundStyle(BorderlandTheme.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Spacing.xl)
                    .padding(.horizontal, Spacing.lg)

                    scannerContent
                        .padding(.horizontal, Spacing.lg)

                    VStack(spacing: Spacing.sm) {
                        if let errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(AppTypography.caption)
                                .foregroundStyle(BorderlandTheme.statusDangerText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Spacing.lg)
                        }

                        BorderlandButton("Chiudi", variant: .ghost) {
                            dismiss()
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, Spacing.xl)
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await resolvePermission()
        }
    }

    @ViewBuilder
    private var scannerContent: some View {
        switch permissionState {
        case .checking:
            RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                .fill(BorderlandTheme.surface2)
                .frame(height: 320)
                .overlay {
                    ProgressView()
                        .tint(BorderlandTheme.gold)
                }

        case .authorized:
            QRCodeScannerCameraView(
                onScan: { value in
                    onScan(value)
                    dismiss()
                },
                onFailure: { message in
                    errorMessage = message
                }
            )
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                    .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
            )

        case .denied:
            RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                .fill(BorderlandTheme.surface2)
                .frame(height: 320)
                .overlay {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(BorderlandTheme.textDim)
                        Text("Fotocamera non autorizzata")
                            .font(AppTypography.callout)
                            .foregroundStyle(BorderlandTheme.textPrimary)
                        Text("Abilita l'accesso alla fotocamera nelle impostazioni di iOS per usare la scansione QR.")
                            .font(AppTypography.caption)
                            .foregroundStyle(BorderlandTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.lg)
                    }
                }
        }
    }

    private func resolvePermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionState = .authorized
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
            permissionState = granted ? .authorized : .denied
        default:
            permissionState = .denied
        }
    }
}

private enum CameraPermissionState {
    case checking
    case authorized
    case denied
}

private struct QRCodeScannerCameraView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onFailure: (String) -> Void

    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        let controller = QRCodeScannerViewController()
        controller.onScan = onScan
        controller.onFailure = onFailure
        return controller
    }

    func updateUIViewController(_ uiViewController: QRCodeScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: QRCodeScannerViewController, coordinator: ()) {
        uiViewController.stopSession()
    }
}

final class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    var onFailure: ((String) -> Void)?

    private let captureSession = AVCaptureSession()
    private let metadataQueue = DispatchQueue(label: "ABG.qr.metadata", qos: .userInitiated)
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var metadataOutput: AVCaptureMetadataOutput?
    private var hasDeliveredCode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updateRectOfInterest()
    }

    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }

    private func configureSession() {
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            onFailure?("Fotocamera non disponibile.")
            return
        }

        captureSession.beginConfiguration()
        if captureSession.canSetSessionPreset(.vga640x480) {
            captureSession.sessionPreset = .vga640x480
        }

        do {
            let input = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                captureSession.commitConfiguration()
                onFailure?("Impossibile inizializzare la fotocamera.")
                return
            }
        } catch {
            captureSession.commitConfiguration()
            onFailure?("Impossibile inizializzare la fotocamera.")
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: metadataQueue)
            metadataOutput.metadataObjectTypes = [.qr]
            self.metadataOutput = metadataOutput
        } else {
            captureSession.commitConfiguration()
            onFailure?("Impossibile leggere i QR code.")
            return
        }
        captureSession.commitConfiguration()

        configureVideoDevice(videoDevice)

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer

        let overlay = ScannerOverlayView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(overlay)
    }

    private func configureVideoDevice(_ videoDevice: AVCaptureDevice) {
        do {
            try videoDevice.lockForConfiguration()
            if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
                videoDevice.focusMode = .continuousAutoFocus
            }
            if videoDevice.isExposureModeSupported(.continuousAutoExposure) {
                videoDevice.exposureMode = .continuousAutoExposure
            }
            if videoDevice.isSmoothAutoFocusSupported {
                videoDevice.isSmoothAutoFocusEnabled = false
            }
            videoDevice.unlockForConfiguration()
        } catch {
            AppLogger.error("qr camera configuration failed: \(error.localizedDescription)")
        }
    }

    private func updateRectOfInterest() {
        guard let previewLayer, let metadataOutput else { return }
        let scanWindow = ScannerOverlayView.scanWindow(in: view.bounds)
        metadataOutput.rectOfInterest = previewLayer.metadataOutputRectConverted(fromLayerRect: scanWindow)
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasDeliveredCode else { return }
        guard
            let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            metadataObject.type == .qr,
            let stringValue = metadataObject.stringValue,
            !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }

        hasDeliveredCode = true
        DispatchQueue.main.async { [weak self] in
            self?.stopSession()
            self?.onScan?(stringValue)
        }
    }
}

private final class ScannerOverlayView: UIView {
    static func scanWindow(in rect: CGRect) -> CGRect {
        CGRect(
            x: rect.midX - 110,
            y: rect.midY - 110,
            width: 220,
            height: 220
        )
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let context = UIGraphicsGetCurrentContext()
        let frameRect = Self.scanWindow(in: rect)

        UIColor.black.withAlphaComponent(0.28).setFill()
        context?.fill(rect)
        context?.clear(frameRect)

        let path = UIBezierPath(roundedRect: frameRect, cornerRadius: 26)
        UIColor.white.withAlphaComponent(0.85).setStroke()
        path.lineWidth = 2
        path.stroke()
    }
}
