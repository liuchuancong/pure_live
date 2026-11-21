import 'dart:convert' show base64Encode, utf8;
import 'dart:typed_data' show ByteData, Uint8List;

import 'package:crypto/crypto.dart' as crypto show sha512;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart' show AESEngine, CTRStreamCipher, KeyParameter, ParametersWithIV;
import 'package:pure_live/modules/hongguo/official/hongguo_media_crypto.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_signer.dart' show hongguoAesCbc;

/// The media's own arithmetic, argued over hand-built bytes: a `spade_a`
/// yields the hex key its body spells, the legacy URL envelope opens to the
/// address it carried, the mp4's moov edge is found or refused, and the
/// CENC sample map — whole samples and sub-sample leads — decrypts in
/// place and in ranges, refusing the maps that overlap or lost their saio.
void main() {
  const keyHex = '00112233445566778899aabbccddeeff';
  final key = _hexBytes(keyHex);
  final iv1 = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 1]);
  final iv2 = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 2]);

  group('the content key', () {
    test('a spade_a yields the hex key its body spells, twice the same', () {
      final spade = _spadeFor(keyHex);
      expect(HongguoMediaCrypto.deriveKey(spade), key);
      expect(HongguoMediaCrypto.deriveKey(spade), key); // the walk is deterministic
    });

    test('a spade_a too short or too sparse throws', () {
      expect(() => HongguoMediaCrypto.deriveKey(base64Encode([1])), throwsA(_format('内容密钥格式异常')));
      expect(
        () => HongguoMediaCrypto.deriveKey(base64Encode(List<int>.filled(41, 255))),
        throwsA(_format('内容密钥格式异常')), // the xor triple eats the whole body
      );
    });

    test('a body that spells no hex fails plainly', () {
      expect(
        () => HongguoMediaCrypto.deriveKey(_spadeFor('zz112233445566778899aabbccddeeff')),
        throwsA(isA<FormatException>()), // int.parse's own complaint
      );
    });
  });

  group('the url envelope', () {
    final seed = Uint8List.fromList(utf8.encode('seed-1'));
    const url = 'https://cdn.example/live.m3u8?sign=abc';

    Uint8List bodyOf(String url, {required bool zeroPad}) {
      final hashed = crypto.sha512.convert([...crypto.sha512.convert(seed).bytes, ...HongguoMediaCrypto.kdfSalt]).bytes;
      final plain = utf8.encode(url);
      final pad = 16 - plain.length % 16;
      final filler = zeroPad ? List<int>.filled(pad, 0) : List<int>.filled(pad, pad);
      final padded = Uint8List.fromList([...plain, ...filler]);
      return hongguoAesCbc(
        Uint8List.fromList(hashed.sublist(0, 16)),
        Uint8List.fromList(hashed.sublist(16, 32)),
        padded,
        decrypt: false,
      );
    }

    String envelope(
      String url, {
      List<int> magic = const [0xA8, 0x42, 0x01, 0x00],
      bool zeroPad = false,
      List<int> trailer = const [],
    }) => base64Encode([...magic, ...bodyOf(url, zeroPad: zeroPad), ...trailer]);

    test('the envelope opens to the url it carried, junk and all', () {
      expect(HongguoMediaCrypto.decryptUrl(envelope(url), seed), url);
      expect(HongguoMediaCrypto.decryptUrl(envelope(url, trailer: [1, 2, 3]), seed), url); // past the blocks: ignored
    });

    test('zeros pad the tail too, and a wrong magic or short raw refuses', () {
      expect(HongguoMediaCrypto.decryptUrl(envelope(url, zeroPad: true), seed), url); // the zeros strip away
      expect(
        () => HongguoMediaCrypto.decryptUrl(envelope(url, magic: [0x11, 0x42, 0x01, 0x00]), seed),
        throwsA(_format('播放地址格式异常')),
      );
      expect(
        () => HongguoMediaCrypto.decryptUrl(base64Encode(List<int>.filled(12, 7)), seed),
        throwsA(_format('播放地址格式异常')),
      );
    });
  });

  group("the header's edge", () {
    final ftyp = _box('ftyp', _chars('isom2024'));

    test('the moov riding the ftyp names its end', () {
      final first = _cat([ftyp, _u32(40), _chars('moov'), Uint8List(40)]);
      expect(HongguoMediaCrypto.headerEnd(first, 200), 56); // ftyp's sixteen plus the moov's forty
    });

    test('a header without a leading moov refuses', () {
      expect(() => HongguoMediaCrypto.headerEnd(_box('mdat', _chars('junk')), 200), throwsA(_format('不支持的视频容器')));
      expect(
        () => HongguoMediaCrypto.headerEnd(_cat([ftyp, _u32(40), _chars('mdat')]), 200),
        throwsA(_format('视频索引不在文件开头')),
      );
      expect(
        () => HongguoMediaCrypto.headerEnd(_cat([ftyp, _u32(40), _chars('moov'), Uint8List(40)]), 50),
        throwsA(_format('视频索引大小异常')),
      ); // the moov outgrows the file
      expect(
        () => HongguoMediaCrypto.headerEnd(_cat([ftyp, _u32(4), _chars('moov')]), 200),
        throwsA(_format('视频索引大小异常')),
      );
    });
  });

  group('the sample map', () {
    test('prepare reads the samples and dresses the header plainly', () {
      final built = _mp4(sizes: [100, 60], perChunk: [2], offsets: [2000], auxSizes: [8, 8], aux: [...iv1, ...iv2]);
      final prepared = HongguoMediaCrypto.prepare(built.data, key);

      expect(prepared.samples, hasLength(2));
      expect(prepared.samples[0].start, 2000);
      expect(prepared.samples[0].end, 2100);
      expect(prepared.samples[0].iv.sublist(0, 8), iv1);
      expect(prepared.samples[1].start, 2100);
      expect(prepared.samples[1].end, 2160);
      expect(prepared.samples[1].iv.sublist(0, 8), iv2);
      expect(prepared.samples[0].encryptedOffset, 0);

      // The codec fourcc came back from frma and the sinf wrapper went blank.
      final raw = String.fromCharCodes(built.data);
      final dressed = String.fromCharCodes(prepared.header);
      final encvAt = raw.indexOf('encv');
      final sinfAt = encvAt + 8; // the sinf box rides right behind the encv fourcc
      expect(encvAt, greaterThan(0));
      expect(dressed.substring(encvAt, encvAt + 4), 'avc1');
      expect(dressed.substring(sinfAt, sinfAt + 4), 'free');
      for (var i = sinfAt + 4; i < sinfAt + 16; i++) {
        expect(prepared.header[i], 0, reason: 'the sinf body is blanked');
      }
      expect(dressed, isNot(contains('encv')));
      expect(dressed, isNot(contains('sinf')));
    });

    test('a null key passes the bytes through with no map', () {
      final built = _mp4(sizes: [100, 60], perChunk: [2], offsets: [2000], auxSizes: [8, 8], aux: [...iv1, ...iv2]);
      final prepared = HongguoMediaCrypto.prepare(built.data, null);
      expect(prepared.header, built.data);
      expect(prepared.samples, isEmpty);
    });

    test('a whole read decrypts both samples and keeps the clear lead clear', () {
      final built = _mp4(sizes: [100, 60], perChunk: [2], offsets: [2000], auxSizes: [8, 8], aux: [...iv1, ...iv2]);
      final plain0 = List<int>.generate(100, (i) => 0x10 + i);
      final plain1 = List<int>.generate(60, (i) => 0x60 + i);
      final file = _cat([
        built.data,
        Uint8List(2000 - built.data.length)..fillRange(0, 2000 - built.data.length, 0xAA),
        _ctrBytes(key, iv1, plain0),
        _ctrBytes(key, iv2, plain1),
      ]);
      final prepared = HongguoMediaCrypto.prepare(built.data, key);

      final out = HongguoMediaCrypto.decrypt(file, 0, key, prepared);
      expect(out.sublist(0, built.data.length), prepared.header); // the dressed header rides along
      expect(out[1500], 0xAA); // the untouched middle stayed
      expect(out.sublist(2000, 2100), Uint8List.fromList(plain0));
      expect(out.sublist(2100, 2160), Uint8List.fromList(plain1));
    });

    test('a subsample clears its lead and resumes the cipher stream', () {
      final built = _mp4(
        sizes: [100, 60],
        perChunk: [2],
        offsets: [2000],
        auxSizes: [16, 8],
        aux: [...iv1, 0, 1, 0, 20, 0, 0, 0, 80, ...iv2], // one sub-sample: twenty clear, eighty ciphered
      );
      final prepared = HongguoMediaCrypto.prepare(built.data, key);
      expect(prepared.samples, hasLength(2));
      expect(prepared.samples[0].start, 2020); // the clear lead stays outside the map
      expect(prepared.samples[0].end, 2100);
      expect(prepared.samples[1].start, 2100);

      final plain0 = List<int>.generate(100, (i) => 0x10 + i);
      final plain1 = List<int>.generate(60, (i) => 0x60 + i);
      final file = _cat([
        built.data,
        Uint8List(2000 - built.data.length)..fillRange(0, 2000 - built.data.length, 0xAA),
        Uint8List.fromList(plain0.sublist(0, 20)), // the lead the reader sees plainly
        _ctrBytes(key, iv1, plain0.sublist(20)),
        _ctrBytes(key, iv2, plain1),
      ]);
      final out = HongguoMediaCrypto.decrypt(file, 0, key, prepared);
      expect(out.sublist(2000, 2020), Uint8List.fromList(plain0.sublist(0, 20)));
      expect(out.sublist(2020, 2100), Uint8List.fromList(plain0.sublist(20)));
      expect(out.sublist(2100, 2160), Uint8List.fromList(plain1));
    });

    test('a range decrypt matches the whole read its bytes came from', () {
      final built = _mp4(sizes: [100, 60], perChunk: [2], offsets: [2000], auxSizes: [8, 8], aux: [...iv1, ...iv2]);
      final plain0 = List<int>.generate(100, (i) => 0x10 + i);
      final plain1 = List<int>.generate(60, (i) => 0x60 + i);
      final file = _cat([
        built.data,
        Uint8List(2000 - built.data.length)..fillRange(0, 2000 - built.data.length, 0xAA),
        _ctrBytes(key, iv1, plain0),
        _ctrBytes(key, iv2, plain1),
        Uint8List(32)..fillRange(0, 32, 0xBB), // past the last sample
      ]);
      final prepared = HongguoMediaCrypto.prepare(built.data, key);

      final whole = HongguoMediaCrypto.decrypt(file, 0, key, prepared);
      final slice = HongguoMediaCrypto.decrypt(file.sublist(2050, 2120), 2050, key, prepared); // straddles both
      expect(slice, whole.sublist(2050, 2120));

      final tail = HongguoMediaCrypto.decrypt(file.sublist(2160), 2160, key, prepared);
      expect(tail, file.sublist(2160)); // no sample touches the tail
      final head = HongguoMediaCrypto.decrypt(file.sublist(0, 100), 0, key, prepared);
      expect(head, prepared.header.sublist(0, 100)); // the header region only dresses
    });

    test('a lost saio, an overlapping map and a headless moov refuse', () {
      final missing = _mp4(
        sizes: [100, 60],
        perChunk: [2],
        offsets: [2000],
        auxSizes: [8, 8],
        aux: [...iv1, ...iv2],
        withSaio: false,
      );
      expect(() => HongguoMediaCrypto.prepare(missing.data, key), throwsA(_format('视频加密索引缺失')));

      final overlap = _mp4(
        sizes: [100, 100],
        perChunk: [1, 1],
        offsets: [2000, 2050],
        auxSizes: [8, 8],
        aux: [...iv1, ...iv2],
      );
      expect(() => HongguoMediaCrypto.prepare(overlap.data, key), throwsA(_format('视频样本重叠')));

      final bare = Uint8List.fromList(_box('ftyp', _chars('isom2024')));
      expect(() => HongguoMediaCrypto.prepare(bare, key), throwsA(_format('视频索引不完整')));
    });
  });
}

