import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif
import UIKit

struct PlayerSettingsSheet: View {
    @ObservedObject var viewModel: PlayerViewModel
    let logoutAction: () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var nickname = ""
    @State private var avatarDataUrl = ""
    @State private var showCamera = false
    private let maxNicknameLength = 24

    #if canImport(PhotosUI)
    @State private var selectedPhotoItem: PhotosPickerItem?
    #endif

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sheetHeader

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        BorderlandPanel(title: "Profilo") {
                            VStack(spacing: Spacing.md) {
                                AvatarView(
                                    avatarDataUrl: avatarDataUrl.isEmpty ? nil : avatarDataUrl,
                                    initials: initials(from: nickname),
                                    size: .large
                                )
                                .frame(maxWidth: .infinity)

                                TextField("Nickname", text: $nickname)
                                    .styledField()

                                Text("\(nickname.count)/\(maxNicknameLength)")
                                    .font(AppTypography.caption2)
                                    .foregroundStyle(BorderlandTheme.textDim)
                                    .frame(maxWidth: .infinity, alignment: .trailing)

                                HStack(spacing: Spacing.sm) {
                                    galleryButton

                                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                        BorderlandButton("Fotocamera", variant: .secondary) {
                                            showCamera = true
                                        }
                                    }

                                    BorderlandButton(
                                        "Rimuovi",
                                        variant: .ghost,
                                        isEnabled: !avatarDataUrl.isEmpty
                                    ) {
                                        avatarDataUrl = ""
                                    }
                                }

                                Text("Scegli una foto dalla galleria o scattala al momento.")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(BorderlandTheme.textDim)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        BorderlandPanel(title: "Braccialetto NFC") {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                HStack(spacing: Spacing.xs) {
                                    Text("Token collegato:")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(BorderlandTheme.textMuted)
                                    Text(viewModel.maskedBraceletToken)
                                        .font(AppTypography.callout)
                                        .foregroundStyle(BorderlandTheme.gold)
                                }

                                TextField("Token manuale (hex)", text: $viewModel.manualToken)
                                    .styledField()
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()

                                BorderlandButton(
                                    "Collega token manuale",
                                    variant: .secondary,
                                    isEnabled: viewModel.canSubmitManualBraceletToken,
                                    isLoading: viewModel.isRegisteringBracelet
                                ) {
                                    viewModel.registerBraceletFromManualInput()
                                }

                                BorderlandButton(
                                    "Leggi NFC e collega",
                                    variant: .primary,
                                    isEnabled: viewModel.canUseNFC && !viewModel.isRegisteringBracelet && viewModel.canRegisterPlayerTag
                                ) {
                                    viewModel.registerBraceletFromNFC()
                                }

                                if !viewModel.canUseNFC {
                                    Text("NFC non disponibile su questo dispositivo.")
                                        .font(AppTypography.caption2)
                                        .foregroundStyle(BorderlandTheme.textDim)
                                } else if !viewModel.canRegisterPlayerTag {
                                    Text("Tag giocatore già attivato: non è più modificabile.")
                                        .font(AppTypography.caption2)
                                        .foregroundStyle(BorderlandTheme.textDim)
                                }
                            }
                        }

                        if !viewModel.statusMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            BorderlandPanel(title: "Stato") {
                                Text(viewModel.statusMessage)
                                    .font(AppTypography.callout)
                                    .foregroundStyle(BorderlandTheme.textMuted)
                            }
                        }

                        BorderlandButton(
                            "Salva profilo",
                            variant: .primary,
                            isEnabled: !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            isLoading: viewModel.isSavingProfile
                        ) {
                            saveProfile()
                        }

                        BorderlandButton("Logout", variant: .danger) {
                            Task { await logoutAction() }
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.vertical, Spacing.lg)
                }
            }
            .borderlandBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BorderlandButton("Chiudi", variant: .ghost) {
                        dismiss()
                    }
                    .frame(width: 90)
                }
            }
            .onAppear {
                if nickname.isEmpty && avatarDataUrl.isEmpty {
                    hydrateLocalState()
                }
            }
            .onChange(of: nickname) { _, newValue in
                let cleaned = sanitizeNickname(newValue)
                if cleaned != newValue {
                    nickname = cleaned
                }
            }
            #if canImport(PhotosUI)
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task { await loadPhoto(item: newItem) }
            }
            #endif
            .sheet(isPresented: $showCamera) {
                CameraImagePicker { image in
                    if let encoded = makeAvatarDataURL(from: image) {
                        avatarDataUrl = encoded
                    }
                }
            }
        }
    }

    private var sheetHeader: some View {
        VStack(spacing: Spacing.xxs) {
            Capsule()
                .fill(BorderlandTheme.borderSubtle)
                .frame(width: 38, height: 4)
                .padding(.top, Spacing.sm)

            Text("Impostazioni")
                .font(AppTypography.title3)
                .foregroundStyle(BorderlandTheme.gold)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Spacing.xs)
    }

    @ViewBuilder
    private var galleryButton: some View {
        #if canImport(PhotosUI)
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
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

    private func hydrateLocalState() {
        nickname = sanitizeNickname(viewModel.profile.nickname)
        avatarDataUrl = sanitizeAvatar(viewModel.profile.avatarDataUrl) ?? ""
    }

    private func saveProfile() {
        let cleanedNickname = sanitizeNickname(nickname)
        guard !cleanedNickname.isEmpty else { return }

        viewModel.profile.nickname = cleanedNickname
        viewModel.profile.avatarDataUrl = sanitizeAvatar(avatarDataUrl)
        viewModel.saveProfile { success in
            if success {
                dismiss()
            }
        }
    }

    #if canImport(PhotosUI)
    private func loadPhoto(item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let encoded = makeAvatarDataURL(from: image) else {
                return
            }
            await MainActor.run {
                avatarDataUrl = encoded
            }
        } catch {
            return
        }
    }
    #endif

    private func makeAvatarDataURL(from image: UIImage) -> String? {
        let targetSize = CGSize(width: 280, height: 280)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let jpegData = resized.jpegData(compressionQuality: 0.62) else {
            return nil
        }
        return "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
    }

    private func initials(from value: String) -> String {
        let chunks = value.split(separator: " ").prefix(2)
        let result = chunks.compactMap { $0.first }.map(String.init).joined().uppercased()
        return result.isEmpty ? "?" : result
    }

    private func sanitizeNickname(_ value: String) -> String {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        guard !trimmed.isEmpty, !looksLikeAvatarPayload(trimmed) else { return "" }
        return String(trimmed.prefix(maxNicknameLength))
    }

    private func sanitizeAvatar(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, looksLikeAvatarPayload(trimmed) else { return nil }
        return trimmed
    }

    private func looksLikeAvatarPayload(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.hasPrefix("data:image/")
            || lower.hasPrefix("preset://")
            || lower.hasPrefix("http://")
            || lower.hasPrefix("https://")
    }
}

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

private extension TextField {
    func styledField() -> some View {
        self
            .font(AppTypography.callout)
            .foregroundStyle(BorderlandTheme.textPrimary)
            .padding(.horizontal, Spacing.sm)
            .frame(height: 44)
            .background(BorderlandTheme.surface3)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
                    .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
    }
}
