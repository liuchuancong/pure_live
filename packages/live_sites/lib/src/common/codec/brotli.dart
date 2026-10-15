import 'dart:typed_data';

import 'package:es_compression/brotli.dart';

/// The codec behind [brotliDecode]; one instance, as the converters are
/// stateless per call.
final BrotliCodec _codec = BrotliCodec();

/// Decodes [data], one complete Brotli stream (RFC 7932), and returns the
/// decompressed bytes.
///
/// Throws a [FormatException] when [data] is not exactly one valid stream:
/// truncated, corrupt, followed by more bytes — whatever the native Brotli
/// library rejects — and, with [maxOutput], when the stream decompresses to
/// more than [maxOutput] bytes. Unlike a streaming decoder, the limit is
/// checked after the output is produced, so [maxOutput] bounds what the
/// caller keeps, not what the decoder allocates; set it for data from the
/// network and keep the cap small (the chat frames here are well under it).
///
/// Decoding is one-shot: Missevan danmaku frames and Bilibili protover 3
/// packets each carry one complete stream. The native library is the same
/// `es_compression` one the Bilibili danmaku codec uses.
Uint8List brotliDecode(List<int> data, {int? maxOutput}) {
  if (maxOutput != null) RangeError.checkNotNegative(maxOutput, 'maxOutput');
  final Uint8List plain;
  try {
    plain = Uint8List.fromList(_codec.decode(data is Uint8List ? data : Uint8List.fromList(data)));
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