Matcher _format(String message) => isA<FormatException>().having((error) => error.message, 'message', message);

int _popcount(int value) {
  var count = 0;
  var v = value;
  while (v != 0) {
    v &= v - 1;
    count++;
  }
  return count;
}

Uint8List _hexBytes(String value) =>
    Uint8List.fromList([for (var i = 0; i < value.length; i += 2) int.parse(value.substring(i, i + 2), radix: 16)]);

Uint8List _chars(String value) => Uint8List.fromList(utf8.encode(value));

Uint8List _u32(int value) {
  final out = Uint8List(4);
  ByteData.sublistView(out).setUint32(0, value);
  return out;
}

Uint8List _cat(List<Uint8List> parts) {
  final total = parts.fold<int>(0, (sum, part) => sum + part.length);
  final out = Uint8List(total);
  var at = 0;
  for (final part in parts) {
    out.setRange(at, at + part.length, part);
    at += part.length;
  }
  return out;
}

Uint8List _box(String type, List<int> payload) =>
    _cat([_u32(8 + payload.length), _chars(type), Uint8List.fromList(payload)]);

/// Builds a `spade_a` whose derived content key is exactly [hex] — the
/// scramble run backwards from the wanted key bytes.
String _spadeFor(String hex) {
  const length = 40;
  final target = utf8.encode(hex);
  final old = List<int>.filled(length, 0);
  var a = 85;
  var b = 246;
  for (var i = 0; i < length; i++) {
    final wanted = i >= 1 && i < 33 ? target[i - 1] : 0;
    final previous = i.isOdd ? a : b;
    old[i] = previous ^ ((wanted + 21 + _popcount(i)) & 0xFF);
    if (i.isOdd) {
      a = old[i];
    } else {
      b = old[i];
    }
  }
  final raw = Uint8List(1 + length);
  raw[0] = 6 ^ old[0] ^ old[1]; // the xor triple pins the length at forty
  raw.setRange(1, 1 + length, old); // raw[1] and raw[2] open the walk
  return base64Encode(raw);
}

