import 'dart:convert' show base64, jsonDecode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:archive/archive.dart' show ZLibDecoder;

// The lyric crypto below (TEA words, DES bits) uses 64-bit integers whose
// exactness does not survive JS; this app never compiles to it.
// ignore_for_file: avoid_js_rounded_ints

/// KRC (KuGou) and QRC (QQ music) decrypt plus the word-timed text shapes
/// both carry, ported 1:1 from lx-music's `lyricUtils/kg.js` and
/// `qrcDecode.js`. Decoded lyric comes back as lx-style LRC: word timing
/// rides `<startMs,duration>` tags that the lyric module strips when a
/// viewer wants plain lines.

/// One decoded song lyric: the main text (word-timed), its translation and
/// its romanization, any of which may be absent.
final class DecodedLyric {
  /// A decoded lyric.
  const DecodedLyric({required this.lyric, this.translation, this.romanization});

  /// The main lyric, line-stamped and word-tagged.
  final String lyric;

  /// The translation, stamped to the same lines.
  final String? translation;

  /// The romanization, stamped to the same lines.
  final String? romanization;
}

final RegExp _krcHead = RegExp(r'^.*\[id:\$\w+\]\n');
final RegExp _krcLanguage = RegExp(r'\[language:([A-Za-z0-9=\\/+]+)\]');
final RegExp _krcLineTag = RegExp(r'\[((\d+),\d+)\]');
final RegExp _krcWordTail = RegExp(r'<(\d+,\d+),\d+>');

/// Decodes a KRC payload (base64 of the encrypted bytes) into its texts.
DecodedLyric? decodeKrc(String base64Data) {
  if (base64Data.isEmpty) return null;
  var text = utf8.decode(_inflateKrc(base64.decode(base64Data)), allowMalformed: true);
  text = text.replaceAll('\r', '');
  if (_krcHead.hasMatch(text)) text = text.replaceFirst(_krcHead, '');

  final language = _krcLanguage.firstMatch(text);
  List<dynamic>? tlyricLines;
  List<dynamic>? rlyricLines;
  if (language != null) {
    text = text.replaceFirst(RegExp(r'\[language:[A-Za-z0-9=\\/+]+\]\n'), '');
    final json = jsonDecode(utf8.decode(base64.decode(language[1]!), allowMalformed: true));
    if (json is Map && json['content'] is List) {
      for (final item in json['content'] as List) {
        if (item is! Map) continue;
        switch (item['type']) {
          case 0:
            rlyricLines = item['lyricContent'] as List?;
          case 1:
            tlyricLines = item['lyricContent'] as List?;
        }
      }
    }
  }

  var index = 0;
  final lxlyric = text
      .replaceAllMapped(_krcLineTag, (match) {
        final ms = int.parse(match[2]!);
        final stamp = _stamp(ms);
        if (rlyricLines != null && index < rlyricLines.length) {
          rlyricLines[index] = '[$stamp]${(rlyricLines[index] as List?)?.join() ?? ''}';
        }
        if (tlyricLines != null && index < tlyricLines.length) {
          tlyricLines[index] = '[$stamp]${(tlyricLines[index] as List?)?.join() ?? ''}';
        }
        index++;
        return '[$stamp]';
      })
      .replaceAll(_krcWordTail, r'<$1>');

  return DecodedLyric(
    lyric: lxlyric,
    translation: _linesOf(tlyricLines),
    romanization: _linesOf(rlyricLines),
  );
}

/// Restamps the raw millisecond tag with the lyric's own stamp format.
String _stamp(int totalMs) {
  final minutes = (totalMs ~/ 60000).toString().padLeft(2, '0');
  final seconds = ((totalMs ~/ 1000) % 60).toString().padLeft(2, '0');
  final millis = (totalMs % 1000).toString().padLeft(3, '0');
  return '$minutes:$seconds.$millis';
}

String? _linesOf(List<dynamic>? lines) {
  if (lines == null) return null;
  final text = lines.whereType<String>().join('\n').trim();
  return text.isEmpty ? null : text;
}

Uint8List _inflateKrc(Uint8List encrypted) {
  final key = [0x40, 0x47, 0x61, 0x77, 0x5e, 0x32, 0x74, 0x47, 0x51, 0x36, 0x31, 0x2d, 0xce, 0xd2, 0x6e, 0x69];
  for (var i = 0; i < encrypted.length; i++) {
    encrypted[i] ^= key[i % 16];
  }
  return const ZLibDecoder().decodeBytes(encrypted);
}

