/// Douyin request signing in pure Dart: msToken, `a_bogus` (the signed API
/// requests) and the `X-Bogus` style signature of the danmaku connection.
///
/// The algorithms, tables and alphabets are kept bit for bit; time, the
/// random draws and the simulated browser window are injectable so a
/// signature is reproducible in a test, and the cipher table is copied for
/// every signature (a signer is reusable). SM3 (GB/T 32905-2016) is
/// implemented here rather than pulled from a package, because the package
/// is not a dependency of this one. The caller's parameter map is never
/// modified.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_endpoints.dart';
import 'package:meta/meta.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Signs Douyin web requests.
final class DouyinSigner {
  /// A signer for [userAgent], which must be the exact UA the signed requests
  /// are sent with (`a_bogus` encodes it). [fingerprint] is the simulated
  /// browser window (default: random, fixed for this signer); [now] and
  /// [random] are injectable for tests.
  factory DouyinSigner({required String userAgent, String? fingerprint, DateTime Function()? now, Random? random}) {
    final source = random ?? Random.secure();
    return DouyinSigner._(userAgent, fingerprint ?? browserFingerprint(source), now ?? DateTime.now, source);
  }

  DouyinSigner._(this.userAgent, this.fingerprint, this._now, this._random);

  /// The UA encoded into every a_bogus.
  final String userAgent;

  /// `innerW|innerH|outerW|outerH|0|screenY|0|0|sizeW|sizeH|availW|availH|innerW|innerH|24|24|Win32`.
  final String fingerprint;

  final DateTime Function() _now;
  final Random _random;

  static const _msTokenAlphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789=';

  /// A random msToken: [length] characters of `A–Z a–z 0–9 =` (not a
  /// server-issued token; Douyin's web client generates it locally).
  String msToken({int length = 184}) {
    if (length < 0) throw ArgumentError.value(length, 'length');
    return List.generate(length, (_) => _msTokenAlphabet[_random.nextInt(_msTokenAlphabet.length)]).join();
  }

  /// The signed URL of [base] with [params] (copied): the base's query plus
  /// the params plus the fixed browser parameters plus an msToken unless one
  /// is given, form-encoded as the query `Q`; the result's query becomes
  /// `Q&a_bogus=…`, the signature last, as its alphabet needs no encoding.
  Uri signedUrl(Uri base, Map<String, String> params) {
    final all = <String, String>{...base.queryParameters, ...params};
    all['aid'] = DouyinEndpoints.aid;
    all['compress'] = 'gzip';
    all['device_platform'] = 'web';
    all['browser_language'] = 'zh-CN';
    all['browser_platform'] = 'Win32';
    all['browser_name'] = 'Edge';
    all['browser_version'] = '125.0.0.0';
    all.putIfAbsent('msToken', msToken);
    final query = Uri(queryParameters: all).query;
    return base.replace(query: '$query&a_bogus=${aBogus(query)}');
  }

