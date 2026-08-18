/// @docImport 'package:mobile_scanner/src/mobile_scanner_controller.dart';
library;

import 'package:flutter/services.dart';
import 'package:mobile_scanner/src/enums/camera_facing.dart';
import 'package:mobile_scanner/src/enums/camera_lens_type.dart';
import 'package:mobile_scanner/src/enums/mobile_scanner_error_code.dart';
import 'package:mobile_scanner/src/enums/torch_state.dart';
import 'package:mobile_scanner/src/mobile_scanner_exception.dart';

/// This class represents the current state of a [MobileScannerController].
class MobileScannerState {
  /// Create a new [MobileScannerState] instance.
  const MobileScannerState({
    required this.availableCameras,
    required this.cameraDirection,
    required this.cameraLensType,
    required this.isInitialized,
    required this.isStarting,
    required this.isRunning,
    required this.size,
    required this.torchState,
    required this.zoomScale,
    required this.deviceOrientation,
    this.error,
  });

  /// Create a new [MobileScannerState] instance that is uninitialized.
  const MobileScannerState.uninitialized()
    : this(
        availableCameras: null,
        cameraDirection: CameraFacing.unknown,
        cameraLensType: CameraLensType.any,
        isInitialized: false,
        isStarting: false,
        isRunning: false,
        size: Size.zero,
        torchState: TorchState.unavailable,
        deviceOrientation: DeviceOrientation.portraitUp,
        zoomScale: 1,
      );

  /// The number of available cameras.
  ///
  /// This is null if the number of cameras is unknown.
  final int? availableCameras;

  /// The facing direction of the camera.
  final CameraFacing cameraDirection;

  /// The lens type of the camera.
  final CameraLensType cameraLensType;

  /// The error that occurred while setting up or using the camera.
  final MobileScannerException? error;

  /// Whether the mobile scanner has initialized successfully.
  ///
  /// This does not indicate that the camera permission was granted.
  /// To check if the camera permission was granted, use [hasCameraPermission].
  final bool isInitialized;

  /// Whether the mobile scanner is currently in the process of starting.
  ///
  /// This flag helps prevent duplicate calls to
  /// [MobileScannerController.start].
  final bool isStarting;

  /// Whether the mobile scanner is currently running.
  ///
  /// This is `true` if the camera is active.
  final bool isRunning;

  /// The size of the camera output.
  final Size size;

  /// The current state of the flashlight of the camera.
  final TorchState torchState;

  /// The current zoom scale of the camera.
  final double zoomScale;

  /// The current device UI orientation.
  final DeviceOrientation deviceOrientation;

  /// Whether permission to access the camera was granted.
  bool get hasCameraPermission {
    return isInitialized &&
        error?.errorCode != MobileScannerErrorCode.permissionDenied;
  }

  /// Create a copy of this state with the given parameters.
  MobileScannerState copyWith({
    int? availableCameras,
    CameraFacing? cameraDirection,
    CameraLensType? cameraLensType,
    MobileScannerException? error,
    bool? isInitialized,
    bool? isStarting,
    bool? isRunning,
    Size? size,
    TorchState? torchState,
    DeviceOrientation? deviceOrientation,
    double? zoomScale,
  }) {
    return MobileScannerState(
      availableCameras: availableCameras ?? this.availableCameras,
      cameraDirection: cameraDirection ?? this.cameraDirection,
      cameraLensType: cameraLensType ?? this.cameraLensType,
      error: error,
      isInitialized: isInitialized ?? this.isInitialized,
      isStarting: isStarting ?? this.isStarting,
      isRunning: isRunning ?? this.isRunning,
      size: size ?? this.size,
      torchState: torchState ?? this.torchState,
      deviceOrientation: deviceOrientation ?? this.deviceOrientation,
      zoomScale: zoomScale ?? this.zoomScale,
    );
  }
}
