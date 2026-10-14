/// Kuaishou endpoints, user agents and protocol constants (ARCHITECTURE.md
/// §7.2: endpoint shapes live here; parsing lives in `parsers/`).
abstract final class KuaishouEndpoints {
  /// Web origin; also the media requests' `Origin`.
  static const String origin = 'https://live.kuaishou.com';

  /// Host of the live pages and the `live_api` endpoints.
  static const String host = 'live.kuaishou.com';

  /// The `Accept` the room pages and lists send.
  static const String accept =
      'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,'
      'application/signed-exchange;v=b3';

  /// Desktop Chrome 140 on macOS, the UA the media CDN is asked with.
  static const String mediaUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// The mobile Chrome 139 on Android 16 presented to the comment feed.
  static const String feedUserAgent =
      'Mozilla/5.0 (Linux; Android 16; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/139.0 Mobile Safari/537.36';

  /// The comment feed's `Accept`.
  static const String feedAccept = 'application/json, text/plain, */*';

  /// The comment feed endpoints, primary first; every request tries the
  /// primary and falls back to the second when it gets no usable answer.
  static const List<String> feedEndpoints = [
    'https://livev.m.chenzhongtech.com/wap/live/feed',
    'https://m.gifshow.com/wap/live/feed',
  ];

  /// The `Referer` the comment feed expects.
  static const String feedReferer = 'https://livev.m.chenzhongtech.com/';

  /// The `misc2` device report of a new session (`registerDid`); failures are
  /// ignored, so the endpoint is best-effort.
  static final Uri deviceReport = Uri.parse(
    'https://log-sdk.ksapisrv.com/rest/wd/common/log/collect/misc2?v=3.9.49&kpn=KS_GAME_LIVE_PC',
  );

  /// The eight fixed first-level categories, in the site's order; their areas
  /// come from [categoryData].
  static const List<({String id, String name})> topCategories = [
    (id: '1', name: '热门'),
    (id: '2', name: '网游'),
    (id: '3', name: '单机'),
    (id: '4', name: '手游'),
    (id: '5', name: '棋牌'),
    (id: '6', name: '娱乐'),
    (id: '7', name: '综合'),
    (id: '8', name: '文化'),
  ];

  /// Rooms kept per area page (the platform's own page size).
  static const int areaPageSize = 20;

  /// The home/recommend list (no query).
  static Uri homeList() => Uri.https(host, '/live_api/home/list');

  /// `live_api/category/data`: the areas of category [categoryId] on [page].
  /// The server ignores `size` (it sends 50 a page); the next page exists
  /// while `hasMore` is true.
  static Uri categoryData(String categoryId, int page) =>
      Uri.https(host, '/live_api/category/data', {'type': categoryId, 'page': '$page', 'size': '30'});

  /// Live rooms of one area page. An area id shorter than 7 characters is a
  /// game board (`gameboard`), the rest `non-gameboard`; a non-gameboard page
  /// after the first also sends the previous page's [cursor].
  static Uri areaRooms(String areaId, int page, {String cursor = ''}) {
    final board = areaId.length < 7 ? 'gameboard' : 'non-gameboard';
    return Uri.https(host, '/live_api/$board/list', {
      'filterType': '0',
      'pageSize': '$areaPageSize',
      'gameId': areaId,
      'page': '$page',
      if (cursor.isNotEmpty) 'cursor': cursor,
    });
  }

  /// The streamer search URL, built by hand: `Uri` drops the `=` of an empty
  /// value, and the site gets a trailing `lssid=`.
  static Uri searchAuthor(String keyword, int page) {
    final encoded = Uri.encodeQueryComponent(keyword.trim());
    return Uri.parse('https://$host/live_api/search/author?keyword=$encoded&page=$page&lssid=');
  }

  /// The `Referer` of a search request (the search page it came from).
  static String searchReferer(String keyword) =>
      'https://$host/search?keyword=${Uri.encodeQueryComponent(keyword.trim())}';

  /// The room page of streamer [roomId]: `https://live.kuaishou.com/u/{id}`.
  static Uri roomPage(String roomId) => Uri.parse(roomPageUrl(roomId));

  /// The room page URL of streamer [roomId].
  static String roomPageUrl(String roomId) => '$origin/u/${Uri.encodeComponent(roomId.trim())}';
}
