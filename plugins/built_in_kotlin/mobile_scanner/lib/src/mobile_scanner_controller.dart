/// @docImport 'package:mobile_scanner/src/mobile_scanner.dart';
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
// ignore: unnecessary_import needed for older Flutter sdk's
import 'package:meta/meta.dart';
import 'package:mobile_scanner/src/enums/barcode_format.dart';
import 'package:mobile_scanner/src/enums/camera_facing.dart';
import 'package:mobile_scanner/src/enums/camera_lens_type.dart';
import 'package:mobile_scanner/src/enums/detection_speed.dart';
import 'package:mobile_scanner/src/enums/mobile_scanner_error_code.dart';
import 'package:mobile_scanner/src/enums/torch_state.dart';
import 'package:mobile_scanner/src/method_channel/mobile_scanner_method_channel.dart';
import 'package:mobile_scanner/src/mobile_scanner_exception.dart';
import 'package:mobile_scanner/src/mobile_scanner_platform_interface.dart';
import 'package:mobile_scanner/src/objects/barcode_capture.dart';
import 'package:mobile_scanner/src/objects/mobile_scanner_state.dart';
import 'package:mobile_scanner/src/objects/start_options.dart';
import 'package:mobile_scanner/src/objects/switch_camera_option.dart';

/// The controller for the [MobileScanner] widget.
class MobileScannerController extends ValueNotifier<MobileScannerState> {
  /// Construct a new [MobileScannerController] instance.
  MobileScannerController({
    this.autoStart = true,
    this.cameraResolution,
    this.lensType = CameraLensType.any,
    this.detectionSpeed = DetectionSpeed.normal,
    int detectionTimeoutMs = 250,
    this.facing = CameraFacing.back,
    this.formats = const <BarcodeFormat>[],
    this.returnImage = false,
    this.torchEnabled = false,
    this.invertImage = false,
    this.autoZoom = false,
    this.initialZoom,
  }) : detectionTimeoutMs =
           detectionSpeed == DetectionSpeed.normal ? detectionTimeoutMs : 0,
       assert(
         detectionTimeoutMs >= 0,
         'The detection timeout must be greater than or equal to 0.',
       ),
       assert(
         facing != CameraFacing.unknown,
         'CameraFacing.unknown is not a valid camera direction.',
       ),
       super(const MobileScannerState.uninitialized());

  /// The desired resolution for the camera.
  ///
  /// When this value is provided, the camera will try to match this resolution,
  /// or fallback to the closest available resolution.
  /// When this is null, Android defaults to a resolution of 640x480.
  ///
  /// Bear in mind that changing the resolution has an effect on the aspect
  /// ratio.
  ///
  /// When the camera orientation changes,
  /// the resolution will be flipped to match the new dimensions of the display.
  ///
  /// Currently only supported on Android.
  final Size? cameraResolution;

  /// Automatically start the scanner on initialization.
  final bool autoStart;

  /// The detection speed for the scanner.
  ///
  /// Defaults to [DetectionSpeed.normal].
  final DetectionSpeed detectionSpeed;

  /// The detection timeout, in milliseconds, for the scanner.
  ///
  /// This timeout is ignored if the [detectionSpeed]
  /// is not set to [DetectionSpeed.normal].
  ///
  /// By default this is set to `250` milliseconds,
  /// which prevents memory issues on older devices.
  final int detectionTimeoutMs;

  /// The facing direction for the camera.
  ///
  /// Defaults to the back-facing camera.
  final CameraFacing facing;

  /// The lens type for the camera.
  ///
  /// This allows selection between normal, wide, and zoom lenses on devices
  /// with multiple cameras.
  ///
  /// Defaults to [CameraLensType.any], which uses the first available camera
  /// for the given [facing] direction.
  ///
  /// Currently only supported on iOS and Android.
  final CameraLensType lensType;

  /// The formats that the scanner should detect.
  ///
  /// If this is empty, all supported formats are detected.
  final List<BarcodeFormat> formats;

  /// Whether the [BarcodeCapture.image] bytes should be provided.
  ///
  /// If this is false, [BarcodeCapture.image] will always be null.
  ///
  /// Defaults to false, and is only supported on iOS, MacOS and Android.
  final bool returnImage;

  /// Invert image colors for analyzer to support white-on-black barcodes, which
  /// are not supported by MLKit. Usage of this parameter can incur a
  /// performance cost, as frames need to be altered during processing.
  ///
  /// Defaults to false and is only supported on Android.
  final bool invertImage;

