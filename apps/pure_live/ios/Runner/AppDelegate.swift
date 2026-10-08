import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var displayModeChannel: FlutterMethodChannel?
  private var highRefreshRateEnabled = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "PureLiveDisplayMode"
    ) else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "pure_live/display_mode",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "setHighRefreshRate":
        let arguments = call.arguments as? [String: Any]
        self.highRefreshRateEnabled = arguments?["enabled"] as? Bool ?? false
        result(self.displayModeInfo())
      case "getDisplayModeInfo":
        result(self.displayModeInfo())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    displayModeChannel = channel
  }

  private func activeScreen() -> UIScreen {
    for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
      if scene.activationState == .foregroundActive || scene.activationState == .foregroundInactive {
        return scene.screen
      }
    }
    return UIScreen.main
  }

  private func displayModeInfo() -> [String: Any] {
    let screen = activeScreen()
    let maximum = Double(screen.maximumFramesPerSecond)
    var supportedRates = [min(60.0, maximum)]
    if maximum > 60.0 { supportedRates.append(maximum) }
    let bounds = screen.nativeBounds
    return [
      "enabled": highRefreshRateEnabled,
      "currentRefreshRate": highRefreshRateEnabled ? maximum : min(60.0, maximum),
      "maxRefreshRate": maximum,
      "preferredRefreshRate": highRefreshRateEnabled ? maximum : min(60.0, maximum),
      "supportedRefreshRates": supportedRates,
      "requestedRefreshRate": highRefreshRateEnabled ? maximum : 0.0,
      "width": Int(bounds.width),
      "height": Int(bounds.height),
    ]
  }
}
