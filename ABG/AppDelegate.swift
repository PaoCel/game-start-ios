import UIKit
import UserNotifications

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

extension Notification.Name {
  static let pushTokenDidChange = Notification.Name("ABG.pushTokenDidChange")
}

enum PushNotificationState {
  private static let tokenKey = "push.currentFCMToken"
  private static let authorizationRequestedKey = "push.authorizationRequested"

  static var currentToken: String? {
    let rawValue = UserDefaults.standard.string(forKey: tokenKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return rawValue.isEmpty ? nil : rawValue
  }

  static var hasRequestedAuthorization: Bool {
    get { UserDefaults.standard.bool(forKey: authorizationRequestedKey) }
    set { UserDefaults.standard.set(newValue, forKey: authorizationRequestedKey) }
  }

  static func store(token: String?) {
    let normalized = token?.trimmingCharacters(in: .whitespacesAndNewlines)
    let nextValue = (normalized?.isEmpty == false) ? normalized : nil
    guard nextValue != currentToken else { return }

    if let nextValue {
      UserDefaults.standard.set(nextValue, forKey: tokenKey)
    } else {
      UserDefaults.standard.removeObject(forKey: tokenKey)
    }

    NotificationCenter.default.post(name: .pushTokenDidChange, object: nextValue)
  }

  static func resolvedToken() async -> String? {
    if let currentToken {
      return currentToken
    }

    #if canImport(FirebaseMessaging)
    return await withCheckedContinuation { continuation in
      Messaging.messaging().token { token, error in
        if let error {
          AppLogger.error("push token fetch failed: \(error.localizedDescription)")
        }

        let normalized = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        store(token: normalized)
        continuation.resume(returning: normalized?.isEmpty == false ? normalized : nil)
      }
    }
    #else
    return nil
    #endif
  }
}

final class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    FirebaseBootstrap.configureIfPossible()
    configurePushNotifications(for: application)
    return true
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    refreshPushAuthorization(for: application)
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    #if canImport(FirebaseMessaging)
    Messaging.messaging().apnsToken = deviceToken
    Messaging.messaging().token { token, error in
      if let error {
        AppLogger.error("push token fetch failed: \(error.localizedDescription)")
      }
      PushNotificationState.store(token: token)
    }
    #endif
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    AppLogger.error("remote notification registration failed: \(error.localizedDescription)")
  }

  private func configurePushNotifications(for application: UIApplication) {
    UNUserNotificationCenter.current().delegate = self
    #if canImport(FirebaseMessaging)
    Messaging.messaging().delegate = self
    Messaging.messaging().isAutoInitEnabled = true
    #endif
    refreshPushAuthorization(for: application)
  }

  private func refreshPushAuthorization(for application: UIApplication) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      switch settings.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
        DispatchQueue.main.async {
          application.registerForRemoteNotifications()
        }
      case .notDetermined:
        self.requestPushAuthorizationIfNeeded(for: application)
      case .denied:
        break
      @unknown default:
        break
      }
    }
  }

  private func requestPushAuthorizationIfNeeded(for application: UIApplication) {
    guard !PushNotificationState.hasRequestedAuthorization else { return }
    PushNotificationState.hasRequestedAuthorization = true

    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      if let error {
        AppLogger.error("push authorization request failed: \(error.localizedDescription)")
      }
      guard granted else { return }
      DispatchQueue.main.async {
        application.registerForRemoteNotifications()
      }
    }
  }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .list, .sound]
  }
}

#if canImport(FirebaseMessaging)
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    PushNotificationState.store(token: fcmToken)
  }
}
#endif
