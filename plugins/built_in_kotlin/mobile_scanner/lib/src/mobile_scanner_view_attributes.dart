import 'package:flutter/services.dart';
import 'package:mobile_scanner/src/enums/camera_facing.dart';
import 'package:mobile_scanner/src/enums/torch_state.dart';

/// This class defines the attributes for the mobile scanner view.
class MobileScannerViewAttributes {
  /// Construct a new [MobileScannerViewAttributes] instance.
  const MobileScannerViewAttributes({
    required this.cameraDirection,
    required this.currentTorchMode,
    required this.size,
    this.numberOfCameras,
    this.initialDeviceOrientation,
  });

  /// The direction of the active camera.
  final CameraFacing cameraDirection;

  /// The current torch state of the active camera.
  final TorchState currentTorchMode;

  /// The number of available cameras.
  final int? numberOfCameras;

  /// The size of the camera output.
  final Size size;

  /// The initial orientation of the device.
  final DeviceOrientation? initialDeviceOrientation;
}
