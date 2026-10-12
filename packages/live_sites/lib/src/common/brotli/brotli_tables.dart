/// Fixed tables of the Brotli format (RFC 7932) used by `brotli.dart`: the
/// literal context lookup tables, the static dictionary layout and the word
/// transforms. Internal to the decoder; not exported from `live_net.dart`.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Lut0 of RFC 7932 section 7.1 (UTF8 context mode, last byte).
const List<int> brotliLut0 = [
  // RFC 7932 section 7.1, CRC-32 0x8e91efb7.
  0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 0, 0, 4, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  8, 12, 16, 12, 12, 20, 12, 16, 24, 28, 12, 12, 32, 12, 36, 12,
  44, 44, 44, 44, 44, 44, 44, 44, 44, 44, 32, 32, 24, 40, 28, 12,
  12, 48, 52, 52, 52, 48, 52, 52, 52, 48, 52, 52, 52, 52, 52, 48,
  52, 52, 52, 52, 52, 48, 52, 52, 52, 52, 52, 24, 12, 28, 12, 12,
  12, 56, 60, 60, 60, 56, 60, 60, 60, 56, 60, 60, 60, 60, 60, 56,
  60, 60, 60, 60, 60, 56, 60, 60, 60, 60, 60, 24, 12, 28, 12, 0,
  0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1,
  0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1,
  0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1,
  0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1,
  2, 3, 2, 3, 2, 3, 2, 3, 2, 3, 2, 3, 2, 3, 2, 3,
  2, 3, 2, 3, 2, 3, 2, 3, 2, 3, 2, 3, 2, 3, 2, 3,
  2, 3, 2, 3, 2, 3, 2, 3, 2, 3, 2, 3, 2, 3, 2, 3,
  2, 3, 2, 3, 2, 3, 2, 3, 2, 3, 2, 3, 2, 3, 2, 3,
];

/// Lut1 of RFC 7932 section 7.1 (UTF8 context mode, second-to-last byte).
const List<int> brotliLut1 = [
  // RFC 7932 section 7.1, CRC-32 0xd01a32f4.
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1,
  1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1,
  1, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 1, 1, 1, 1, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
];

/// Lut2 of RFC 7932 section 7.1 (Signed context mode).
const List<int> brotliLut2 = [
  // RFC 7932 section 7.1, CRC-32 0x0dd7a0d6.
  0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
  5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
  5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
  5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
  6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 7,
];

/// Literal context IDs by context mode (LSB6, MSB6, UTF8, Signed): for mode
/// `m` the ID is `lookup[512 * m + p1] | lookup[512 * m + 256 + p2]`, where
/// `p1` and `p2` are the last and second-to-last output bytes.
final Uint8List brotliContextLookup = () {
  final lookup = Uint8List(2048);
  for (var byte = 0; byte < 256; byte++) {
    lookup[byte] = byte & 0x3f;
    lookup[512 + byte] = byte >> 2;
    lookup[1024 + byte] = brotliLut0[byte];
    lookup[1024 + 256 + byte] = brotliLut1[byte];
    lookup[1536 + byte] = brotliLut2[byte] << 3;
    lookup[1536 + 256 + byte] = brotliLut2[byte];
  }
  return lookup;
}();

/// NDBITS of RFC 7932 section 8: the static dictionary has `1 << bits[n]`
/// words of each length `n` from 4 to 24.
const List<int> brotliDictionaryBits = [
  // Lengths 0 to 24.
  0, 0, 0, 0, 10, 10, 11, 11, 10, 10, 10, 10, 10, 9, 9, 8, 7, 7, 8, 7, 7, 6, 6, 5, 5,
];

/// DOFFSET of RFC 7932 section 8: where the words of each length start in the
/// dictionary. The entry after the last (index 25) is the dictionary size.
final Int32List brotliDictionaryOffsets = () {
  final offsets = Int32List(26);
  for (var length = 0; length < 25; length++) {
    final words = length < 4 ? 0 : 1 << brotliDictionaryBits[length];
    offsets[length + 1] = offsets[length] + length * words;
  }
  return offsets;
}();

// Elementary transforms, numbered as in RFC 7932 Appendix B: OmitFirstK is
// `_omitFirst + K` and OmitLastK is `_omitLast + K`.
const int _identity = 0;
const int _fermentFirst = 1;
const int _fermentAll = 2;
const int _omitFirst = 2;
const int _omitLast = 11;

