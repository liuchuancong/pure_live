/// SOOP's (formerly AfreecaTV) endpoints and constants (3.x's `SoopApi`
/// statics): the four hosts of the API, the media CDN's headers, the one
/// catalog category, the platform's limits, and the app-link scheme.
abstract final class SoopEndpoints {
  /// The web origin: `Origin` and `Referer` of API requests, `Origin` of
  /// media requests.
  static const String origin = 'https://www.sooplive.co.kr';

  /// Where the catalog, area lists and search are answered.
  static const String searchHost = 'sch.sooplive.co.kr';

  /// Where the player API and the recommendations are answered.
  static const String liveHost = 'live.sooplive.co.kr';

  /// Where streamers' stations are answered.
  static const String stationHost = 'chapi.sooplive.co.kr';

  /// Where a room's player page lives (the `Referer` of media requests).
  static const String playHost = 'play.sooplive.co.kr';

  /// Desktop Chrome 128, the user agent 3.x sent with every API request.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/128.0.0.0 Safari/537.36';

  /// Desktop Chrome 140, the user agent 3.x sent to the media CDN.
  static const String mediaUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// The SOOP app's link scheme (`sooplive://player/live?…`).
  static const String appScheme = 'sooplive';

  /// The single first-level category every area is listed under: 3.x's id
  /// and name, so areas keep their parent.
  static const ({String id, String name}) category = (id: '1', name: '热门');

  /// Areas asked for per catalog page (3.x's `nListCnt`).
  static const int categoryPageSize = 120;

  /// More catalog pages than the platform has ever had (5 of 120 in
  /// 2026-09), so a server that never says "no more" cannot loop the
  /// catalog.
  static const int maxCategoryPages = 20;

  /// Largest area list sent (3.x clamped `nListCnt` to 1–60).
  static const int areaPageSizeMax = 60;

  /// Largest search page sent (3.x clamped `nListCnt` to 1–50).
  static const int searchPageSizeMax = 50;

  /// Streamer ids (3.x's link rule): letters, digits, `_` and `-`.
  static final RegExp roomIdPattern = RegExp(r'^[a-zA-Z0-9_-]+$');

  /// Hosts of SOOP pages: the two live ones and the former `afreecatv.com`,
  /// which SOOP's own search answers still link to.
  static const Set<String> linkHosts = {'sooplive.co.kr', 'sooplive.com', 'afreecatv.com'};

  /// First path segments that are pages there, not streamers (besides
  /// [reservedSegments] and `station`).
  static const Set<String> pageSegments = {'live', 'vod', 'main', 'my', 'all', 'player'};

  /// Path segments that name pages, not rooms (3.x's shared link rules).
  static const Set<String> reservedSegments = {
    'search',
    'category',
    'categories',
    'directory',
    'directories',
    'game',
    'games',
    'video',
    'videos',
    'user',
    'users',
    'index',
    'topic',
    'topics',
    'downloads',
    'settings',
    'login',
    'signup',
  };

  /// The room page of streamer [roomId].
  static String roomPageUrl(String roomId) => 'https://$playHost/${Uri.encodeComponent(roomId.trim())}';

  /// The SOOP app's link to streamer [roomId]'s broadcast [bno], as list
  /// entries carry it: `sooplive://player/live?broad_no=<bno>&user_id=<id>`;
  /// without [bno] only `user_id`.
  static String appLink(String roomId, {String bno = ''}) => Uri(
    scheme: appScheme,
    host: 'player',
    path: '/live',
    queryParameters: {if (bno.trim().isNotEmpty) 'broad_no': bno.trim(), 'user_id': roomId.trim()},
  ).toString();

  /// The streamer of a SOOP app link ([appLink]'s form: `user_id` of
  /// `sooplive://player/live?…`), lower case; null for anything else.
  static String? appLinkRoomId(String link) {
    final uri = Uri.tryParse(link.trim());
    if (uri == null || !uri.isScheme(appScheme) || uri.host.toLowerCase() != 'player') return null;
    if (uri.pathSegments.firstOrNull?.toLowerCase() != 'live') return null;
    final id = uri.queryParameters['user_id']?.trim().toLowerCase() ?? '';
    return RegExp(r'^[a-z0-9_-]+$').hasMatch(id) ? id : null;
  }