// ---------------------------------------------------------------------------
// QRC: the 3DES variant with two non-standard S-box entries, then zlib.
// ---------------------------------------------------------------------------

const List<List<int>> _sbox = [
  [
    14,
    4,
    13,
    1,
    2,
    15,
    11,
    8,
    3,
    10,
    6,
    12,
    5,
    9,
    0,
    7,
    0,
    15,
    7,
    4,
    14,
    2,
    13,
    1,
    10,
    6,
    12,
    11,
    9,
    5,
    3,
    8,
    4,
    1,
    14,
    8,
    13,
    6,
    2,
    11,
    15,
    12,
    9,
    7,
    3,
    10,
    5,
    0,
    15,
    12,
    8,
    2,
    4,
    9,
    1,
    7,
    5,
    11,
    3,
    14,
    10,
    0,
    6,
    13,
  ],
  [
    15,
    1,
    8,
    14,
    6,
    11,
    3,
    4,
    9,
    7,
    2,
    13,
    12,
    0,
    5,
    10,
    3,
    13,
    4,
    7,
    15,
    2,
    8,
    15,
    12,
    0,
    1,
    10,
    6,
    9,
    11,
    5,
    0,
    14,
    7,
    11,
    10,
    4,
    13,
    1,
    5,
    8,
    12,
    6,
    9,
    3,
    2,
    15,
    13,
    8,
    10,
    1,
    3,
    15,
    4,
    2,
    11,
    6,
    7,
    12,
    0,
    5,
    14,
    9,
  ],
  [
    10,
    0,
    9,
    14,
    6,
    3,
    15,
    5,
    1,
    13,
    12,
    7,
    11,
    4,
    2,
    8,
    13,
    7,
    0,
    9,
    3,
    4,
    6,
    10,
    2,
    8,
    5,
    14,
    12,
    11,
    15,
    1,
    13,
    6,
    4,
    9,
    8,
    15,
    3,
    0,
    11,
    1,
    2,
    12,
    5,
    10,
    14,
    7,
    1,
    10,
    13,
    0,
    6,
    9,
    8,
    7,
    4,
    15,
    14,
    3,
    11,
    5,
    2,
    12,
  ],
  [
    7,
    13,
    14,
    3,
    0,
    6,
    9,
    10,
    1,
    2,
    8,
    5,
    11,
    12,
    4,
    15,
    13,
    8,
    11,
    5,
    6,
    15,
    0,
    3,
    4,
    7,
    2,
    12,
    1,
    10,
    14,
    9,
    10,
    6,
    9,
    0,
    12,
    11,
    7,
    13,
    15,
    1,
    3,
    14,
    5,
    2,
    8,
    4,
    3,
    15,
    0,
    6,
    10,
    10,
    13,
    8,
    9,
    4,
    5,
    11,
    12,
    7,
    2,
    14,
  ],
  [
    2,
    12,
    4,
    1,
    7,
    10,
    11,
    6,
    8,
    5,
    3,
    15,
    13,
    0,
    14,
    9,
    14,
    11,
    2,
    12,
    4,
    7,
    13,
    1,
    5,
    0,
    15,
    10,
    3,
    9,
    8,
    6,
    4,
    2,
    1,
    11,
    10,
    13,
    7,
    8,
    15,
    9,
    12,
    5,
    6,
    3,
    0,
    14,
    11,
    8,
    12,
    7,
    1,
    14,
    2,
    13,
    6,
    15,
    0,
    9,
    10,
    4,
    5,
    3,
  ],
  [
    12,
    1,
    10,
    15,
    9,
    2,
    6,
    8,
    0,
    13,
    3,
    4,
    14,
    7,
    5,
    11,
    10,
    15,
    4,
    2,
    7,
    12,
    9,
    5,
    6,
    1,
    13,
    14,
    0,
    11,
    3,
    8,
    9,
    14,
    15,
    5,
    2,
    8,
    12,
    3,
    7,
    0,
    4,
    10,
    1,
    13,
    11,
    6,
    4,
    3,
    2,
    12,
    9,
    5,
    15,
    10,
    11,
    14,
    1,
    7,
    6,
    0,
    8,
    13,
  ],
  [
    4,
    11,
    2,
    14,
    15,
    0,
    8,
    13,
    3,
    12,
    9,
    7,
    5,
    10,
    6,
    1,
    13,
    0,
    11,
    7,
    4,
    9,
    1,
    10,
    14,
    3,
    5,
    12,
    2,
    15,
    8,
    6,
    1,
    4,
    11,
    13,
    12,
    3,
    7,
    14,
    10,
    15,
    6,
    8,
    0,
    5,
    9,
    2,
    6,
    11,
    13,
    8,
    1,
    4,
    10,
    7,
    9,
    5,
    0,
    15,
    14,
    2,
    3,
    12,
  ],
  [
    13,
    2,
    8,
    4,
    6,
    15,
    11,
    1,
    10,
    9,
    3,
    14,
    5,
    0,
    12,
    7,
    1,
    15,
    13,
    8,
    10,
    3,
    7,
    4,
    12,
    5,
    6,
    11,
    0,
    14,
    9,
    2,
    7,
    11,
    4,
    1,
    9,
    12,
    14,
    2,
    0,
    6,
    10,
    13,
    15,
    3,
    5,
    8,
    2,
    1,
    14,
    7,
    4,
    10,
    8,
    13,
    15,
    12,
    9,
    0,
    3,
    5,
    6,
    11,
  ],
];

