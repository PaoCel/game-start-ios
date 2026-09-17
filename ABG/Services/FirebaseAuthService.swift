#if canImport(FirebaseAuth)
import Foundation
import FirebaseAuth
import FirebaseCore

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

#if canImport(UIKit)
import UIKit
#endif

final class FirebaseAuthService: AuthService {
  private(set) var currentRole: AppRole = .unknown

  #if canImport(AuthenticationServices) && canImport(CryptoKit) && canImport(UIKit)
  @MainActor private var appleSignInCoordinator: AppleSignInCoordinator?
  #endif

  var currentUser: AppUser? {
    guard let user = Auth.auth().currentUser else {
      return nil
    }
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName ?? (user.isAnonymous ? "Guest" : nil),
      isGuest: user.isAnonymous
    )
  }

  func restoreSession() async {
    await refreshRoleFromClaims()
  }

  func refreshCurrentRole() async -> AppRole {
    await refreshRoleFromClaims()
    return currentRole
  }

  func signInWithGoogle() async throws -> AppRole {
    #if canImport(GoogleSignIn) && canImport(UIKit)
    guard let clientID = FirebaseApp.app()?.options.clientID else {
      throw NSError(domain: "auth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Firebase clientID mancante"])
    }

    guard let presenter = UIApplication.topViewController() else {
      throw NSError(domain: "auth", code: 2, userInfo: [NSLocalizedDescriptionKey: "Presenter iOS non disponibile"])
    }

    let config = GIDConfiguration(clientID: clientID)
    GIDSignIn.sharedInstance.configuration = config

    let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
    guard let idToken = result.user.idToken?.tokenString else {
      throw NSError(domain: "auth", code: 3, userInfo: [NSLocalizedDescriptionKey: "Google ID token mancante"])
    }

    let accessToken = result.user.accessToken.tokenString
    let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
    _ = try await Auth.auth().signIn(with: credential)

    await refreshRoleFromClaims()
    return currentRole
    #else
    throw NSError(domain: "auth", code: 4, userInfo: [NSLocalizedDescriptionKey: "Google Sign-In SDK non installato"])
    #endif
  }

  @MainActor
  func signInWithApple() async throws -> AppRole {
    #if canImport(AuthenticationServices) && canImport(CryptoKit) && canImport(UIKit)
    let coordinator = AppleSignInCoordinator()
    appleSignInCoordinator = coordinator
    defer { appleSignInCoordinator = nil }

    let result = try await coordinator.start()
    let credential = OAuthProvider.appleCredential(
      withIDToken: result.idToken,
      rawNonce: result.rawNonce,
      fullName: nil
    )

    _ = try await Auth.auth().signIn(with: credential)
    await refreshRoleFromClaims()
    return currentRole
    #else
    throw NSError(domain: "auth", code: 5, userInfo: [NSLocalizedDescriptionKey: "Sign in with Apple non disponibile in questa build"])
    #endif
  }

  func signOut() async throws {
    #if canImport(GoogleSignIn)
    GIDSignIn.sharedInstance.signOut()
    #endif
    try Auth.auth().signOut()
    currentRole = .unknown
  }

  func signInAsGuest() async throws -> AppRole {
    do {
      _ = try await Auth.auth().signInAnonymously()
      currentRole = .player
      return currentRole
    } catch {
      if let nsError = error as NSError?,
         let code = AuthErrorCode(rawValue: nsError.code),
         code == .adminRestrictedOperation || code == .operationNotAllowed {
        throw NSError(
          domain: "auth",
          code: nsError.code,
          userInfo: [
            NSLocalizedDescriptionKey: "Accesso ospite non abilitato nel progetto Firebase. Attiva Authentication > Sign-in method > Anonymous per completare il login guest."
          ]
        )
      }
      throw error
    }
  }

  private func refreshRoleFromClaims() async {
    guard Auth.auth().currentUser != nil else {
      currentRole = .unknown
      return
    }
    currentRole = .player
    AppLogger.info("role resolved from authenticated session: PLAYER")
  }

}
#endif
