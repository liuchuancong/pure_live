import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:mobile_scanner/src/enums/barcode_format.dart';
import 'package:mobile_scanner/src/enums/camera_facing.dart';
import 'package:mobile_scanner/src/enums/camera_lens_type.dart';
import 'package:mobile_scanner/src/enums/mobile_scanner_error_code.dart';
import 'package:mobile_scanner/src/enums/torch_state.dart';
import 'package:mobile_scanner/src/enums/web_barcode_reader.dart';
import 'package:mobile_scanner/src/mobile_scanner_exception.dart';
import 'package:mobile_scanner/src/mobile_scanner_platform_interface.dart';
import 'package:mobile_scanner/src/mobile_scanner_view_attributes.dart';
import 'package:mobile_scanner/src/objects/barcode_capture.dart';
import 'package:mobile_scanner/src/objects/start_options.dart';
import 'package:mobile_scanner/src/web/barcode_detector/barcode_detector_reader.dart';
import 'package:mobile_scanner/src/web/barcode_reader.dart';
import 'package:mobile_scanner/src/web/media_track_constraints_delegate.dart';
import 'package:mobile_scanner/src/web/media_track_extension.dart';
import 'package:mobile_scanner/src/web/preferred_device_storage.dart';
import 'package:mobile_scanner/src/web/web_camera_utility.dart';
import 'package:mobile_scanner/src/web/zxing/zxing_barcode_reader.dart';
import 'package:mobile_scanner/src/web/zxing_wasm/zxing_wasm_barcode_reader.dart';
import 'package:web/web.dart';

/// A web implementation of the MobileScannerPlatform of the MobileScanner
/// plugin.
class MobileScannerWeb extends MobileScannerPlatform {
  /// Constructs a [MobileScannerWeb] instance.
  MobileScannerWeb();

  static const String _kModeContinuous = 'continuous';
  static const String _kModeSingleShot = 'single-shot';

  /// The alternate script url for the barcode library.
  String? _alternateScriptUrl;

  /// The preferred web barcode reader backend.
  WebBarcodeReader _preferredWebReader = WebBarcodeReader.auto;

  /// The barcode reader that is currently active.
  WebBarcodeReader? _activeWebReader;

  /// The internal barcode reader.
  BarcodeReader? _barcodeReader;

  /// The stream controller for the barcode stream.
  final StreamController<BarcodeCapture> _barcodesController =
      StreamController.broadcast();

  /// The subscription for the barcode stream.
  StreamSubscription<Object?>? _barcodesSubscription;

  /// The container div element for the camera view.
  late HTMLDivElement _divElement;

  /// The stream controller for the media track settings stream.
  ///
  /// Currently, only the facing mode setting can be supported,
  /// because that is the only property for video tracks that can be observed.
  ///
  /// See https://developer.mozilla.org/en-US/docs/Web/API/MediaTrackConstraints#instance_properties_of_video_tracks
  final StreamController<MediaTrackSettings> _settingsController =
      StreamController.broadcast();

  /// The delegate that retrieves the media track settings.
  final MediaTrackConstraintsDelegate _settingsDelegate =
      const MediaTrackConstraintsDelegate();

  /// The texture ID for the camera view.
  int _textureId = 1;

  /// The current scan window in widget coordinates, or null if not set.
  Rect? _scanWindow;

  /// The video element for the camera view.
  late HTMLVideoElement _videoElement;

  /// Storage for the preferred camera device ID across sessions.
  static const PreferredDeviceStorage _preferredDeviceStorage =
      PreferredDeviceStorage();

  /// Get the view type for the platform view factory.
  String _getViewType(int textureId) => 'mobile-scanner-view-$textureId';

  /// Registers this class as the default instance of [MobileScannerPlatform].
  static void registerWith(Registrar registrar) {
    MobileScannerPlatform.instance = MobileScannerWeb();
  }

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodesController.stream;

