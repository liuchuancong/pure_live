// Dart port of hongguoTV's Signer + AesV3 (kotlin-tv/core), itself a port of
// drpys 22261ad; GPL-3.0-only. Emits only hash branch 0: the request ticket
// is adjusted until the branch lands there, exactly as the reference does.
// 32-bit integer arithmetic is kept in the unsigned 0x00000000–0xFFFFFFFF
// domain; every operation masks back into it.
import 'dart:convert' show base64Decode, base64Encode, utf8;
import 'dart:math' as math;
import 'dart:typed_data' show ByteData, Endian, Uint8List;
import 'dart:typed_data' show BytesBuilder;

import 'package:crypto/crypto.dart' as crypto show md5;
import 'package:pointycastle/export.dart' show AESEngine, CBCBlockCipher, KeyParameter, ParametersWithIV, SM3Digest;
import 'package:pure_live/modules/hongguo/official/hongguo_vendor.dart';

const int _mask32 = 0xFFFFFFFF;

int _add32(int a, int b) => (a + b) & _mask32;

// Kotlin's rotateLeft/rotateRight take the count modulo 32; a rotate amount
// above 31 must mask on its own, or `32 - n` goes negative and Dart's shift
// throws instead of rotating.
int _rol32(int v, int n) {
  final shift = n & 31;
  final value = v & _mask32;
  return shift == 0 ? value : ((value << shift) | (value >>> (32 - shift))) & _mask32;
}

int _ror32(int v, int n) {
  final shift = n & 31;
  final value = v & _mask32;
  return shift == 0 ? value : ((value >>> shift) | (value << (32 - shift))) & _mask32;
}

Uint8List _md5(List<int> data) => Uint8List.fromList(crypto.md5.convert(data).bytes);

Uint8List _sm3(List<int> data) {
  final digest = SM3Digest()..update(Uint8List.fromList(data), 0, data.length);
  final out = Uint8List(digest.digestSize);
  digest.doFinal(out, 0);
  return out;
}

Uint8List _hex(String value) =>
    Uint8List.fromList([for (var i = 0; i < value.length; i += 2) int.parse(value.substring(i, i + 2), radix: 16)]);

String _hexOf(List<int> bytes) => bytes.map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0')).join();

Uint8List _le32(int n) {
  final data = ByteData(4)..setUint32(0, n & _mask32, Endian.little);
  return data.buffer.asUint8List();
}

Uint8List _be32(int n) {
  final data = ByteData(4)..setUint32(0, n & _mask32);
  return data.buffer.asUint8List();
}

Uint8List _concat(List<List<int>> parts) {
  final out = Uint8List(parts.fold(0, (total, part) => total + part.length));
  var at = 0;
  for (final part in parts) {
    out.setRange(at, at + part.length, part);
    at += part.length;
  }
  return out;
}

/// One signed request: the URL to send, the headers to carry and the body.
final class HongguoSignedRequest {
  /// Creates the request.
  const HongguoSignedRequest({required this.url, required this.headers, this.body});

  /// The full URL, query signed in.
  final String url;

  /// The headers the platform expects, signature included.
  final Map<String, String> headers;

  /// The pre-encoded JSON body, or null on a GET.
  final Uint8List? body;
}

