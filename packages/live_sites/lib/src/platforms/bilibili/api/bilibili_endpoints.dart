import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_json.dart';

/// Bilibili's endpoints, user agent and protocol constants (ARCHITECTURE.md
/// §7.2: endpoint shapes live here; the WBI signature lives in
/// `bilibili_wbi.dart`, request assembly in `bilibili_http.dart`).
abstract final class BilibiliEndpoints {
  /// Desktop Chrome 138, the UA the web client sends with every request.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/138.0.0.0 Safari/537.36';

  /// Host of the web API (search, nav, finger/spi, player).
  static const String apiHost = 'api.bilibili.com';

  /// Host of the live API (areas, room lists, room detail, play, danmaku
  /// credentials).
  static const String liveApiHost = 'api.live.bilibili.com';

  /// Host of the live pages; also the Referer of every request.
  static const String liveHost = 'live.bilibili.com';

  /// Host of the passport QR login endpoints.
  static const String passportHost = 'passport.bilibili.com';

  /// The short-link host a shared room link is usually posted as.
  static const String shortLinkHost = 'b23.tv';

  /// Origin and Referer of the live pages.
  static const String origin = 'https://live.bilibili.com';

  /// Referer of the API requests.
  static const String referer = 'https://live.bilibili.com/';

  /// The general danmaku gateway, tried first: some ISP and mobile DNS
  /// resolvers intermittently miss the regional nodes `getDanmuInfo` returns.
  static const String danmakuGateway = 'wss://broadcastlv.chat.bilibili.com/sub';

  /// How long WBI keys, the guest buvid and the `w_webid` access id are reused.
  static const Duration sessionLifetime = Duration(hours: 6);

  /// How long the gift table (`giftConfig()`) is reused across rooms.
  static const Duration giftCatalogLifetime = Duration(hours: 6);

  /// Pause before the one retry of a signed request after `-352`, and between
  /// the two ranked recommendation attempts.
  static const Duration retryDelay = Duration(milliseconds: 180);

  /// The room page of [roomId].
  static Uri roomPage(String roomId) => Uri.https(liveHost, '/${Uri.encodeComponent(roomId)}');

  /// The area board: `room/v1/Area/getList` (categories and their areas).
  static Uri areaList() => Uri.https(liveApiHost, '/room/v1/Area/getList', {'need_entrance': '1', 'parent_id': '0'});

  /// The unsigned per-area room list, [pageSize] limited to 1–30.
  static Uri areaRooms({
    required String parentAreaId,
    required String areaId,
    required int page,
    required int pageSize,
  }) => Uri.https(liveApiHost, '/room/v1/area/getRoomList', {
    'platform': 'web',
    'parent_area_id': parentAreaId,
    'area_id': areaId,
    'sort_type': 'online',
    'page': '$page',
    'page_size': '${pageSize.clamp(1, 30)}',
  });

  /// The parameters of the signed fallback list (`second/getList`, whose
  /// request also carries the `w_webid` and is WBI signed).
  static Map<String, String> secondListParams({
    required String parentAreaId,
    required String areaId,
    required int page,
  }) => {'platform': 'web', 'parent_area_id': parentAreaId, 'area_id': areaId, 'sort_type': 'online', 'page': '$page'};

  /// Path of the signed fallback list.
  static const String secondListPath = '/xlive/web-interface/v1/second/getList';

  /// The ranked recommendation list (`sort=online`, anonymous).
  static Uri recommend({required int page, required int pageSize}) => Uri.https(
    liveApiHost,
    '/room/v1/Area/getListByAreaID',
    {'areaId': '0', 'parent_area_id': '0', 'sort': 'online', 'pageSize': '${pageSize.clamp(1, 30)}', 'page': '$page'},
  );

  /// The recommendation feed fallback.
  static Uri moreRecommendations({required int page}) =>
      Uri.https(liveApiHost, '/xlive/web-interface/v1/webMain/getMoreRecList', {'platform': 'web', 'page': '$page'});

  /// The search endpoint of [type] (`live` rooms, `live_user` streamers) for
  /// [keyword]; the boilerplate keys are what the web client sends.
  static Uri search({required String type, required String keyword, required int page, int? pageSize}) =>
      Uri.https(apiHost, '/x/web-interface/search/type', {
        'context': '',
        'search_type': type,
        'cover_type': 'user_cover',
        'order': '',
        'keyword': keyword,
        'category_id': '',
        '__refresh__': '',
        '_extra': '',
        'highlight': '0',
        'single_column': '0',
        'page': '$page',
        if (pageSize != null) 'page_size': '$pageSize',
      });

  /// Path of the WBI-signed room detail (`getInfoByRoom`).
  static const String roomDetailPath = '/xlive/web-room/v1/index/getInfoByRoom';

  /// Path of the WBI-signed danmaku credentials (`getDanmuInfo`).
  static const String danmakuInfoPath = '/xlive/web-room/v1/index/getDanmuInfo';

