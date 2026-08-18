//
//  MobileScannerErrorCodes.swift
//  mobile_scanner
//
//  Created by Navaron Bracke on 27/05/2024.
//

import Foundation

struct MobileScannerErrorCodes {
    static let ALREADY_STARTED_ERROR = "MOBILE_SCANNER_ALREADY_STARTED_ERROR"
    static let ALREADY_STARTED_ERROR_MESSAGE = "The scanner was already started."
    static let ANALYZE_IMAGE_IOS_SIMULATOR_NOT_SUPPORTED_ERROR_MESSAGE = "Analyzing an image from a file is not supported on the iOS Simulator."
    static let ANALYZE_IMAGE_NO_VALID_IMAGE_ERROR_MESSAGE = "The provided file is not an image."
    // The error code 'BARCODE_ERROR' does not have an error message,
    // because it uses the error message from the undelying error.
    static let BARCODE_ERROR = "MOBILE_SCANNER_BARCODE_ERROR"
    // The error code 'CAMERA_ERROR' does not have an error message,
    // because it uses the error message from the underlying error.
    static let CAMERA_ERROR = "MOBILE_SCANNER_CAMERA_ERROR"
    // This error message is used when the active AVCaptureSession cannot add the camera video input.
    static let CAMERA_ERROR_CAPTURE_SESSION_INPUT_OCCUPIED_MESSAGE = "The camera video input could not be initialized."
    static let GENERIC_ERROR = "MOBILE_SCANNER_GENERIC_ERROR"
    static let GENERIC_ERROR_MESSAGE = "An unknown error occurred."
    // This message is used with the 'GENERIC_ERROR' error code.
    static let INVALID_ZOOM_SCALE_ERROR_MESSAGE = "The zoom scale should be between 0 and 1 (both inclusive)"
    static let INVALID_FOCUS_POINT = "MOBILE_SCANNER_INVALID_FOCUS_POINT"
    static let INVALID_FOCUS_POINT_MESSAGE = "The focus coordinates are not valid."
    static let NO_CAMERA_ERROR = "MOBILE_SCANNER_NO_CAMERA_ERROR"
    static let NO_CAMERA_ERROR_MESSAGE = "No cameras available."
    static let SET_SCALE_WHEN_STOPPED_ERROR = "MOBILE_SCANNER_SET_SCALE_WHEN_STOPPED_ERROR"
    static let SET_SCALE_WHEN_STOPPED_ERROR_MESSAGE = "The zoom scale cannot be changed when the camera is stopped."
    static let UNSUPPORTED_OPERATION_ERROR = "MOBILE_SCANNER_UNSUPPORTED_OPERATION"
}
