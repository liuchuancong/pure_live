//
//  DeviceOrientationStreamHandler.swift
//  Pods
//
//  Created by Julian Steenbakker on 21/04/2025.
//

#if os(iOS)
  import Flutter
  import UIKit

class DeviceOrientationStreamHandler: NSObject, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?
    private var orientationObserver: NSObjectProtocol?
    private var lastSentOrientation: UIInterfaceOrientation?
    private var lastSentDeviceOrientation: UIDeviceOrientation?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events

        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.sendCurrentOrientation()
        }

        sendCurrentOrientation() // Send initial orientation
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
            orientationObserver = nil
        }

        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        eventSink = nil
        lastSentOrientation = nil
        lastSentDeviceOrientation = nil
        return nil
    }

    private func sendCurrentOrientation() {
        guard let sink = eventSink else { return }

        // Use interface orientation instead of device orientation
        // This respects Flutter's setPreferredOrientations
        if #available(iOS 13.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                return
            }

            let interfaceOrientation = windowScene.interfaceOrientation

            // Only send event if interface orientation has changed
            if lastSentOrientation == interfaceOrientation {
                return
            }

            lastSentOrientation = interfaceOrientation

            let orientationString: String
            switch interfaceOrientation {
            case .portrait:
                orientationString = "PORTRAIT_UP"
            case .portraitUpsideDown:
                orientationString = "PORTRAIT_DOWN"
            case .landscapeLeft:
                orientationString = "LANDSCAPE_LEFT"
            case .landscapeRight:
                orientationString = "LANDSCAPE_RIGHT"
            default:
                return
            }

            sink(orientationString)
        } else {
            // Fallback for iOS < 13: use device orientation
            let orientation = UIDevice.current.orientation

            if orientation == .faceUp || orientation == .faceDown {
                return
            }
            
            // Only send event if device orientation has changed
            if lastSentDeviceOrientation == orientation {
                return
            }

            lastSentDeviceOrientation = orientation

            let orientationString = orientation.toOrientationString
            sink(orientationString)
        }
    }
}

#endif