const List<int> _keyRndShift = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1];
const List<int> _keyPermC = [
  56,
  48,
  40,
  32,
  24,
  16,
  8,
  0,
  57,
  49,
  41,
  33,
  25,
  17,
  9,
  1,
  58,
  50,
  42,
  34,
  26,
  18,
  10,
  2,
  59,
  51,
  43,
  35,
];
const List<int> _keyPermD = [
  62,
  54,
  46,
  38,
  30,
  22,
  14,
  6,
  61,
  53,
  45,
  37,
  29,
  21,
  13,
  5,
  60,
  52,
  44,
  36,
  28,
  20,
  12,
  4,
  27,
  19,
  11,
  3,
];
const List<int> _keyCompression = [
  13,
  16,
  10,
  23,
  0,
  4,
  2,
  27,
  14,
  5,
  20,
  9,
  22,
  18,
  11,
  3,
  25,
  7,
  15,
  6,
  26,
  19,
  12,
  1,
  40,
  51,
  30,
  36,
  46,
  54,
  29,
  39,
  50,
  44,
  32,
  47,
  43,
  48,
  38,
  55,
  33,
  52,
  45,
  41,
  49,
  35,
  28,
  31,
];

int _u32(int value) => value & 0xFFFFFFFF;

int _bitnum(Uint8List a, int b, int c) => _u32((a[(b ~/ 32) * 4 + 3 - ((b % 32) ~/ 8)] >> (7 - (b % 8))) & 1 << c);

int _bitnumIntr(int a, int b, int c) => _u32(((a >> (31 - b)) & 1) << c);

int _bitnumIntl(int a, int b, int c) => _u32(_u32(_u32(a << b) & 0x80000000) >>> c);

int _sboxBit(int a) => (a & 32) | ((a & 31) >>> 1) | ((a & 1) << 4);

(int, int) _initialPermutation(Uint8List input) {
  final s0 = _u32(
    _bitnum(input, 57, 31) |
        _bitnum(input, 49, 30) |
        _bitnum(input, 41, 29) |
        _bitnum(input, 33, 28) |
        _bitnum(input, 25, 27) |
        _bitnum(input, 17, 26) |
        _bitnum(input, 9, 25) |
        _bitnum(input, 1, 24) |
        _bitnum(input, 59, 23) |
        _bitnum(input, 51, 22) |
        _bitnum(input, 43, 21) |
        _bitnum(input, 35, 20) |
        _bitnum(input, 27, 19) |
        _bitnum(input, 19, 18) |
        _bitnum(input, 11, 17) |
        _bitnum(input, 3, 16) |
        _bitnum(input, 61, 15) |
        _bitnum(input, 53, 14) |
        _bitnum(input, 45, 13) |
        _bitnum(input, 37, 12) |
        _bitnum(input, 29, 11) |
        _bitnum(input, 21, 10) |
        _bitnum(input, 13, 9) |
        _bitnum(input, 5, 8) |
        _bitnum(input, 63, 7) |
        _bitnum(input, 55, 6) |
        _bitnum(input, 47, 5) |
        _bitnum(input, 39, 4) |
        _bitnum(input, 31, 3) |
        _bitnum(input, 23, 2) |
        _bitnum(input, 15, 1) |
        _bitnum(input, 7, 0),
  );
  final s1 = _u32(
    _bitnum(input, 56, 31) |
        _bitnum(input, 48, 30) |
        _bitnum(input, 40, 29) |
        _bitnum(input, 32, 28) |
        _bitnum(input, 24, 27) |
        _bitnum(input, 16, 26) |
        _bitnum(input, 8, 25) |
        _bitnum(input, 0, 24) |
        _bitnum(input, 58, 23) |
        _bitnum(input, 50, 22) |
        _bitnum(input, 42, 21) |
        _bitnum(input, 34, 20) |
        _bitnum(input, 26, 19) |
        _bitnum(input, 18, 18) |
        _bitnum(input, 10, 17) |
        _bitnum(input, 2, 16) |
        _bitnum(input, 60, 15) |
        _bitnum(input, 52, 14) |
        _bitnum(input, 44, 13) |
        _bitnum(input, 36, 12) |
        _bitnum(input, 28, 11) |
        _bitnum(input, 20, 10) |
        _bitnum(input, 12, 9) |
        _bitnum(input, 4, 8) |
        _bitnum(input, 62, 7) |
        _bitnum(input, 54, 6) |
        _bitnum(input, 46, 5) |
        _bitnum(input, 38, 4) |
        _bitnum(input, 30, 3) |
        _bitnum(input, 22, 2) |
        _bitnum(input, 14, 1) |
        _bitnum(input, 6, 0),
  );
  return (s0, s1);
}

