import SwiftUI

struct NicknameStepView: View {
    @ObservedObject var viewModel: ProfileCompletionViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(BorderlandTheme.gold)

            VStack(spacing: Spacing.xs) {
                Text("Scegli il nome con cui ti riconosceranno")
                    .font(AppTypography.title2)
                    .foregroundStyle(BorderlandTheme.textPrimary)

                Text("Comparira negli overlay di battaglia, nei roster e nelle notifiche. Usa un nome chiaro e riconoscibile al volo.")
                    .font(AppTypography.callout)
                    .foregroundStyle(BorderlandTheme.textMuted)
                    .multilineTextAlignment(.center)
            }

            TextField("Es. Paolo / Raptor", text: $viewModel.nickname)
                .font(AppTypography.headline)
                .foregroundStyle(BorderlandTheme.textPrimary)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, Spacing.md)
                .frame(height: 52)
                .background(BorderlandTheme.surface3)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
                        .stroke(isFocused ? BorderlandTheme.borderGold : BorderlandTheme.borderSubtle, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
                .focused($isFocused)

            HStack {
                Text("Minimo 2 caratteri, massimo 20")
                    .font(AppTypography.caption2)
                    .foregroundStyle(BorderlandTheme.textMuted)
                Spacer()
                Text("\(viewModel.normalizedNickname.count)/20")
                    .font(AppTypography.caption2)
                    .foregroundStyle(BorderlandTheme.textDim)
            }

            BorderlandPanel(title: "Anteprima rapida") {
                HStack(spacing: Spacing.md) {
                    AvatarView(
                        avatarDataUrl: viewModel.avatarDataUrl,
                        initials: viewModel.previewInitials,
                        size: .medium
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.previewNickname)
                            .font(AppTypography.headline)
                            .foregroundStyle(BorderlandTheme.textPrimary)

                        Text("Questo e il nome che gli altri leggeranno mentre ti affrontano.")
                            .font(AppTypography.caption)
                            .foregroundStyle(BorderlandTheme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
            }
        }
        .onChange(of: viewModel.nickname) { _, newValue in
            if newValue.count > 20 {
                viewModel.nickname = String(newValue.prefix(20))
            }
        }
    }
}