  @override
  Stream<TorchState> get torchStateStream =>
      _settingsController.stream.map((_) => TorchState.unavailable);

  @override
  Stream<double> get zoomScaleStateStream =>
      _settingsController.stream.map((_) => 1.0);

  /// Create the [HTMLVideoElement] along with its parent container
  /// [HTMLDivElement].
  HTMLVideoElement _createVideoElement(int textureId) {
    final videoElement = HTMLVideoElement();

    videoElement.style
      ..height = '100%'
      ..width = '100%'
      ..objectFit = 'cover'
      ..transformOrigin = 'center'
      ..pointerEvents = 'none';

    // Do not show the media controls, as this is a preview element.
    // Also prevent play/pause events from changing the media controls.
    videoElement
      ..controls = false
      ..onplay =
          (JSAny _) {
            videoElement.controls = false;
          }.toJS
      ..onpause =
          (JSAny _) {
            videoElement.controls = false;
          }.toJS;

    // Attach the video element to its parent container
    // and setup the PlatformView factory for this `textureId`.
    _divElement =
        HTMLDivElement()
          ..style.objectFit = 'cover'
          ..style.height = '100%'
          ..style.width = '100%'
          ..append(videoElement);

    ui_web.platformViewRegistry.registerViewFactory(
      _getViewType(textureId),
      (_) => _divElement,
    );

    return videoElement;
  }

  void _handleMediaTrackSettingsChange(MediaTrackSettings settings) {
    if (_settingsController.isClosed) {
      return;
    }

    _settingsController.add(settings);
  }

  /// Apply focus, exposure, and white-balance constraints to [track] if the
  /// browser supports them (part of the Image Capture API).
  ///
  /// Silently ignores any errors. These constraints are best-effort.
  Future<void> _applyVideoConstraints(MediaStreamTrack track) async {
    try {
      final caps = track.getCapabilities();
      var hasConstraints = false;

      final constraints = MediaTrackConstraints();

      final focusModes = caps.focusMode.toDart.map((e) => e.toDart).toSet();
      if (focusModes.contains(_kModeContinuous)) {
        constraints.focusMode = _kModeContinuous.toJS;
        hasConstraints = true;
      } else if (focusModes.contains(_kModeSingleShot)) {
        constraints.focusMode = _kModeSingleShot.toJS;
        hasConstraints = true;
      }

      final exposureModes =
          caps.exposureMode.toDart.map((e) => e.toDart).toSet();
      if (exposureModes.contains(_kModeContinuous)) {
        constraints.exposureMode = _kModeContinuous.toJS;
        hasConstraints = true;
      }

      final wbModes = caps.whiteBalanceMode.toDart.map((e) => e.toDart).toSet();
      if (wbModes.contains(_kModeContinuous)) {
        constraints.whiteBalanceMode = _kModeContinuous.toJS;
        hasConstraints = true;
      }

      if (!hasConstraints) return;

      await track.applyConstraints(constraints).toDart;
    } on Object catch (_) {
      // Not supported on this browser or device.
    }
  }

  /// Validate that [deviceId] refers to a currently available video input.
  Future<bool> _isValidDeviceId(String deviceId) async {
    try {
      final devices =
          (await window.navigator.mediaDevices.enumerateDevices().toDart)
              .toDart;
      return devices.any(
        (d) => d.kind == 'videoinput' && d.deviceId == deviceId,
      );
    } on Object catch (_) {
      return false;
    }
  }