  /// Whether the room is live (`room/v1/Room/get_info`); a carousel is not.
  static Uri liveStatus(String roomId) => Uri.https(liveApiHost, '/room/v1/Room/get_info', {'room_id': roomId.trim()});

  /// The super chat list of the long room id [roomId].
  static Uri superChats(String roomId) =>
      Uri.https(liveApiHost, '/av/v1/SuperChat/getMessageList', {'room_id': roomId});

  /// The gift table: public, anonymous and the same for every room.
  static Uri giftConfig() => Uri.https(liveApiHost, '/xlive/web-room/v1/giftPanel/giftConfig', {'platform': 'pc'});

  /// The play information of the long room id [roomId] at [qn] (0 asks for
  /// whatever this client is allowed).
  static Uri playInfo({required String roomId, required Object qn}) =>
      Uri.https(liveApiHost, '/xlive/web-room/v2/index/getRoomPlayInfo', {
        'room_id': roomId,
        'protocol': '0,1',
        'format': '0,1,2',
        'codec': '0',
        'qn': '$qn',
        'platform': 'web',
        'ptype': '8',
        'dolby': '5',
        'panorama': '1',
        'mask': '0',
        'no_playurl': '0',
      });

  /// The video the room's carousel is playing (`live/getRoundPlayVideo`).
  static Uri roundPlayVideo(String roomId) => Uri.https(liveApiHost, '/live/getRoundPlayVideo', {'room_id': roomId});

  /// `x/player/playurl` of part [cid] of [bvid] as one muxed MP4
  /// (`platform=html5`): unsigned and available to guests.
  static Uri videoPlayUrl(String bvid, int cid) => Uri.https(apiHost, '/x/player/playurl', {
    'bvid': bvid,
    'cid': '$cid',
    'qn': '80',
    'fnval': '0',
    'fnver': '0',
    'fourk': '1',
    'platform': 'html5',
    'high_quality': '1',
  });

  /// The guest buvid pair (`b_3`, `b_4`).
  static Uri fingerSpi() => Uri.https(apiHost, '/x/frontend/finger/spi');

  /// The nav answer (WBI keys, login state).
  static Uri nav() => Uri.https(apiHost, '/x/web-interface/nav');

  /// The page `w_webid`'s access id is read out of.
  static Uri lol() => Uri.https(liveHost, '/lol');

  /// A QR login: the key to poll with, and the URL to encode (the auth
  /// capability's QR issue reads both).
  static Uri qrGenerate() => Uri.https(passportHost, '/x/passport-login/web/qrcode/generate');

  /// One poll of the QR login [key].
  static Uri qrPoll(String key) => Uri.https(passportHost, '/x/passport-login/web/qrcode/poll', {'qrcode_key': key});

  /// The signed-in account (`x/member/web/account`).
  static Uri account() => Uri.https(apiHost, '/x/member/web/account');

  /// API request headers; without a cookie only UA and Referer.
  static Map<String, String> apiHeaders(String cookie) => {
    'user-agent': userAgent,
    'referer': referer,
    if (cookie.isNotEmpty) 'cookie': cookie,
  };

  /// Headers that read a short link: a plain browser UA, no cookie.
  static const Map<String, String> shortLinkHeaders = {'user-agent': userAgent};

  /// Media request headers for the long room id [roomId]: UA, Origin, the
  /// room page as Referer and the cookie. Never `authority` or browser
  /// navigation headers — those make stream reads fail.
  static Map<String, String> mediaHeaders(String roomId, {String? cookie}) => {
    'user-agent': userAgent,
    'origin': origin,
    'referer': '$origin/${Uri.encodeComponent(roomId)}',
    if (cookie != null && cookie.trim().isNotEmpty) 'cookie': cookie.trim(),
  };

  /// The media headers of a carousel video: the video page is the Referer the
  /// CDN checks.
  static Map<String, String> videoHeaders(String bvid, {String? cookie}) => {
    'user-agent': userAgent,
    'referer': 'https://www.bilibili.com/video/${Uri.encodeComponent(bvid)}/',
    if (cookie != null && cookie.trim().isNotEmpty) 'cookie': cookie.trim(),
  };

  /// The name of guard `level` (`guard_level`): 1 总督, 2 提督, 3 舰长; empty
  /// for any other.
  static String guardName(int level) => switch (level) {
    1 => '总督',
    2 => '提督',
    3 => '舰长',
    _ => '',
  };

  /// A gift or guard picture: an absolute http(s) address, `hdslb.com`'s made
  /// https; null when there is none.
  static Uri? giftIcon(Object? value) {
    final url = imageUrl(value);
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final bilibili = uri.host == 'hdslb.com' || uri.host.endsWith('.hdslb.com');
    return bilibili && uri.scheme == 'http' ? uri.replace(scheme: 'https') : uri;
  }
}
