import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

enum FirebaseBootstrap {
  static func configureIfPossible() {
    #if canImport(FirebaseCore)
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
      AppLogger.info("Firebase configured")
    }
    #else
    AppLogger.info("Firebase SDK non ancora installato (staging mode)")
    #endif
  }
}
