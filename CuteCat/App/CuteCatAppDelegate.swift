import UIKit

final class CuteCatAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        ModelDownloadService.shared.registerBackgroundCompletionHandler(
            identifier: identifier,
            completionHandler: completionHandler
        )
    }
}
