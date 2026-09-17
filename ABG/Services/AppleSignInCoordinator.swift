#if canImport(AuthenticationServices) && canImport(CryptoKit) && canImport(UIKit)
import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

struct AppleSignInResult {
  let idToken: String
  let rawNonce: String
}

@MainActor
final class AppleSignInCoordinator: NSObject {
  private var continuation: CheckedContinuation<AppleSignInResult, Error>?
  private var currentNonce = ""

  func start() async throws -> AppleSignInResult {
    let nonce = Self.randomNonceString()
    currentNonce = nonce

    return try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation

      let request = ASAuthorizationAppleIDProvider().createRequest()
      request.requestedScopes = [.fullName, .email]
      request.nonce = Self.sha256(nonce)

      let controller = ASAuthorizationController(authorizationRequests: [request])
      controller.delegate = self
      controller.presentationContextProvider = self
      controller.performRequests()
    }
  }

  private func complete(with result: Result<AppleSignInResult, Error>) {
    guard let continuation else {
      return
    }
    self.continuation = nil
    continuation.resume(with: result)
  }

  private static func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remaining = length

    while remaining > 0 {
      var randoms = [UInt8](repeating: 0, count: 16)
      let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
      if errorCode != errSecSuccess {
        AppLogger.error("SecRandomCopyBytes failed with OSStatus \(errorCode), falling back to SystemRandomNumberGenerator")
        var rng = SystemRandomNumberGenerator()
        randoms = (0..<randoms.count).map { _ in UInt8.random(in: 0...255, using: &rng) }
      }

      randoms.forEach { random in
        if remaining == 0 {
          return
        }

        if random < charset.count {
          result.append(charset[Int(random)])
          remaining -= 1
        }
      }
    }

    return result
  }

  private static func sha256(_ input: String) -> String {
    let data = Data(input.utf8)
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
      complete(
        with: .failure(
          NSError(
            domain: "auth",
            code: 1001,
            userInfo: [NSLocalizedDescriptionKey: "Credenziale Apple non valida"]
          )
        )
      )
      return
    }

    guard
      let tokenData = credential.identityToken,
      let token = String(data: tokenData, encoding: .utf8)
    else {
      complete(
        with: .failure(
          NSError(
            domain: "auth",
            code: 1002,
            userInfo: [NSLocalizedDescriptionKey: "Apple identity token mancante"]
          )
        )
      )
      return
    }

    complete(with: .success(AppleSignInResult(idToken: token, rawNonce: currentNonce)))
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    complete(with: .failure(error))
  }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    let scenes = UIApplication.shared
      .connectedScenes
      .compactMap { $0 as? UIWindowScene }

    if let keyWindow = scenes
      .flatMap(\.windows)
      .first(where: { $0.isKeyWindow }) {
      return keyWindow
    }

    if let firstScene = scenes.first {
      return firstScene.windows.first ?? UIWindow(windowScene: firstScene)
    }

    AppLogger.error("No active window scene available for Sign in with Apple.")
    return ASPresentationAnchor()
  }
}
#endif
