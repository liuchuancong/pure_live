import 'dart:convert';

import 'package:live_sites/src/common/crypto/aes_cbc.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/platforms/looklive/looklive_manifest.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_room.dart';

/// LOOK Live's (LOOK 直播, NetEase) endpoints and constants (3.x's
/// `LookLiveApi` statics): the two hosts, the request envelope, the room
/// links, the media address rules, the platform's limits and its two areas.
abstract final class LookliveEndpoints {
  /// How long one request may take (3.x's 20 s deadline).
  static const Duration requestTimeout = Duration(seconds: 20);

  /// The website.
  static const String origin = 'https://look.163.com';

  /// The API.
  static const String apiOrigin = 'https://api.look.163.com';

  /// The user agent of the API requests and of the media (3.x's).
  static const String userAgent = 'Mozilla/5.0';

  /// Headers of every API request (dio's form content type included).
  static const Map<String, String> requestHeaders = {
    'accept': 'application/json, text/plain, */*',
    'origin': origin,
    'referer': '$origin/',
    'user-agent': userAgent,
    'content-type': 'application/x-www-form-urlencoded',
  };

  /// The media headers of [roomId]: the lines' `Origin`, the room page as
  /// `Referer` and the platform's user agent.
  static Map<String, String> mediaHeaders(String roomId) => {
    'origin': origin,
    'referer': roomUrl(roomId),
    'user-agent': userAgent,
  };

  /// The largest answer read (2 MiB, in UTF-8 bytes).
  static const int responseLimit = 2 * 1024 * 1024;

  /// Rooms a list request asks for (`limit`).
  static const int pageSize = 20;

  /// Most entries of a list answer accepted.
  static const int maxEntries = 100;

  /// Last page asked for.
  static const int maxPage = 10000;

  /// Largest search page size served; a larger one gives nothing.
  static const int maxSearchSize = 100;

  /// The platform's display name: the areas' parent group.
  static const String categoryName = 'LOOK 直播';

  /// Name of the video area.
  static const String videoAreaName = '视频直播';

  /// Name of the voice area.
  static const String audioAreaName = '语音直播';

  /// The video area.
  static final LiveArea videoArea = LiveArea.normalized(
    platform: lookliveSiteId,
    areaId: 'video',
    areaName: videoAreaName,
    parentAreaId: lookliveSiteId,
    parentAreaName: categoryName,
  );

  /// The voice area.
  static final LiveArea audioArea = LiveArea.normalized(
    platform: lookliveSiteId,
    areaId: 'audio',
    areaName: audioAreaName,
    parentAreaId: lookliveSiteId,
    parentAreaName: categoryName,
  );

  /// The notice of every room, in words for users: the two audience figures
  /// are kept apart.
  static const String chatNotice = '人数是正在观看的人数，热度另外显示。';

  /// The notice line of a banned room.
  static const String bannedNotice = '这个 LOOK 直播间被平台禁播或正在违规整改，现在不能观看。';

  /// The notice line of an app-only room.
  static const String appOnlyNotice = '这场 LOOK 直播只能在 LOOK App 里观看。';

  /// The notice line of a ticketed broadcast.
  static const String paidNotice = '这场 LOOK 直播要购票才能观看。';

  /// Id of the HLS quality.
  static const String hlsId = 'hls:source';

  /// Id of the FLV quality.
  static const String flvId = 'flv:source';

  /// Label of the HLS quality.
  static const String hlsLabel = 'HLS 原始线路';

  /// Label of the FLV quality.
  static const String flvLabel = 'FLV 原始线路';

  /// Path of the video list.
  static const String videoListPath = '/weapi/livestream/homepage/recommend';

  /// Path of the voice list.
  static const String audioListPath = '/weapi/livestream/listen/homepage/recommend/list';

  /// Path of the room answer.
  static const String roomPath = '/weapi/livestream/room/get/v3';

  /// Path of the chat servers of a live room: LOOK's web client posts
  /// `/api/livestream/chat/address` (the Live chunk's chat service), which
  /// its request helper sends as this `weapi` path.
  static const String chatAddressPath = '/weapi/livestream/chat/address';

  static final RegExp _roomNumber = RegExp(r'^[1-9][0-9]{1,17}$');
  static final RegExp _mediaHost = RegExp(r'^[a-z0-9-]+\.live\.126\.net$');
  static final RegExp _hlsPath = RegExp(r'^/live/[a-f0-9]{32}/playlist\.m3u8$');
  static final RegExp _flvPath = RegExp(r'^/live/[a-f0-9]{32}\.flv$');
  static final RegExp _chatAddress = RegExp(
    r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+:([0-9]{1,5})$',
  );

  // Links ---------------------------------------------------------------------