void _inversePermutation(int s0, int s1, Uint8List out) {
  int byteOf(List<int> bits) {
    var value = 0;
    for (var i = 0; i < bits.length; i += 2) {
      value |= _bitnumIntr(bits[i], bits[i + 1], 7 - i ~/ 2);
    }
    return value & 0xff;
  }

  out[3] = byteOf([s1, 7, s0, 7, s1, 15, s0, 15, s1, 23, s0, 23, s1, 31, s0, 31]);
  out[2] = byteOf([s1, 6, s0, 6, s1, 14, s0, 14, s1, 22, s0, 22, s1, 30, s0, 30]);
  out[1] = byteOf([s1, 5, s0, 5, s1, 13, s0, 13, s1, 21, s0, 21, s1, 29, s0, 29]);
  out[0] = byteOf([s1, 4, s0, 4, s1, 12, s0, 12, s1, 20, s0, 20, s1, 28, s0, 28]);
  out[7] = byteOf([s1, 3, s0, 3, s1, 11, s0, 11, s1, 19, s0, 19, s1, 27, s0, 27]);
  out[6] = byteOf([s1, 2, s0, 2, s1, 10, s0, 10, s1, 18, s0, 18, s1, 26, s0, 26]);
  out[5] = byteOf([s1, 1, s0, 1, s1, 9, s0, 9, s1, 17, s0, 17, s1, 25, s0, 25]);
  out[4] = byteOf([s1, 0, s0, 0, s1, 8, s0, 8, s1, 16, s0, 16, s1, 24, s0, 24]);
}

