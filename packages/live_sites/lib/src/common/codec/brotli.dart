import 'dart:typed_data';

import 'package:brotli_neo/v2.dart';

/// Decodes one complete Brotli stream (RFC 7932).
///
/// Throws [FormatException] when the input is invalid or the decompressed
/// output exceeds [maxOutput].
///
/// Note: [maxOutput] is checked after decompression and does not limit
/// the memory allocated by the decoder.
Uint8List brotliDecode(List<int> data, {int? maxOutput}) {
  if (maxOutput != null) {
    RangeError.checkNotNegative(maxOutput, 'maxOutput');
  }

  final compressed = data is Uint8List ? data : Uint8List.fromList(data);

  final Uint8List plain;

  try {
    plain = BrotliDecoderV2.decode(compressed);
  } on FormatException {
    rethrow;
  } on Object catch (error) {
    throw FormatException('Invalid Brotli stream: $error');
  }

  if (maxOutput != null && plain.length > maxOutput) {
    throw FormatException('Invalid Brotli stream: output over $maxOutput bytes');
  }

  return plain;
}
