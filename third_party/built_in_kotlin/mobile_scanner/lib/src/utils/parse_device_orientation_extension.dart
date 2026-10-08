import 'package:flutter/services.dart';

/// This extension defines a utility function for parsing a [DeviceOrientation]
/// from a [String].
extension ParseDeviceOrientation on String {
  /// Parse `this` into a [DeviceOrientation].
  ///
  /// Returns the parsed device orientation.
  /// Throws an [ArgumentError] if `this` is an invalid device orientation.
  DeviceOrientation parseDeviceOrientation() {
    return switch (this) {
      'PORTRAIT_UP' => DeviceOrientation.portraitUp,
      'PORTRAIT_DOWN' => DeviceOrientation.portraitDown,
      'LANDSCAPE_LEFT' => DeviceOrientation.landscapeLeft,
      'LANDSCAPE_RIGHT' => DeviceOrientation.landscapeRight,
      _ =>
        throw ArgumentError.value(
          this,
          'deviceOrientation',
          'Received an invalid device orientation',
        ),
    };
  }
}