  /// The a_bogus of the query string [query] and request [body] (empty for a
  /// GET).
  ///
  /// SM3 twice over the salted query and body, SM3 of the RC4-encrypted UA,
  /// the clock before and after, the options, aid and page id and the
  /// fingerprint are laid out in the field order below, followed by an XOR
  /// check byte; the bytes go through the stream cipher and, behind a 12-byte
  /// random prefix, into the custom base64. Fields 24 and 25 (the timestamps'
  /// high bytes) are 0, which masks the timestamp to 32 bits.
  String aBogus(String query, {String body = ''}) {
    final start = _now().millisecondsSinceEpoch;
    final paramsHash = _sm3(_sm3(utf8.encode('$query$_salt')));
    final bodyHash = _sm3(_sm3(utf8.encode('$body$_salt')));
    final uaHash = _sm3(utf8.encode(_base64(_rc4(_uaKey, userAgent.codeUnits), _alphabet1)));
    final end = _now().millisecondsSinceEpoch;

    final fields = <int, int>{
      8: 3,
      18: 44,
      66: 0,
      69: 0,
      70: 0,
      71: 0,
      20: (start >> 24) & 255,
      21: (start >> 16) & 255,
      22: (start >> 8) & 255,
      23: start & 255,
      24: 0,
      25: 0,
      26: (_options[0] >> 24) & 255,
      27: (_options[0] >> 16) & 255,
      28: (_options[0] >> 8) & 255,
      29: _options[0] & 255,
      30: (_options[1] ~/ 256) & 255,
      31: (_options[1] % 256) & 255,
      32: (_options[1] >> 24) & 255,
      33: (_options[1] >> 16) & 255,
      34: (_options[2] >> 24) & 255,
      35: (_options[2] >> 16) & 255,
      36: (_options[2] >> 8) & 255,
      37: _options[2] & 255,
      38: paramsHash[21],
      39: paramsHash[22],
      40: bodyHash[21],
      41: bodyHash[22],
      42: uaHash[23],
      43: uaHash[24],
      44: (end >> 24) & 255,
      45: (end >> 16) & 255,
      46: (end >> 8) & 255,
      47: end & 255,
      48: 3,
      49: 0,
      50: 0,
      51: (_pageId >> 24) & 255,
      52: (_pageId >> 16) & 255,
      53: (_pageId >> 8) & 255,
      54: _pageId & 255,
      55: _pageId,
      56: _aid,
      57: _aid & 255,
      58: (_aid >> 8) & 255,
      59: (_aid >> 16) & 255,
      60: (_aid >> 24) & 255,
      64: fingerprint.length,
      65: fingerprint.length,
    };
    final values = [for (final index in _order) fields[index] ?? 0, ...fingerprint.codeUnits];
    var check = 0;
    for (final index in _checkOrder) {
      check ^= fields[index] ?? 0;
    }
    values.add(check);
    return _encode([..._randomPrefix(), ..._transform(values)]);
  }

  /// The danmaku connection's `signature` for this broadcast's [roomId] and
  /// the visitor's [userUniqueId]: the X-Bogus of the MD5 of the fixed
  /// parameter string. Its alphabet has `+` and `/`, so it must be sent
  /// percent-encoded.
  String danmakuSignature({required String roomId, required String userUniqueId}) {
    final stub = [
      'live_id=1',
      'aid=${DouyinEndpoints.aid}',
      'version_code=${DouyinEndpoints.versionCode}',
      'webcast_sdk_version=${DouyinEndpoints.sdkVersion}',
      'room_id=$roomId',
      'sub_room_id=',
      'sub_channel_id=',
      'did_rule=3',
      'user_unique_id=$userUniqueId',
      'device_platform=web',
      'device_type=',
      'ac=',
      'identity=audience',
    ].join(',');
    return xBogus(md5.convert(utf8.encode(stub)).toString());
  }

  /// The X-Bogus of [msStub] (32 hex digits): two random bytes, the last two
  /// bytes of the MD5 of those 16 bytes spelled, a 10-byte payload with an
  /// XOR check byte RC4-encrypted under the second random byte, all 12 bytes
  /// in the X-Bogus base64 alphabet.
  String xBogus(String msStub, {int counter = 1}) {
    if (!RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(msStub)) {
      throw ArgumentError.value(msStub, 'msStub', 'expected 32 hex digits');
    }
    final random1 = _random.nextInt(256);
    final random2 = _random.nextInt(255);
    final digest = md5.convert([
      for (var i = 0; i < 16; i++) int.parse(msStub.substring(i * 2, i * 2 + 2), radix: 16),
    ]).bytes;
    final payload = [counter & 0x3f, 0, 1, 0x0e, 0x45, 0x3f, digest[14], digest[15], random2, 0];
    for (var i = 0; i < 9; i++) {
      payload[9] ^= payload[i];
    }
    final encrypted = _rc4([random2], payload);
    final bytes = [0x40 | (random1 & 0x1f), random2, ...encrypted];
    final out = StringBuffer();
    for (var i = 0; i < bytes.length; i += 3) {
      final n = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
      for (var j = 0; j < 4; j++) {
        out.write(_xBogusAlphabet[(n >> (18 - 6 * j)) & 0x3f]);
      }
    }
    return out.toString();
  }

