/// The pinned versions of the external barcode libraries that are loaded
/// from a CDN by the web implementation.
///
/// These versions are mirrored in the `package.json` at the repository root,
/// which exists solely so that Dependabot can detect and propose updates.
/// The test in `test/web/web_library_versions_test.dart` fails when the two
/// files are out of sync.
library;

/// The pinned version of the legacy `@zxing/library` JavaScript library.
const String zxingJsVersion = '0.23.0';

/// The pinned version of the `zxing-wasm` library.
///
/// When crossing a major version, verify the barcode format names in
/// `zxing_wasm_formats.dart` against the upstream release notes: the 2.x to
/// 3.x transition renamed the output format names (e.g. `EAN-13` became
/// `EAN13`) and introduced sub-variant names (e.g. `ITF14`, `ISBN`).
const String zxingWasmVersion = '3.1.1';
