import 'dart:typed_data';

/// Represents the raw bytes of a barcode.
sealed class BarcodeBytes {
  const BarcodeBytes();
}

/// Decoded barcode bytes, available on Android and web.
final class DecodedBarcodeBytes extends BarcodeBytes {
  /// Creates a new [DecodedBarcodeBytes] instance.
  const DecodedBarcodeBytes({required this.bytes});

  /// The decoded raw bytes of the barcode value,
  /// without header or padding bytes.
  final Uint8List bytes;
}

/// Decoded barcode bytes from the Apple Vision API.
///
/// On Apple platforms, the Vision API may provide both decoded bytes
/// (without header/padding) and the raw payload bytes
/// (including header and padding).
final class DecodedVisionBarcodeBytes extends BarcodeBytes {
  /// Creates a new [DecodedVisionBarcodeBytes] instance.
  const DecodedVisionBarcodeBytes({required this.rawBytes, this.bytes});

  /// The decoded raw bytes of the barcode value,
  /// without header or padding bytes.
  ///
  /// This is null if removing the header or padding bytes from [rawBytes]
  /// failed.
  final Uint8List? bytes;

  /// The raw bytes from the Vision API, including header and padding bytes.
  ///
  /// If the original barcode is not encoded in UTF-8,
  /// this field can be used for manual conversion.
  ///
  /// Only available on iOS 17.0+ / macOS 14.0+. On older OS versions,
  /// [DecodedVisionBarcodeBytes] will not be returned.
  final Uint8List rawBytes;
}