  /// A visitor id like the web client's (`user_unique_id`): `7`, a digit 3–9
  /// and 17 more digits, 7.3e18 up to 8e18.
  static String visitorId(Random random) =>
      ['7', '${3 + random.nextInt(7)}', for (var i = 0; i < 17; i++) '${random.nextInt(10)}'].join();

  /// A browser window drawn from the web client's ranges.
  static String browserFingerprint(Random random) {
    int between(int low, int high) => low + random.nextInt(high - low + 1);
    final innerWidth = between(1024, 1920);
    final innerHeight = between(768, 1080);
    final outerWidth = innerWidth + between(24, 32);
    final outerHeight = innerHeight + between(75, 90);
    final screenY = const [0, 30][random.nextInt(2)];
    final sizeWidth = between(1024, 1920);
    final sizeHeight = between(768, 1080);
    final availWidth = between(1280, 1920);
    final availHeight = between(800, 1080);
    return '$innerWidth|$innerHeight|$outerWidth|$outerHeight|0|$screenY|0|0|$sizeWidth|$sizeHeight|'
        '$availWidth|$availHeight|$innerWidth|$innerHeight|24|24|Win32';
  }

  /// Three groups of four bytes, each from one 0–9999 draw.
  List<int> _randomPrefix() {
    final prefix = <int>[];
    for (var group = 0; group < 3; group++) {
      final value = _random.nextInt(10000);
      prefix.addAll([
        (value & 255 & 170) | 1,
        (value & 255 & 85) | 2,
        ((value >> 8) & 170) | 5,
        ((value >> 8) & 85) | 40,
      ]);
    }
    return prefix;
  }

  /// The stream cipher; every signature starts from the initial table.
  static List<int> _transform(List<int> bytes) {
    final table = List<int>.of(_table);
    final length = table.length;
    final output = <int>[];
    var indexB = table[1];
    var initial = 0;
    var valueE = 0;
    for (var index = 0; index < bytes.length; index++) {
      int sum;
      if (index == 0) {
        initial = table[indexB];
        sum = indexB + initial;
        table[1] = initial;
        table[indexB] = indexB;
      } else {
        sum = initial + valueE;
      }
      output.add(bytes[index] ^ table[sum % length]);
      final next = (index + 2) % length;
      valueE = table[next];
      sum = (indexB + valueE) % length;
      initial = table[sum];
      table[sum] = table[next];
      table[next] = initial;
      indexB = sum;
    }
    return output;
  }

  /// Base64 with alphabet 0, `=` padded to a multiple of four.
  static String _encode(List<int> bytes) {
    final out = StringBuffer();
    var count = 0;
    for (var i = 0; i < bytes.length; i += 3) {
      final remaining = bytes.length - i;
      final n = (bytes[i] << 16) | (remaining > 1 ? bytes[i + 1] << 8 : 0) | (remaining > 2 ? bytes[i + 2] : 0);
      final chars = remaining > 2 ? 4 : remaining + 1;
      for (var j = 0; j < chars; j++) {
        out.write(_alphabet0[(n >> (18 - 6 * j)) & 0x3f]);
        count++;
      }
    }
    out.write('=' * ((4 - count % 4) % 4));
    return out.toString();
  }

  /// Base64 of [bytes] with [alphabet].
  static String _base64(List<int> bytes, String alphabet) {
    final out = StringBuffer();
    for (var i = 0; i < bytes.length; i += 3) {
      final remaining = bytes.length - i;
      final n = (bytes[i] << 16) | (remaining > 1 ? bytes[i + 1] << 8 : 0) | (remaining > 2 ? bytes[i + 2] : 0);
      final chars = remaining > 2 ? 4 : remaining + 1;
      for (var j = 0; j < chars; j++) {
        out.write(alphabet[(n >> (18 - 6 * j)) & 0x3f]);
      }
      if (remaining < 3) out.write('=' * (3 - remaining));
    }
    return out.toString();
  }

