import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
  @Published var isLoading = false
  @Published var errorMessage = ""

  private let authService: AuthService
  private let onSignedIn: (AppRole) -> Void

  init(authService: AuthService, onSignedIn: @escaping (AppRole) -> Void) {
    self.authService = authService
    self.onSignedIn = onSignedIn
  }

  func signInWithGoogle() {
    guard !isLoading else { return }
    isLoading = true
    errorMessage = ""

    Task {
      defer { isLoading = false }
      do {
        let role = try await authService.signInWithGoogle()
        handleAuthenticatedRole(role)
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  func signInWithApple() {
    guard !isLoading else { return }
    isLoading = true
    errorMessage = ""

    Task {
      defer { isLoading = false }
      do {
        let role = try await authService.signInWithApple()
        handleAuthenticatedRole(role)
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  func signInAsGuest() {
    guard !isLoading else { return }
    isLoading = true
    errorMessage = ""

    Task {
      defer { isLoading = false }
      do {
        let role = try await authService.signInAsGuest()
        handleAuthenticatedRole(role)
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  private func handleAuthenticatedRole(_ role: AppRole) {
    onSignedIn(role)
  }
}