  /// Whether the flashlight should be turned on when the camera is started.
  ///
  /// Defaults to false.
  final bool torchEnabled;

  /// Whether the camera should auto zoom if the detected code is to far from
  /// the camera.
  ///
  /// Only supported on Android.
  final bool autoZoom;

  /// The initial zoom scale for the camera.
  ///
  /// Defaults to no initial zoom and is only supported on iOS, MacOS and
  /// Android.
  final double? initialZoom;

  /// The internal barcode controller, that listens for detected barcodes.
  final StreamController<BarcodeCapture> _barcodesController =
      StreamController.broadcast();

  /// Get the stream of scanned barcodes.
  ///
  /// If an error occurred during the detection of a barcode,
  /// a [MobileScannerBarcodeException] error is emitted to the stream.
  Stream<BarcodeCapture> get barcodes => _barcodesController.stream;

  StreamSubscription<BarcodeCapture?>? _barcodesSubscription;
  StreamSubscription<TorchState>? _torchStateSubscription;
  StreamSubscription<double>? _zoomScaleSubscription;
  StreamSubscription<DeviceOrientation>? _deviceOrientationSubscription;

  bool _isDisposed = false;
  // This completer keeps track of whether the MobileScanner widget,
  // that is attached to this controller,
  // called its `initState()` lifecycle method.
  final Completer<void> _isAttachedCompleter = Completer<void>();

  // The controller that currently holds the platform camera session.
  //
  // Only one camera session can be active at a time,
  // but multiple controllers can exist simultaneously,
  // for instance when two routes with a scanner are on the navigation stack.
  //
  // A controller that does not hold the session must not tear down the
  // platform resources, as that would break the controller that does.
  // See https://github.com/juliansteenbakker/mobile_scanner/issues/1631
  static MobileScannerController? _platformSessionOwner;

  /// Reset the shared platform camera session owner.
  ///
  /// This is only intended for use in tests,
  /// to prevent state from leaking between test cases.
  @visibleForTesting
  static void resetPlatformSessionOwner() {
    _platformSessionOwner = null;
  }

  void _disposeListeners() {
    unawaited(_barcodesSubscription?.cancel());
    unawaited(_torchStateSubscription?.cancel());
    unawaited(_zoomScaleSubscription?.cancel());
    unawaited(_deviceOrientationSubscription?.cancel());

    _barcodesSubscription = null;
    _torchStateSubscription = null;
    _zoomScaleSubscription = null;
    _deviceOrientationSubscription = null;
  }

  void _setupListeners() {
    _barcodesSubscription = MobileScannerPlatform.instance.barcodesStream
        .listen(
          (barcode) {
            if (_barcodesController.isClosed || barcode == null) {
              return;
            }

            _barcodesController.add(barcode);
          },
          onError: (Object error) {
            if (_barcodesController.isClosed) {
              return;
            }

            _barcodesController.addError(error);
          },
          // Errors are handled gracefully by forwarding them.
          cancelOnError: false,
        );

    _torchStateSubscription = MobileScannerPlatform.instance.torchStateStream
        .listen((torchState) {
          if (_isDisposed) {
            return;
          }

          value = value.copyWith(torchState: torchState);
        });

    _zoomScaleSubscription = MobileScannerPlatform.instance.zoomScaleStateStream
        .listen((zoomScale) {
          if (_isDisposed) {
            return;
          }

          value = value.copyWith(zoomScale: zoomScale);
        });

    if (MobileScannerPlatform.instance
        case final MethodChannelMobileScanner implementation
        when defaultTargetPlatform != TargetPlatform.macOS) {
      _deviceOrientationSubscription = implementation
          .deviceOrientationChangedStream
          .listen((orientation) {
            if (_isDisposed) {
              return;
            }

            value = value.copyWith(deviceOrientation: orientation);
          });
    }
  }

  void _throwIfNotInitialized() {
    // If the controller is disposed,
    // for example, it was never started, and then disposed,
    // throw the disposed error.
    if (_isDisposed) {
      throw MobileScannerException(
        errorCode: MobileScannerErrorCode.controllerDisposed,
        errorDetails: MobileScannerErrorDetails(
          message: MobileScannerErrorCode.controllerDisposed.message,
        ),
      );
    }

    if (!value.isInitialized) {
      throw MobileScannerException(
        errorCode: MobileScannerErrorCode.controllerUninitialized,
        errorDetails: MobileScannerErrorDetails(
          message: MobileScannerErrorCode.controllerUninitialized.message,
        ),
      );
    }
  }

