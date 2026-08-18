//
//  MobileScannerError.swift
//  mobile_scanner
//
//  Created by Julian Steenbakker on 24/08/2022.
//
import Foundation

// TODO: decide if we should keep or discard this enum
// When merging the iOS / MacOS implementations we should either keep the enum or remove it

// This enum is a bit of a leftover from older parts of the iOS implementation.
// It is used by the handler that throws these error codes,
// while the plugin class intercepts these and converts them to `FlutterError()`s.
enum MobileScannerError: Error {
    case noCamera
    case alreadyStarted
    case alreadyStopped
    case alreadyPaused
    case cameraError(_ error: Error)
    case zoomWhenStopped
    case zoomError(_ error: Error)
    case analyzerError(_ error: Error)
}
