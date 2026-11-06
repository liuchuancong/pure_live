import 'package:live_sites/src/models/enums/live_stream_format.dart';

/// NetEase CC's endpoints and constants (3.x's `CCApi` statics): the hosts,
/// the headers of the API, Dashen and media requests, the platform's limits,
/// the id patterns and the qualities' own names.
abstract final class CcEndpoints {
  /// Desktop Chrome 140, the UA 3.x sent to CC and to its media CDN.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// Web origin; also the API requests' `Referer` (with a slash) and the
  /// media requests' `Origin`.
  static const String origin = 'https://cc.163.com';

  /// Headers of the CC API and page requests.
  static const Map<String, String> apiHeaders = {'user-agent': userAgent, 'referer': '$origin/'};

  /// Headers of the Dashen catalog requests (3.x's `getCategores`).
  static const Map<String, String> dashenHeaders = {
    'user-agent': userAgent,
    'referer': 'https://ds.163.com/glive/',
    'origin': 'https://ds.163.com',
  };

  /// Identity of the Dashen configuration whose "直播入口列表" holds the
  /// official entries (3.x's `CCCatalog.configurationId`).
  static const String catalogConfigurationId = '67b32cdd1801fc391a6c2657';

  /// Name of the official rooms and events category, opened on the website
  /// instead of listed (3.x's `official:` areas).
  static const String officialLabel = '官方房间/专题';

  /// Name of the Dashen configuration group that holds the official
  /// entries.
  static const String officialGroupName = '直播入口列表';

  /// The parent group id of the official areas.
  static const String officialAreaType = 'official';

  /// How long before `auth_key` expires a play URL is renewed (at most a
  /// quarter of its lifetime).
  static const Duration leaseLead = Duration(seconds: 60);

  /// The limit of a follow refresh's existence check (9-7); past it the
  /// anchor stays marked offline.
  static const Duration existenceTimeout = Duration(seconds: 8);

  /// A CC id (`ccid`, `cuteid`): a positive decimal number.
  static final RegExp ccidPattern = RegExp(r'^[1-9]\d{0,15}$');

  /// A game type: a decimal number; 0 is "其他游戏".
  static final RegExp areaIdPattern = RegExp(r'^(?:0|[1-9][0-9]{0,15})$');

  /// The site's own names of its tier codes (`vbrname_mapping` in every
  /// recorded answer), for an answer without the mapping.
  static const Map<String, String> siteQualityNames = {'original': '原画', 'ultra': '超清', 'high': '高清', 'standard': '标清'};

  /// 3.x's names for the tier codes of the channel's stream list.
  static const Map<String, String> legacyQualityNames = {
    'blueray': '原画',
    'original': '原画',
    'high': '高清',
    'medium': '标准',
    'standard': '标准',
    'low': '低清',
    'ultra': '蓝光',
  };

  /// 3.x's quality ids (the channel's `stream_list` tiers, also stored
  /// before 9-1) → the `video_play_url` tier that plays the same stream, so
  /// a stored quality preference migrates once. Matched by the stream name
  /// suffix both answers give.
  static const Map<String, String> legacyQualityIds = {
    'original': 'original',
    'high': 'ultra',
    'medium': 'high',
    'low': 'standard',
    'blueray_20M': 'blueray_5M_avc',
  };

  /// The `video_play_url` quality id for a 3.x one ([legacyQualityIds]); an
  /// id not in the table is kept (it names the same tier on both sides or
  /// none, and then the player's usual default applies).
  static String qualityIdFromLegacy(String id) => legacyQualityIds[id.trim()] ?? id.trim();

  /// The room page of [ccid] (3.x opened `https://cc.163.com/{ccid}`).
  static String roomUrl(String ccid) => '$origin/$ccid/';

  /// `wapcc/gamecategory?catetype=[id]`: `0` names the categories, one
  /// request per category lists its areas.
  static Uri categoryUrl(String id) => Uri.https('api.cc.163.com', '/v1/wapcc/gamecategory', {'catetype': id});

  /// The area [game]'s rooms: [start] = (page − 1) × size.
  static Uri areaRoomsUrl(String game, {required int start, required int size}) => Uri.https(
    'cc.163.com',
    '/api/category/$game/',
    {'format': 'json', 'tag_id': '0', 'start': '$start', 'size': '$size'},
  );

