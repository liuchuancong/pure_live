import fl_pip
import Flutter
import UIKit

@main
@objc class AppDelegate: FlFlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func registerPlugin(_ registry: FlutterPluginRegistry) {
        GeneratedPluginRegistrant.register(with: registry)
    }
}