/// The protocol-specific AES the medusa header carries. Not standard AES:
/// the reference's own rounds over the vendor s-box.
final class HongguoAesV3 {
  /// Creates the cipher for [key] at [timestamp].
  HongguoAesV3(Uint8List key, int timestamp) {
    _word = timestamp & 3;
    final box = HongguoVendor.sbox;
    _box = [for (var i = _word * 256; i < (_word + 1) * 256; i++) box[i] & 0xFF];
    _con = const [
      [1, 0, 2, 3],
      [2, 0, 3, 1],
      [0, 1, 3, 2],
      [1, 0, 2, 3],
    ][_word];
    _order = const [
      [0, 9, 14, 11, 4, 13, 2, 7, 8, 1, 6, 15, 12, 5, 10, 3],
      [0, 9, 14, 15, 4, 13, 2, 7, 8, 1, 6, 3, 12, 5, 10, 11],
      [0, 9, 14, 7, 4, 13, 2, 11, 8, 1, 6, 3, 12, 5, 10, 15],
      [0, 9, 14, 11, 4, 13, 2, 7, 8, 1, 6, 15, 12, 5, 10, 3],
    ][_word];
    final initial = const [0xca025ddc, 0x823dc546, 0xc9420583, 0xc298225f][_word];
    final seed = _concat([_le32(initial), _le32(initial), _le32(initial), _le32(initial)]);
    final expanded = List<int>.generate(16 + 32, (i) => i < 16 ? (seed[i] ^ key[i % key.length]) & 0xFF : 0);
    var rounds = 8;
    for (var i = 4; i < 12; i++) {
      final at = 4 * (i - 1);
      var a = expanded[at];
      var b = expanded[at + 1];
      var c = expanded[at + 2];
      var d = expanded[at + 3];
      if (i % 4 == 0) {
        final t = ((initial >>> (rounds & 24)) ^ _box[b]) & 0xFF;
        b = _box[c];
        c = _box[d];
        d = _box[a];
        a = t;
      }
      rounds += 2;
      expanded[at + 4] = a ^ expanded[at - 12];
      expanded[at + 5] = b ^ expanded[at - 11];
      expanded[at + 6] = c ^ expanded[at - 10];
      expanded[at + 7] = d ^ expanded[at - 9];
    }
    _keys = [for (var i = 0; i < 12; i++) expanded.sublist(i * 4, i * 4 + 4)];
  }

  late final int _word;
  late final List<int> _box;
  late final List<int> _con;
  late final List<int> _order;
  late final List<List<int>> _keys;

  static int _xt(int x) => ((x << 1) ^ (x & 0x80 != 0 ? 0x1B : 0)) & 0xFF;

  Uint8List _block(Uint8List value) {
    final rows = List.generate(4, (i) => List.generate(4, (j) => value[i * 4 + j] & 0xFF));
    void addCon(int offset) {
      for (var i = 0; i < 4; i++) {
        for (var j = 0; j < 4; j++) {
          rows[i][j] = rows[i][j] ^ _keys[offset + i][_con[j]];
        }
      }
    }

    addCon(0);
    for (var round = 1; round <= 2; round++) {
      for (var i = 0; i < 4; i++) {
        for (var j = 0; j < 4; j++) {
          rows[i][j] = _box[rows[i][j]];
        }
      }
      final before = [for (final row in rows) List<int>.of(row)];
      for (var i = 0; i < 4; i++) {
        rows[i] = List<int>.of(before[_con[i]]);
      }
      final flat = [for (final row in rows) ...row];
      for (var i = 0; i < 16; i++) {
        rows[i ~/ 4][i % 4] = flat[_order[i]];
      }
      if (round == 1) {
        for (var i = 0; i < 4; i++) {
          final old = List<int>.of(rows[i]);
          rows[i] = [for (final c in _con) old[c]];
        }
        for (var i = 0; i < 4; i++) {
          final t = rows[0][i] ^ rows[1][i] ^ rows[2][i] ^ rows[3][i];
          final u = rows[0][i];
          rows[0][i] = rows[0][i] ^ t ^ _xt(rows[0][i] ^ rows[1][i]);
          rows[1][i] = rows[1][i] ^ t ^ _xt(rows[1][i] ^ rows[2][i]);
          rows[2][i] = rows[2][i] ^ t ^ _xt(rows[2][i] ^ rows[3][i]);
          rows[3][i] = rows[3][i] ^ t ^ _xt(rows[3][i] ^ u);
        }
      }
      addCon(round * 4);
    }
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 4; j++) {
        rows[i][j] = rows[i][j] ^ _keys[4 + i][j];
      }
    }
    return Uint8List.fromList([for (final row in rows) ...row]);
  }

  /// Encrypts [source] (at least 248 bytes) with the derived [iv].
  Uint8List encrypt(Uint8List source, Uint8List iv) {
    if (source.length < 248) {
      throw ArgumentError('AesV3 source too short');
    }
    final plaintext = Uint8List(32);
    for (var i = 0; i < 31; i++) {
      final at = i * 8;
      plaintext[i] =
          (((source[at] >>> 4) & 2) |
              (source[at + 1] & 64) |
              ((source[at + 2] >>> 2) & 1) |
              ((source[at + 3] << 3) & 128) |
              ((source[at + 4] >>> 1) & 4) |
              ((source[at + 5] << 3) & 16) |
              ((source[at + 6] << 5) & 32) |
              ((source[at + 7] >>> 4) & 8)) &
          0xFF;
    }
    plaintext[31] = 1;
    Uint8List xor(Uint8List a, Uint8List b) =>
        Uint8List.fromList([for (var i = 0; i < a.length; i++) a[i] ^ b[i % b.length]]);

    final first = _block(xor(plaintext.sublist(0, 16), iv));
    final key = _concat([first, _block(xor(plaintext.sublist(16, 32), first))]);
    final out = Uint8List.fromList(source);
    for (var i = 0; i < 31; i++) {
      final at = i * 8;
      final k = key[i] & 0xFF;
      out[at] = (out[at] & 0xDF) | ((k << 4) & 32);
      out[at + 1] = (out[at + 1] & 0xBF) | (k & 64);
      out[at + 2] = (out[at + 2] & 0xFB) | ((k << 2) & 4);
      out[at + 3] = (out[at + 3] & 0xEF) | ((k >>> 3) & 16);
      out[at + 4] = (out[at + 4] & 0xF7) | ((k + k) & 8);
      out[at + 5] = (out[at + 5] & 0xFD) | ((k >>> 3) & 2);
      out[at + 6] = (out[at + 6] & 0xFE) | ((k >>> 5) & 1);
      out[at + 7] = (out[at + 7] & 0x7F) | ((k << 4) & 128);
    }
    return _concat([
      Uint8List.fromList([key.last]),
      out,
    ]);
  }
}

