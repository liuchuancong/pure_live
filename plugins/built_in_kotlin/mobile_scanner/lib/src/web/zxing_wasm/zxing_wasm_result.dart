import 'dart:js_interop';
import 'dart:ui';

import 'package:mobile_scanner/src/enums/barcode_type.dart';
import 'package:mobile_scanner/src/objects/barcode.dart';
import 'package:mobile_scanner/src/objects/barcode_bytes.dart';
import 'package:mobile_scanner/src/web/web_barcode_utils.dart';
import 'package:mobile_scanner/src/web/zxing_wasm/zxing_wasm_formats.dart';
import 'package:web/web.dart' as web;

/// JS interop for the `window.ZXingWASM` global set by the zxing-wasm IIFE
/// build.
///
/// See https://github.com/Sec-ant/zxing-wasm
@JS('ZXingWASM')
external ZXingWasmModule get zxingWasmModule;

/// The `ZXingWASM` global object exposed by the IIFE reader build.
@JS()
extension type ZXingWasmModule(JSObject _) implements JSObject {
  /// Detect barcodes in [imageData] captured from a canvas.
  ///
  /// Returns a [JSPromise] that resolves to a list of [ZXingWasmReadResult]s.
  external JSPromise<JSArray<ZXingWasmReadResult>> readBarcodes(
    web.ImageData imageData,
    ZXingWasmReaderOptions options,
  );
}

/// Options passed to [ZXingWasmModule.readBarcodes].
@JS()
extension type ZXingWasmReaderOptions._(JSObject _) implements JSObject {
  /// Creates reader options that detect all supported barcode formats.
  external factory ZXingWasmReaderOptions({
    /// Spend more time to improve detection accuracy. Defaults to `true`.
    bool tryHarder,

    /// Also try 90°/180°/270° rotations. Defaults to `true`.
    bool tryRotate,

    /// Also try inverted/reversed reflectance. Defaults to `false`.
    bool tryInvert,
  });

  /// Creates reader options restricted to the given [formats].
  ///
  /// Pass a non-empty list of format strings (e.g. `['QRCode', 'EAN13']`).
  /// Passing an empty list or omitting formats detects all supported formats.
  @JS('ZXingWasmReaderOptions')
  external factory ZXingWasmReaderOptions.withFormats({
    /// Barcode format filter.
    JSArray<JSString> formats,

    /// Spend more time to improve detection accuracy. Defaults to `true`.
    bool tryHarder,

    /// Also try 90°/180°/270° rotations. Defaults to `true`.
    bool tryRotate,

    /// Also try inverted/reversed reflectance. Defaults to `false`.
    bool tryInvert,
  });
}

/// A single barcode result returned by [ZXingWasmModule.readBarcodes].
@JS()
extension type ZXingWasmReadResult(JSObject _) implements JSObject {
  /// Decoded text content.
  external String? get text;

  /// Canonical barcode format name, e.g. `'QRCode'`, `'EAN13'`, `'Code128'`.
  ///
  /// May be a sub-variant name, e.g. `'ITF14'`, `'ISBN'` or `'AztecCode'`.
  external String get format;

  /// Raw barcode bytes as returned by the decoder.
  external JSUint8Array? get bytes;

  /// Corner positions in image pixel coordinates.
  external ZXingWasmPosition get position;

  /// Whether the result passed all integrity checks (checksum, etc.).
  external bool get isValid;
}

/// Corner positions of a detected barcode in image pixel coordinates.
@JS()
extension type ZXingWasmPosition(JSObject _) implements JSObject {
  /// Top-left corner, or `null` if not available.
  external ZXingWasmPoint? get topLeft;

  /// Top-right corner, or `null` if not available.
  external ZXingWasmPoint? get topRight;

  /// Bottom-right corner, or `null` if not available.
  external ZXingWasmPoint? get bottomRight;

  /// Bottom-left corner, or `null` if not available.
  external ZXingWasmPoint? get bottomLeft;
}

/// A 2-D point in image pixel coordinates, used for barcode corner positions.
@JS()
extension type ZXingWasmPoint(JSObject _) implements JSObject {
  /// Horizontal coordinate in image pixel space.
  external double get x;

  /// Vertical coordinate in image pixel space.
  external double get y;
}

/// Converts a [ZXingWasmReadResult] to a [Barcode].
extension ZXingWasmReadResultToBarcode on ZXingWasmReadResult {
  /// Converts this result to a [Barcode].
  Barcode get toBarcode {
    final pos = position;
    final corners = <Offset>[];

    final tl = pos.topLeft;
    final tr = pos.topRight;
    final br = pos.bottomRight;
    final bl = pos.bottomLeft;

    if (tl != null && tr != null && br != null && bl != null) {
      corners.addAll([
        Offset(tl.x, tl.y),
        Offset(tr.x, tr.y),
        Offset(br.x, br.y),
        Offset(bl.x, bl.y),
      ]);
    }

    final rawBytes = bytes?.toDart;

    return Barcode(
      corners: corners,
      format: format.toBarcodeFormat,
      displayValue: text,
      // Populate deprecated rawBytes for backward compatibility.
      // ignore: deprecated_member_use_from_same_package
      rawBytes: rawBytes,
      rawDecodedBytes:
          rawBytes != null ? DecodedBarcodeBytes(bytes: rawBytes) : null,
      rawValue: text,
      size: computeBoundingBoxSize(corners),
      type: BarcodeType.text,
    );
  }
}
