import 'dart:js_interop';

/// The JS static interop class for the Result class in the ZXing library.
///
/// See also: https://github.com/zxing-js/library/blob/master/src/core/ResultPoint.ts
@JS()
extension type ResultPoint(JSObject _) implements JSObject {
  /// The x coordinate of the point.
  external double get x;

  /// The y coordinate of the point.
  external double get y;
}