/// The 121 word transforms of RFC 7932 Appendix B: prefix, elementary
/// transform (0 Identity, 1 FermentFirst, 2 FermentAll, 3..11 OmitFirst1..9,
/// 12..20 OmitLast1..9) and suffix. Prefixes and suffixes are written as
/// UTF-8.
const List<(String, int, String)> brotliTransforms = [
  ('', _identity, ''), // 0
  ('', _identity, ' '), // 1
  (' ', _identity, ' '), // 2
  ('', _omitFirst + 1, ''), // 3
  ('', _fermentFirst, ' '), // 4
  ('', _identity, ' the '), // 5
  (' ', _identity, ''), // 6
  ('s ', _identity, ' '), // 7
  ('', _identity, ' of '), // 8
  ('', _fermentFirst, ''), // 9
  ('', _identity, ' and '), // 10
  ('', _omitFirst + 2, ''), // 11
  ('', _omitLast + 1, ''), // 12
  (', ', _identity, ' '), // 13
  ('', _identity, ', '), // 14
  (' ', _fermentFirst, ' '), // 15
  ('', _identity, ' in '), // 16
  ('', _identity, ' to '), // 17
  ('e ', _identity, ' '), // 18
  ('', _identity, '"'), // 19
  ('', _identity, '.'), // 20
  ('', _identity, '">'), // 21
  ('', _identity, '\n'), // 22
  ('', _omitLast + 3, ''), // 23
  ('', _identity, ']'), // 24
  ('', _identity, ' for '), // 25
  ('', _omitFirst + 3, ''), // 26
  ('', _omitLast + 2, ''), // 27
  ('', _identity, ' a '), // 28
  ('', _identity, ' that '), // 29
  (' ', _fermentFirst, ''), // 30
  ('', _identity, '. '), // 31
  ('.', _identity, ''), // 32
  (' ', _identity, ', '), // 33
  ('', _omitFirst + 4, ''), // 34
  ('', _identity, ' with '), // 35
  ('', _identity, "'"), // 36
  ('', _identity, ' from '), // 37
  ('', _identity, ' by '), // 38
  ('', _omitFirst + 5, ''), // 39
  ('', _omitFirst + 6, ''), // 40
  (' the ', _identity, ''), // 41
  ('', _omitLast + 4, ''), // 42
  ('', _identity, '. The '), // 43
  ('', _fermentAll, ''), // 44
  ('', _identity, ' on '), // 45
  ('', _identity, ' as '), // 46
  ('', _identity, ' is '), // 47
  ('', _omitLast + 7, ''), // 48
  ('', _omitLast + 1, 'ing '), // 49
  ('', _identity, '\n\t'), // 50
  ('', _identity, ':'), // 51
  (' ', _identity, '. '), // 52
  ('', _identity, 'ed '), // 53
  ('', _omitFirst + 9, ''), // 54
  ('', _omitFirst + 7, ''), // 55
  ('', _omitLast + 6, ''), // 56
  ('', _identity, '('), // 57
  ('', _fermentFirst, ', '), // 58
  ('', _omitLast + 8, ''), // 59
  ('', _identity, ' at '), // 60
  ('', _identity, 'ly '), // 61
  (' the ', _identity, ' of '), // 62
  ('', _omitLast + 5, ''), // 63
  ('', _omitLast + 9, ''), // 64
  (' ', _fermentFirst, ', '), // 65
  ('', _fermentFirst, '"'), // 66
  ('.', _identity, '('), // 67
  ('', _fermentAll, ' '), // 68
  ('', _fermentFirst, '">'), // 69
  ('', _identity, '="'), // 70
  (' ', _identity, '.'), // 71
  ('.com/', _identity, ''), // 72
  (' the ', _identity, ' of the '), // 73
  ('', _fermentFirst, "'"), // 74
  ('', _identity, '. This '), // 75
  ('', _identity, ','), // 76
  ('.', _identity, ' '), // 77
  ('', _fermentFirst, '('), // 78
  ('', _fermentFirst, '.'), // 79
  ('', _identity, ' not '), // 80
  (' ', _identity, '="'), // 81
  ('', _identity, 'er '), // 82
  (' ', _fermentAll, ' '), // 83
  ('', _identity, 'al '), // 84
  (' ', _fermentAll, ''), // 85
  ('', _identity, "='"), // 86
  ('', _fermentAll, '"'), // 87
  ('', _fermentFirst, '. '), // 88
  (' ', _identity, '('), // 89
  ('', _identity, 'ful '), // 90
  (' ', _fermentFirst, '. '), // 91
  ('', _identity, 'ive '), // 92
  ('', _identity, 'less '), // 93
  ('', _fermentAll, "'"), // 94
  ('', _identity, 'est '), // 95
  (' ', _fermentFirst, '.'), // 96
  ('', _fermentAll, '">'), // 97
  (' ', _identity, "='"), // 98
  ('', _fermentFirst, ','), // 99
  ('', _identity, 'ize '), // 100
  ('', _fermentAll, '.'), // 101
  ('\u00a0', _identity, ''), // 102
  (' ', _identity, ','), // 103
  ('', _fermentFirst, '="'), // 104
  ('', _fermentAll, '="'), // 105
  ('', _identity, 'ous '), // 106
  ('', _fermentAll, ', '), // 107
  ('', _fermentFirst, "='"), // 108
  (' ', _fermentFirst, ','), // 109
  (' ', _fermentAll, '="'), // 110
  (' ', _fermentAll, ', '), // 111
  ('', _fermentAll, ','), // 112
  ('', _fermentAll, '('), // 113
  ('', _fermentAll, '. '), // 114
  (' ', _fermentAll, '.'), // 115
  ('', _fermentAll, "='"), // 116
  (' ', _fermentAll, '. '), // 117
  (' ', _fermentFirst, '="'), // 118
  (' ', _fermentAll, "='"), // 119
  (' ', _fermentFirst, "='"), // 120
];

