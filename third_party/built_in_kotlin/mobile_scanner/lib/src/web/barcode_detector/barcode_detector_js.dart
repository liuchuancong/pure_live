import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Checks whether the native BarcodeDetector API is available in this browser.
///
/// Returns `true` when `BarcodeDetector` is defined on `globalThis` **and**
/// `BarcodeDetector.getSupportedFormats()` resolves to a non-empty list.
Future<bool> isBarcodeDetectorSupported() async {
  try {
    final formats = await NativeBarcodeDetector.getSupportedFormats().toDart;
    return formats.toDart.isNotEmpty;
  } on Object {
    return false;
  }
}

/// The JS `BarcodeDetector` class from the Shape Detection API.
///
/// See https://developer.mozilla.org/en-US/docs/Web/API/BarcodeDetector
@JS('BarcodeDetector')
extension type NativeBarcodeDetector._(JSObject _) implements JSObject {
  /// Constructs a detector that recognises all supported formats.
  external factory NativeBarcodeDetector();

  /// Constructs a detector restricted to the given [options].
  @JS('BarcodeDetector')
  external factory NativeBarcodeDetector.withOptions(
    BarcodeDetectorInit options,
  );

  /// Returns the list of barcode formats supported by the current browser.
  external static JSPromise<JSArray<JSString>> getSupportedFormats();

  /// Detects barcodes in [videoElement].
  ///
  /// Returns a [JSPromise] that resolves to a list of [DetectedBarcode]s.
  /// Corner points are in the intrinsic coordinate space of the video
  /// frame (i.e. `[0, videoWidth] × [0, videoHeight]`).
  external JSPromise<JSArray<DetectedBarcode>> detect(
    web.HTMLVideoElement videoElement,
  );
}

/// Options object for [NativeBarcodeDetector.withOptions].
@JS()
extension type BarcodeDetectorInit._(JSObject _) implements JSObject {
  /// Creates an init object restricting detection to the given [formats].
  external factory BarcodeDetectorInit({required JSArray<JSString> formats});
}

/// A single barcode result from [NativeBarcodeDetector.detect].
@JS()
extension type DetectedBarcode(JSObject _) implements JSObject {
  /// Decoded text content of the barcode.
  external String get rawValue;

  /// Barcode format string, e.g. `'qr_code'`, `'ean_13'`.
  external String get format;

  /// The four corner points of the barcode in video pixel coordinates.
  external JSArray<BarcodePoint> get cornerPoints;
}

/// A 2-D point returned as a corner position by [DetectedBarcode].
@JS()
extension type BarcodePoint(JSObject _) implements JSObject {
  /// Horizontal coordinate in video pixel space.
  external double get x;

  /// Vertical coordinate in video pixel space.
  external double get y;
}