/// The platform's request signer: one call answers the URL, the headers and
/// the body a signed endpoint expects.
final class HongguoSigner {
  /// Creates a signer; [random] seeds the signature's noise fields and
  /// [clock] the wall time, both so a test can pin the signature it expects.
  HongguoSigner({int Function()? random, Map<String, String>? device, int Function()? clock})
    : _random = random ?? (() => math.Random().nextInt(0x100000000)),
      _device = device ?? HongguoVendor.device,
      _now = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final int Function() _random;
  final Map<String, String> _device;
  final int Function() _now;

  int _rand() => _random() & _mask32;

  int _nowMs() => _now();

  static Uint8List _varint(int value) {
    var n = value;
    if (n < 0) n = -n; // sint values are pre-folded positive
    final out = <int>[];
    while (n > 127) {
      out.add((n & 127) | 128);
      n >>>= 7;
    }
    out.add(n);
    return Uint8List.fromList(out);
  }

  static Uint8List _proto(List<List<Object?>> fields) {
    final out = BytesBuilder();
    for (final field in fields) {
      final tag = field[0]! as int;
      final value = field[1];
      // Most fields are strings and carry no third slot; indexing [2] blindly
      // throws on those.
      final type = field.length > 2 ? (field[2] as String?) : null;
      if (type == 'sint') {
        final n = (value! as num).toInt();
        out
          ..add(_varint(tag << 3))
          ..add(_varint(n < 0 ? -n * 2 - 1 : n * 2));
      } else if (type == 'float') {
        out.add(_varint((tag << 3) | 5));
        final data = ByteData(4)..setFloat32(0, (value! as num).toDouble(), Endian.little);
        out.add(data.buffer.asUint8List());
      } else {
        final bytes = value is Uint8List ? value : Uint8List.fromList(utf8.encode(value.toString()));
        if (bytes.isNotEmpty) {
          out
            ..add(_varint((tag << 3) | 2))
            ..add(_varint(bytes.length))
            ..add(bytes);
        }
      }
    }
    return out.toBytes();
  }

