import SwiftUI

struct TeamRosterView: View {
    struct Teammate: Identifiable {
        let id: String
        let nickname: String
        let avatarDataUrl: String?
        let role: String
        let cardCode: String
        let identityDeckIndex: Int?
    }

    let teammates: [Teammate]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                SuitBackdrop(density: .light)

                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        if teammates.isEmpty {
                            VStack(spacing: Spacing.sm) {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 40, weight: .semibold))
                                    .foregroundStyle(BorderlandTheme.textDim)
                                Text("Nessun compagno")
                                    .font(AppTypography.callout)
                                    .foregroundStyle(BorderlandTheme.textDim)
                            }
                            .padding(.top, Spacing.xxl)
                        } else {
                            ForEach(teammates) { mate in
                                BorderlandCard {
                                    HStack(spacing: Spacing.sm) {
                                        AvatarView(avatarDataUrl: mate.avatarDataUrl, initials: initials(from: mate.nickname), size: .medium)
                                        VStack(alignment: .leading, spacing: Spacing.xxxs) {
                                            Text(mate.nickname)
                                                .font(AppTypography.headline)
                                                .foregroundStyle(BorderlandTheme.textPrimary)

                                            StatusBadge(
                                                text: mate.role.lowercased().contains("leader") ? "LEADER" : "Giocatore",
                                                variant: mate.role.lowercased().contains("leader") ? .warn : .neutral
                                            )

                                            Text(mate.cardCode)
                                                .font(AppTypography.caption)
                                                .foregroundStyle(BorderlandTheme.textDim)

                                            if let deckIndex = mate.identityDeckIndex, deckIndex > 1 {
                                                Text("Mazzo \(deckIndex)")
                                                    .font(AppTypography.caption2)
                                                    .foregroundStyle(BorderlandTheme.gold)
                                            }
                                        }

                                        Spacer()
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
            .navigationTitle("SQUADRA")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BorderlandButton("Chiudi", variant: .ghost) {
                        dismiss()
                    }
                    .frame(width: 88)
                }
            }
        }
    }

    private func initials(from value: String) -> String {
        value.split(separator: " ").compactMap { $0.first }.prefix(2).map(String.init).joined().uppercased()
    }
}