  /// The headers 3.x sent with every API request, names in lower case, plus
  /// [cookie] — the user's login — only when there is one (3.x sent an empty
  /// one, and so does a signed-out viewer; the player API reads this cookie as
  /// the viewer's identity, which is what unlocks an age-restricted broadcast
  /// and the presets above the guest ones).
  static Map<String, String> apiHeaders({String cookie = ''}) => {
    'accept': '*/*',
    'origin': origin,
    'referer': '$origin/',
    'sec-fetch-dest': 'empty',
    'sec-fetch-mode': 'cors',
    'sec-fetch-site': 'same-site',
    'user-agent': userAgent,
    if (cookie.isNotEmpty) 'cookie': cookie,
  };

  /// Media request headers for streamer [roomId]: the media user agent, the
  /// web origin, and the room page as `Referer` (the site root without a
  /// room).
  static Map<String, String> mediaHeaders(String roomId) {
    final id = roomId.trim();
    return {'user-agent': mediaUserAgent, 'origin': origin, 'referer': id.isEmpty ? '$origin/' : roomPageUrl(id)};
  }

  /// The profile image 3.x showed on recommendation and search cards.
  static String avatar(String roomId) {
    final id = roomId.trim();
    if (id.length < 2) return '';
    return 'https://stimg.sooplive.co.kr/LOGO/${id.substring(0, 2)}/$id/m/$id.webp';
  }

  /// The channel logo 3.x showed on a room detail.
  static String logo(String roomId) {
    final id = roomId.trim();
    if (id.length < 2) return '';
    return 'https://stimg.sooplive.co.kr/LOGO/${id.substring(0, 2)}/$id/$id.jpg';
  }

  /// `api.php?m=categoryList`, page [page] of areas.
  static Uri categoryListUrl(int page) => Uri.https(searchHost, '/api.php', {
    'm': 'categoryList',
    'szKeyword': '',
    'szOrder': 'view_cnt',
    'nPageNo': '$page',
    'nListCnt': '$categoryPageSize',
    'nOffset': '0',
    'szPlatform': 'pc',
  });

  /// `api.php?m=categoryContentsList`: live rooms of area [areaId], page
  /// [page] of [pageSize] rows.
  static Uri areaRoomsUrl({required String areaId, required int page, required int pageSize}) =>
      Uri.https(searchHost, '/api.php', {
        'm': 'categoryContentsList',
        'szType': 'live',
        'nPageNo': '$page',
        'nListCnt': '$pageSize',
        'szPlatform': 'pc',
        'szOrder': 'view_cnt_desc',
        'szCateNo': areaId,
      });

  /// `main_broad_list_api.php`: the whole site by viewers, page [page].
  static Uri recommendUrl(int page) => Uri.https(liveHost, '/api/main_broad_list_api.php', {
    'selectType': 'action',
    'selectValue': 'all',
    'orderType': 'view_cnt',
    'pageNo': '$page',
    'lang': 'ko_KR',
  });

  /// `api.php?m=liveSearch`: live rooms matching [keyword], page [page] of
  /// [pageSize] rows.
  static Uri searchUrl(String keyword, {required int page, required int pageSize}) =>
      Uri.https(searchHost, '/api.php', {
        'l': 'DF',
        'm': 'liveSearch',
        'c': 'UTF-8',
        'w': 'webk',
        'isMobile': '0',
        'onlyParent': '1',
        'szType': 'json',
        'szOrder': 'score',
        'szKeyword': keyword,
        'nPageNo': '$page',
        'nListCnt': '$pageSize',
        'tab': 'live',
        'location': 'total_search',
        'isHashSearch': '0',
        'v': '2.0',
      });

  /// A streamer's station.
  static Uri stationUrl(String roomId) => Uri.https(stationHost, '/api/${roomId.trim()}/station');

  /// `player_live_api.php` for streamer [roomId]: `type` `live` (the room)
  /// or `aid` (the stream key), 3.x's form.
  static Uri playerLiveUrl(String roomId) =>
      Uri.https(liveHost, '/afreeca/player_live_api.php', {'bjid': roomId.trim()});

  /// The player API's form fields for `type` of broadcast `bno` at quality
  /// `quality`.
  static Map<String, String> playerFields(
    String roomId, {
    required String type,
    String bno = '',
    String quality = 'HD',
  }) => {
    'bid': roomId.trim(),
    'bno': bno,
    'type': type,
    'pwd': '',
    'player_type': 'html5',
    'stream_type': 'common',
    'quality': quality,
    'mode': 'landing',
    'from_api': '0',
    'is_revive': 'false',
  };
}
