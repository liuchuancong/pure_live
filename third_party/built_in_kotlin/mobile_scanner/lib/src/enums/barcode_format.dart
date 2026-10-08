/// This enum defines the different barcode formats.
enum BarcodeFormat {
  /// A barcode format that represents all unknown formats.
  unknown(-1),

  /// A barcode format that represents all known formats.
  all(0),

  /// Barcode format constant for Code 128.
  code128(1),

  /// Barcode format constant for Code 39.
  code39(2),

  /// Barcode format constant for Code 93.
  code93(4),

  /// Barcode format constant for Codabar.
  codabar(8),

  /// Barcode format constant for Data Matrix.
  dataMatrix(16),

  /// Barcode format constant for EAN-13.
  ean13(32),

  /// Barcode format constant for EAN-8.
  ean8(64),

  /// Barcode format constant for Interleaved 2 of 5.
  itf2of5(126),

  /// Barcode format constant for Interleaved 2 of 5, with a checksum.
  itf2of5WithChecksum(127),

  /// Barcode format constant for ITF (Interleaved Two-of-Five).
  @Deprecated('Use BarcodeFormats.itf14 instead.')
  itf(128),

  /// Barcode format constant for ITF-14 (Interleaved Two-of-Five).
  itf14(128),

  /// Barcode format constant for QR Codes.
  qrCode(256),

  /// Barcode format constant for UPC-A.
  upcA(512),

  /// Barcode format constant for UPC-E.
  upcE(1024),

  /// Barcode format constant for PDF-417.
  pdf417(2048),

  /// Barcode format constant for AZTEC.
  aztec(4096),

  /// Barcode format constant for MaxiCode.
  maxiCode(8192),

  /// Barcode format constant for Micro QR Code.
  microQrCode(16384),

  /// Barcode format constant for GS1 DataBar (RSS-14).
  dataBar(32768),

  /// Barcode format constant for GS1 DataBar Expanded (RSS Expanded).
  dataBarExpanded(65536),

  /// Barcode format constant for GS1 DataBar Limited.
  dataBarLimited(131072);

  const BarcodeFormat(this.rawValue);

  factory BarcodeFormat.fromRawValue(int value) {
    switch (value) {
      case -1:
        return BarcodeFormat.unknown;
      case 0:
        return BarcodeFormat.all;
      case 1:
        return BarcodeFormat.code128;
      case 2:
        return BarcodeFormat.code39;
      case 4:
        return BarcodeFormat.code93;
      case 8:
        return BarcodeFormat.codabar;
      case 16:
        return BarcodeFormat.dataMatrix;
      case 32:
        return BarcodeFormat.ean13;
      case 64:
        return BarcodeFormat.ean8;
      case 126:
        return BarcodeFormat.itf2of5;
      case 127:
        return BarcodeFormat.itf2of5WithChecksum;
      case 128:
        return BarcodeFormat.itf14;
      case 256:
        return BarcodeFormat.qrCode;
      case 512:
        return BarcodeFormat.upcA;
      case 1024:
        return BarcodeFormat.upcE;
      case 2048:
        return BarcodeFormat.pdf417;
      case 4096:
        return BarcodeFormat.aztec;
      case 8192:
        return BarcodeFormat.maxiCode;
      case 16384:
        return BarcodeFormat.microQrCode;
      case 32768:
        return BarcodeFormat.dataBar;
      case 65536:
        return BarcodeFormat.dataBarExpanded;
      case 131072:
        return BarcodeFormat.dataBarLimited;
      default:
        throw ArgumentError.value(value, 'value', 'Invalid raw value.');
    }
  }

  /// This constant represents the old value for [BarcodeFormat.codabar].
  ///
  /// Prefer using the new [BarcodeFormat.codabar] constant,
  /// as the `codebar` value will be removed in a future release.
  @Deprecated('Use BarcodeFormat.codabar instead.')
  static const BarcodeFormat codebar = codabar;

  /// The raw value of the barcode format.
  final int rawValue;
}
