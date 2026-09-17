import SwiftUI

struct BorderlandPanel<HeaderAccessory: View, Content: View>: View {
    let title: String?
    @ViewBuilder let headerAccessory: HeaderAccessory
    @ViewBuilder let content: Content

    init(
        title: String? = nil,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.headerAccessory = headerAccessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if title != nil {
                HStack(spacing: Spacing.sm) {
                    Text(title ?? "")
                        .font(AppTypography.title3)
                        .foregroundStyle(BorderlandTheme.textPrimary)
                    Spacer()
                    headerAccessory
                }
            }

            content
        }
        .padding(Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BorderlandTheme.panelGradient)
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous)
                .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLarge, style: .continuous))
        .shadow(color: BorderlandTheme.shadowMedium.color, radius: BorderlandTheme.shadowMedium.radius, y: BorderlandTheme.shadowMedium.y)
    }
}

extension BorderlandPanel where HeaderAccessory == EmptyView {
    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, headerAccessory: { EmptyView() }, content: content)
    }
}
