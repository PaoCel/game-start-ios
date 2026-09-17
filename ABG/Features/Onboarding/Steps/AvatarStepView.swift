import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(UIKit)
import UIKit
#endif

struct AvatarStepView: View {
    @ObservedObject var viewModel: ProfileCompletionViewModel

    #if canImport(PhotosUI)
    @State private var photoItem: PhotosPickerItem?
    #endif
    @State private var showCamera = false

    private let presets: [String] = [
        "person.fill", "person.fill.badge.plus", "person.2.fill", "flame.fill",
        "bolt.fill", "star.fill", "crown.fill", "moon.stars.fill"
    ]

    var body: some View {
        VStack(spacing: Spacing.xl) {
            VStack(spacing: Spacing.xs) {
                Text("Scegli un avatar visibile davvero in partita")
                    .font(AppTypography.title2)
                    .foregroundStyle(BorderlandTheme.textPrimary)

                Text("Serve per completare il profilo e per farti riconoscere piu in fretta in lobby e nel roster.")
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .multilineTextAlignment(.center)
            }

            avatarPreview

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: 4), spacing: Spacing.md) {
                ForEach(presets, id: \.self) { symbol in
                    avatarPreset(symbol: symbol)
                }
            }

            HStack(spacing: Spacing.sm) {
                galleryButton

                #if canImport(UIKit)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    BorderlandButton("Fotocamera", variant: .secondary) {
                        showCamera = true
                    }
                }
                #endif
            }

            Text(viewModel.hasChosenAvatar ? "Avatar pronto per il profilo." : "Seleziona un preset, una foto dalla galleria o scatta al momento.")
                .font(AppTypography.caption)
                .foregroundStyle(viewModel.hasChosenAvatar ? BorderlandTheme.statusOkText : BorderlandTheme.textMuted)
        }
        #if canImport(PhotosUI)
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadPhoto(item: newItem) }
        }
        #endif
        .sheet(isPresented: $showCamera) {
            CameraImagePicker { image in
                if let encoded = makeDataURL(from: image) {
                    viewModel.setPickedAvatarDataURL(encoded)
                }
            }
        }
    }

    private var avatarPreview: some View {
        AvatarView(
            avatarDataUrl: viewModel.avatarDataUrl,
            initials: viewModel.previewInitials,
            size: .large
        )
        .padding(Spacing.md)
        .background(
            Circle()
                .fill(BorderlandTheme.surface3)
        )
        .overlay(
            Circle()
                .stroke(BorderlandTheme.borderGold.opacity(0.55), lineWidth: 1.5)
        )
    }

    private func avatarPreset(symbol: String) -> some View {
        let isSelected = viewModel.selectedPresetSymbol == symbol
        return Button {
            HapticManager.lightTap()
            viewModel.selectPresetAvatar(symbol: symbol)
        } label: {
            ZStack {
                Circle()
                    .fill(BorderlandTheme.surface3)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? BorderlandTheme.borderGold : BorderlandTheme.borderSubtle, lineWidth: isSelected ? 2 : 1)
                    )
                    .glowEffect(color: isSelected ? BorderlandTheme.goldGlow : .clear, radius: 12)

                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? BorderlandTheme.gold : BorderlandTheme.textMuted)
            }
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(PressableStyle())
    }

    @ViewBuilder
    private var galleryButton: some View {
        #if canImport(PhotosUI)
        PhotosPicker(selection: $photoItem, matching: .images) {
            Text("Galleria")
                .font(AppTypography.headline)
                .foregroundStyle(BorderlandTheme.gold)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(BorderlandTheme.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
                        .stroke(BorderlandTheme.borderGold, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
        }
        .buttonStyle(.plain)
        #else
        BorderlandButton("Galleria", variant: .secondary, isEnabled: false) {}
        #endif
    }

    #if canImport(PhotosUI)
    private func loadPhoto(item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data),
              let encoded = makeDataURL(from: uiImage) else { return }
        viewModel.setPickedAvatarDataURL(encoded)
    }

    private func makeDataURL(from image: UIImage) -> String? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 220, height: 220))
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: CGSize(width: 220, height: 220)))
        }
        guard let jpegData = resized.jpegData(compressionQuality: 0.58) else { return nil }
        return "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
    }
    #endif
}

#if canImport(UIKit)
private struct CameraImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraImagePicker

        init(parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
#endif
