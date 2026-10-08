import 'package:flutter/services.dart';
import 'package:mobile_scanner/src/enums/camera_facing.dart';
import 'package:mobile_scanner/src/enums/mobile_scanner_error_code.dart';
import 'package:mobile_scanner/src/mobile_scanner_exception.dart';
import 'package:mobile_scanner/src/utils/parse_device_orientation_extension.dart';

/// This class will manage the orientation corrections for textures
/// that are provided by the SurfaceProducer API on Android.
class AndroidSurfaceProducerDelegate {
  /// Construct a new [AndroidSurfaceProducerDelegate].
  AndroidSurfaceProducerDelegate({
    required this.cameraFacingDirection,
    required this.handlesCropAndRotation,
    required this.initialDeviceOrientation,
    required this.sensorOrientationDegrees,
  });

  /// Construct a new [AndroidSurfaceProducerDelegate]
  /// from the given [config] and [cameraDirection].
  ///
  /// Throws a [MobileScannerException] if the configuration is invalid.
  factory AndroidSurfaceProducerDelegate.fromConfiguration(
    Map<String, Object?> config,
    CameraFacing cameraDirection,
  ) {
    if (config case {
      'handlesCropAndRotation': final bool handlesCropAndRotation,
      'naturalDeviceOrientation': final String naturalDeviceOrientation,
      'sensorOrientation': final int sensorOrientation,
    }) {
      final naturalOrientation =
          naturalDeviceOrientation.parseDeviceOrientation();

      return AndroidSurfaceProducerDelegate(
        cameraFacingDirection: cameraDirection,
        handlesCropAndRotation: handlesCropAndRotation,
        initialDeviceOrientation: naturalOrientation,
        sensorOrientationDegrees: sensorOrientation.toDouble(),
      );
    }

    throw const MobileScannerException(
      errorCode: MobileScannerErrorCode.genericError,
      errorDetails: MobileScannerErrorDetails(
        message: 'The start method did not return a valid configuration.',
      ),
    );
  }

  /// The facing direction of the active camera.
  final CameraFacing cameraFacingDirection;

  /// Whether the underlying surface producer handles crop and rotation.
  ///
  /// If this is false, the preview needs to be manually rotated.
  final bool handlesCropAndRotation;

  /// The initial device orientation when this [AndroidSurfaceProducerDelegate]
  /// is created.
  final DeviceOrientation initialDeviceOrientation;

  /// The orientation of the camera sensor on the device, in degrees.
  final double sensorOrientationDegrees;
}
