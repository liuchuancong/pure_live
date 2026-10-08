/// The barcode detection backend to use on the web platform.
enum WebBarcodeReader {
  /// Automatically select the best available reader.
  ///
  /// Uses the native [BarcodeDetector API](https://developer.mozilla.org/en-US/docs/Web/API/BarcodeDetector)
  /// when available (Chrome, Edge, Safari 17+), and falls back to
  /// `zxing-wasm` (zxing-cpp compiled to WebAssembly) for browsers that do
  /// not support it (e.g. Firefox).
  auto,

  /// Force the native BarcodeDetector API.
  ///
  /// Throws a `MobileScannerException` during `start()` if the API is not
  /// available in the current browser.
  barcodeDetector,

  /// Force the zxing-wasm (zxing-cpp WASM) reader.
  ///
  /// Works in all browsers that support WebAssembly (effectively all modern
  /// browsers).
  zxingWasm,

  /// Force the legacy `@zxing/library` JavaScript reader.
  ///
  /// This is a pure-JS port of ZXing.
  /// Prefer [zxingWasm] or [barcodeDetector] instead.
  zxingJs;

  /// A human-readable display name for this reader, suitable for use in UI
  /// labels and dialogs.
  String get label => switch (this) {
    WebBarcodeReader.auto => 'Auto',
    WebBarcodeReader.barcodeDetector => 'Native BarcodeDetector',
    WebBarcodeReader.zxingWasm => 'zxing-wasm',
    WebBarcodeReader.zxingJs => 'ZXing-js (legacy)',
  };

  /// A short display name for this reader, suitable for use in compact UI
  /// elements such as menu items or badges.
  String get shortLabel => switch (this) {
    WebBarcodeReader.auto => 'Auto',
    WebBarcodeReader.barcodeDetector => 'Native',
    WebBarcodeReader.zxingWasm => 'WASM',
    WebBarcodeReader.zxingJs => 'JS',
  };
}