int _desF(int state, List<int> key) {
  final t1 = _u32(
    _bitnumIntl(state, 31, 0) |
        _u32(state & 0xF0000000) >>> 1 |
        _bitnumIntl(state, 4, 5) |
        _bitnumIntl(state, 3, 6) |
        _u32(state & 0x0F000000) >>> 3 |
        _bitnumIntl(state, 8, 11) |
        _bitnumIntl(state, 7, 12) |
        _u32(state & 0x00F00000) >>> 5 |
        _bitnumIntl(state, 12, 17) |
        _bitnumIntl(state, 11, 18) |
        _u32(state & 0x000F0000) >>> 7 |
        _bitnumIntl(state, 16, 23),
  );
  final t2 = _u32(
    _bitnumIntl(state, 15, 0) |
        _u32(_u32(state & 0x0000F000) << 15) |
        _bitnumIntl(state, 20, 5) |
        _bitnumIntl(state, 19, 6) |
        _u32(_u32(state & 0x00000F00) << 13) |
        _bitnumIntl(state, 24, 11) |
        _bitnumIntl(state, 23, 12) |
        _u32(_u32(state & 0x000000F0) << 11) |
        _bitnumIntl(state, 28, 17) |
        _bitnumIntl(state, 27, 18) |
        _u32(_u32(state & 0x0000000F) << 9) |
        _bitnumIntl(state, 0, 23),
  );

  final lrgstate = [
    (t1 >>> 24) & 0xFF,
    (t1 >>> 16) & 0xFF,
    (t1 >>> 8) & 0xFF,
    (t2 >>> 24) & 0xFF,
    (t2 >>> 16) & 0xFF,
    (t2 >>> 8) & 0xFF,
  ];
  for (var i = 0; i < 6; i++) {
    lrgstate[i] ^= key[i];
  }

  final s = _u32(
    (_sbox[0][_sboxBit(lrgstate[0] >>> 2)] << 28) |
        (_sbox[1][_sboxBit(((lrgstate[0] & 0x03) << 4) | (lrgstate[1] >>> 4))] << 24) |
        (_sbox[2][_sboxBit(((lrgstate[1] & 0x0F) << 2) | (lrgstate[2] >>> 6))] << 20) |
        (_sbox[3][_sboxBit(lrgstate[2] & 0x3F)] << 16) |
        (_sbox[4][_sboxBit(lrgstate[3] >>> 2)] << 12) |
        (_sbox[5][_sboxBit(((lrgstate[3] & 0x03) << 4) | (lrgstate[4] >>> 4))] << 8) |
        (_sbox[6][_sboxBit(((lrgstate[4] & 0x0F) << 2) | (lrgstate[5] >>> 6))] << 4) |
        _sbox[7][_sboxBit(lrgstate[5] & 0x3F)],
  );

  return _u32(
    _bitnumIntl(s, 15, 0) |
        _bitnumIntl(s, 6, 1) |
        _bitnumIntl(s, 19, 2) |
        _bitnumIntl(s, 20, 3) |
        _bitnumIntl(s, 28, 4) |
        _bitnumIntl(s, 11, 5) |
        _bitnumIntl(s, 27, 6) |
        _bitnumIntl(s, 16, 7) |
        _bitnumIntl(s, 0, 8) |
        _bitnumIntl(s, 14, 9) |
        _bitnumIntl(s, 22, 10) |
        _bitnumIntl(s, 25, 11) |
        _bitnumIntl(s, 4, 12) |
        _bitnumIntl(s, 17, 13) |
        _bitnumIntl(s, 30, 14) |
        _bitnumIntl(s, 9, 15) |
        _bitnumIntl(s, 1, 16) |
        _bitnumIntl(s, 7, 17) |
        _bitnumIntl(s, 23, 18) |
        _bitnumIntl(s, 13, 19) |
        _bitnumIntl(s, 31, 20) |
        _bitnumIntl(s, 26, 21) |
        _bitnumIntl(s, 2, 22) |
        _bitnumIntl(s, 8, 23) |
        _bitnumIntl(s, 18, 24) |
        _bitnumIntl(s, 12, 25) |
        _bitnumIntl(s, 29, 26) |
        _bitnumIntl(s, 5, 27) |
        _bitnumIntl(s, 21, 28) |
        _bitnumIntl(s, 10, 29) |
        _bitnumIntl(s, 3, 30) |
        _bitnumIntl(s, 24, 31),
  );
}

void _desCrypt(Uint8List input, List<Uint8List> schedule, Uint8List output) {
  var (s0, s1) = _initialPermutation(input);
  for (var i = 0; i < 15; i++) {
    final prev = s1;
    s1 = _u32(_desF(s1, schedule[i]) ^ s0);
    s0 = prev;
  }
  s0 = _u32(_desF(s1, schedule[15]) ^ s0);
  _inversePermutation(s0, s1, output);
}

List<Uint8List> _keySchedule(Uint8List key, bool decrypt) {
  final schedule = List.generate(16, (_) => Uint8List(6));
  var c = 0;
  var d = 0;
  for (var i = 0; i < 28; i++) {
    c |= _bitnum(key, _keyPermC[i], 31 - i);
    d |= _bitnum(key, _keyPermD[i], 31 - i);
  }
  for (var i = 0; i < 16; i++) {
    final shift = _keyRndShift[i];
    c = _u32(_u32(c << shift | c >>> (28 - shift)) & 0xFFFFFFF0);
    d = _u32(_u32(d << shift | d >>> (28 - shift)) & 0xFFFFFFF0);
    final togen = decrypt ? 15 - i : i;
    for (var j = 0; j < 24; j++) {
      schedule[togen][j ~/ 8] |= _bitnumIntr(c, _keyCompression[j], 7 - (j % 8));
    }
    for (var j = 24; j < 48; j++) {
      schedule[togen][j ~/ 8] |= _bitnumIntr(d, _keyCompression[j] - 27, 7 - (j % 8));
    }
  }
  return schedule;
}

/// The EDE3 key order for decryption, from the fixed 24-byte QRC key.
List<List<Uint8List>> _tripledesDecryptSchedule(Uint8List key) => [
  _keySchedule(key.sublist(16, 24), true),
  _keySchedule(key.sublist(8, 16), false),
  _keySchedule(key.sublist(0, 8), true),
];