  static List<int> _rc4(List<int> key, List<int> data) {
    final s = List<int>.generate(256, (i) => i);
    var j = 0;
    for (var i = 0; i < 256; i++) {
      j = (j + s[i] + key[i % key.length]) % 256;
      final swap = s[i];
      s[i] = s[j];
      s[j] = swap;
    }
    var i = 0;
    j = 0;
    return [
      for (final byte in data)
        () {
          i = (i + 1) % 256;
          j = (j + s[i]) % 256;
          final swap = s[i];
          s[i] = s[j];
          s[j] = swap;
          return (byte ^ s[(s[i] + s[j]) % 256]) & 0xff;
        }(),
    ];
  }

  /// The SM3 digest of [data] (GB/T 32905-2016), 32 bytes.
  @visibleForTesting
  static List<int> sm3(List<int> data) => _sm3(data);

  static List<int> _sm3(List<int> data) {
    int rotl(int x, int n) {
      final s = n % 32;
      return s == 0 ? x : ((x << s) | (x >> (32 - s))) & 0xffffffff;
    }

    int p0(int x) => x ^ rotl(x, 9) ^ rotl(x, 17);
    int p1(int x) => x ^ rotl(x, 15) ^ rotl(x, 23);

    final bitLength = data.length * 8;
    final padded = BytesBuilder(copy: false)
      ..add(data)
      ..addByte(0x80)
      ..add(Uint8List((56 - (data.length + 1) % 64) % 64))
      ..add((ByteData(8)..setUint64(0, bitLength)).buffer.asUint8List());
    final message = ByteData.sublistView(padded.takeBytes());

    final v = List<int>.of(_sm3Iv);
    final w = List<int>.filled(68, 0);
    final w1 = List<int>.filled(64, 0);
    for (var offset = 0; offset < message.lengthInBytes; offset += 64) {
      for (var j = 0; j < 16; j++) {
        w[j] = message.getUint32(offset + 4 * j);
      }
      for (var j = 16; j < 68; j++) {
        w[j] = p1(w[j - 16] ^ w[j - 9] ^ rotl(w[j - 3], 15)) ^ rotl(w[j - 13], 7) ^ w[j - 6];
      }
      for (var j = 0; j < 64; j++) {
        w1[j] = w[j] ^ w[j + 4];
      }
      var a = v[0];
      var b = v[1];
      var c = v[2];
      var d = v[3];
      var e = v[4];
      var f = v[5];
      var g = v[6];
      var h = v[7];
      for (var j = 0; j < 64; j++) {
        final t = j < 16 ? 0x79cc4519 : 0x7a879d8a;
        final ss1 = rotl((rotl(a, 12) + e + rotl(t, j)) & 0xffffffff, 7);
        final ss2 = ss1 ^ rotl(a, 12);
        final ff = j < 16 ? a ^ b ^ c : (a & b) | (a & c) | (b & c);
        final gg = j < 16 ? e ^ f ^ g : (e & f) | ((~e & 0xffffffff) & g);
        final tt1 = (ff + d + ss2 + w1[j]) & 0xffffffff;
        final tt2 = (gg + h + ss1 + w[j]) & 0xffffffff;
        d = c;
        c = rotl(b, 9);
        b = a;
        a = tt1;
        h = g;
        g = rotl(f, 19);
        f = e;
        e = p0(tt2);
      }
      v[0] ^= a;
      v[1] ^= b;
      v[2] ^= c;
      v[3] ^= d;
      v[4] ^= e;
      v[5] ^= f;
      v[6] ^= g;
      v[7] ^= h;
    }
    final digest = ByteData(32);
    for (var i = 0; i < 8; i++) {
      digest.setUint32(4 * i, v[i]);
    }
    return digest.buffer.asUint8List();
  }

