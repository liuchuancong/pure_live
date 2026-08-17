import 'dart:async';
import 'dart:js_interop';
import 'dart:ui';

import 'package:meta/meta.dart';
import 'package:mobile_scanner/src/objects/barcode.dart';
import 'package:mobile_scanner/src/objects/barcode_capture.dart';
import 'package:mobile_scanner/src/objects/start_options.dart';
import 'package:mobile_scanner/src/web/barcode_reader.dart';
import 'package:mobile_scanner/src/web/media_track_constraints_delegate.dart';
import 'package:mobile_scanner/src/web/web_camera_utility.dart';
import 'package:web/web.dart' as web;

/// Base class for barcode readers that decode frames from a video element on
/// a periodic timer.
///
/// Subclasses only implement the decoding of a single frame, through
/// [prepareDecoder], [decodeFrame] and [disposeDecoder]. The video lifecycle,
/// the decode loop, the scan window filter and the mirror correction are
/// handled by this class.
abstract base class PollingBarcodeReader extends BarcodeReader {
  /// Construct a new [PollingBarcodeReader] instance.
  PollingBarcodeReader();

  web.HTMLVideoElement? _videoElement;
  web.MediaStream? _videoStream;

  /// The scan window as a normalized [Rect] (values in [0, 1]) relative to
  /// the camera texture. Barcodes whose bounding box is not contained within
  /// this rect are filtered out.
  Rect? _scanWindow;

  int _timeBetweenScansMs = 1000;

  /// The listener for media track settings changes.
  void Function(web.MediaTrackSettings)? _onMediaTrackSettingsChanged;

  /// The internal media stream track constraints delegate.
  final MediaTrackConstraintsDelegate _mediaTrackConstraintsDelegate =
      const MediaTrackConstraintsDelegate();

  Timer? _decodeTimer;

  /// Guard against overlapping decode calls when a frame takes longer to
  /// process than the configured interval.
  bool _isDecoding = false;

  @override
  bool get isScanning => _videoStream != null;

  @override
  Size get videoSize {
    final video = _videoElement;

    if (video == null) {
      return Size.zero;
    }

    return Size(video.videoWidth.toDouble(), video.videoHeight.toDouble());
  }

  @override
  web.MediaStream? get videoStream => _videoStream;

  @override
  bool? get paused => _videoElement?.paused;

  @override
  void pause() => _videoElement?.pause();

  @override
  Future<void> resume() async {
    await _videoElement?.play().toDart;
  }

  @override
  void updateScanWindow(Rect? window) => _scanWindow = window;

  @override
  void setMediaTrackSettingsListener(
    void Function(web.MediaTrackSettings) listener,
  ) {
    _onMediaTrackSettingsChanged ??= listener;
  }

  /// Prepare the decoder for the given [options].
  ///
  /// Called by [start], before the video stream is attached to the video
  /// element.
  @protected
  Future<void> prepareDecoder(StartOptions options);

  /// Decode the barcodes that are currently visible in [video].
  ///
  /// Called on each tick of the decode loop. The returned barcodes are in
  /// raw (pre-mirror) camera coordinates; the scan window filter and the
  /// mirror correction are applied by the caller.
  @protected
  Future<List<Barcode>> decodeFrame(web.HTMLVideoElement video);

  /// Release any decoder resources held by the subclass.
  ///
  /// Called by [stop].
  @protected
  void disposeDecoder();

  @override
  Future<void> start(
    StartOptions options, {
    required web.HTMLVideoElement videoElement,
    required web.MediaStream videoStream,
  }) async {
    _videoElement = videoElement;
    _videoStream = videoStream;
    _timeBetweenScansMs = options.detectionTimeoutMs;

    await prepareDecoder(options);

    // Attach the stream to the video element and start playback.
    videoElement.srcObject = videoStream;
    await videoElement.play().toDart;

    final settings = _mediaTrackConstraintsDelegate.getSettings(videoStream);

    if (settings != null) {
      _onMediaTrackSettingsChanged?.call(settings);
    }
  }

  @override
  Stream<BarcodeCapture> detectBarcodes() {
    final controller = StreamController<BarcodeCapture>();

    controller
      ..onListen = () {
        _startDecodeLoop(controller);
      }
      // The onCancel() method of the controller is called when the stream
      // subscription returned by this method is cancelled in
      // `MobileScannerWeb.stop()`. This avoids both leaving the barcode
      // scanner running and a memory leak for the stream subscription.
      ..onCancel = () async {
        _stopDecodeLoop();
        await controller.close();
      };

    return controller.stream;
  }

  @override
  Future<void> stop() async {
    _stopDecodeLoop();
    _isDecoding = false;
    _onMediaTrackSettingsChanged = null;
    _scanWindow = null;
    _videoElement = null;
    _videoStream = null;
    disposeDecoder();
  }

  void _startDecodeLoop(StreamController<BarcodeCapture> controller) {
    _decodeTimer?.cancel();

    // For unrestricted / zero-timeout mode, clamp to ~60 fps so we don't spin
    // the timer as fast as the event loop allows.
    final interval = Duration(
      milliseconds: _timeBetweenScansMs > 0 ? _timeBetweenScansMs : 16,
    );

    _decodeTimer = Timer.periodic(interval, (_) async {
      if (_isDecoding) return;
      _isDecoding = true;
      try {
        await _decodeAndEmit(controller);
      } on Object catch (_) {
        // Swallow per-frame errors so the loop keeps running.
      } finally {
        _isDecoding = false;
      }
    });
  }

  void _stopDecodeLoop() {
    _decodeTimer?.cancel();
    _decodeTimer = null;
  }

  Future<void> _decodeAndEmit(
    StreamController<BarcodeCapture> controller,
  ) async {
    final video = _videoElement;

    if (video == null || controller.isClosed || video.paused) return;
    if (video.videoWidth == 0 || video.videoHeight == 0) return;

    final results = await decodeFrame(video);

    if (results.isEmpty || controller.isClosed) return;

    final barcodes = <Barcode>[];

    for (var barcode in results) {
      // Check the scan window using raw camera coordinates (before
      // mirroring), because the scan window percentages are also in raw
      // camera space.
      if (!isInsideScanWindow(barcode, _scanWindow, videoSize)) {
        continue;
      }

      // Mirror corners for display after the scan window check.
      if (shouldMirrorStream(_videoStream)) {
        barcode = mirrorBarcodeX(barcode, videoSize.width);
      }

      barcodes.add(barcode);
    }

    if (barcodes.isEmpty || controller.isClosed) return;

    controller.add(BarcodeCapture(barcodes: barcodes, size: videoSize));
  }
}
