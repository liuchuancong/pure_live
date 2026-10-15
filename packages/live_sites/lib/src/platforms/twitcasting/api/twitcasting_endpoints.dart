/// TwitCasting's (ツイキャス) endpoints and constants (3.x's `TwitcastingApi`
/// statics): the web origin, the request headers, the windows of the list and
/// search answers, the stream tiers, and what a channel id and link are.
abstract final class TwitcastingEndpoints {
  /// Web origin: the channel pages, `Referer` (with a slash) and `Origin`.
  static const String origin = 'https://twitcasting.tv';

  /// Host of the channel pages, the stream server and the comment socket's
  /// URL endpoint.
  static const String host = 'twitcasting.tv';

  /// Hosts of the channel pages.
  static const Set<String> hosts = {'twitcasting.tv', 'www.twitcasting.tv'};

  /// What 3.x sent with every request and every media request: a bare
  /// `Mozilla/5.0` user agent and no `Accept-Language`, to which the site
  /// answers with the same English tab names as sample S01 (2026-09-28).
  static const Map<String, String> headers = {'referer': '$origin/', 'origin': origin, 'user-agent': 'Mozilla/5.0'};

  /// The one window `top/category` answers: 60 broadcasts, no other page.
  /// The popular and area pages ask for it whole and page it locally.
  static const int directoryWindow = 60;

  /// Live results the search page shows at most, all in one page.
  static const int searchWindow = 50;

  /// Tiers of `tc-hls.streams`, best first. The qualities keep 3.x's names
  /// (`HLS high`…) and ids: no rename or merge was decided for TwitCasting,
  /// so there is no old → new id table for stored preferences (M9).
  static const List<String> qualityKeys = ['high', 'medium', 'low'];

  /// Name of the one category (the homepage's tabs are its areas).
  static const String categoryName = 'TwitCasting';

  /// A channel (screen) id, lower case: an optional `c:` (TwitCasting),
  /// `g:` (Google), `f:` (Facebook) or `ig:` (Instagram) prefix and
  /// `[a-z0-9_]`.
  static final RegExp channelPattern = RegExp(r'^(?:(?:c|g|f|ig):)?[a-z0-9_]{1,64}$');

  /// Site pages that look like channels.
  static const Set<String> reservedPaths = {
    'search', 'help', 'login', 'logout', 'settings', 'signup', //
    'register', 'terms', 'privacy', 'about', 'index', 'show', 'categories',
  };

  /// A homepage tab key (`data-channel`).
  static final RegExp areaIdPattern = RegExp(r'^[a-zA-Z0-9_]{1,80}$');

  /// The path of a tier playlist of [movie]: `/tc.livehls/v1/streams/` +
  /// the movie id + `/hls/a.b/media.m3u8`.
  static RegExp playlistPath(int movie) =>
      RegExp('^/tc[.]livehls/v1/streams/$movie/hls/[0-9]+[.][0-9]+/media[.]m3u8\$');

  /// [value] as a channel id (trimmed, lower case), or null when it is not
  /// one or names a site page.
  static String? channelName(String value) {
    final name = value.trim().toLowerCase();
    return channelPattern.hasMatch(name) && !reservedPaths.contains(name) ? name : null;
  }

  /// The channel of a channel page `http(s)://(www.)twitcasting.tv/{id}`
  /// (query and one trailing slash allowed). Movie and archive links name
  /// one old broadcast, not the channel's current one, and are not channels
  /// (REG-TWITCASTING-003); nor are other hosts, ports, user info or
  /// undecodable paths.
  static String? channelFromUri(Uri uri) {
    if (!(uri.isScheme('http') || uri.isScheme('https')) ||
        !hosts.contains(uri.host.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != (uri.isScheme('https') ? 443 : 80))) {
      return null;
    }
    try {
      final parts = uri.pathSegments.toList();
      if (parts.isNotEmpty && parts.last.isEmpty) parts.removeLast();
      return parts.length == 1 ? channelName(parts.single) : null;
    } on FormatException {
      return null;
    }
  }

  /// Whether [value] is a TwitCasting host (the site's own or a subdomain,
  /// as the comment socket's nodes are).
  static bool isSiteHost(String value) => value == host || value.endsWith('.$host');

  /// The homepage, whose tabs are the catalog.
  static Uri homeUrl() => Uri.https(host, '/');

  /// The one `top/category` window of [category] (the whole site's when it
  /// is empty).
  static Uri directoryUrl(String category) =>
      Uri.https('frontendapi.twitcasting.tv', '/top/category', {'id': category, 'count': '$directoryWindow'});

  /// The website's text search page of [query], answered in English.
  static Uri searchUrl(String query) => Uri(
    scheme: 'https',
    host: 'search.twitcasting.tv',
    pathSegments: ['search', 'text', query],
    queryParameters: {'hl': 'en'},
  );

  /// The channel page of [channel] (a redirect means the channel is unknown).
  static Uri channelUrl(String channel) => Uri.https(host, '/$channel');

  /// The stream server's state answer for [channel].
  static Uri streamServerUrl(String channel) =>
      Uri.https(host, '/streamserver.php', {'target': channel, 'mode': 'client', 'player': 'pc_web'});

  /// The channel's own page, the room's link.
  static String roomUrl(String channel) => '$origin/$channel';
}