  /// Returns false if stop is called but not necessary, otherwise true is
  /// returned.
  bool _stop() {
    // Do nothing if not initialized or already stopped.
    // On the web, the permission popup triggers a lifecycle change from resumed
    // to inactive,
    // due to the permission popup gaining focus.
    // This would 'stop' the camera while it is not ready yet.
    if (!value.isInitialized || !value.isRunning || _isDisposed) {
      return false;
    }

    _disposeListeners();

    final oldTorchState = value.torchState;

    // After the camera stopped, set the torch state to off,
    // as the torch state callback is never called when the camera is stopped.
    // If the device does not have a torch, do not report "off".
    value = value.copyWith(
      isRunning: false,
      torchState:
          oldTorchState == TorchState.unavailable
              ? TorchState.unavailable
              : TorchState.off,
    );
    return true;
  }

  /// Analyze an image file.
  ///
  /// The [path] points to a file on the device.
  /// The [formats] specify the barcode formats that should be detected in the
  /// image.
  /// If the [formats] are omitted or empty, all formats are detected.
  ///
  /// This is only supported on Android, physical iOS devices and MacOS.
  /// This is not supported on the iOS Simulator, due to restrictions on the
  /// Simulator.
  ///
  /// Returns the [BarcodeCapture] that was found in the image.
  ///
  /// If an error occurred during the analysis of the image,
  /// a [MobileScannerBarcodeException] error is thrown.
  ///
  /// If analyzing images from a file is not supported, an [UnsupportedError]
  /// is thrown.
  Future<BarcodeCapture?> analyzeImage(
    String path, {
    List<BarcodeFormat> formats = const <BarcodeFormat>[],
  }) {
    return MobileScannerPlatform.instance.analyzeImage(path, formats: formats);
  }

  /// Build a camera preview widget.
  Widget buildCameraView() {
    _throwIfNotInitialized();

    return MobileScannerPlatform.instance.buildCameraView();
  }

  /// Reset the zoom scale of the camera.
  ///
  /// Does nothing if the camera is not running.
  Future<void> resetZoomScale() async {
    _throwIfNotInitialized();

    if (!value.isRunning) {
      return;
    }

    // When the platform has updated the zoom scale,
    // it will send an update through the zoom scale state event stream.
    await MobileScannerPlatform.instance.resetZoomScale();
  }

  /// Set the zoom scale of the camera.
  ///
  /// The [zoomScale] must be between 0.0 and 1.0 (both inclusive).
  ///
  /// If the [zoomScale] is out of range,
  /// it is adjusted to fit within the allowed range.
  ///
  /// Does nothing if the camera is not running.
  Future<void> setZoomScale(double zoomScale) async {
    _throwIfNotInitialized();

    if (!value.isRunning) {
      return;
    }

    final clampedZoomScale = zoomScale.clamp(0.0, 1.0);

    // Update the zoom scale state to the new state.
    // When the platform has updated the zoom scale,
    // it will send an update through the zoom scale state event stream.
    await MobileScannerPlatform.instance.setZoomScale(clampedZoomScale);
  }

  /// Set the focus point for the camera.
  ///
  /// The [position] must be a point between `0,0` and `1,1`, both inclusive.
  ///
  /// Does nothing if the camera is not running.
  Future<void> setFocusPoint(Offset position) async {
    _throwIfNotInitialized();

    if (!value.isRunning) {
      return;
    }

    final clampedPosition = Offset(
      position.dx.clamp(0, 1),
      position.dy.clamp(0, 1),
    );

    await MobileScannerPlatform.instance.setFocusPoint(clampedPosition);
  }

