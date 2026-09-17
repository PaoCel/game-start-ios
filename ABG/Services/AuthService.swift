import Foundation

protocol AuthService {
  var currentUser: AppUser? { get }
  var currentRole: AppRole { get }

  func restoreSession() async
  func refreshCurrentRole() async -> AppRole
  func signInWithGoogle() async throws -> AppRole
  func signInWithApple() async throws -> AppRole
  func signInAsGuest() async throws -> AppRole
  func signOut() async throws
}

enum AuthServiceFactory {
  static func make() -> AuthService {
    #if canImport(FirebaseAuth)
    return FirebaseAuthService()
    #else
    return MockAuthService()
    #endif
  }
}

final class MockAuthService: AuthService {
  private(set) var currentUser: AppUser?
  private(set) var currentRole: AppRole = .unknown

  func restoreSession() async {
    // no-op for staging
  }

  func refreshCurrentRole() async -> AppRole {
    currentRole
  }

  func signInWithGoogle() async throws -> AppRole {
    currentUser = AppUser(uid: "mock-player", email: "player@example.com", displayName: "Mock Player")
    currentRole = .player
    return currentRole
  }

  func signInWithApple() async throws -> AppRole {
    currentUser = AppUser(uid: "mock-admin", email: nil, displayName: "Mock Admin")
    currentRole = .player
    return currentRole
  }

  func signInAsGuest() async throws -> AppRole {
    currentUser = AppUser(
      uid: "guest-\(UUID().uuidString.lowercased())",
      email: nil,
      displayName: "Guest",
      isGuest: true
    )
    currentRole = .player
    return currentRole
  }

  func signOut() async throws {
    currentUser = nil
    currentRole = .unknown
  }
}