/// Builds an encrypted header: ftyp, a moov holding one trak whose stbl
/// carries the CENC boxes, then the aux-info blob the saio points at.
({Uint8List header, Uint8List data}) _mp4({
  required List<int> sizes,
  required List<int> perChunk,
  required List<int> offsets,
  required List<int> auxSizes,
  required List<int> aux,
  bool withSaio = true,
}) {
  Uint8List build(int auxAt) => _cat([
    _box('ftyp', _chars('isom2024')),
    _box(
      'moov',
      _box(
        'trak',
        _box('stbl', [
          ..._box('stsz', [
            0, 0, 0, 0, // flags
            ..._u32(0), // no default size: the sizes follow
            ..._u32(sizes.length),
            for (final size in sizes) ..._u32(size),
          ]),
          ..._box('stsc', [
            0,
            0,
            0,
            0,
            ..._u32(perChunk.length),
            for (var i = 0; i < perChunk.length; i++) ...[..._u32(i + 1), ..._u32(perChunk[i]), ..._u32(1)],
          ]),
          ..._box('stco', [0, 0, 0, 0, ..._u32(offsets.length), for (final offset in offsets) ..._u32(offset)]),
          ..._box('saiz', [0, 0, 0, 0, 0, ..._u32(auxSizes.length), ...auxSizes]),
          if (withSaio) ..._box('saio', [0, 0, 0, 0, ..._u32(1), ..._u32(auxAt)]),
          ..._box('encv', _box('sinf', _box('frma', _chars('avc1')))),
        ]),
      ),
    ),
  ]);

  final auxAt = build(0).length; // the aux blob rides right behind the moov
  return (header: build(auxAt), data: _cat([build(auxAt), Uint8List.fromList(aux)]));
}

Uint8List _ctrBytes(Uint8List key, Uint8List iv8, List<int> plain) {
  final iv = Uint8List(16)..setRange(0, 8, iv8);
  final cipher = CTRStreamCipher(AESEngine())..init(false, ParametersWithIV(KeyParameter(key), iv));
  return cipher.process(Uint8List.fromList(plain));
}
