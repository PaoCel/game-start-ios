import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif
import UIKit

struct ProfileEditorSheet: View {
    let gameService: GameService
    let canDeleteAccount: Bool
    let onSaved: () -> Void
    let onDeleteAccount: (() async throws -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var nickname = ""
    @State private var avatarDataUrl = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var isDeletingAccount = false
    @State private var errorMessage = ""
    @State private var showCamera = false
    @State private var showDeleteConfirmation = false
    private let maxNicknameLength = 24

    #if canImport(PhotosUI)
    @State private var selectedPhotoItem: PhotosPickerItem?
    #endif

    init(
        gameService: GameService,
        canDeleteAccount: Bool = false,
        onSaved: @escaping () -> Void,
        onDeleteAccount: (() async throws -> Void)? = nil
    ) {
        self.gameService = gameService
        self.canDeleteAccount = canDeleteAccount
        self.onSaved = onSaved
        self.onDeleteAccount = onDeleteAccount
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sheetHeader

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    if isLoading {
                        ProgressView()
                            .tint(BorderlandTheme.gold)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, Spacing.xxl)
                    } else {
                        BorderlandPanel(title: "Profilo") {
                            VStack(spacing: Spacing.sm) {
                                TextField("Nickname", text: $nickname)
                                    .profileField()

                                Text("\(nickname.count)/\(maxNicknameLength)")
                                    .font(AppTypography.caption2)
                                    .foregroundStyle(BorderlandTheme.textDim)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }

                        BorderlandPanel(title: "Avatar") {
                            VStack(spacing: Spacing.md) {
                                AvatarView(
                                    avatarDataUrl: avatarDataUrl.isEmpty ? nil : avatarDataUrl,
                                    initials: initials(from: nickname),
                                    size: .large
                                )
                                .frame(maxWidth: .infinity)

                                HStack(spacing: Spacing.sm) {
                                    galleryButton

                                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                        BorderlandButton("Fotocamera", variant: .secondary) {
                                            showCamera = true
                                        }
                                    }

                                    BorderlandButton("Rimuovi", variant: .ghost) {
                                        avatarDataUrl = ""
                                    }
                                }

                                Text("Scegli una foto da galleria o fotocamera")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(BorderlandTheme.textDim)
                            }
                        }

                        if !errorMessage.isEmpty {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(BorderlandTheme.statusDangerText)
                                Text(errorMessage)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(BorderlandTheme.statusDangerText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(Spacing.sm)
                            .background(BorderlandTheme.statusDanger.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
                        }

                        BorderlandButton(
                            "Salva profilo",
                            variant: .primary,
                            isEnabled: !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            isLoading: isSaving
                        ) {
                            Task { await saveProfile() }
                        }

                        if canDeleteAccount, onDeleteAccount != nil {
                            BorderlandPanel(title: "Account") {
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    Text("Questa azione elimina account e dati personali associati all'app.")
                                        .font(AppTypography.callout)
                                        .foregroundStyle(BorderlandTheme.textMuted)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text("Se possiedi partite create come organizer, dovrai prima archiviarle o rimuoverle.")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(BorderlandTheme.textDim)
                                        .fixedSize(horizontal: false, vertical: true)

                                    BorderlandButton(
                                        "Elimina account",
                                        variant: .danger,
                                        isEnabled: !isDeletingAccount,
                                        isLoading: isDeletingAccount
                                    ) {
                                        showDeleteConfirmation = true
                                    }
                                }
                            }
                        }
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
                    .disabled(isDeletingAccount)
                }
            }
            .interactiveDismissDisabled(isDeletingAccount)
            .task {
                await loadProfile()
            }
            .onChange(of: nickname) { _, newValue in
                let cleaned = sanitizeNicknameInput(newValue)
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
            .alert("Eliminare l'account?", isPresented: $showDeleteConfirmation) {
                Button("Annulla", role: .cancel) {}
                Button("Elimina account", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text("L'account verra eliminato in modo definitivo. Verrai disconnesso dall'app.")
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

    private func loadProfile() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let profile = try await gameService.fetchOwnProfile()
            let rawNickname = profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            let rawAvatar = profile.avatarDataUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if rawAvatar.isEmpty, looksLikeAvatarPayload(rawNickname) {
                avatarDataUrl = sanitizeAvatar(rawNickname) ?? ""
                nickname = ""
            } else {
                avatarDataUrl = sanitizeAvatar(rawAvatar) ?? ""
                nickname = sanitizeNicknameInput(rawNickname)
            }
            errorMessage = ""
        } catch {
            errorMessage = "Impossibile caricare il profilo: \(error.localizedDescription)"
        }
    }

    private func saveProfile() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let cleanedNickname = sanitizeNicknameInput(nickname)
            guard !cleanedNickname.isEmpty else {
                errorMessage = "Inserisci un nickname valido"
                return
            }

            var profile = try await gameService.fetchOwnProfile()
            profile.nickname = cleanedNickname
            profile.avatarDataUrl = sanitizeAvatar(avatarDataUrl)
            try await gameService.savePlayerProfile(profile)
            nickname = cleanedNickname
            errorMessage = ""
            onSaved()
            dismiss()
        } catch {
            errorMessage = "Errore salvataggio: \(error.localizedDescription)"
        }
    }

    private func deleteAccount() async {
        guard !isDeletingAccount, let onDeleteAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await onDeleteAccount()
            errorMessage = ""
            dismiss()
        } catch {
            errorMessage = "Errore eliminazione account: \(error.localizedDescription)"
        }
    }

    #if canImport(PhotosUI)
    private func loadPhoto(item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let encoded = makeAvatarDataURL(from: image) else {
                errorMessage = "Impossibile leggere l'immagine selezionata"
                return
            }
            avatarDataUrl = encoded
            errorMessage = ""
        } catch {
            errorMessage = "Errore selezione immagine: \(error.localizedDescription)"
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

    private func sanitizeNicknameInput(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !looksLikeAvatarPayload(trimmed) else { return "" }

        let collapsed = trimmed
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return String(collapsed.prefix(maxNicknameLength))
    }

    private func sanitizeAvatar(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard looksLikeAvatarPayload(trimmed) else { return nil }
        return trimmed
    }

    private func looksLikeAvatarPayload(_ value: String) -> Bool {
        let lower = value.lowercased()
        if lower.hasPrefix("data:image/") || lower.hasPrefix("preset://") {
            return true
        }
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return true
        }
        return value.count > 180
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
    func profileField() -> some View {
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
