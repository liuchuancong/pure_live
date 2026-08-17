import Flutter
import UIKit

@objc public class FlutterExitAppPlugin: NSObject, FlutterPlugin {
    @objc public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_exit_app", binaryMessenger: registrar.messenger())
        let instance = FlutterExitAppPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    @objc public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)

        case "com.laoitdev.exit.app":
            guard let arguments = call.arguments as? [String: Any],
                  let killIosProcess = arguments["killIosProcess"] as? Bool else {
                exitApp(forceKill: false)
                result("Done")
                return
            }
            exitApp(forceKill: killIosProcess)
            result("Done")

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Exits the application using iOS best practices
    ///
    /// - Parameter forceKill: If true, forcibly terminates the app process after cleanup.
    ///   Default behavior (false) moves the app to background gracefully (Apple recommended).
    ///
    /// **Apple's Best Practices:**
    /// - Apps should never quit programmatically (HIG guideline)
    /// - Default mode suspends app to background (user can reopen)
    /// - Force kill terminates process completely (appears as crash to user)
    /// - For App Store submission, only use default mode
    private func exitApp(forceKill: Bool = false) {
        // Execute on main thread to ensure proper UI/lifecycle handling
        DispatchQueue.main.async { [weak self] in
            self?.performExit(forceKill: forceKill)
        }
    }

    /// Performs the actual exit operation
    ///
    /// **Implementation Details:**
    /// - Default: Moves app to background state (suspended by iOS)
    /// - Force: Performs cleanup, delays, then terminates process
    /// - Both modes properly handle app lifecycle events
    private func performExit(forceKill: Bool) {
        // Post notification for any listeners that want to perform cleanup
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)

        if forceKill {
            // Force termination with proper cleanup sequence
            // 1. Resign active state
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

            // 2. Allow brief time for cleanup and state saving
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 3. Terminate the application
                // Note: This will appear as a crash in iOS. Use only for enterprise/internal apps.
                exit(0)
            }
        } else {
            // Best Practice: Move to background gracefully
            // This is the Apple-recommended approach

            // 1. Trigger background state
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

            // 2. Use private API to suspend (moves app to background)
            // Alternative: On iOS 13+ you could use UIWindowScene to manage visibility
            // Note: This private API usage might cause App Store rejection
            // For App Store apps, consider removing this line and relying only on notifications
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                UIApplication.shared.perform(#selector(URLSessionTask.suspend))
            }

            // Note: The app will remain in memory in suspended state.
            // iOS will terminate it automatically when memory is needed.
            // This is the correct iOS behavior and follows Apple's guidelines.
        }
    }
}
