import 'dart:js_interop';

import 'package:mobile_scanner/src/enums/barcode_format.dart';
import 'package:mobile_scanner/src/objects/barcode.dart';
import 'package:mobile_scanner/src/objects/start_options.dart';
import 'package:mobile_scanner/src/web/polling_barcode_reader.dart';
import 'package:mobile_scanner/src/web/web_library_versions.dart';
import 'package:mobile_scanner/src/web/zxing_wasm/zxing_wasm_formats.dart';
import 'package:mobile_scanner/src/web/zxing_wasm/zxing_wasm_result.dart';
import 'package:web/web.dart' as web;

/// Canvas 2D context creation attributes.
///
/// Setting `willReadFrequently` to `true` tells the browser to optimise the
/// backing store for repeated `getImageData` calls, avoiding GPU readback.
@JS()
extension type _CanvasContextAttributes._(JSObject _) implements JSObject {
  external factory _CanvasContextAttributes({bool willReadFrequently});
}

/// A barcode reader that uses zxing-wasm (zxing-cpp compiled to WebAssembly).
///
/// Frames are extracted by drawing the video element onto an off-screen canvas
/// on each tick, then passed to `ZXingWasmModule.readBarcodes`.
///
/// The IIFE build is loaded from jsDelivr. Once loaded it exposes
/// `window.ZXingWASM`; the WASM binary is lazy-fetched on the first call to
/// `readBarcodes`.
final class ZXingWasmBarcodeReader extends PollingBarcodeReader {
  /// Construct a new [ZXingWasmBarcodeReader] instance.
  ZXingWasmBarcodeReader();

  @override
  String get scriptId => 'mobile-scanner-zxing-wasm';

  // The version is pinned so that upstream releases cannot change the
  // behavior of this reader (and the lazily fetched WASM binary) without a
  // corresponding update here.
  @override
  String get scriptUrl =>
      'https://cdn.jsdelivr.net/npm/zxing-wasm@$zxingWasmVersion'
      '/dist/iife/reader/index.js';

  web.HTMLCanvasElement? _canvas;
  web.CanvasRenderingContext2D? _ctx;

  List<BarcodeFormat> _formats = const [];

  @override
  Future<void> prepareDecoder(StartOptions options) async {
    _formats = [
      for (final f in options.formats)
        if (f != BarcodeFormat.unknown) f,
    ];

    // Off-screen canvas used to extract ImageData from each video frame.
    // willReadFrequently: true tells the browser to optimise for repeated
    // getImageData calls, avoiding the GPU-readback warning.
    _canvas = web.HTMLCanvasElement();
    _ctx =
        _canvas!.getContext(
              '2d',
              _CanvasContextAttributes(willReadFrequently: true),
            )
            as web.CanvasRenderingContext2D?;
  }

  @override
  Future<List<Barcode>> decodeFrame(web.HTMLVideoElement video) async {
    final canvas = _canvas;
    final ctx = _ctx;

    if (canvas == null || ctx == null) {
      return const [];
    }

    final vw = video.videoWidth;
    final vh = video.videoHeight;

    // Keep the canvas in sync with the video resolution.
    if (canvas.width != vw || canvas.height != vh) {
      canvas
        ..width = vw
        ..height = vh;
    }

    // Capture the current video frame.
    ctx.drawImage(video, 0, 0);
    final imageData = ctx.getImageData(0, 0, vw, vh);

    final jsResults =
        await zxingWasmModule
            .readBarcodes(imageData, _buildReaderOptions())
            .toDart;

    return [
      for (final result in jsResults.toDart)
        if (result.isValid) result.toBarcode,
    ];
  }

  @override
  void disposeDecoder() {
    _canvas = null;
    _ctx = null;
  }

  ZXingWasmReaderOptions _buildReaderOptions() {
    final detectAll = _formats.isEmpty || _formats.contains(BarcodeFormat.all);

    if (!detectAll) {
      final formatStrs = <JSString>[
        for (final f in _formats)
          if (f.toZXingWasmString case final s?) s.toJS,
      ];

      if (formatStrs.isNotEmpty) {
        return ZXingWasmReaderOptions.withFormats(
          formats: formatStrs.toJS,
          tryHarder: true,
          tryRotate: true,
          tryInvert: false,
        );
      }

      // If none of the requested formats are supported by zxing-wasm,
      // deliberately fall through to detecting all formats, rather than
      // detecting nothing at all.
    }

    // Omit the formats key entirely so zxing-wasm detects all formats.
    // Passing formats: null causes a crash inside the WASM module.
    return ZXingWasmReaderOptions(
      tryHarder: true,
      tryRotate: true,
      tryInvert: false,
    );
  }
}