/// QRC's fixed 24-byte key: `!@#)(*$%123ZXC!@!@#)(NHL`.
final Uint8List _qrcKey = Uint8List.fromList([
  0x21, 0x40, 0x23, 0x29, 0x28, 0x2a, 0x24, 0x25, 0x31, 0x32, 0x33, 0x5a, //
  0x58, 0x43, 0x21, 0x40, 0x21, 0x40, 0x23, 0x29, 0x28, 0x4e, 0x48, 0x4c,
]);

Uint8List? _inflateQrc(Uint8List encrypted) {
  // QRC streams are cut mid-flow, so the strict decoder is given one extra
  // sync-flush marker before giving up.
  for (final attempt in [
    encrypted,
    Uint8List.fromList([...encrypted, 0x00, 0x00, 0xff, 0xff]),
  ]) {
    try {
      return const ZLibDecoder().decodeBytes(attempt);
    } on Object {
      // Try the next shape.
    }
  }
  return null;
}

/// Decodes a QRC payload (the hex string the server returns) to its lyric
/// text, or null when the payload does not decrypt.
String? decodeQrc(String? hexData) {
  if (hexData == null || hexData.isEmpty || hexData.length % 2 != 0) return null;
  final encrypted = _hexDecode(hexData);
  if (encrypted == null || encrypted.isEmpty) return null;

  final schedule = _tripledesDecryptSchedule(_qrcKey);
  final block = Uint8List(8);
  for (var i = 0; i + 8 <= encrypted.length; i += 8) {
    _desCrypt(Uint8List.sublistView(encrypted, i, i + 8), schedule[0], block);
    final mid = Uint8List(8);
    _desCrypt(block, schedule[1], mid);
    _desCrypt(mid, schedule[2], block);
    encrypted.setRange(i, i + 8, block);
  }

  final inflated = _inflateQrc(encrypted);
  if (inflated == null) return null;
  return utf8.decode(inflated, allowMalformed: true);
}

Uint8List? _hexDecode(String hex) {
  if (hex.length % 2 != 0) return null;
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    final value = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    if (value == null) return null;
    out[i] = value;
  }
  return out;
}

// ---------------------------------------------------------------------------
// QRC text parsing: the decrypted payload is an XML attribute; translation
// and romanization ride the same shape and are re-stamped against the main
// lyric's lines.
// ---------------------------------------------------------------------------

final RegExp _qrcLineTag = RegExp(r'^\[(\d+),\d+\]');
final RegExp _qrcLineTag2 = RegExp(r'^\[([\d:.]+)\]');
final RegExp _qrcWordTagAll = RegExp(r'(\(\d+,\d+\))');
final RegExp _qrcWordTag = RegExp(r'\((\d+),(\d+)\)');

String _qrcRemoveTag(String str) =>
    str.replaceFirst(RegExp(r'^[\S\s]*?LyricContent="'), '').replaceFirst(RegExp(r'"\/>[\S\s]*?$'), '');

String _qrcStamp(int totalMs) => _stamp(totalMs);

int _qrcIntervalMs(String interval) {
  var parts = interval.split(RegExp(r':|\.'));
  while (parts.length < 3) {
    parts = ['0', ...parts];
  }
  return int.parse(parts[0]) * 3600000 + int.parse(parts[1]) * 1000 + int.parse(parts[2]);
}

/// Splits a decrypted QRC payload into main/translation/romanization lines
/// stamped the same way; word tags come out as lx's `<startMs,duration>`.
DecodedLyric? parseQrc(String? rawLrc, String? rawTlrc, String? rawRlrc) {
  var lyric = '';
  var lxlyric = '';
  if (rawLrc != null && rawLrc.trim().isNotEmpty) {
    final parsed = _qrcParseLyric(_qrcRemoveTag(rawLrc));
    lyric = parsed.$1;
    lxlyric = parsed.$2;
  }
  if (lyric.isEmpty) return null;
  var translation = '';
  var romanization = '';
  if (rawTlrc != null && rawTlrc.trim().isNotEmpty) {
    translation = _qrcAlignTimeTags(rawTlrc, lyric);
  }
  if (rawRlrc != null && rawRlrc.trim().isNotEmpty) {
    final parsed = _qrcParseRlyric(_qrcRemoveTag(rawRlrc));
    romanization = _qrcAlignTimeTags(parsed, lyric);
  }
  return DecodedLyric(lyric: lxlyric, translation: translation, romanization: romanization);
}

