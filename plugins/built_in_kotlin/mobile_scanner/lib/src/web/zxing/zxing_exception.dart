import 'dart:js_interop';

/// The JS static interop class for the Result class in the ZXing library.
///
/// See also: https://github.com/zxing-js/library/blob/master/src/core/Exception.ts
@JS('ZXing.Exception')
extension type ZXingException._(JSObject _) implements JSObject {
  /// The error message of the exception, if any.
  external String? get message;
}
