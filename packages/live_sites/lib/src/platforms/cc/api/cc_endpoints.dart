/// NetEase CC's (网易CC) endpoints and constants (3.x's `CcApi` statics):
/// the hosts of the API, the pages and the media CDN, the headers they
/// carry, the official catalog's identity, and the platform's limits and
/// quality-id table.
abstract final class CcEndpoints {
  /// The platform id.
  static const String site = 'cc';

  /// The website: also the API requests' `Referer` (with a slash) and the
  /// media requests' `Origin`.
  static const String origin = 'https://cc.163.com';

  /// Host of the mobile API (`wapcc`, `activitylives`).
  static const String apiHost = 'api.cc.163.com';

  /// Host of the play answers.
  static const String mediaHost = 'vapi.cc.163.com';

  /// Desktop Chrome 140, the UA 3.x sent to CC and to its media CDN
  /// (`PlaybackHeaderResolver`).
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// Headers of the CC API and page requests.
  static const Map<String, String> apiHeaders = {'user-agent': userAgent, 'referer': '$origin/'};

  /// Headers of the Dashen catalog requests (3.x's `getCategores`).
  static const Map<String, String> dashenHeaders = {
    'user-agent': userAgent,
    'referer': 'https://ds.163.com/glive/',
    'origin': 'https://ds.163.com',
  };

  /// Media request headers for [roomId]: UA, Origin and the room page as
  /// `Referer`. CC has no cookie.
  static Map<String, String> mediaHeaders(String roomId) {
    final id = Uri.encodeComponent(roomId.trim());
    return {'user-agent': userAgent, 'origin': origin, 'referer': id.isEmpty ? '$origin/' : '$origin/$id/'};
  }

  /// Largest answer accepted, in UTF-8 bytes: a category page of 1000 rooms
  /// stays far below it, a room page is about 110 KB.
  static const int responseLimit = 4 * 1024 * 1024;

  /// Identity of the Dashen configuration whose "直播入口列表" holds the
  /// official entries (3.x's `CCCatalog.configurationId`).
  static const String catalogConfigurationId = '67b32cdd1801fc391a6c2657';

  /// Name of the official rooms and events category, opened on the website
  /// instead of listed (3.x's `official:` areas).
  static const String officialLabel = '官方房间/专题';

  /// How long before `auth_key` expires a play URL is renewed (at most a
  /// quarter of its lifetime).
  static const Duration leaseLead = Duration(seconds: 60);

  /// How long the `video_play_url` answer that listed a room's qualities
  /// stands in for the request of its own tier (the first play after
  /// entering a room), once. Its URLs admit new connections for 300 s.
  static const Duration qualityAnswerReuse = Duration(seconds: 30);

  /// The limit of a follow refresh's existence check (9-7); past it the
  /// anchor stays marked offline.
  static const Duration existenceTimeout = Duration(seconds: 8);

  /// The first row an area page lists (`start = (page − 1) × pageSize`),
  /// out of 1–100000 pages.
  static const int maxPage = 100000;

  /// The rows an area page asks for, out of 1–1000 (a larger one outruns the
  /// platform's own answer limit).
  static const int maxPageSize = 1000;

  /// Largest search page size sent; a larger one is cut to it.
  static const int maxSearchSize = 50;

  /// A CC id (`ccid`, `cuteid`): a positive decimal number without a leading
  /// zero.
  static final RegExp ccidPattern = RegExp(r'^[1-9]\d{0,15}$');

  /// A game type: a decimal number; 0 is "其他游戏".
  static final RegExp areaIdPattern = RegExp(r'^(?:0|[1-9][0-9]{0,15})$');

  /// Whether [value] is a CC id (`ccid`, `cuteid`): a positive decimal
  /// number without a leading zero.
  static bool isCcid(String value) => ccidPattern.hasMatch(value);

  /// Whether [value] is a game type an area is listed by.
  static bool isAreaId(String value) => areaIdPattern.hasMatch(value);

  /// The room's web page (3.x opened `https://cc.163.com/{ccid}`).
  static String roomUrl(String ccid) => '$origin/$ccid/';

  /// `wapcc/gamecategory?catetype=0`: the top-level categories.
  static Uri categoryTypesUrl() => Uri.https(apiHost, '/v1/wapcc/gamecategory', {'catetype': '0'});

  /// `wapcc/gamecategory?catetype={id}`: the areas of the category [id].
  static Uri categoryAreasUrl(String id) => Uri.https(apiHost, '/v1/wapcc/gamecategory', {'catetype': id});

  /// `api/category/{gametype}/`: rows [start] to [start + size] of the area.
  static Uri categoryRoomsUrl(String gametype, {required int start, required int size}) => Uri.https(
    'cc.163.com',
    '/api/category/$gametype/',
    {'format': 'json', 'tag_id': '0', 'start': '$start', 'size': '$size'},
  );

  /// `api/category/live/`: every live room, rows [start] to [start + size].
  static Uri recommendRoomsUrl({required int start, required int size}) =>
      Uri.https('cc.163.com', '/api/category/live/', {'format': 'json', 'start': '$start', 'size': '$size'});

  /// `search/anchor/`: streamers for [keyword]. The path ends with a slash
  /// (without it the site answers 301).
  static Uri searchUrl(String keyword, {required int page, required int size}) =>
      Uri.https('cc.163.com', '/search/anchor/', {'query': keyword, 'size': '$size', 'page': '$page'});

  /// `activitylives/anchor/lives`: the channels the anchor [ccid] broadcasts
  /// in.
  static Uri liveChannelsUrl(String ccid) =>
      Uri.https(apiHost, '/v1/activitylives/anchor/lives', {'anchor_ccid': ccid});

  /// `live/channel/?channelids=`: the room broadcasting in [channel].
  static Uri channelUrl(String channel) => Uri.https('cc.163.com', '/live/channel/', {'channelids': channel});

  /// The room page of [ccid], as the website's own links carry it.
  static Uri roomPageUri(String ccid) =>
      Uri.https('cc.163.com', '/$ccid/', {'open': 'blizzardtv', 'from': '8382', 'platform': 'ds'});

  /// `vapi.cc.163.com/video_play_url/{ccid}` as the website's h5 player asks
  /// for it (https URLs), at [quality] (`vbrname`) and [cdn] when given.
  static Uri playUrl(String ccid, {String? quality, String? cdn}) => Uri.https(mediaHost, '/video_play_url/$ccid', {
    'src': 'webcc_h5',
    'vbrmode': '1',
    'use_new_vbrmap': '1',
    'secure': '1',
    'vbrname': ?quality,
    'cdn': ?cdn,
  });

  /// `wapcc/recommendbyccid?ccid=`: whether [ccid] is a CC account (9-7).
  static Uri anchorExistsUrl(String ccid) => Uri.https(apiHost, '/v1/wapcc/recommendbyccid', {'ccid': ccid});

  /// The Dashen game registry (the official entries' names and icons).
  static Uri officialGamesUrl() =>
      Uri.https('inf.ds.163.com', '/v1/web/game-center/basic/base-info-list/by-type', {'gameType': 'NETEASE'});

  /// The Dashen live configuration holding the "直播入口列表".
  static Uri officialConfigUrl() => Uri.https('inf-act.ds.163.com', '/v1/act-web/pageConf/commonAppConfig');

  /// 3.x's quality ids (the channel's `stream_list` tiers, also stored
  /// before 9-1) → the `video_play_url` tier that plays the same stream, for
  /// a stored quality preference to migrate once. Matched by the stream
  /// name suffix both answers give; note that `high` is an id on both sides
  /// with different streams, so this applies to old ids only.
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
}