  static int _getIv(int initial, List<int> data) {
    var value = initial & _mask32;
    for (var i = 0; i < data.length; i++) {
      final b = data[i] & 0xFF;
      // Plain left shifts here, not rotates: the reference masks them back
      // into 32 bits afterwards.
      value = i.isEven
          ? ((value >>> 4) ^ value ^ ((value << 6) & _mask32) ^ b) & _mask32
          : (~((value >>> 7) ^ value ^ (b | ((value << 12) & _mask32)))) & _mask32;
    }
    return value;
  }

  static int _iv(List<int> query, List<int> body, int ts) => _getIv(_getIv(_getIv(0x20230928, query), body), _le32(ts));

  int _branch(String query, Uint8List? body, int ts) {
    final bodyMd5 = body == null ? Uint8List(16) : _md5(body);
    return (_iv(_sm3(utf8.encode(query)), bodyMd5, ts) & 15) % 3;
  }

  static int _sumMd5(List<int> data) {
    var check = 0x20220420;
    for (var i = 0; i < 12; i++) {
      final temp = (check >>> (i.isEven ? 3 : 5)) ^ check;
      check = i.isEven
          ? ((data[i] & 0xFF) ^ ((check << 7) & _mask32)) & _mask32
          : (~(((data[i] & 0xFF) | ((check << 11) & _mask32)) & _mask32)) & _mask32;
      check = check ^ temp;
    }
    return ((check | 4) ^ 0x1000000) & _mask32;
  }

  static Uint8List _hashF13(Uint8List query, Uint8List body, int ts) {
    final ivAll = _iv(query, body, ts);
    if ((ivAll & 15) % 3 != 0) {
      throw StateError('Unsupported hash branch');
    }
    final index = (ivAll & 15) ~/ 3;
    final ivV1 = [0xc4a78580, 0xb3c0fd39, 0xc58c5686, 0xc9aa3ba7, 0xf5a7adf2, 0x963c2ed1][index];
    final count = _add32(ivV1, ts);
    final tt = [for (final value in HongguoVendor.hashTable) _ror32(value, (count + 1) & 255)];
    final shift = (count + 2) & 7;
    final pad = Uint8List.fromList([
      for (final it in [0xfa, 0x45, 0x61, 0xd7]) (((it | (it << 8)) & 0xFFFF) >>> shift) & 0xFF,
    ]);
    final data = _concat([query, body, _le32(ts), pad, _hex('00000000000001a0')]);
    // Unsigned, big-endian — the reference reads the schedule words that way;
    // little-endian signed signs extend every value.
    int i32At(int at) => ByteData.sublistView(data).getUint32(at);
    final di = <int>[for (var at = 0; at + 4 <= data.length; at += 4) i32At(at)];
    int rolSigned(int v, int n) => _rol32(v, n);
    for (var i = 0; i < 112; i++) {
      final x = di[i + 1];
      final y = di[i + 14];
      di.add(
        _add32(
          _add32(di[i], di[i + 9]),
          _add32(
            rolSigned(x, 14) ^ rolSigned(x, 25) ^ ((x >>> 3) & _mask32),
            rolSigned(y, 13) ^ rolSigned(y, 15) ^ ((y >>> 10) & _mask32),
          ),
        ),
      );
    }
    final initial = [
      for (final value in [
        0x7aba4fc8,
        0x67166507,
        0x6403fa00,
        0x340f512f,
        984304912,
        3005047866,
        2874125293,
        2152413264,
      ])
        _ror32(value, count),
    ];
    final chosen = [
      [101, 5, 7, 6, 3, 2, 1, 0, 5, 4, 3],
      [96, 0, 6, 7, 5, 3, 2, 1, 5, 4, 4],
      [96, 7, 6, 2, 1, 4, 0, 5, 4, 3, 5],
      [99, 3, 6, 2, 4, 5, 1, 0, 0, 7, 6],
      [96, 0, 5, 6, 7, 3, 1, 2, 5, 4, 4],
      [100, 2, 0, 3, 5, 4, 6, 7, 2, 1, 5],
    ][index];
    final d = List<int>.of(initial);
    for (var i = 0; i < chosen[0]; i++) {
      final base = _add32(ivV1, i);
      final n1 = (((d[chosen[3]] ^ d[chosen[4]]) & d[chosen[1]]) ^ d[chosen[3]]) & _mask32;
      final n2 = _rol32(d[chosen[1]], 26) ^ _rol32(d[chosen[1]], 21) ^ _rol32(d[chosen[1]], 7);
      final n4 = _add32(_add32(_add32(di[base & 127], n1), _add32(n2, _add32(tt[base & 63], d[chosen[5]]))), 0);
      final n5 = _rol32(d[chosen[2]], 30) ^ _rol32(d[chosen[2]], 19) ^ _rol32(d[chosen[2]], 10);
      final n6 = ((d[chosen[2]] & d[chosen[6]]) | ((d[chosen[2]] | d[chosen[6]]) & d[chosen[7]])) & _mask32;
      final old = d[chosen[9]];
      d.insert(0, d.removeAt(7));
      d[chosen[10]] = _add32(_add32(n5, n6), n4);
      d[chosen[8]] = _add32(old, n4);
    }
    final tail = <int>[];
    for (var i = 0; i < 8; i++) {
      final data = ByteData(4)..setUint32(0, _add32(d[i], initial[i]));
      tail.addAll(data.buffer.asUint8List());
    }
    final ret = Uint8List.fromList(tail);
    final folded = Uint8List.fromList([for (var i = 0; i < 16; i++) ret[i] ^ ret[i + 16]]);
    return _concat([folded, _le32(_sumMd5(folded))]);
  }

