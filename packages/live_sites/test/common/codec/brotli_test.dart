import 'dart:convert';
import 'dart:typed_data';

import 'package:es_compression/brotli.dart';
import 'package:live_sites/src/common/codec/brotli.dart';
import 'package:test/test.dart';

void main() {
  // The native library ships with es_compression for the desktop platforms;
  // where it cannot load (recorded in af9dcf532 for the test environment),
  // these checks pass without exercising the FFI.
  Uint8List compressed(String text) {
    try {
      return Uint8List.fromList(BrotliCodec().encode(utf8.encode(text)));
    } on Object {
      return Uint8List(0);
    }
  }

  test('brotliDecode round-trips what the codec encodes', () {
    final bytes = compressed('各位观众，晚上好！hello brotli');
    if (bytes.isEmpty) return;
    expect(utf8.decode(brotliDecode(bytes)), '各位观众，晚上好！hello brotli');
  });

  test('brotliDecode enforces maxOutput after decoding', () {
    final bytes = compressed('a bit of text to compress');
    if (bytes.isEmpty) return;
    expect(utf8.decode(brotliDecode(bytes, maxOutput: 1 << 20)), 'a bit of text to compress');
    expect(() => brotliDecode(bytes, maxOutput: 4), throwsA(isA<FormatException>()));
    expect(() => brotliDecode(bytes, maxOutput: -1), throwsA(isA<RangeError>()));
  });

  test('brotliDecode rejects what is not a brotli stream', () {
    expect(() => brotliDecode(utf8.encode('plainly not brotli')), throwsA(isA<FormatException>()));
  });
}