(String, String) _qrcParseLyric(String raw) {
  final lrcLines = <String>[];
  final lxlrcLines = <String>[];
  for (var line in raw.trim().replaceAll('\r', '').split('\n')) {
    line = line.trim();
    final match = _qrcLineTag.firstMatch(line);
    if (match == null) {
      if (line.startsWith('[offset')) {
        lxlrcLines.add(line);
        lrcLines.add(line);
      }
      if (_qrcLineTag2.hasMatch(line)) {
        lrcLines.add(line);
      }
      continue;
    }
    final startMs = int.parse(match[1]!);
    final stamp = _qrcStamp(startMs);
    final words = line.replaceFirst(_qrcLineTag, '');
    lrcLines.add('$stamp${words.replaceAll(_qrcWordTagAll, '')}');

    final lxLine = StringBuffer(stamp);
    var last = 0;
    for (final time in _qrcWordTag.allMatches(words)) {
      final start = int.parse(time[1]!);
      final duration = int.parse(time[2]!);
      lxLine.write('${words.substring(last, time.start)}<${start - startMs < 0 ? 0 : start - startMs},$duration>');
      last = time.end;
    }
    lxLine.write(words.substring(last));
    lxlrcLines.add(lxLine.toString());
  }
  return (lrcLines.join('\n'), lxlrcLines.join('\n'));
}

String _qrcParseRlyric(String raw) {
  final lines = <String>[];
  for (var line in raw.trim().replaceAll('\r', '').split('\n')) {
    line = line.trim();
    final match = _qrcLineTag.firstMatch(line);
    if (match == null) continue;
    final stamp = _qrcStamp(int.parse(match[1]!));
    final words = line.replaceFirst(_qrcLineTag, '');
    lines.add('$stamp${words.replaceAll(_qrcWordTagAll, '')}');
  }
  return lines.join('\n');
}

/// Moves each translation/romanization line onto the main lyric's nearest
/// line stamp (within 100 ms), lx-music's `fixTlrcTimeTag`.
String _qrcAlignTimeTags(String raw, String mainLyric) {
  final mainLines = mainLyric.split('\n').toList();
  final out = <String>[];
  for (var line in raw.trim().replaceAll('\r', '').split('\n')) {
    line = line.trim();
    final match = _qrcLineTag2.firstMatch(line);
    if (match == null) continue;
    final words = line.replaceFirst(_qrcLineTag2, '');
    if (words.trim().isEmpty) continue;
    final timeMs = _qrcIntervalMs(match[1]!);
    while (mainLines.isNotEmpty) {
      final mainLine = mainLines.removeAt(0);
      final mainMatch = _qrcLineTag2.firstMatch(mainLine);
      if (mainMatch == null) continue;
      if ((timeMs - _qrcIntervalMs(mainMatch[1]!)).abs() < 100) {
        out.add(line.replaceFirst(_qrcLineTag2, mainMatch[0]!));
        break;
      }
    }
  }
  return out.join('\n');
}

// ---------------------------------------------------------------------------
// Netease yrc: word-timed lines `[startMs,durationMs]word(start,dur,0)...`.
// ---------------------------------------------------------------------------

final RegExp _yrcLineTag = RegExp(r'^\[(\d+),\d+\]');
final RegExp _yrcWordTagAll = RegExp(r'(\(\d+,\d+,\d+\))');
final RegExp _yrcWordTag = RegExp(r'\((\d+),(\d+),\d+\)');

/// Splits a yrc payload into plain lines and lx word tags.
DecodedLyric? parseYrc(String? rawLrc, String? rawTlrc, String? rawRlrc) {
  if (rawLrc == null || rawLrc.trim().isEmpty) return null;
  final lrcLines = <String>[];
  final lxlrcLines = <String>[];
  for (var line in rawLrc.trim().replaceAll('\r', '').split('\n')) {
    line = line.trim();
    final match = _yrcLineTag.firstMatch(line);
    if (match == null) {
      if (line.startsWith('[offset')) {
        lxlrcLines.add(line);
        lrcLines.add(line);
      }
      continue;
    }
    final startMs = int.parse(match[1]!);
    final stamp = _qrcStamp(startMs);
    final words = line.replaceFirst(_yrcLineTag, '');
    lrcLines.add('$stamp${words.replaceAll(_yrcWordTagAll, '')}');

    final lxLine = StringBuffer(stamp);
    var last = 0;
    for (final time in _yrcWordTag.allMatches(words)) {
      final start = int.parse(time[1]!);
      final duration = int.parse(time[2]!);
      lxLine.write('${words.substring(last, time.start)}<${start - startMs < 0 ? 0 : start - startMs},$duration>');
      last = time.end;
    }
    lxLine.write(words.substring(last));
    lxlrcLines.add(lxLine.toString());
  }
  if (lrcLines.isEmpty) return null;
  String? clean(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim().replaceAll('\r', '');
  }

  return DecodedLyric(lyric: lxlrcLines.join('\n'), translation: clean(rawTlrc), romanization: clean(rawRlrc));
}