  /// Prepare a [MediaStream] for the video output.
  ///
  /// This method requests permission to use the camera.
  ///
  /// Throws a [MobileScannerException] if the permission was denied,
  /// or if using a video stream, with the given set of constraints, is
  /// unsupported.
  Future<MediaStream> _prepareVideoStream(
    CameraFacing cameraDirection, {
    Size? cameraResolution,
  }) async {
    final mediaDevices = window.navigator.mediaDevicesNullable;

    if (mediaDevices == null) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.unsupported,
        errorDetails: MobileScannerErrorDetails(
          message:
              'This browser does not support displaying video from the camera.',
        ),
      );
    }

    final capabilities = mediaDevices.getSupportedConstraints();

    final width = ConstrainULongRange(
      ideal: cameraResolution?.width.toInt() ?? 1920,
    );
    final height = ConstrainULongRange(
      ideal: cameraResolution?.height.toInt() ?? 1080,
    );

    var useStoredDevice = false;
    final MediaStreamConstraints constraints;

    if (capabilities.isUndefinedOrNull || !capabilities.facingMode) {
      // facingMode is not supported (desktop). Try to reuse the previously
      // chosen device to keep the same camera across restarts.
      final storedDeviceId = _preferredDeviceStorage.read();
      useStoredDevice =
          storedDeviceId != null && await _isValidDeviceId(storedDeviceId);

      constraints =
          useStoredDevice
              ? MediaStreamConstraints(
                video: MediaTrackConstraintSet(
                  deviceId: storedDeviceId.toJS,
                  width: width,
                  height: height,
                ),
              )
              : MediaStreamConstraints(
                video: MediaTrackConstraintSet(width: width, height: height),
              );
    } else {
      // facingMode is supported (mobile). Always use it so that switching
      // between front and back cameras works correctly.
      final facingMode = _settingsDelegate.getFacingMode(cameraDirection);

      constraints = MediaStreamConstraints(
        video: MediaTrackConstraintSet(
          facingMode: facingMode.toJS,
          width: width,
          height: height,
        ),
      );
    }

    try {
      // Retrieving the media devices requests the camera permission.
      final videoStream = await mediaDevices.getUserMedia(constraints).toDart;

      // Apply focus, exposure and white-balance constraints if supported.
      final videoTrack = videoStream.getVideoTracks().toDart.firstOrNull;
      if (videoTrack != null) {
        await _applyVideoConstraints(videoTrack);

        // Persist the device ID so the same camera is preferred next time.
        final deviceId = videoTrack.getSettings().deviceIdNullable?.toDart;
        if (deviceId != null) {
          _preferredDeviceStorage.write(deviceId);
        }
      }

      return videoStream;
    } on Object catch (error, stackTrace) {
      // If the stored device ID failed, clear it so we don't retry it.
      if (useStoredDevice) {
        _preferredDeviceStorage.remove();
      }
      final errorMessage = error.toString();

      var errorCode = MobileScannerErrorCode.genericError;

      // Handle both unsupported and permission errors from the web.
      if (errorMessage.contains('NotFoundError') ||
          errorMessage.contains('NotSupportedError')) {
        errorCode = MobileScannerErrorCode.unsupported;
      } else if (errorMessage.contains('NotAllowedError')) {
        errorCode = MobileScannerErrorCode.permissionDenied;
      }

      throw MobileScannerException(
        errorCode: errorCode,
        errorDetails: MobileScannerErrorDetails(
          message: errorMessage,
          details: stackTrace.toString(),
        ),
      );
    }
  }

  @override
  Future<BarcodeCapture?> analyzeImage(
    String path, {
    List<BarcodeFormat> formats = const <BarcodeFormat>[],
  }) {
    throw UnsupportedError('analyzeImage() is not supported on the web.');
  }

  @override
  Widget buildCameraView() {
    if (_barcodeReader?.isScanning ?? false) {
      return HtmlElementView(viewType: _getViewType(_textureId));
    }

    return const SizedBox();
  }

  @override
  Future<Set<CameraLensType>> getSupportedLenses({
    CameraFacing? facing,
  }) async {
    final mediaDevices = window.navigator.mediaDevicesNullable;

    if (mediaDevices == null) {
      return <CameraLensType>{};
    }

    try {
      final jsDevices = await mediaDevices.enumerateDevices().toDart;
      final devices = jsDevices.toDart;

      final hasVideoInput = devices.any(
        (device) => device.kind == 'videoinput',
      );

      if (!hasVideoInput) {
        return <CameraLensType>{};
      }

      return <CameraLensType>{CameraLensType.any};
    } on Object catch (_) {
      return <CameraLensType>{};
    }
  }

  @override
  Future<CameraLensType?> getBestCloseRangeScanningLens({
    CameraFacing facing = CameraFacing.back,
  }) async {
    final mediaDevices = window.navigator.mediaDevicesNullable;

    if (mediaDevices == null) {
      return null;
    }

    try {
      final jsDevices = await mediaDevices.enumerateDevices().toDart;
      final devices = jsDevices.toDart;

      final hasVideoInput = devices.any(
        (device) => device.kind == 'videoinput',
      );

      if (!hasVideoInput) {
        return null;
      }

      // The web MediaDevices API has no concept of lens type, and its
      // `focusDistance` capability (where available at all) is limited to
      // Chrome on Android, so there is no reliable cross-browser way to pick
      // a closer-focusing camera here.
      return CameraLensType.normal;
    } on Object catch (_) {
      return null;
    }
  }

  @override
  Future<void> resetZoomScale() {
    throw UnsupportedError(
      'Setting the zoom scale is not supported for video tracks on the web.\n'
      'See https://developer.mozilla.org/en-US/docs/Web/API/MediaTrackConstraints#instance_properties_of_video_tracks',
    );
  }

  @override
  void setBarcodeLibraryScriptUrl(String scriptUrl) {
    _alternateScriptUrl ??= scriptUrl;
  }

  @override
  void setWebBarcodeReader(WebBarcodeReader reader) {
    _preferredWebReader = reader;
  }

  @override
  WebBarcodeReader? get activeWebReader => _activeWebReader;

  @override
  Future<void> setZoomScale(double zoomScale) {
    throw UnsupportedError(
      'Setting the zoom scale is not supported for video tracks on the web.\n'
      'See https://developer.mozilla.org/en-US/docs/Web/API/MediaTrackConstraints#instance_properties_of_video_tracks',
    );
  }

  @override
  Future<void> setFocusPoint(Offset position) {
    throw UnimplementedError('setFocusPoint() has not been implemented.');
  }

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    if (_barcodeReader != null) {
      if (_barcodeReader!.paused ?? false) {
        await _barcodeReader?.resume();

        final cameraDirection = _settingsDelegate.getCameraDirection(
          _barcodeReader?.videoStream,
        );

        return MobileScannerViewAttributes(
          cameraDirection: cameraDirection,
          // The torch of a media stream is not available for video tracks.
          // See https://developer.mozilla.org/en-US/docs/Web/API/MediaTrackConstraints#instance_properties_of_video_tracks
          currentTorchMode: TorchState.unavailable,
          size: _barcodeReader?.videoSize ?? Size.zero,
        );
      }

      throw MobileScannerException(
        errorCode: MobileScannerErrorCode.controllerAlreadyInitialized,
        errorDetails: MobileScannerErrorDetails(
          message: MobileScannerErrorCode.controllerAlreadyInitialized.message,
        ),
      );
    }

    // If the previous state is a pause, reset scanner.
    if (_barcodesSubscription != null && _barcodesSubscription!.isPaused) {
      await stop();
    }

    // Select the barcode reader based on the preferred backend.
    switch (_preferredWebReader) {
      case WebBarcodeReader.barcodeDetector:
        _barcodeReader = BarcodeDetectorReader();
        _activeWebReader = _preferredWebReader;
      case WebBarcodeReader.zxingWasm:
        _barcodeReader = ZXingWasmBarcodeReader();
        _activeWebReader = _preferredWebReader;
      case WebBarcodeReader.zxingJs:
        _barcodeReader = ZXingBarcodeReader();
        _activeWebReader = _preferredWebReader;
      case WebBarcodeReader.auto:
        // Use the native BarcodeDetector API when available (Chrome/Edge/Safari
        // 17+), fall back to zxing-wasm for Firefox and older browsers.
        if (await BarcodeDetectorReader.isSupported()) {
          _barcodeReader = BarcodeDetectorReader();
          _activeWebReader = WebBarcodeReader.barcodeDetector;
        } else {
          _barcodeReader = ZXingWasmBarcodeReader();
          _activeWebReader = WebBarcodeReader.zxingWasm;
        }
    }

    await _barcodeReader?.maybeLoadLibrary(
      alternateScriptUrl: _alternateScriptUrl,
    );

    // Request camera permissions and prepare the video stream.
    final videoStream = await _prepareVideoStream(
      startOptions.cameraDirection,
      cameraResolution: startOptions.cameraResolution,
    );

    try {
      // Clear the existing barcodes.
      if (!_barcodesController.isClosed) {
        _barcodesController.add(const BarcodeCapture());
      }

      // Listen for changes to the media track settings.
      _barcodeReader?.setMediaTrackSettingsListener(
        _handleMediaTrackSettingsChange,
      );

      _textureId += 1; // Request a new texture.

      _videoElement = _createVideoElement(_textureId);

      maybeFlipVideoPreview(_videoElement, videoStream);

      await _barcodeReader?.start(
        startOptions,
        videoElement: _videoElement,
        videoStream: videoStream,
      );

      // Re-apply the scan window if one was set before start() was called.
      if (_scanWindow != null) {
        _barcodeReader?.updateScanWindow(_scanWindow);
      }
    } catch (error, stackTrace) {
      throw MobileScannerException(
        errorCode: MobileScannerErrorCode.genericError,
        errorDetails: MobileScannerErrorDetails(
          message: error.toString(),
          details: stackTrace.toString(),
        ),
      );
    }

    try {
      _barcodesSubscription = _barcodeReader?.detectBarcodes().listen(
        (barcode) {
          if (_barcodesController.isClosed) {
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

      final hasTorch = await _barcodeReader?.hasTorch() ?? false;

      if (hasTorch && startOptions.torchEnabled) {
        await _barcodeReader?.setTorchState(TorchState.on);
      }

      final cameraDirection = _settingsDelegate.getCameraDirection(videoStream);

      return MobileScannerViewAttributes(
        cameraDirection: cameraDirection,
        // The torch of a media stream is not available for video tracks.
        // See https://developer.mozilla.org/en-US/docs/Web/API/MediaTrackConstraints#instance_properties_of_video_tracks
        currentTorchMode: TorchState.unavailable,
        size: _barcodeReader?.videoSize ?? Size.zero,
      );
    } catch (error, stackTrace) {
      throw MobileScannerException(
        errorCode: MobileScannerErrorCode.genericError,
        errorDetails: MobileScannerErrorDetails(
          message: error.toString(),
          details: stackTrace.toString(),
        ),
      );
    }
  }

  @override
  Future<void> pause() async {
    _barcodesSubscription?.pause();
    _barcodeReader?.pause();
  }

  @override
  Future<void> stop() async {
    // Ensure the barcode scanner is stopped, by cancelling the subscription.
    await _barcodesSubscription?.cancel();
    _barcodesSubscription = null;

    await _barcodeReader?.stop();
    _barcodeReader = null;
    _activeWebReader = null;
  }

  @override
  Future<void> toggleTorch() {
    throw UnsupportedError(
      'Setting the torch state is not supported for video tracks on the web.\n'
      'See https://developer.mozilla.org/en-US/docs/Web/API/MediaTrackConstraints#instance_properties_of_video_tracks',
    );
  }

  @override
  Future<void> updateScanWindow(Rect? window) {
    _scanWindow = window;
    _barcodeReader?.updateScanWindow(window);

    return Future<void>.value();
  }

  @override
  Future<void> dispose() async {
    // The `_barcodesController` and `_settingsController`
    // are not closed, as these have the same lifetime as the plugin.
    await stop();
  }
}