  static const _sm3Iv = [
    0x7380166f,
    0x4914b2b9,
    0x172442d7,
    0xda8a0600,
    0xa96f30bc,
    0x163138aa,
    0xe38dee4d,
    0xb0fb0e4e,
  ];

  static const _aid = 6383;
  static const _pageId = 0;
  static const _salt = 'cus';
  static const _options = [0, 1, 14];
  static const _uaKey = [0, 1, 14];
  static const _alphabet0 = 'Dkdpgh2ZmsQB80/MfvV36XI1R45-WUAlEixNLwoqYTOPuzKFjJnry79HbGcaStCe';
  static const _alphabet1 = 'ckdp1h4ZKsUB80/Mfvw36XIgR25+WQAlEi7NLboqYTOPuzmFjJnryx9HVGDaStCe';
  static const _xBogusAlphabet = 'Dkdpgh4ZKsQB80/Mfvw36XI1R25+WUAlEi7NLboqYTOPuzmFjJnryx9HVGcaStCe';

  /// Field order of the signed values.
  static const _order = [
    18, 20, 52, 26, 30, 34, 58, 38, 40, 53, 42, 21, 27, 54, 55, 31, 35, 57, 39, 41, 43, 22, 28, 32, 60, 36, 23, //
    29, 33, 37, 44, 45, 59, 46, 47, 48, 49, 50, 24, 25, 65, 66, 70, 71,
  ];

  /// Field order of the XOR check byte.
  static const _checkOrder = [
    18, 20, 26, 30, 34, 38, 40, 42, 21, 27, 31, 35, 39, 41, 43, 22, 28, 32, 36, 23, 29, 33, 37, 44, 45, 46, 47, //
    48, 49, 50, 24, 25, 52, 53, 54, 55, 57, 58, 59, 60, 65, 66, 70, 71,
  ];

  /// Initial stream-cipher table (256 entries).
  static const _table = [
    121, 243, 55, 234, 103, 36, 47, 228, 30, 231, 106, 6, 115, 95, 78, 101, 250, 207, 198, 50, 139, 227, 220, 105, //
    97, 143, 34, 28, 194, 215, 18, 100, 159, 160, 43, 8, 169, 217, 180, 120, 247, 45, 90, 11, 27, 197, 46, 3, //
    84, 72, 5, 68, 62, 56, 221, 75, 144, 79, 73, 161, 178, 81, 64, 187, 134, 117, 186, 118, 16, 241, 130, 71, //
    89, 147, 122, 129, 65, 40, 88, 150, 110, 219, 199, 255, 181, 254, 48, 4, 195, 248, 208, 32, 116, 167, 69, 201, //
    17, 124, 125, 104, 96, 83, 80, 127, 236, 108, 154, 126, 204, 15, 20, 135, 112, 158, 13, 1, 188, 164, 210, 237, //
    222, 98, 212, 77, 253, 42, 170, 202, 26, 22, 29, 182, 251, 10, 173, 152, 58, 138, 54, 141, 185, 33, 157, 31, //
    252, 132, 233, 235, 102, 196, 191, 223, 240, 148, 39, 123, 92, 82, 128, 109, 57, 24, 38, 113, 209, 245, 2, 119, //
    153, 229, 189, 214, 230, 174, 232, 63, 52, 205, 86, 140, 66, 175, 111, 171, 246, 133, 238, 193, 99, 60, 74, 91, //
    225, 51, 76, 37, 145, 211, 166, 151, 213, 206, 0, 200, 244, 176, 218, 44, 184, 172, 49, 216, 93, 168, 53, 21, //
    183, 41, 67, 85, 224, 155, 226, 242, 87, 177, 146, 70, 190, 12, 162, 19, 137, 114, 25, 165, 163, 192, 23, 59, //
    9, 94, 179, 107, 35, 7, 142, 131, 239, 203, 149, 136, 61, 249, 14, 156,
  ];
}
