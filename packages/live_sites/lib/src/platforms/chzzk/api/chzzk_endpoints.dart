import 'dart:convert';

/// CHZZK endpoints, headers and protocol constants (ARCHITECTURE.md §7.2:
/// endpoint shapes live here; parsing lives in `parsers/`).
///
/// CHZZK is anonymous and public: no cookie, no signature, no API key. Every
/// request carries the same desktop-browser fingerprint and follows no
/// redirect — a 3xx is a network failure, not an answer.
abstract final class ChzzkEndpoints {
  /// The JSON API host.
  static const String apiHost = 'api.chzzk.naver.com';

  /// The website; the `Origin` and `Referer` of every request.
  static const String origin = 'https://chzzk.naver.com';

  /// The chat host whose routing service names the session servers.
  static const String chatHost = 'chat.naver.com';

  /// The desktop browser user agent of [headers] and the chat handshake.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// The headers of every API request and of the master playlists.
  static const Map<String, String> headers = {
    'user-agent': userAgent,
    'accept': 'application/json, text/plain, */*',
    'origin': origin,
    'referer': '$origin/',
  };

  /// Media request headers: the segments and playlists are asked with less
  /// than the API is (the site's own playback headers).
  static const Map<String, String> mediaHeaders = {'user-agent': userAgent, 'referer': '$origin/'};

  /// The largest answer read (2 MiB, counted as the site's own code counts it:
  /// characters of the decoded body).
  static const int responseLimit = 2 * 1024 * 1024;

  /// The platform's display name and the parent name of every area.
  static const String siteName = 'CHZZK';

  /// Rows of a lives page, also after a cursor: the platform sends exactly
  /// this many and its cursor names the row it points after.
  static const int pageSize = 30;

  /// The last page number the adapter replays to.
  static const int maxDirectoryPage = 20;

  /// Areas asked per `categories/live` page.
  static const int categoryPageSize = 50;

  /// `categories/live` pages read for the catalog: the list is sorted by
  /// viewers, and four pages held every area with a real audience on
  /// 2026-09-29 (200 of 228 areas, 1269 of 1298 lives); the areas after them
  /// have one or two lives each.
  static const int maxCategoryPages = 4;

  /// Names of the platform's `categoryType`s, in catalog order. Another type
  /// is listed after these under its own name.
  static const Map<String, String> categoryTypeNames = {
    'GAME': '游戏',
    'ENTERTAINMENT': '娱乐',
    'SPORTS': '体育',
    'ETC': '其他',
  };

  /// Rows of a search page, whatever the caller asks (the website's own size).
  static const int searchPageSize = 20;

  /// The longest keyword searched; a longer one is cut, never refused.
  static const int maxKeywordLength = 100;

  /// The largest search offset; past it the caller is wrong, without a
  /// request.
  static const int maxSearchOffset = 1000000;

  /// How long before its token expires a line is renewed (at most a quarter of
  /// its lifetime).
  static const Duration leaseLead = Duration(minutes: 10);

  /// The media list of one `livePlaybackJson`; more than this is a changed API.
  static const int maxMediaItems = 16;

  /// The longest accepted master playlist or media path.
  static const int maxPathLength = 16384;

  /// First path segments of `chzzk.naver.com` that are not a channel.
  static const String livePath = 'live';

  /// `categories/live`: the page after [after] (the previous page's `next`,
  /// empty for the first).
  static Uri categories(Map<String, String> after) =>
      Uri.https(apiHost, '/service/v1/categories/live', {'size': '$categoryPageSize', ...after});

  /// The lives page of [areaType]/[areaId] with [query] — the site-wide
  /// `/service/v1/lives` when [areaId] is null. The path segments are built by
  /// hand because an area id may hold an `&` (`Mount_&_Blade2_Bannerlord`),
  /// which the platform itself accepts.
  static Uri lives({String? areaType, String? areaId, Map<String, String> query = const {}}) {
    if (areaId == null) return Uri.https(apiHost, '/service/v1/lives', query);
    return Uri(
      scheme: 'https',
      host: apiHost,
      pathSegments: ['service', 'v2', 'categories', areaType!, areaId, 'lives'],
      queryParameters: query,
    );
  }

  /// The channel search for [keyword] at [offset].
  static Uri search(String keyword, int offset) => Uri.https(apiHost, '/service/v1/search/channels', {
    'keyword': keyword,
    'offset': '$offset',
    'size': '$searchPageSize',
  });

  /// One channel's page (its name, avatar, followers and `openLive`).
  static Uri channel(String channelId) => Uri.https(apiHost, '/service/v1/channels/$channelId');

  /// One channel's latest live. `v3.1`, never `v2`: the v2 endpoint answers an
  /// overseas-restricted live with HTTP 500 / code 9004 and the whole read
  /// fails (seen 2026-09-28).
  static Uri liveDetail(String channelId) => Uri.https(apiHost, '/service/v3.1/channels/$channelId/live-detail');

  /// The live state of [channelId], which the site's chat page polls every
  /// 30 s; the adapter asks it only when a joined chat has gone quiet.
  static Uri liveStatus(String channelId) => Uri.https(apiHost, '/polling/v3.1/channels/$channelId/live-status');

  /// The read-only chat access token of [chatChannelId].
  static Uri accessToken(String chatChannelId) => Uri.https(
    'comm-api.game.naver.com',
    '/nng_main/v1/chats/access-token',
    {'channelId': chatChannelId, 'chatType': 'STREAMING'},
  );

  /// The session servers of the chat service `game`.
  static Uri routing() => Uri.https('routing.$chatHost', '/routing/getRouting', {'serviceId': 'game'});

  /// The chat socket of [host].
  static Uri chatSocket(String host) => Uri(scheme: 'wss', host: host, path: '/chat');

  /// The web page of [channelId] — the room's own link.
  static String roomUrl(String channelId) => '$origin/live/$channelId';

  /// The lives query of a page after [cursor]: [pageSize] rows, and after a
  /// cursor its two fields. The cursor is exclusive — the page after it starts
  /// at the next row (proved by the recorded page pair of 2026-09-27; the
  /// reference asked one row more and dropped the repeated first).
  static Map<String, String>? livesQuery(String? cursor) {
    if (cursor == null) return {'size': '$pageSize'};
    final after = decodeCursor(cursor);
    if (after == null) return null;
    return {'size': '$pageSize', 'concurrentUserCount': '${after.viewers}', 'liveId': '${after.liveId}'};
  }

  /// The cursor after the row of [viewers] and [liveId]: an opaque JSON pair.
  static String encodeCursor(int viewers, int liveId) => jsonEncode({'v': viewers, 'l': liveId});

  /// The row a cursor of [encodeCursor] points after; null for anything else
  /// (a caller error the capabilities report, refused before any request).
  static ({int viewers, int liveId})? decodeCursor(String? cursor) {
    if (cursor == null || cursor.length > 128) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(cursor);
    } on FormatException {
      return null;
    }
    if (decoded is! Map || decoded.length != 2) return null;
    final viewers = decoded['v'];
    final liveId = decoded['l'];
    if (viewers is! int || viewers < 0 || liveId is! int || liveId <= 0) return null;
    return (viewers: viewers, liveId: liveId);
  }
}
