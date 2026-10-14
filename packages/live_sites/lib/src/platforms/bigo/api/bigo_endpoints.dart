/// Bigo Live endpoints, headers and protocol constants (ARCHITECTURE.md §7.2:
/// endpoint shapes live here; parsing lives in `parsers/`).
///
/// Bigo is anonymous: no cookie, no account, no login flow. Every request
/// carries the same desktop-browser fingerprint ([headers]) because the site's
/// firewall answers a bare user agent with a 418 or with a `needLogin` shell
/// (checked 2026-10-06), and it never follows a redirect.
abstract final class BigoEndpoints {
  /// The website; the `Origin` and `Referer` of every request.
  static const String webOrigin = 'https://www.bigo.tv';

  /// The public list, the studio and the chat visitor account.
  static const String apiHost = 'ta.bigo.tv';

  /// The anonymous web token service.
  static const String tokenHost = 'sec.bigo.sg';

  /// The chat socket of `www.bigo.tv` (`wss.bigoapp.tv` and `wss.bigoapp.ru`
  /// serve the site's other domains).
  static const String chatHost = 'wss.bigolive.tv';

  /// The desktop browser user agent of [headers] and the chat handshake.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// The headers of every request, of the chat handshake and of the media.
  static const Map<String, String> headers = {
    'origin': webOrigin,
    'referer': '$webOrigin/',
    'user-agent': userAgent,
    'accept': 'application/json, text/javascript, */*; q=0.01',
    'accept-language': 'zh-CN,zh;q=0.9,en;q=0.8',
    'x-requested-with': 'XMLHttpRequest',
  };

  /// The largest answer accepted, in UTF-8 bytes.
  static const int responseLimit = 1024 * 1024;

  /// The platform's name: the cards' area and the one area's type name.
  static const String siteName = 'Bigo Live';

  /// The one area: the public list, whose id is the `vedioList` path segment.
  static const String areaId = '72';

  /// The one area's name.
  static const String areaName = '公开推荐';

  /// Rooms kept per directory page (the platform's own page size).
  static const int directoryPageSize = 20;

  /// The largest slice served; a bigger page size gives nothing.
  static const int maxPageSize = 100;

  /// The id of the one quality.
  static const String qualityId = 'live';

  /// The label of the one quality.
  static const String qualityLabel = '直播自动';

  /// First path segments of `bigo.tv` that are pages, not rooms.
  static const Set<String> reservedPaths = {'about', 'download', 'index', 'live', 'login', 'search', 'signup'};

  /// `OInterfaceWeb/vedioList/72`: the public list, a finite snapshot of about
  /// 20 live rooms whatever `fetchNum` asks.
  static Uri publicList() => Uri.https(apiHost, '/official_website/OInterfaceWeb/vedioList/$areaId', {
    'tabType': '00',
    'fetchNum': '10',
    'lang': 'en',
    'countryCode': 'US',
  });

  /// `webjs/t`: the server time the token request is made for (a JSONP answer
  /// of [callback]).
  static Uri serverTime(String callback) => Uri.https(tokenHost, '/v1/webjs/t', {'callback': callback});

  /// `webjs/status`: the web token for the encrypted [data] (a JSONP answer of
  /// [callback]).
  static Uri tokenRequest(String callback, String data) =>
      Uri.https(tokenHost, '/v1/webjs/status', {'callback': callback, 'data': data});

  /// `studio/getInternalStudioInfo` for [siteId] with the web [token].
  static Uri studio(String siteId, String token) => Uri.https(
    apiHost,
    '/official_website/studio/getInternalStudioInfo',
    {'siteId': siteId, 'verify': '', 'token': token},
  );

  /// `studio/getWebSocketLink`: where the page gets its chat visitor account.
  static Uri chatLink() => Uri.https(apiHost, '/official_website/studio/getWebSocketLink');

  /// The room page of [siteId].
  static String roomPageUrl(String siteId) => '$webOrigin/$siteId';

  /// The room page of [siteId] as a URI.
  static Uri roomPage(String siteId) => Uri.parse(roomPageUrl(siteId));
}
