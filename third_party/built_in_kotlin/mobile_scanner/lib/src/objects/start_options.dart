import 'dart:ui';

import 'package:mobile_scanner/src/enums/barcode_format.dart';
import 'package:mobile_scanner/src/enums/camera_facing.dart';
import 'package:mobile_scanner/src/enums/camera_lens_type.dart';
import 'package:mobile_scanner/src/enums/detection_speed.dart';

/// This class defines the different start options for the mobile scanner.
class StartOptions {
  /// Construct a new [StartOptions] instance.
  const StartOptions({
    required this.cameraDirection,
    required this.cameraLensType,
    required this.cameraResolution,
    required this.detectionSpeed,
    required this.detectionTimeoutMs,
    required this.formats,
    required this.returnImage,
    required this.torchEnabled,
    required this.invertImage,
    required this.autoZoom,
    required this.initialZoom,
  });

  /// The direction for the camera.
  final CameraFacing cameraDirection;

  /// The desired camera resolution for the scanner.
  final Size? cameraResolution;

  /// The preferred lens type for the camera.
  ///
  /// This allows selection between normal, wide, and zoom lenses on devices
  /// with multiple cameras.
  ///
  /// When set to [CameraLensType.any], the first available camera for the
  /// given [cameraDirection] will be used.
  final CameraLensType cameraLensType;

  /// Invert image colors for analyzer to support white-on-black barcodes, which
  /// are not supported by MLKit.
  final bool invertImage;

  /// The detection speed for the scanner.
  final DetectionSpeed detectionSpeed;

  /// The detection timeout for the scanner, in milliseconds.
  final int detectionTimeoutMs;

  /// The barcode formats to detect.
  final List<BarcodeFormat> formats;

  /// Whether the detected barcodes should provide their image data.
  final bool returnImage;

  /// Whether the torch should be turned on when the scanner starts.
  final bool torchEnabled;

  /// Whether the camera should auto zoom if the detected code is to far from
  /// the camera.
  ///
  /// This option is only supported on Android. Other platforms will ignore this
  /// option.
  final bool autoZoom;

  /// The initial zoom scale factor for the camera.
  ///
  /// Currently only supported on iOS, MacOS and Android.
  final double? initialZoom;

  /// Converts this object to a map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (cameraResolution != null)
        'cameraResolution': <int>[
          cameraResolution!.width.toInt(),
          cameraResolution!.height.toInt(),
        ],
      'facing': cameraDirection.rawValue,
      'lensType': cameraLensType.rawValue,
      if (formats.isNotEmpty)
        'formats': formats.map((f) => f.rawValue).toList(),
      'returnImage': returnImage,
      'speed': detectionSpeed.rawValue,
      'timeout': detectionTimeoutMs,
      'torch': torchEnabled,
      'invertImage': invertImage,
      'autoZoom': autoZoom,
      'initialZoom': initialZoom,
    };
  }
}