  String _gorgon(String query, Uint8List? body, int ts, int random) {
    final input = _concat([
      _md5(utf8.encode(query)).sublist(0, 4),
      if (body == null) Uint8List(4) else _md5(body).sublist(0, 4),
      Uint8List(4),
      _le32(67503104),
      _be32(ts),
    ]);
    final key = [0x4a, 0x40, 0x16, (random >>> 8) & 255, 0x47, 0x6c, 0x01, random & 255];
    final s = List<int>.generate(256, (i) => i);
    var j = 0;
    for (var i = 0; i <= 255; i++) {
      j = (j + s[i] + key[i % 8]) & 255;
      s[i] = s[j];
    }
    // The reference's swap loop reads s[i] with i starting at 1.
    j = 0;
    final out = Uint8List(input.length);
    for (var n = 0; n < input.length; n++) {
      final i = n + 1;
      j = (j + s[i]) & _mask32;
      final y = s[j & 255];
      s[i] = y;
      out[n] = (input[n] ^ s[(y + y) & 255]) & 0xFF;
    }
    for (var i = 0; i < out.length; i++) {
      final value = (((out[i] >>> 4) | (out[i] << 4)) & 0xFF) & _mask32;
      final next = out[i + 1 < out.length ? i + 1 : 0] & 0xFF;
      var reversed = 0;
      var bits = next ^ value;
      for (var b = 0; b < 8; b++) {
        reversed = (reversed << 1) | (bits & 1);
        bits >>>= 1;
      }
      out[i] = (~(reversed ^ 20)) & 0xFF;
    }
    return _hexOf(
      _concat([
        _hex('8404'),
        Uint8List.fromList([random & 0xFF, (random >>> 8) & 0xFF, 0x40, 0x01]),
        out,
      ]),
    );
  }