final List<Uint8List> _prefixes = [for (final (prefix, _, _) in brotliTransforms) utf8.encode(prefix)];
final List<Uint8List> _suffixes = [for (final (_, _, suffix) in brotliTransforms) utf8.encode(suffix)];

/// Bytes the word of [length] bytes turns into under [transform].
int brotliTransformedLength(int length, int transform) {
  final type = brotliTransforms[transform].$2;
  final omitted = type > _omitFirst ? type - (type > _omitLast ? _omitLast : _omitFirst) : 0;
  final kept = length > omitted ? length - omitted : 0;
  return _prefixes[transform].length + kept + _suffixes[transform].length;
}

/// Writes [transform] of the dictionary word of [length] bytes at [word] in
/// [dictionary] to [out] from [position]; returns the position after it.
/// The caller makes sure [brotliTransformedLength] bytes fit.
int brotliTransformWord(Uint8List out, int position, Uint8List dictionary, int word, int length, int transform) {
  var at = position;
  final prefix = _prefixes[transform];
  for (var i = 0; i < prefix.length; i++) {
    out[at++] = prefix[i];
  }
  final type = brotliTransforms[transform].$2;
  var start = word;
  var kept = length;
  if (type > _omitLast) {
    kept -= type - _omitLast;
  } else if (type > _omitFirst) {
    start += type - _omitFirst;
    kept -= type - _omitFirst;
  }
  if (kept > 0) {
    out.setRange(at, at + kept, dictionary, start);
    if (type == _fermentFirst) {
      _ferment(out, at, at + kept);
    } else if (type == _fermentAll) {
      for (var i = at; i < at + kept;) {
        i += _ferment(out, i, at + kept);
      }
    }
    at += kept;
  }
  final suffix = _suffixes[transform];
  for (var i = 0; i < suffix.length; i++) {
    out[at++] = suffix[i];
  }
  return at;
}

/// The "uppercasing" of RFC 7932 section 8 at [i] of a word ending at [end];
/// returns the number of bytes stepped over.
int _ferment(Uint8List word, int i, int end) {
  final byte = word[i];
  if (byte < 192) {
    if (byte >= 97 && byte <= 122) word[i] = byte ^ 32;
    return 1;
  }
  if (byte < 224) {
    if (i + 1 < end) word[i + 1] ^= 32;
    return 2;
  }
  if (i + 2 < end) word[i + 2] ^= 5;
  return 3;
}
