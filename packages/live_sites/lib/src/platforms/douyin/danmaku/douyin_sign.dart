import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' show md5;
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_danmaku.dart';

/// The X-Bogus style signature of Douyin's danmaku connection (3.x's
/// `DouyinDanmaku.getSignature` and `generateXBogus`), kept bit for bit.
///
/// Only what the chat socket signs is ported here — the API requests' `a_bogus`
/// stays the site's injectable signer seam. The random draws are injectable for
/// tests through the constructor.
final class DouyinSign {
  /// A signer drawing its random bytes from [random].
  new([Random? random]) : _random = random ?? Random.secure();

  final Random _random;

  /// The danmaku connection's `signature` for this broadcast's [roomId] and the
  /// visitor's [userUniqueId]: the X-Bogus of the MD5 of the fixed parameter
  /// string. Its alphabet has `+` and `/`, so it must be sent percent-encoded.
  String danmakuSignature({required String roomId, required String userUniqueId}) {
    final stub = [
      'live_id=1',
      'aid=${DouyinDanmakuProtocol.aid}',
      'version_code=${DouyinDanmakuProtocol.versionCode}',
      'webcast_sdk_version=${DouyinDanmakuProtocol.sdkVersion}',
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

  /// 3.x's `generateXBogus`: two random bytes, the last two bytes of the MD5 of
  /// the 16 bytes [msStub] (32 hex digits) spells, a 10-byte payload with an XOR
  /// check byte RC4-encrypted under the second random byte, all 12 bytes in the
  /// X-Bogus base64 alphabet.
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
        out.write(_alphabet[(n >> (18 - 6 * j)) & 0x3f]);
      }
    }
    return out.toString();
  }

  /// A visitor id like the web client's (`user_unique_id`): `7`, a digit 3–9 and
  /// 17 more digits, 7.3e18 up to 8e18.
  static String visitorId([Random? random]) {
    final source = random ?? Random.secure();
    return ['7', 3 + source.nextInt(7), for (var i = 0; i < 17; i++) source.nextInt(10)].join();
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

  static const _alphabet = 'Dkdpgh4ZKsQB80/Mfvw36XI1R25+WUAlEi7NLboqYTOPuzmFjJnryx9HVGcaStCe';
}