  Uint8List _deviceProto() => _proto([
    [1, 1, 'sint'],
    [2, 2, 'sint'],
    [3, '8662'],
    [4, _device['device_id'] ?? ''],
    [5, 'Ai6svO3PyrwDOUSmO6ZcResxu'],
    [6, '!noperm!'],
    [7, -888888, 'sint'],
    [8, -888888, 'sint'],
    [9, 3, 'sint'],
    [10, -888888, 'sint'],
    [11, '!notset!'],
    [12, 'Asia/Shanghai,8'],
    [13, 'zh_CN'],
    [14, 4, 'sint'],
    [16, 255.24993896484375, 'float'],
    [17, 35.58599090576172, 'float'],
    [18, 3.467449188232422, 'float'],
    [19, 3.467449188232422, 'float'],
    [20, 255.1754913330078, 'float'],
    [21, 42.17544174194336, 'float'],
    [22, '16'],
    [23, 41, 'sint'],
    [24, 36, 'sint'],
    [25, 1728388016635, 'sint'],
    [26, 1728388016635, 'sint'],
    [27, 1728388016635, 'sint'],
    [28, 1728388016637, 'sint'],
    [29, -1, 'sint'],
    [30, '25053RT47C'],
    [31, 'Redmi'],
    [32, '25053RT47C'],
    [33, '25053RT47C'],
    [34, 'Xiaomi'],
    [35, 'Redmi'],
    [36, 'Redmi'],
    [38, 31, 'sint'],
  ]);

  static Uint8List _xmXor(Uint8List data, Uint8List key) {
    final encoded = List<int>.filled(data.length, 0);
    for (var i = 0; i < data.length; i++) {
      final at = (i * 4) & 28;
      final d0 = key[at] & 0xFF;
      final d1 = key[at + 1] & 0xFF;
      final v = data[i] & 0xFF;
      var d2 = ((((v << 4) | (v >>> 4)) & 0xFF) + d0) & _mask32;
      d2 = (~d2 ^ d1) & _mask32;
      d2 = ((((d2 & 0xFF) << 3) | ((d2 & 0xFF) >>> 5)) & 0xFF) & _mask32;
      d2 = (d2 + d1) & _mask32;
      d2 = (d2 ^ d0) & 0xFF;
      encoded[data.length - i - 1] = (~d2) & 0xFF;
    }
    final last = encoded[encoded.length - 1] ^ encoded[encoded.length - 2];
    final first = encoded[0];
    encoded[0] = (~last + first) & 0xFF;
    encoded[1] = ((encoded[0] ^ encoded[encoded.length - 1] ^ 254) + encoded[1]) & 0xFF;
    encoded[2] = encoded[2] + ((last - first) ^ (((encoded[1] << 3) | (encoded[1] >>> 5)) & 0xFF) ^ 2) & 0xFF;
    for (var i = 0; i < encoded.length - 4; i++) {
      final temp = ((((encoded[i + 2] << 3) | (encoded[i + 2] >>> 5)) & 0xFF) ^ encoded[i + 1] ^ (i + 3)) & _mask32;
      encoded[i + 3] = ((~temp) + encoded[i + 3]) & 0xFF;
    }
    encoded[encoded.length - 1] = encoded[encoded.length - 1] ^ encoded[encoded.length - 2];
    var sum = 0;
    for (var i = 1; i < encoded.length; i++) {
      sum += encoded[i];
    }
    encoded[0] = ((encoded[0] ^ encoded[1]) + sum) & 0xFF;
    return Uint8List.fromList(encoded);
  }

