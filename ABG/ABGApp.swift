import SwiftUI

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct ABGApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  @StateObject private var container: AppContainer

  init() {
    _container = StateObject(wrappedValue: AppContainer())
  }

  var body: some Scene {
    WindowGroup {
      Group {
        if AppStoreScreenshotLaunch.isEnabled {
          AppStoreScreenshotStudioView()
        } else {
          RootView()
            .environmentObject(container)
            .onOpenURL { url in
              #if canImport(GoogleSignIn)
              _ = GIDSignIn.sharedInstance.handle(url)
              #endif
              container.handleIncomingURL(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
              guard let url = activity.webpageURL else { return }
              container.handleIncomingURL(url)
            }
        }
      }
      .environment(\.theme, BorderlandTheme())
    }
  }
}
