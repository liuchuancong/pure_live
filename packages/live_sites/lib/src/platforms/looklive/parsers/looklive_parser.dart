import 'dart:convert';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:live_sites/live_sites.dart';

/// Static parsers and the request envelope for the Look (网易 LOOK) APIs.
abstract final class LookLiveParser {
  /// Web origin.
  static const String origin = 'https://look.163.com';

  /// API origin.
  static const String apiOrigin = 'https://api.look.163.com';

  /// The room endpoint.
  static const String roomPath = '/weapi/livestream/room/get/v3';

  /// Request headers of every API call.
  static const Map<String, String> requestHeaders = {
    'accept': 'application/json, text/plain, */*',
    'origin': origin,
    'referer': '$origin/',
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'content-type': 'application/x-www-form-urlencoded',
  };

  /// Media headers of [roomId].
  static Map<String, String> mediaHeaders(String roomId) => {
    'origin': origin,
    'referer': '$origin/live?id=$roomId',
    'user-agent': requestHeaders['user-agent']!,
  };

  static const String _nonce = '0CoJUm6Qyw8W8jud';
  static const String _secretKey = '0123456789abcdef';
  static const String _iv = '0102030405060708';

  /// The web client's RSA modulus (public).
  static final BigInt _modulus = BigInt.parse(
    '00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152b3ab17a876aea8a5aa76d2e417629ec'
    '4ee341f56135fccf695280104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813'
    'cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7',
    radix: 16,
  );

  /// The `encSecKey`: the reversed secret key as hexadecimal raised to
  /// 65537 mod the modulus.
  static final String encSecKey = BigInt.parse(
    utf8.encode(_secretKey).reversed.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
    radix: 16,
  ).modPow(BigInt.from(0x10001), _modulus).toRadixString(16).padLeft(256, '0');

  static final crypto.AesCbc _aesCbc = crypto.AesCbc.with256bits(macAlgorithm: crypto.MacAlgorithm.empty);

  /// AES-128-CBC (PKCS#7, fixed IV) of [text] under [key], Base64.
  static Future<String> aesEncrypt(String text, String key) async {
    final box = await _aesCbc.encrypt(
      utf8.encode(text),
      secretKey: crypto.SecretKey(utf8.encode(key)),
      nonce: utf8.encode(_iv),
    );
    return base64Encode(box.cipherText);
  }

  /// The `weapi` envelope of [payload]: `params` double-encrypted
  /// (nonce then secret key), `encSecKey` the RSA blob.
  static Future<Map<String, String>> envelope(Object? payload) async {
    final once = await aesEncrypt(jsonEncode(payload), _nonce);
    final twice = await aesEncrypt(once, _secretKey);
    return {'params': twice, 'encSecKey': encSecKey};
  }

  /// The form body of [payload].
  static Future<String> formBody(Object? payload) async => Uri(queryParameters: await envelope(payload)).query;

  /// Validates the envelope (`code` 0) and returns `data`; code 404 is
  /// "not found".
  static Map<String, Object?> data(String body, {int status = 200, String what = 'response'}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('looklive $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('looklive $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('looklive $what: body is not an object');
    }
    final code = (decoded['code'] as num?)?.toInt();
    if (code == 404) {
      throw SiteNotFoundError('looklive $what: room not found');
    }
    if (code != null && code != 0 && code != 200) {
      throw SiteApiChangedError('looklive $what: code $code');
    }
    final data = decoded['data'];
    if (data is! Map<String, Object?>) {
      throw SiteApiChangedError('looklive $what: no data object');
    }
    return data;
  }

  /// `room/get/v3` → the room snapshot with its media URLs in `data`.
  static LiveRoom room(String body, {required String roomId, int status = 200}) {
    const what = 'room/get/v3';
    final data = LookLiveParser.data(body, status: status, what: what);
    final anchor = data['anchor'];
    final anchorMap = anchor is Map<String, Object?> ? anchor : const <String, Object?>{};
    final answered = anchorMap['liveRoomNo']?.toString() ?? '';
    if (answered != roomId) {
      throw SiteApiChangedError('looklive $what: asked $roomId, got $answered');
    }
    final info = data['roomInfo'];
    final infoMap = info is Map<String, Object?> ? info : const <String, Object?>{};
    final liveStatus = (data['liveStatus'] as num?)?.toInt();
    final live = liveStatus == 1;
    final banned = liveStatus == -10 || liveStatus == -4;
    final startSeconds = (infoMap['startTime'] as num?)?.toInt();
    return LiveRoom(
      platform: SiteIds.looklive,
      roomId: roomId,
      title: infoMap['title']?.toString() ?? '',
      nick: anchorMap['nickName']?.toString() ?? '',
      avatar: _picture(anchorMap['avatarUrl']),
      cover: _picture(infoMap['liveCoverUrl']),
      status: live
          ? LiveStatus.live
          : banned
          ? LiveStatus.banned
          : LiveStatus.offline,
      startedAt: live && startSeconds != null && startSeconds > 0
          ? DateTime.fromMillisecondsSinceEpoch(startSeconds * 1000, isUtc: true)
          : null,
      data: live ? infoMap : null,
    );
  }

  /// The play lines of a live room: the HLS playlist then the FLV stream
  /// from `liveUrl`.
  static List<LivePlayLine> playLines(Object? liveUrl, String roomId) {
    if (liveUrl is! Map<String, Object?>) {
      return const [];
    }
    final lines = <LivePlayLine>[];
    final hls = liveUrl['hlsPullUrl']?.toString() ?? '';
    final flv = liveUrl['httpPullUrl']?.toString() ?? '';
    if (hls.startsWith('http')) {
      lines.add(LivePlayLine(url: hls, headers: mediaHeaders(roomId), format: StreamFormat.hls, lineId: 'hls'));
    }
    if (flv.startsWith('http')) {
      lines.add(LivePlayLine(url: flv, headers: mediaHeaders(roomId), format: StreamFormat.flv, lineId: 'flv'));
    }
    return lines;
  }

  static String? _picture(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