  String _medusa(String url, Uint8List? body, int ts) {
    final bodyMd5 = body == null ? Uint8List(16) : _md5(body);
    final query = Uint8List.fromList(utf8.encode(url.substring(url.indexOf('?') + 1)));
    final querySm3 = _sm3(query);
    final queryBodyTs = _hashF13(querySm3, bodyMd5, ts);
    final nested = _proto([
      [1, 111, 'sint'],
      [2, 10, 'sint'],
      [3, 694367, 'sint'],
      [5, 586952199, 'sint'],
    ]);
    final messageRand = _rand();
    final envLaunch = (_randomDouble() * 21).toInt() + 100;
    final envPid = (_randomDouble() * 2000).toInt() + 10001;
    final version = _device['version_name'] ?? '';
    final clockSeconds = _nowMs() ~/ 1000;
    final env = _proto([
      [1, envLaunch, 'sint'],
      [2, 146331399, 'sint'],
      [3, 146331396, 'sint'],
      [5, 7, 'sint'],
      [6, 'v04.06.04.03-bugfix'],
      [7, envPid, 'sint'],
      [12, _deviceProto()],
      [
        13,
        _proto([
          [1, clockSeconds, 'sint'],
          [2, -2, 'sint'],
          [4, 200, 'sint'],
        ]),
      ],
      [14, version],
    ]);
    final queryHash = _sm3(_concat([query, bodyMd5, utf8.encode('none')]));
    final message = _proto([
      [1, _hex('f7e85ffad7d7dc3bd62ac87057cf6118')],
      [2, 3, 'sint'],
      [3, messageRand, 'sint'],
      [4, '8662'],
      [5, _device['device_id'] ?? ''],
      [6, '1588093228'],
      [7, version],
      [8, 'v04.06.04-ml-android'],
      [9, 67503104, 'sint'],
      [10, _hex('4001000000000000')],
      [12, ts, 'sint'],
      [13, queryBodyTs],
      [14, querySm3.sublist(0, 6)],
      [15, nested],
      [16, 'AXYQOS6n2m60x1fVZHIrH3iol'],
      [17, ts, 'sint'],
      [19, queryHash],
      [20, 'none'],
      [21, 312, 'sint'],
      [23, env],
      [
        24,
        '{"cmr":16777216,"cmr2":16777216,"un_h":1879194040,"vpn":0,"kd":0,"fkd":3672518972,"pd":-1872573247,"dyn":"","do":0,"tk":true}',
      ],
    ]);
    final r = _rand();
    final signKey = _hex('8ebdfa3806ecc5cee79423e6029ed82540bc2218bb7eaef71cb691f7aa8aa2f5');
    final hash = _sm3(_concat([signKey, _le32(r), signKey]));
    final d1 = (r >>> 16) & 255;
    final seedValue = (~(((d1 << 11) | (r >>> 24)) ^ (d1 >>> 5) ^ d1) & _mask32) & _mask32;
    final seed = _le32(seedValue);
    final xored = _xmXor(message, hash);
    final transformed = Uint8List.fromList(_concat([_hex('4001000000000000'), xored]).reversed.toList());
    for (var i = 0; i < transformed.length; i++) {
      transformed[i] = transformed[i] ^ seed[(~i) & 3];
    }
    final check = (((querySm3[0] & 63) << 14) | 0x18000001 | ((queryBodyTs[0] & 63) << 8)) & _mask32;
    final packed = _concat([
      Uint8List.fromList([0x35]),
      _le32(_rand()),
      _le32(check),
      transformed,
      Uint8List.fromList([(r >>> 16) & 0xFF, (r >>> 24) & 0xFF]),
    ]);
    final encrypted = HongguoAesV3(
      _hex('f1593376766ea98d34f31b057a9d5be4'),
      ts,
    ).encrypt(packed, _hex('1fe109a4125283f418de9e051a969e12'));
    final versionBytes = _hex('03000000f7e85ffad7d7dc3bd62ac87057cf6118');
    final prefix = BytesBuilder();
    for (var i = 0; i < 20; i += 4) {
      final word = ByteData.sublistView(versionBytes).getUint32(i, Endian.little);
      prefix.add(_le32(word ^ ts));
    }
    return base64Encode(
      _concat([
        prefix.toBytes(),
        Uint8List.fromList([r & 0xFF, (r >>> 8) & 0xFF, 0, 1]),
        encrypted,
      ]),
    );
  }

  double _randomDouble() => _random().toDouble() / 4294967296.0;

  String _helios(int ts) {
    final random = _rand();
    final ascii = utf8.encode(_hexOf(_md5(_concat([_le32(random), utf8.encode('8662')]))));
    int i64At(List<int> data, int at) => ByteData.sublistView(Uint8List.fromList(data)).getInt64(at, Endian.little);
    final words = <int>[for (var i = 0; i < 4; i++) i64At(ascii, i * 8)];
    final queue = List<int>.of(words);
    final table = <int>[queue[0]];
    var b0 = queue.removeAt(0);
    var b8 = queue.removeAt(0);
    int ror64(int v, int n) => (v >>> n) | (v << (64 - n));
    for (var i = 0; i < 34; i++) {
      var x8 = (ror64(b8, 8) + b0) ^ i;
      queue.add(x8);
      x8 = x8 ^ ror64(b0, 61);
      table.add(x8);
      b0 = x8;
      b8 = queue.removeAt(0);
    }
    final text = utf8.encode('$ts-1588093228-8662');
    final padding = 16 - text.length % 16;
    final data = Uint8List.fromList([...text, ...List.filled(padding, padding)]);
    final out = BytesBuilder()..add(_le32(random));
    for (var at = 0; at < data.length; at += 16) {
      var a = i64At(data, at);
      var b = i64At(data, at + 8);
      for (var i = 0; i < 34; i++) {
        b = table[i] ^ (a + ror64(b, 8));
        a = b ^ ror64(a, 61);
      }
      out
        ..add(_le64(a))
        ..add(_le64(b));
    }
    return base64Encode(out.toBytes());
  }

