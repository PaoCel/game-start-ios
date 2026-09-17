import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LobbyView: View {
  let role: AppRole
  let isGuestSession: Bool
  let selectedGameName: String
  let selectedGameCode: String?
  let gameService: GameService
  let statusMessage: String
  let onEnterAsPlayer: (String) -> Void
  let onEnterAsAdmin: () -> Void
  let onEnterAsGuest: (String, String) -> Void
  let onBack: () -> Void
  let onLeaveMatch: () -> Void
  let onLogout: () async -> Void

  @State private var matchCode = ""
  @State private var playerProfile: PlayerProfile = .empty
  @State private var localStatus = ""
  @State private var isLoading = false
  @State private var hasLoadedProfile = false

  var body: some View {
    NavigationStack {
      ZStack {
        SuitBackdrop(density: .full)
        FloatingParticles()

        ScrollView(showsIndicators: false) {
          VStack(spacing: Spacing.lg) {
            headerPanel
            entryPanel
            if role == .admin {
              adminFallbackPanel
            }
          }
          .padding(.horizontal, Spacing.screenHorizontal)
          .padding(.vertical, Spacing.lg)
        }
      }
      .borderlandBackground()
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Games") {
            onBack()
          }
          .foregroundStyle(BorderlandTheme.gold)
        }
        ToolbarItem(placement: .topBarTrailing) {
          HStack(spacing: Spacing.sm) {
            Button("Esci") {
              onLeaveMatch()
            }
            .foregroundStyle(BorderlandTheme.textMuted)
            Button("Logout") {
              Task { await onLogout() }
            }
            .foregroundStyle(BorderlandTheme.gold)
          }
        }
      }
      .task {
        if matchCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          matchCode = selectedGameCode ?? ""
        }
        await loadProfileIfNeeded()
      }
    }
  }

  private var headerPanel: some View {
    BorderlandCard(variant: .elevated) {
      VStack(alignment: .leading, spacing: Spacing.xs) {
        HStack {
          Text("Lobby")
            .font(AppTypography.title2)
            .foregroundStyle(BorderlandTheme.gold)
          Spacer()
          StatusBadge(
            text: isGuestSession ? "Guest" : "Player",
            variant: isGuestSession ? .warn : .neutral
          )
        }

        Text("Game: \(selectedGameName)")
          .font(AppTypography.callout)
          .foregroundStyle(BorderlandTheme.textMuted)

        if !statusMessage.isEmpty {
          Text(statusMessage)
            .font(AppTypography.caption)
            .foregroundStyle(BorderlandTheme.textDim)
        }

        if !localStatus.isEmpty {
          HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundStyle(BorderlandTheme.statusDangerText)
            Text(localStatus)
              .font(AppTypography.caption)
              .foregroundStyle(BorderlandTheme.statusDangerText)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .padding(Spacing.sm)
          .background(BorderlandTheme.statusDanger.opacity(0.12))
          .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous))
        }
      }
    }
  }

  private var entryPanel: some View {
    BorderlandPanel(title: "Entra In Partita") {
      VStack(alignment: .leading, spacing: Spacing.md) {
        TextField("Codice partita", text: $matchCode)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .lobbyField()

        BorderlandButton(
          isGuestSession ? "Entra Come Ospite" : "Entra In Partita",
          variant: .primary,
          isEnabled: !matchCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          isLoading: isLoading
        ) {
          joinMatch()
        }
      }
    }
  }

  private var adminFallbackPanel: some View {
    BorderlandPanel(title: "Admin") {
      BorderlandButton("Apri Console Admin", variant: .secondary, isEnabled: !isLoading) {
        onEnterAsAdmin()
      }
    }
  }

  private func loadProfileIfNeeded() async {
    guard role == .player, !isGuestSession, !hasLoadedProfile else { return }
    do {
      playerProfile = try await gameService.fetchOwnProfile()
    } catch {
      // keep empty profile as fallback
    }
    hasLoadedProfile = true
  }

  private func joinMatch() {
    guard !isLoading else { return }

    let code = matchCode.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !code.isEmpty else {
      localStatus = "Inserisci un codice partita"
      return
    }

    isLoading = true
    localStatus = ""

    Task {
      defer { isLoading = false }

      do {
        if isGuestSession {
          // Auto-complete guest profile with a random nickname and default card
          // so the server's profileCompleted check passes.
          var guestProfile = (try? await gameService.fetchOwnProfile()) ?? .empty
          if !guestProfile.profileCompleted {
            let suffix = String(UUID().uuidString.prefix(4)).uppercased()
            guestProfile.nickname = guestProfile.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              ? "Guest-\(suffix)"
              : guestProfile.nickname
            if guestProfile.avatarDataUrl == nil || guestProfile.avatarDataUrl?.isEmpty == true {
              guestProfile.avatarDataUrl = ProfileCompletionViewModel.minimalAvatarDataURL
            }
            guestProfile.profileCompleted = true
            try await gameService.savePlayerProfile(guestProfile)
          }
          _ = try await gameService.joinMatch(gameCode: code, nickname: guestProfile.nickname)
          onEnterAsGuest(code, guestProfile.playingCard)
          return
        }

        var profile: PlayerProfile
        do {
          profile = try await gameService.fetchOwnProfile()
        } catch {
          profile = playerProfile
        }

        let trimmedNickname = profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedNickname.isEmpty {
          let fallbackSuffix = String((profile.uid.isEmpty ? UUID().uuidString : profile.uid).prefix(4)).uppercased()
          profile.nickname = "Giocatore-\(fallbackSuffix)"
          try? await gameService.savePlayerProfile(profile)
        }

        _ = try await gameService.joinMatch(gameCode: code, nickname: profile.nickname)
        playerProfile = profile
        onEnterAsPlayer(code)
      } catch {
        localStatus = "Errore ingresso: \(error.localizedDescription)"
      }
    }
  }
}

private extension View {
  func lobbyField() -> some View {
    self
      .font(AppTypography.callout)
      .foregroundStyle(BorderlandTheme.textPrimary)
      .padding(.horizontal, Spacing.sm)
      .frame(height: 48)
      .background(BorderlandTheme.surface3)
      .overlay(
        RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous)
          .stroke(BorderlandTheme.borderSubtle, lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMedium, style: .continuous))
  }
}