// ---------------------------------------------------------------------------
// Migu MRC: a hex string whose 64-bit words ride one round of TEA, then the
// words come back as UTF-16LE text.
// ---------------------------------------------------------------------------

const int _teaDelta = 2654435769;
const List<int> _teaKey = [
  27303562373562475,
  18014862372307051,
  22799692160172081,
  34058940340699235,
  30962724186095721,
  27303523720101991,
  27303523720101998,
  31244139033526382,
  28992395054481524,
];

/// Reads 16 hex characters as one signed 64-bit word (Dart ints wrap, so the
/// halves only need joining).
int _mrcWord(String hex) {
  final high = int.parse(hex.substring(0, 8), radix: 16);
  final low = int.parse(hex.substring(8, 16), radix: 16);
  return (high << 32) | low;
}

List<int> _teaDecrypt(List<int> data) {
  final n = data.length;
  if (n < 1) return data;
  var y = data[0];
  var sum = (6 + 52 ~/ n) * _teaDelta;
  while (true) {
    final round = sum;
    if (round == 0) break;
    final e = (round >> 2) & 3;
    var p = n;
    while (true) {
      p--;
      if (p <= 0) break;
      final z = data[p - 1];
      y = data[p] - ((((y ^ round) + (z ^ _teaKey[(p & 3) ^ e])) ^ ((z >> 5) ^ (y << 2))) + ((y >> 3) ^ (z << 4)));
      data[p] = y;
    }
    final z = data[n - 1];
    y = data[0] - ((((_teaKey[(p & 3) ^ e] ^ z) + (y ^ round)) ^ ((z >> 5) ^ (y << 2))) + ((y >> 3) ^ (z << 4)));
    data[0] = y;
    sum = round - _teaDelta;
  }
  return data;
}

/// Decodes Migu's MRC payload to its word-timed text, or null when the
/// payload is too short to hold a lyric.
String? decryptMrc(String? data) {
  if (data == null || data.length < 32 || data.length % 16 != 0) return null;
  final words = [for (var i = 0; i < data.length ~/ 16; i++) _mrcWord(data.substring(i * 16, i * 16 + 16))];
  _teaDecrypt(words);
  final text = StringBuffer();
  for (final word in words) {
    for (var i = 0; i < 4; i++) {
      final unit = (word >> (16 * i)) & 0xFFFF;
      text.writeCharCode(unit);
    }
  }
  return text.toString();
}

final RegExp _mrcLineTag = RegExp(r'^\s*\[(\d+),\d+\]');
final RegExp _mrcWordTagAll = RegExp(r'(\(\d+,\d+\))');
final RegExp _mrcWordTag = RegExp(r'\((\d+),(\d+)\)');

/// Splits a decrypted MRC payload into plain lines and lx word tags.
DecodedLyric? parseMrc(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final lrcLines = <String>[];
  final lxlrcLines = <String>[];
  for (var line in raw.replaceAll('\r', '').split('\n')) {
    line = line.trim();
    if (line.length < 6) continue;
    final match = _mrcLineTag.firstMatch(line);
    if (match == null) continue;
    final startMs = int.parse(match[1]!);
    final stamp = _qrcStamp(startMs);
    final words = line.replaceFirst(_mrcLineTag, '');
    lrcLines.add('$stamp${words.replaceAll(_mrcWordTagAll, '')}');

    final lxLine = StringBuffer(stamp);
    var last = 0;
    for (final time in _mrcWordTag.allMatches(words)) {
      final start = int.parse(time[1]!);
      final duration = int.parse(time[2]!);
      lxLine.write('${words.substring(last, time.start)}<${start - startMs},$duration>');
      last = time.end;
    }
    lxLine.write(words.substring(last));
    lxlrcLines.add(lxLine.toString());
  }
  if (lrcLines.isEmpty) return null;
  return DecodedLyric(lyric: lxlrcLines.join('\n'));
}
