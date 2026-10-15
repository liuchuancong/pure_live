import 'dart:convert';

import 'package:live_sites/src/common/crypto/aes_cbc.dart';

/// LOOK Live's (NetEase LOOK 直播) endpoints and constants (3.x's
/// `LookLiveApi` statics): the two hosts, the `weapi` request envelope, the
/// four paths, the platform's limits, its two areas and its two qualities.
abstract final class LookliveEndpoints {
  /// The website.
  static const String origin = 'https://look.163.com';

  /// The API.
  static const String apiOrigin = 'https://api.look.163.com';

  /// The user agent of the requests and the media (3.x's `Mozilla/5.0`).
  static const String userAgent = 'Mozilla/5.0';

  /// The headers of every API request (3.x's `requestHeaders`, with the
  /// form content type of the `weapi` POSTs).
  static const Map<String, String> requestHeaders = {
    'accept': 'application/json, text/plain, */*',
    'origin': origin,
    'referer': '$origin/',
    'user-agent': userAgent,
    'content-type': 'application/x-www-form-urlencoded',
  };

  /// The headers of the media of [roomId] (3.x's `mediaHeaders`): the
  /// headers of every play line and of the stream requests.
  static Map<String, String> mediaHeaders(String roomId) => {
    'origin': origin,
    'referer': link(roomId),
    'user-agent': userAgent,
  };

  /// The largest answer read, in UTF-8 bytes (3.x's `responseLimit`).
  static const int responseLimit = 2 * 1024 * 1024;

  /// Rooms a list request asks for (`limit`).
  static const int pageSize = 20;

  /// Most entries of a list answer accepted.
  static const int maxEntries = 100;

  /// Last page asked for.
  static const int maxPage = 10000;

  /// Largest search page size served; a larger one gives nothing.
  static const int maxSearchSize = 100;

  /// The platform name (zh.json `site_looklive`).
  static const String siteName = 'LOOK 直播';

  /// `areaId` of the video area.
  static const String videoAreaId = 'video';

  /// `areaId` of the voice area.
  static const String audioAreaId = 'audio';

  /// The video area's name.
  static const String videoAreaName = '视频直播';

  /// The voice area's name.
  static const String audioAreaName = '语音直播';

  /// The notice of every room (text key `looklive_chat_notice`): the
  /// platform shows heat and current viewers apart, and the chat carries
  /// neither.
  static const String chatNotice = '人数是正在观看的人数，热度另外显示。';

  /// The notice line of a banned room (text key `looklive_restricted_notice`).
  static const String bannedNotice = '这个 LOOK 直播间被平台禁播或正在违规整改，现在不能观看。';

  /// The notice line of an app-only room (`looklive_app_only_notice`).
  static const String appOnlyNotice = '这场 LOOK 直播只能在 LOOK App 里观看。';

  /// The notice line of a ticketed broadcast (`looklive_paid_notice`).
  static const String paidNotice = '这场 LOOK 直播要购票才能观看。';

  /// Id of the HLS quality.
  static const String hlsId = 'hls:source';

  /// Id of the FLV quality.
  static const String flvId = 'flv:source';

  /// The HLS quality's label (zh.json `looklive_quality_hls`).
  static const String hlsQualityLabel = 'HLS 原始线路';

  /// The FLV quality's label (zh.json `looklive_quality_flv`).
  static const String flvQualityLabel = 'FLV 原始线路';

  /// Path of the video list.
  static const String videoListPath = '/weapi/livestream/homepage/recommend';

  /// Path of the voice list.
  static const String audioListPath = '/weapi/livestream/listen/homepage/recommend/list';

  /// Path of the room answer.
  static const String roomPath = '/weapi/livestream/room/get/v3';

  /// Path of the chat servers of a live room (the web client's chat
  /// service, sent as this `weapi` path).
  static const String chatAddressPath = '/weapi/livestream/chat/address';

  /// Whether [value] is a room number: 2 to 18 digits, not starting with 0.
  static bool isRoomNumber(String value) => _roomNumber.hasMatch(value);

  static final RegExp _roomNumber = RegExp(r'^[1-9][0-9]{1,17}$');

  /// The room page of [roomId] (3.x's `watchUrl`).
  static String link(String roomId) => '$origin/live?id=$roomId';

  /// The room of [raw]: a room number (trimmed), or a room link
  /// ([roomIdFromUrl]); null otherwise.
  static String? roomIdOf(String raw) {
    final value = raw.trim();
    return isRoomNumber(value) ? value : roomIdFromUrl(value);
  }

  /// The room of a room link: http(s) on `look.163.com` (any case), no user
  /// info, port 80 or 443 or none, no fragment, the one path segment `live`
  /// (any case, empty segments ignored) and exactly one `id` that is a room
  /// number. Null for anything else, spaces and control characters included.
  static String? roomIdFromUrl(String url) {
    final value = url.trim();
    if (value.length > 8192 || _control.hasMatch(value)) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (!uri.isScheme('http') && !uri.isScheme('https')) ||
        uri.host.toLowerCase() != 'look.163.com' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 80 && uri.port != 443) ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    try {
      final segments = [
        for (final segment in uri.pathSegments)
          if (segment.isNotEmpty) segment,
      ];
      if (segments.length != 1 || segments.single.toLowerCase() != 'live') return null;
      final ids = uri.queryParametersAll['id'];
      if (ids == null || ids.length != 1 || !isRoomNumber(ids.single)) return null;
      return ids.single;
    } on FormatException {
      return null;
    }
  }

  static final RegExp _control = RegExp(r'[\x00-\x20\x7f]');

  // The weapi envelope --------------------------------------------------------

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

  /// `encSecKey`: the reversed secret key read as hexadecimal, raised to
  /// 65537 modulo the web client's modulus, 256 hex digits. The secret key
  /// is fixed, so this is a constant.
  static final String encSecKey = BigInt.parse(
    utf8.encode(_secretKey).reversed.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
    radix: 16,
  ).modPow(BigInt.from(0x10001), _modulus).toRadixString(16).padLeft(256, '0');

  static String _aes(String text, String key) =>
      base64Encode(AesCbc.encrypt(utf8.encode(text), key: utf8.encode(key), iv: utf8.encode(_iv)));

  /// The `weapi` form of [payload] (NetEase's web envelope): `params` is the
  /// compact JSON AES-128-CBC encrypted (PKCS#7, IV `0102030405060708`) with
  /// the web nonce, Base64, encrypted again with the secret key, Base64;
  /// `encSecKey` is [encSecKey].
  static Map<String, String> envelope(Object? payload) => {
    'params': _aes(_aes(jsonEncode(payload), _nonce), _secretKey),
    'encSecKey': encSecKey,
  };

  /// The body of the form POST of [payload], encoded as 3.x encoded it
  /// (`Uri(queryParameters: …).query`).
  static String formBody(Object? payload) => Uri(queryParameters: envelope(payload)).query;

  // Requests ------------------------------------------------------------------

  /// The list request of page [page]: [pageSize] rooms from
  /// `(page - 1) × pageSize`.
  static Map<String, int> listPayload(int page) => {'offset': (page - 1) * pageSize, 'limit': pageSize};

  /// The room request of [roomId].
  static Map<String, String> roomPayload(String roomId) => {'liveRoomNo': roomId};

  /// The chat server request of [roomId], as the web client sends it.
  static Map<String, Object> chatAddressPayload(String roomId) => {'liveRoomNo': roomId, 'os': 0};
}
