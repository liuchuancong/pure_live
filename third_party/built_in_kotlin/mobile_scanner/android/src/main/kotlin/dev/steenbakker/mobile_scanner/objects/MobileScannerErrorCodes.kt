package dev.steenbakker.mobile_scanner.objects

class MobileScannerErrorCodes {
    companion object {
        const val ALREADY_STARTED_ERROR = "MOBILE_SCANNER_ALREADY_STARTED_ERROR"
        const val ALREADY_STARTED_ERROR_MESSAGE = "The scanner was already started."
        const val ANALYZE_IMAGE_NO_VALID_IMAGE_ERROR_MESSAGE = "The provided file is not an image."
        // The error code 'BARCODE_ERROR' does not have an error message,
        // because it uses the error message from the underlying error.
        const val BARCODE_ERROR = "MOBILE_SCANNER_BARCODE_ERROR"
        // The error code 'CAMERA_ACCESS_DENIED' does not have an error message,
        // because it is used for a boolean result.
        const val CAMERA_ACCESS_DENIED = "MOBILE_SCANNER_CAMERA_PERMISSION_DENIED"
        const val CAMERA_ERROR = "MOBILE_SCANNER_CAMERA_ERROR"
        const val CAMERA_ERROR_MESSAGE = "An error occurred when opening the camera."
        const val CAMERA_PERMISSIONS_REQUEST_ONGOING = "MOBILE_SCANNER_CAMERA_PERMISSION_REQUEST_PENDING"
        const val CAMERA_PERMISSIONS_REQUEST_ONGOING_MESSAGE = "Another request is ongoing and multiple requests cannot be handled at once."
        const val GENERIC_ERROR = "MOBILE_SCANNER_GENERIC_ERROR"
        const val GENERIC_ERROR_MESSAGE = "An unknown error occurred."
        const val INVALID_ZOOM_SCALE_ERROR_MESSAGE = "The zoom scale should be between 0 and 1 (both inclusive)"
        const val NO_CAMERA_ERROR = "MOBILE_SCANNER_NO_CAMERA_ERROR"
        const val NO_CAMERA_ERROR_MESSAGE = "No cameras available."
        const val SET_SCALE_WHEN_STOPPED_ERROR = "MOBILE_SCANNER_SET_SCALE_WHEN_STOPPED_ERROR"
        const val SET_SCALE_WHEN_STOPPED_ERROR_MESSAGE = "The zoom scale cannot be changed when the camera is stopped."
        const val UNSUPPORTED_OPERATION_ERROR = "MOBILE_SCANNER_UNSUPPORTED_OPERATION" // Reserved for future use.
        const val INVALID_FOCUS_POINT = "MOBILE_SCANNER_INVALID_FOCUS_POINT"
        const val INVALID_FOCUS_POINT_MESSAGE = "The focus coordinates are not valid."
    }
}