  /// Start scanning for barcodes.
  ///
  /// The [cameraDirection] can be used to specify the camera direction.
  /// If this is null, this defaults to the [facing] value.
  ///
  /// The [cameraLensType] can be used to specify the camera lens type.
  /// If this is null, this defaults to the [lensType] value.
  ///
  /// Does nothing if the camera is already running.
  /// Upon calling this method, the necessary camera permission will be
  /// requested.
  ///
  /// If the permission is denied on iOS, MacOS or Web, there is no way to
  /// request it again.
  Future<void> start({
    CameraFacing? cameraDirection,
    CameraLensType? cameraLensType,
  }) async {
    if (_isDisposed) {
      throw MobileScannerException(
        errorCode: MobileScannerErrorCode.controllerDisposed,
        errorDetails: MobileScannerErrorDetails(
          message: MobileScannerErrorCode.controllerDisposed.message,
        ),
      );
    }

    // If start was called before the MobileScanner widget
    // had a chance to call its initState method,
    // wait for it to be called, using a timeout.
    if (!_isAttachedCompleter.isCompleted) {
      // The timeout is currently an arbitrary value,
      // which should be long enough for the next frame
      // to propagate any pending changes to the widget tree.
      await _isAttachedCompleter.future
          .timeout(const Duration(milliseconds: 500))
          .catchError((Object error, StackTrace stackTrace) {
            throw MobileScannerException(
              errorCode: MobileScannerErrorCode.controllerNotAttached,
              errorDetails: MobileScannerErrorDetails(
                message: MobileScannerErrorCode.controllerNotAttached.message,
                details: stackTrace.toString(),
              ),
            );
          });

      // Abort if the controller was disposed
      // while waiting for the widget to be attached.
      if (_isDisposed) {
        throw MobileScannerException(
          errorCode: MobileScannerErrorCode.controllerDisposed,
          errorDetails: MobileScannerErrorDetails(
            message: MobileScannerErrorCode.controllerDisposed.message,
          ),
        );
      }
    }

    if (cameraDirection == CameraFacing.unknown) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.genericError,
        errorDetails: MobileScannerErrorDetails(
          message: 'CameraFacing.unknown is not a valid camera direction.',
        ),
      );
    }

    // Do nothing if the camera is already running.
    if (value.isRunning) {
      return;
    }

    if (value.isStarting) {
      throw MobileScannerException(
        errorCode: MobileScannerErrorCode.controllerInitializing,
        errorDetails: MobileScannerErrorDetails(
          message: MobileScannerErrorCode.controllerInitializing.message,
        ),
      );
    }

    if (!_isDisposed) {
      value = value.copyWith(isStarting: true);
    }

    final options = StartOptions(
      cameraDirection: cameraDirection ?? facing,
      cameraLensType: cameraLensType ?? lensType,
      cameraResolution: cameraResolution,
      detectionSpeed: detectionSpeed,
      detectionTimeoutMs: detectionTimeoutMs,
      formats: formats,
      returnImage: returnImage,
      torchEnabled: torchEnabled,
      invertImage: invertImage,
      autoZoom: autoZoom,
      initialZoom: initialZoom,
    );

    try {
      _setupListeners();

      final viewAttributes = await MobileScannerPlatform.instance.start(
        options,
      );

      // This controller now holds the platform camera session.
      _platformSessionOwner = this;

      if (!_isDisposed) {
        value = value.copyWith(
          availableCameras: viewAttributes.numberOfCameras,
          cameraDirection: viewAttributes.cameraDirection,
          cameraLensType: options.cameraLensType,
          isInitialized: true,
          isStarting: false,
          isRunning: true,
          size: viewAttributes.size,
          deviceOrientation: viewAttributes.initialDeviceOrientation,
          // Provide the current torch state.
          // Updates are provided by the `torchStateStream`.
          torchState: viewAttributes.currentTorchMode,
        );
      }
    } on MobileScannerException catch (error) {
      // The initialization finished with an error.
      // To avoid stale values, reset the camera direction,
      // output size, torch state and zoom scale to the defaults.
      if (!_isDisposed) {
        value = value.copyWith(
          cameraDirection: CameraFacing.unknown,
          isInitialized: true,
          isStarting: false,
          isRunning: false,
          error: error,
          size: Size.zero,
          torchState: TorchState.unavailable,
          zoomScale: 1,
        );
      }
    }
  }

  /// Stop the camera.
  ///
  /// After calling this method, the camera can be restarted using [start].
  ///
  /// Does nothing if the camera is already stopped.
  Future<void> stop() async {
    if (_stop()) {
      // Stopping releases the platform camera session,
      // so that another controller can start it.
      // Pausing does not, as a paused session is resumed by its own owner.
      if (identical(_platformSessionOwner, this)) {
        _platformSessionOwner = null;
      }

      await MobileScannerPlatform.instance.stop();
    }
  }

  /// Pause the camera.
  ///
  /// This method stops to update camera frame and scan barcodes.
  /// After calling this method, the camera can be restarted using [start].
  ///
  /// Does nothing if the camera is already paused or stopped.
  Future<void> pause() async {
    if (_stop()) {
      await MobileScannerPlatform.instance.pause();
    }
  }

  /// Switch the camera based on the given [option].
  ///
  /// The [option] parameter determines how the camera is switched:
  /// - [ToggleDirection]: Toggles between front and back cameras (default).
  /// - [ToggleLensType]: Cycles through available lens types on the current
  ///   camera facing direction.
  /// - [SelectCamera]: Selects a specific camera direction and/or lens type.
  ///
  /// For [ToggleDirection], does nothing if the device has less than 2 cameras,
  /// or if the current camera direction is [CameraFacing.unknown]
  /// or [CameraFacing.external].
  ///
  /// For [ToggleLensType], does nothing if the device has less than 2 lens
  /// types available.
  Future<void> switchCamera([
    SwitchCameraOption option = const ToggleDirection(),
  ]) async {
    _throwIfNotInitialized();

    switch (option) {
      case ToggleDirection():
        await _toggleCameraDirection();
      case ToggleLensType():
        await _toggleLensType();
      case SelectCamera(:final facingDirection, :final lensType):
        await _selectCamera(
          facingDirection: facingDirection,
          lensType: lensType,
        );
    }
  }

  Future<void> _toggleCameraDirection() async {
    final availableCameras = value.availableCameras;
    final cameraDirection = value.cameraDirection;

    // Do nothing if the amount of cameras is less than 2 cameras.
    // If the the current platform does not provide the amount of cameras,
    // continue anyway.
    if (availableCameras != null && availableCameras < 2) {
      return;
    }

    // If the camera direction is not known,
    // or if the camera is an external camera, do not allow switching cameras.
    if (cameraDirection == CameraFacing.unknown ||
        cameraDirection == CameraFacing.external) {
      return;
    }

    await stop();

    switch (value.cameraDirection) {
      case CameraFacing.front:
        return start(cameraDirection: CameraFacing.back);
      case CameraFacing.back:
        return start(cameraDirection: CameraFacing.front);
      case CameraFacing.external:
      case CameraFacing.unknown:
        return;
    }
  }

  Future<void> _toggleLensType() async {
    // Fetch supported lenses fresh each time to handle dynamic camera changes
    // (e.g., external cameras being attached/detached).
    // Pass the current facing direction so only lenses for that camera side
    // are returned, avoiding cross-side pollution.
    final supportedLenses = await getSupportedLenses(
      facing: value.cameraDirection,
    );

    // Filter out 'any' and keep only specific lens types.
    final specificLenses =
        supportedLenses.where((lens) => lens != CameraLensType.any).toList();

    // Do nothing if there are less than 2 lens types available.
    if (specificLenses.length < 2) {
      return;
    }

    // Define the lens cycle order.
    const lensCycle = [
      CameraLensType.normal,
      CameraLensType.wide,
      CameraLensType.zoom,
    ];

    // Find the current lens type from state (default to normal if unknown).
    final stateLensType = value.cameraLensType;
    final currentLens =
        stateLensType == CameraLensType.any
            ? CameraLensType.normal
            : stateLensType;

    // Find the next available lens in the cycle.
    final currentIndex = lensCycle.indexOf(currentLens);
    CameraLensType? nextLens;

    for (var i = 1; i <= lensCycle.length; i++) {
      final candidateIndex = (currentIndex + i) % lensCycle.length;
      final candidate = lensCycle[candidateIndex];
      if (specificLenses.contains(candidate)) {
        nextLens = candidate;
        break;
      }
    }

    // If no next lens found (shouldn't happen with 2+ lenses), do nothing.
    if (nextLens == null || nextLens == currentLens) {
      return;
    }

    await stop();
    return start(
      cameraDirection: value.cameraDirection,
      cameraLensType: nextLens,
    );
  }

  Future<void> _selectCamera({
    CameraFacing? facingDirection,
    CameraLensType lensType = CameraLensType.any,
  }) async {
    // Use current direction if not specified.
    final targetDirection = facingDirection ?? value.cameraDirection;

    // If the target direction is unknown or external, do nothing.
    if (targetDirection == CameraFacing.unknown ||
        targetDirection == CameraFacing.external) {
      return;
    }

    // Skip if the configuration is already the same to avoid unnecessary
    // camera restarts and UI flicker.
    if (targetDirection == value.cameraDirection &&
        lensType == value.cameraLensType) {
      return;
    }

    await stop();
    return start(cameraDirection: targetDirection, cameraLensType: lensType);
  }

  /// Switches the flashlight on or off.
  ///
  /// Does nothing if the device has no torch,
  /// or if the camera is not running.
  ///
  /// If the current torch state is [TorchState.auto],
  /// the torch is turned on or off depending on its actual current state.
  Future<void> toggleTorch() async {
    _throwIfNotInitialized();

    if (!value.isRunning) {
      return;
    }

    final torchState = value.torchState;

    if (torchState == TorchState.unavailable) {
      return;
    }

    // Request the torch state to be switched to the opposite state.
    // When the platform has updated the torch state,
    // it will send an update through the torch state event stream.
    await MobileScannerPlatform.instance.toggleTorch();
  }

  /// Update the scan window with the given [window] rectangle.
  ///
  /// If [window] is null, the scan window will be reset to the full camera
  /// preview.
  Future<void> updateScanWindow(Rect? window) async {
    if (_isDisposed || !value.isInitialized) {
      return;
    }

    await MobileScannerPlatform.instance.updateScanWindow(window);
  }

  /// Get the set of supported camera lens types for the current device.
  ///
  /// Returns a set of [CameraLensType] values that are available on the
  /// device. This can be used to determine which lens types can be used
  /// with the scanner.
  ///
  /// Returns an empty set if the device has no cameras. On platforms
  /// that do not support querying specific lens types, returns a set
  /// containing only [CameraLensType.any] if cameras are available.
  ///
  /// This method can be called before starting the scanner.
  ///
  /// Throws a [MobileScannerException] if the controller has been disposed.
  ///
  /// Example:
  /// ```dart
  /// final supportedLenses = await controller.getSupportedLenses();
  /// if (supportedLenses.isEmpty) {
  ///   print('No camera lenses available');
  /// } else {
  ///   print('Available lenses: $supportedLenses');
  /// }
  /// ```
  Future<Set<CameraLensType>> getSupportedLenses({
    CameraFacing? facing,
  }) async {
    if (_isDisposed) {
      throw MobileScannerException(
        errorCode: MobileScannerErrorCode.controllerDisposed,
        errorDetails: MobileScannerErrorDetails(
          message: MobileScannerErrorCode.controllerDisposed.message,
        ),
      );
    }

    return MobileScannerPlatform.instance.getSupportedLenses(facing: facing);
  }

  /// Determine the lens type best suited for close-range scanning.
  ///
  /// Returns the [CameraLensType] whose camera can focus closest to the
  /// phone, making it best suited for scanning barcodes held at close range.
  ///
  /// Returns `null` if the device has no camera for the given [facing]
  /// direction.
  ///
  /// This does not switch the camera. Combine it with [getSupportedLenses]
  /// and [switchCamera] to only switch to the returned lens if it is
  /// actually available on the device:
  ///
  /// ```dart
  /// final bestLens = await controller.getBestCloseRangeScanningLens();
  /// final supported = await controller.getSupportedLenses(
  ///   facing: CameraFacing.back,
  /// );
  ///
  /// if (bestLens != null && supported.contains(bestLens)) {
  ///   await controller.switchCamera(
  ///     SelectCamera(facingDirection: CameraFacing.back, lensType: bestLens),
  ///   );
  /// }
  /// ```
  ///
  /// Throws a [MobileScannerException] if the controller has been disposed.
  Future<CameraLensType?> getBestCloseRangeScanningLens({
    CameraFacing facing = CameraFacing.back,
  }) async {
    if (_isDisposed) {
      throw MobileScannerException(
        errorCode: MobileScannerErrorCode.controllerDisposed,
        errorDetails: MobileScannerErrorDetails(
          message: MobileScannerErrorCode.controllerDisposed.message,
        ),
      );
    }

    return MobileScannerPlatform.instance.getBestCloseRangeScanningLens(
      facing: facing,
    );
  }

  /// Dispose the controller.
  ///
  /// Once the controller is disposed, it cannot be used anymore.
  @override
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    _disposeListeners();
    unawaited(_barcodesController.close());
    super.dispose();

    // If another controller currently holds the platform camera session,
    // disposing the platform resources would break that controller.
    // In that case only this controller's own resources are cleaned up.
    if (_platformSessionOwner != null &&
        !identical(_platformSessionOwner, this)) {
      return;
    }

    _platformSessionOwner = null;

    await MobileScannerPlatform.instance.dispose();
  }

  /// Signal to this [MobileScannerController] that it is attached
  /// to a [MobileScanner] widget.
  ///
  /// This method is called by `_MobileScannerState.initState()`
  /// and is not intended to be used directly.
  @internal
  void attach() {
    if (_isAttachedCompleter.isCompleted) {
      return;
    }

    _isAttachedCompleter.complete();
  }
}