  static Uint8List _le64(int n) {
    final data = ByteData(8)..setInt64(0, n, Endian.little);
    return data.buffer.asUint8List();
  }

  /// Signs [base] with the query [values] and optional pre-encoded JSON
  /// [body], retrying the ticket until the hash branch the implementation
  /// covers appears.
  HongguoSignedRequest sign(String base, Map<String, String> values, {Uint8List? body}) {
    final now = _nowMs();
    final ts = (now ~/ 1000) & _mask32;
    for (var offset = 0; offset <= 127; offset++) {
      final ticket = now + offset;
      final query = encodeValues({...values, 'ts': '$ts', '_rticket': '$ticket'});
      if (_branch(query, body, ts) != 0) continue;
      final url = '$base?$query';
      final random = (_randomDouble() * 65536).toInt();
      final headers = <String, String>{
        'User-Agent': body == null ? HongguoVendor.appUa : HongguoVendor.videoUa,
        'Accept': 'application/json; charset=utf-8,application/x-protobuf',
        'x-ss-req-ticket': '$ticket',
        'x-tt-request-tag': 't=0;n=0',
        'sdk-version': '2',
        'passport-sdk-version': '50561',
        'x-xs-from-web': '0',
        'x-khronos': '$ts',
        'x-ladon': base64Encode(_be32(ts)),
        'x-argus': base64Encode(_le32(ts)),
        'x-gorgon': _gorgon(query, body, ts, random),
        'x-helios': _helios(ts),
        'x-medusa': _medusa(url, body, ts),
        'x-tt-dt': '',
      };
      if (body != null) {
        headers['Content-Type'] = 'application/json; charset=UTF-8';
        headers['x-vc-bdturing-sdk-version'] = '3.7.2.cn';
        headers['x-ss-stub'] = _hexOf(_md5(body)).toUpperCase();
      }
      return HongguoSignedRequest(url: url, headers: headers, body: body);
    }
    throw StateError('无法生成请求签名');
  }

  /// Query encoding, `+` as `%20` and `~` kept, as the platform expects.
  static String encodeValue(String value) =>
      Uri.encodeQueryComponent(value).replaceAll('+', '%20').replaceAll('%7E', '~').replaceAll('%7e', '~');

  /// Encodes a whole query string.
  static String encodeValues(Map<String, String> values) =>
      values.entries.map((entry) => '${encodeValue(entry.key)}=${encodeValue(entry.value)}').join('&');
}

/// AES-128-CBC with no padding, over 16-byte aligned input.
Uint8List hongguoAesCbc(Uint8List key, Uint8List iv, Uint8List data, {required bool decrypt}) {
  // PointyCastle's flag is `forEncryption`, the opposite of [decrypt].
  final cipher = CBCBlockCipher(AESEngine())..init(!decrypt, ParametersWithIV(KeyParameter(key), iv));
  final out = Uint8List(data.length);
  for (var at = 0; at < data.length; at += 16) {
    cipher.processBlock(data, at, out, at);
  }
  return out;
}

/// Decodes the reference's base64 (URL-safe tolerated).
Uint8List hongguoDecode64(String value) {
  final buffer = StringBuffer(value.replaceAll('-', '+').replaceAll('_', '/'));
  while (buffer.length % 4 != 0) {
    buffer.write('=');
  }
  return base64Decode(buffer.toString());
}