  /// Every live room, [start] a 0-based offset.
  static Uri recommendUrl({required int start, required int size}) =>
      Uri.https('cc.163.com', '/api/category/live/', {'format': 'json', 'start': '$start', 'size': '$size'});

  /// The streamers matching [query]. The path ends with a slash (without it
  /// the site answers 301).
  static Uri searchUrl(String query, {required int page, required int size}) =>
      Uri.https('cc.163.com', '/search/anchor/', {'query': query, 'size': '$size', 'page': '$page'});

  /// The channel [ccid] broadcasts in.
  static Uri anchorLivesUrl(String ccid) =>
      Uri.https('api.cc.163.com', '/v1/activitylives/anchor/lives', {'anchor_ccid': ccid});

  /// The room broadcasting in [channelId].
  static Uri channelUrl(String channelId) => Uri.https('cc.163.com', '/live/channel/', {'channelids': channelId});

  /// The room page of an anchor without a live channel, whose
  /// `__NEXT_DATA__` tells an unknown id from an offline one.
  static Uri roomPageUrl(String ccid) =>
      Uri.https('cc.163.com', '/$ccid/', {'open': 'blizzardtv', 'from': '8382', 'platform': 'ds'});

  /// Whether [ccid] is a CC account (9-7).
  static Uri existsUrl(String ccid) => Uri.https('api.cc.163.com', '/v1/wapcc/recommendbyccid', {'ccid': ccid});

  /// The Dashen game registry (the official entries' names and icons).
  static Uri dashenGamesUrl() =>
      Uri.https('inf.ds.163.com', '/v1/web/game-center/basic/base-info-list/by-type', {'gameType': 'NETEASE'});

  /// The Dashen live configuration (the official entries themselves); the
  /// configuration id goes in the JSON POST body.
  static Uri dashenConfigUrl() => Uri.https('inf-act.ds.163.com', '/v1/act-web/pageConf/commonAppConfig');

  /// `video_play_url/{ccid}` as the website's h5 player asks for it (https
  /// URLs), at [quality] and [cdn] when given.
  static Uri playUrl(String ccid, {String? quality, String? cdn}) => Uri.https(
    'vapi.cc.163.com',
    '/video_play_url/$ccid',
    {'src': 'webcc_h5', 'vbrmode': '1', 'use_new_vbrmap': '1', 'secure': '1', 'vbrname': ?quality, 'cdn': ?cdn},
  );

  /// Media request headers for [roomId] (3.x's `PlaybackHeaderResolver`):
  /// UA, Origin and the room page as Referer. CC has no cookie.
  static Map<String, String> mediaHeaders(String roomId) {
    final id = Uri.encodeComponent(roomId.trim());
    return {'user-agent': userAgent, 'origin': origin, 'referer': id.isEmpty ? '$origin/' : '$origin/$id/'};
  }

  /// The container by the URL path: `.m3u8` is HLS, `.flv` FLV (every line
  /// seen so far), anything else unknown.
  static LiveStreamFormat formatOf(Uri url) {
    final path = url.path.toLowerCase();
    if (path.endsWith('.m3u8')) return LiveStreamFormat.hls;
    if (path.endsWith('.flv')) return LiveStreamFormat.flv;
    return LiveStreamFormat.other;
  }

  /// A room of `cc.163.com/{ccid}` (3.x), and the two forms the site now
  /// shares: the mobile page `h5.cc.163.com/cc/{ccid}` and the Dashen
  /// player `ds.163.com/glive/?ccid=` (where `cc.163.com/{ccid}/`
  /// redirects). Only positive decimal ids without leading zeros are rooms.
  static String? roomIdFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return null;
    String? number(String text) {
      final value = text.trim();
      if (!RegExp(r'^\d{1,16}$').hasMatch(value)) return null;
      final parsed = int.tryParse(value);
      return parsed != null && parsed > 0 ? '$parsed' : null;
    }

    try {
      final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList(growable: false);
      return switch (uri.host.toLowerCase()) {
        'cc.163.com' when segments.isNotEmpty => number(segments.first),
        'h5.cc.163.com' when segments.length >= 2 && segments.first == 'cc' => number(segments[1]),
        'ds.163.com' when segments.firstOrNull == 'glive' => number(uri.queryParameters['ccid'] ?? ''),
        _ => null,
      };
    } on FormatException {
      // Undecodable escapes (`/%FF`, a broken `ccid=` query): not a room link.
      return null;
    }
  }
}
