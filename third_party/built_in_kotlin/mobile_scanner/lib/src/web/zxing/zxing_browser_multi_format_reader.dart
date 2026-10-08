/// @docImport 'package:mobile_scanner/src/web/zxing/result.dart';
library;

import 'dart:js_interop';

import 'package:mobile_scanner/src/web/javascript_map.dart';
import 'package:web/web.dart';

/// The JS interop class for the ZXing BrowserMultiFormatReader.
///
/// See https://github.com/zxing-js/library/blob/master/src/browser/BrowserMultiFormatReader.ts
@JS('ZXing.BrowserMultiFormatReader')
extension type ZXingBrowserMultiFormatReader._(JSObject _) implements JSObject {
  /// Construct a new `ZXing.BrowserMultiFormatReader`.
  ///
  /// The [hints] are the configuration options for the reader.
  /// The [timeBetweenScansMillis] is the allowed time between scans in
  /// milliseconds.
  ///
  /// See also: https://github.com/zxing-js/library/blob/master/src/core/DecodeHintType.ts
  external factory ZXingBrowserMultiFormatReader(
    JSMap? hints,
    int timeBetweenScansMillis,
  );

  /// Attach a [MediaStream] to a [HTMLVideoElement].
  ///
  /// This function accepts a [MediaStream] and a [HTMLVideoElement] as
  /// arguments,and returns a [JSPromise].
  ///
  /// See https://github.com/zxing-js/library/blob/master/src/browser/BrowserCodeReader.ts#L406
  external JSFunction attachStreamToVideo;

  /// Continuously decode barcodes from a [HTMLVideoElement].
  ///
  /// When a barcode is found, a callback function is called with the result.
  /// The callback function receives a [Result] and an exception object as
  /// arguments.
  ///
  /// See also: https://github.com/zxing-js/library/blob/master/src/browser/DecodeContinuouslyCallback.ts
  external JSFunction decodeContinuously;

  /// Whether the video stream is currently playing.
  ///
  /// This function takes a [HTMLVideoElement] as argument,
  /// and returns a [bool].
  ///
  /// See https://github.com/zxing-js/library/blob/master/src/browser/BrowserCodeReader.ts#L458
  external JSFunction isVideoPlaying;

  /// Reset the barcode reader to it's initial state,
  /// and stop any ongoing barcode decoding.
  ///
  /// This function takes no arguments and returns no result.
  ///
  /// See https://github.com/zxing-js/library/blob/master/src/browser/BrowserCodeReader.ts#L1104
  external JSFunction reset;

  /// Stop decoding barcodes.
  ///
  /// This function takes no arguments and returns no result.
  ///
  /// See https://github.com/zxing-js/library/blob/master/src/browser/BrowserCodeReader.ts#L396
  external JSFunction stopContinuousDecode;

  /// Get the current MediaStream of the barcode reader.
  external MediaStream? get stream;

  /// Get the current HTMLVideoElement of the barcode reader.
  external HTMLVideoElement? get videoElement;
}