  /// Whether [value] is a room number: 2 to 18 digits, not starting with 0.
  static bool isRoomNumber(String value) => _roomNumber.hasMatch(value);

  /// The room page of [roomId].
  static String roomUrl(String roomId) => '$origin/live?id=$roomId';

  /// The room of [raw]: a room number (trimmed), or a room link
  /// ([roomIdFromUrl]); null otherwise.
  static String? roomIdOf(String raw) {
    final value = raw.trim();
    return isRoomNumber(value) ? value : roomIdFromUrl(value);
  }

  /// The room of a room link: http(s) on `look.163.com` (any case), no user
  /// info, port 80 or 443 or none, no fragment, the one path segment `live`
  /// (any case, empty segments ignored) and exactly one `id` that is a room
  /// number. Null for anything else, spaces and control characters
  /// included.
  static String? roomIdFromUrl(String url) {
    final value = url.trim();
    if (value.length > 8192 || RegExp(r'[\x00-\x20\x7f]').hasMatch(value)) return null;
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

  // Requests ------------------------------------------------------------------

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
  /// compact JSON AES-128-CBC encrypted (PKCS#7, IV `0102030405060708`)
  /// with the web nonce, Base64, encrypted again with the secret key,
  /// Base64; `encSecKey` is [encSecKey].
  static Map<String, String> envelope(Object? payload) => {
    'params': _aes(_aes(jsonEncode(payload), _nonce), _secretKey),
    'encSecKey': encSecKey,
  };

  /// The body of the form POST of [payload], as `Uri(queryParameters:
  /// …).query` writes it.
  static String formBody(Object? payload) => Uri(queryParameters: envelope(payload)).query;

  /// The list request of page [page]: 20 rooms from `(page - 1) × 20`.
  static Map<String, int> listPayload(int page) => {'offset': (page - 1) * pageSize, 'limit': pageSize};

  /// The room request of [roomId].
  static Map<String, String> roomPayload(String roomId) => {'liveRoomNo': roomId};

  /// The chat server request of [roomId], as LOOK's web client sends it
  /// (`{liveRoomNo, os: 0}`).
  static Map<String, Object> chatAddressPayload(String roomId) => {'liveRoomNo': roomId, 'os': 0};

  /// The list path of [kind].
  static String listPath(LookLiveKind kind) => kind == LookLiveKind.audio ? audioListPath : videoListPath;

  /// The [LookLiveKind] of an area id of this platform: video or voice; null
  /// for anything else.
  static LookLiveKind? kindOfAreaId(String? areaId) => switch (areaId) {
    'video' => LookLiveKind.video,
    'audio' => LookLiveKind.audio,
    _ => null,
  };

  // Media ---------------------------------------------------------------------

  /// A stream address as the site accepts it, made https: http(s) on a
  /// `*.live.126.net` host (one label of letters, digits and hyphens), no
  /// user info, port or fragment, a query of at most 2048 characters, and
  /// the path `/live/<32 lower-case hex>/playlist.m3u8` (HLS) or
  /// `/live/<32 lower-case hex>.flv` (FLV). Anything else is
  /// [LookliveFailureKind.apiChanged].
  static Uri mediaUri(String raw, {required LiveStreamKind format}) {
    final source = Uri.tryParse(raw.trim());
    final path = switch (format) {
      LiveStreamKind.hls => _hlsPath,
      LiveStreamKind.flv => _flvPath,
    };
    if (source == null ||
        (!source.isScheme('http') && !source.isScheme('https')) ||
        source.userInfo.isNotEmpty ||
        source.hasPort ||
        source.fragment.isNotEmpty ||
        !_mediaHost.hasMatch(source.host.toLowerCase()) ||
        source.query.length > 2048 ||
        !path.hasMatch(source.path)) {
      throw LookliveFailure(
        LookliveFailureKind.apiChanged,
        'not a LOOK ${format.name.toUpperCase()} address: ${snippet(raw)}',
      );
    }
    return source.replace(scheme: 'https');
  }

  /// The chat servers of a `chat/address` answer's `data.address`: each a
  /// `host:port` of NetEase Yunxin's chatroom service, in the answer's
  /// order, lower-cased, each once; entries that are not a host name and a
  /// port (1 to 65535) are left out.
  static List<String> chatAddressList(List<Object?> raw) => <String>{
    for (final entry in raw)
      if (entry is String)
        if (entry.trim().toLowerCase() case final address)
          if (_chatAddress.firstMatch(address) case final match?)
            if (int.parse(match.group(4)!) case final port when port >= 1 && port <= 65535) address,
  }.toList();

  /// The first 80 characters of an unusable value, for a failure's text.
  static String snippet(String body) {
    final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= 80 ? text : '${text.substring(0, 80)}…';
  }
}
