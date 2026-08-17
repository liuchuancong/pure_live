import 'package:mobile_scanner/src/enums/barcode_format.dart';

/// Maps a BarcodeDetector format string to [BarcodeFormat].
extension BarcodeDetectorFormatStringToBarcodeFormat on String {
  /// Converts a BarcodeDetector format string (e.g. `'qr_code'`) to a
  /// [BarcodeFormat] enum value.
  BarcodeFormat get toBarcodeFormat => switch (this) {
    'aztec' => BarcodeFormat.aztec,
    'codabar' => BarcodeFormat.codabar,
    'code_39' => BarcodeFormat.code39,
    'code_93' => BarcodeFormat.code93,
    'code_128' => BarcodeFormat.code128,
    'data_matrix' => BarcodeFormat.dataMatrix,
    'ean_8' => BarcodeFormat.ean8,
    'ean_13' => BarcodeFormat.ean13,
    'itf' => BarcodeFormat.itf,
    'pdf417' => BarcodeFormat.pdf417,
    'qr_code' => BarcodeFormat.qrCode,
    'upc_a' => BarcodeFormat.upcA,
    'upc_e' => BarcodeFormat.upcE,
    _ => BarcodeFormat.unknown,
  };
}

/// Maps a [BarcodeFormat] to a BarcodeDetector format string, or `null` if
/// the format is not supported by the BarcodeDetector API.
extension BarcodeFormatToBarcodeDetectorString on BarcodeFormat {
  /// Converts a [BarcodeFormat] to a BarcodeDetector format string
  /// (e.g. `'qr_code'`), or `null` if the format is not supported.
  String? get toBarcodeDetectorString => switch (this) {
    BarcodeFormat.aztec => 'aztec',
    BarcodeFormat.codabar => 'codabar',
    BarcodeFormat.code39 => 'code_39',
    BarcodeFormat.code93 => 'code_93',
    BarcodeFormat.code128 => 'code_128',
    BarcodeFormat.dataMatrix => 'data_matrix',
    BarcodeFormat.ean8 => 'ean_8',
    BarcodeFormat.ean13 => 'ean_13',
    BarcodeFormat.itf ||
    BarcodeFormat.itf14 ||
    BarcodeFormat.itf2of5 ||
    BarcodeFormat.itf2of5WithChecksum => 'itf',
    BarcodeFormat.pdf417 => 'pdf417',
    BarcodeFormat.qrCode => 'qr_code',
    BarcodeFormat.upcA => 'upc_a',
    BarcodeFormat.upcE => 'upc_e',
    BarcodeFormat.all || BarcodeFormat.unknown || _ => null,
  };
}
