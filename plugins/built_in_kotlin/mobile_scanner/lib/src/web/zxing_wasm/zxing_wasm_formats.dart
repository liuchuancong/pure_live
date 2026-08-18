import 'package:mobile_scanner/src/enums/barcode_format.dart';

/// Maps a zxing-wasm format string to [BarcodeFormat].
extension ZXingWasmFormatStringToBarcodeFormat on String {
  /// Converts a zxing-wasm format string (e.g. `'QRCode'`) to a
  /// [BarcodeFormat] enum value.
  ///
  /// Handles the canonical zxing-wasm 3.x names, including the sub-variant
  /// names that the reader may return (e.g. `'ITF14'`, `'ISBN'`,
  /// `'AztecCode'`). The hyphenated 2.x names (e.g. `'EAN-13'`) are also
  /// accepted, in case an older library version is loaded through a custom
  /// script url.
  BarcodeFormat get toBarcodeFormat => switch (this) {
    'Aztec' || 'AztecCode' || 'AztecRune' => BarcodeFormat.aztec,
    'Codabar' => BarcodeFormat.codabar,
    'Code39' ||
    'Code39Std' ||
    'Code39Ext' ||
    'Code32' ||
    'PZN' => BarcodeFormat.code39,
    'Code93' => BarcodeFormat.code93,
    'Code128' => BarcodeFormat.code128,
    'DataBar' ||
    'DataBarOmni' ||
    'DataBarStk' ||
    'DataBarStkOmni' => BarcodeFormat.dataBar,
    'DataBarExp' ||
    'DataBarExpanded' ||
    'DataBarExpStk' => BarcodeFormat.dataBarExpanded,
    'DataBarLtd' || 'DataBarLimited' => BarcodeFormat.dataBarLimited,
    'DataMatrix' => BarcodeFormat.dataMatrix,
    'EAN8' || 'EAN-8' => BarcodeFormat.ean8,
    'EAN13' || 'ISBN' || 'EAN-13' => BarcodeFormat.ean13,
    'ITF' => BarcodeFormat.itf,
    'ITF14' => BarcodeFormat.itf14,
    'MaxiCode' => BarcodeFormat.maxiCode,
    'PDF417' || 'CompactPDF417' || 'MicroPDF417' => BarcodeFormat.pdf417,
    'QRCode' || 'QRCodeModel1' || 'QRCodeModel2' => BarcodeFormat.qrCode,
    'MicroQRCode' => BarcodeFormat.microQrCode,
    'UPCA' || 'UPC-A' => BarcodeFormat.upcA,
    'UPCE' || 'UPC-E' => BarcodeFormat.upcE,
    _ => BarcodeFormat.unknown,
  };
}

/// Maps a [BarcodeFormat] to a zxing-wasm format string, or `null` if the
/// format is not supported by zxing-wasm.
extension BarcodeFormatToZXingWasmString on BarcodeFormat {
  /// Converts a [BarcodeFormat] to a canonical zxing-wasm format string
  /// (e.g. `'QRCode'`), or `null` if the format is not supported.
  String? get toZXingWasmString => switch (this) {
    BarcodeFormat.aztec => 'Aztec',
    BarcodeFormat.codabar => 'Codabar',
    BarcodeFormat.code39 => 'Code39',
    BarcodeFormat.code93 => 'Code93',
    BarcodeFormat.code128 => 'Code128',
    BarcodeFormat.dataBar => 'DataBar',
    BarcodeFormat.dataBarExpanded => 'DataBarExp',
    BarcodeFormat.dataBarLimited => 'DataBarLtd',
    BarcodeFormat.dataMatrix => 'DataMatrix',
    BarcodeFormat.ean8 => 'EAN8',
    BarcodeFormat.ean13 => 'EAN13',
    BarcodeFormat.itf ||
    BarcodeFormat.itf2of5 ||
    BarcodeFormat.itf2of5WithChecksum => 'ITF',
    BarcodeFormat.itf14 => 'ITF14',
    BarcodeFormat.maxiCode => 'MaxiCode',
    BarcodeFormat.pdf417 => 'PDF417',
    BarcodeFormat.qrCode => 'QRCode',
    BarcodeFormat.microQrCode => 'MicroQRCode',
    BarcodeFormat.upcA => 'UPCA',
    BarcodeFormat.upcE => 'UPCE',
    BarcodeFormat.all || BarcodeFormat.unknown || _ => null,
  };
}
