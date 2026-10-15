/// Picarto.TV's endpoints and constants (the reference `PicartoApi`
/// statics): the two API hosts, the request headers, the platform's limits,
/// the channel-name rule and the one catalog's public directory.
abstract final class PicartoEndpoints {
  /// The site id every request goes as.
  static const String siteId = 'picarto';

  /// The web origin: `Origin`, and with a trailing `/` `Referer`, of every
  /// request.
  static const String origin = 'https://picarto.tv';

  /// Host of the site's internal API (catalog, explore, search, channel
  /// detail, chat tokens).
  static const String apiHost = 'ptvintern.picarto.tv';

  /// Host of the public API (v1). Of its answers only the start of the
  /// broadcast on air (`last_live`) is used: the internal API has none.
  static const String publicApiHost = 'api.picarto.tv';

  /// Host of the chat sockets; the token is part of the path.
  static const String chatHost = 'chat.picarto.tv';

  /// Desktop Chrome 140, the user agent the player sent to the media
  /// servers and every API request carries.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// Headers of every request, names in lower case (`Referer`, `Origin` and
  /// the desktop user agent). No cookie: anonymous.
  static const Map<String, String> headers = {'user-agent': userAgent, 'referer': '$origin/', 'origin': origin};

  /// The title Picarto gives a channel whose streamer never set one. A
  /// placeholder: it is left empty, so it never replaces a follow's stored
  /// title.
  static const String placeholderTitle = 'My Channel Title';

  /// The explore page size the reference's directory pager used.
  static const int pageSize = 30;

  /// Largest page asked for (`first`); larger sizes are clamped.
  static const int maxPageSize = 60;

  /// Longest search keyword sent.
  static const int maxKeywordLength = 100;

  /// Largest answer accepted (1 MiB); a larger one is a parse failure.
  static const int responseLimit = 1024 * 1024;

  /// The single category of the catalog: its id names the parent of every
  /// area, its name the parent's display name.
  static const ({String id, String name}) category = (id: 'picarto', name: 'Picarto');

  /// The first area of the catalog: every public live channel, adult
  /// content excluded (the recommendations).
  static const ({String id, String name}) publicDirectory = (id: 'live', name: '公开直播（不含成人内容）');

  /// Channel names: letters, digits and `_`, 1–50 characters.
  static final RegExp namePattern = RegExp(r'^[a-zA-Z0-9_]{1,50}$');

  /// Site paths that are never channels (case ignored).
  static const Set<String> reservedNames = {
    'explore',
    'search',
    'settings',
    'login',
    'signup',
    'register',
    'password',
    'terms',
    'privacy',
    'help',
    'about',
  };

  /// First path segments of site pages that are no channel, besides
  /// [reservedNames]. Only links use them: a channel of such a name in an
  /// answer is still a channel.
  static const Set<String> pagePaths = {'videos', 'communities', 'subscriptions', 'following', 'shop', 'commissions'};

  /// Hosts of Picarto pages, lower-case.
  static const Set<String> linkHosts = {'picarto.tv', 'www.picarto.tv'};

  /// Whether [name] is a channel name.
  static bool isChannelName(String name) => namePattern.hasMatch(name) && !reservedNames.contains(name.toLowerCase());

  /// The channel page of [name].
  static String roomPageUrl(String name) => '$origin/${Uri.encodeComponent(name.trim())}';

  /// `api/languages-categories`: the platform's categories.
  static Uri categoriesUrl() => Uri.https(apiHost, '/api/languages-categories');

  /// `api/explore` page [page] of [pageSize] rows, live non-adult channels
  /// by viewers; a category narrows it to one.
  static Uri exploreUrl({required int page, required int pageSize, int? categoryId}) =>
      Uri.https(apiHost, '/api/explore', {
        'first': '$pageSize',
        'page': '$page',
        'filter_params[adult]': 'false',
        'order_by[field]': 'viewers',
        'order_by[order]': 'DESC',
        'type': 'stream',
        if (categoryId != null) 'filter_params[languages]': '',
        if (categoryId != null) 'filter_params[categories]': '$categoryId: true',
      });

  /// `api/search` (`searchProfiles`) page [page] of [pageSize] profiles for
  /// [keyword], already trimmed and cut to length.
  static Uri searchUrl({required String keyword, required int page, required int pageSize}) => Uri.https(
    apiHost,
    '/api/search',
    {'first': '$pageSize', 'page': '$page', 'q': keyword, 'type': 'searchProfiles', 'tag_search': 'false'},
  );

  /// `api/channel/detail/<name>`: the channel [name] asks for.
  static Uri channelDetailUrl(String name) => Uri.https(apiHost, '/api/channel/detail/$name');

  /// The public API's record of channel [name] (its broadcast's start).
  static Uri channelNameUrl(String name) => Uri.https(publicApiHost, '/api/v1/channel/name/$name');

  /// The GraphQL endpoint that issues chat tokens.
  static Uri tokenUrl() => Uri.https(apiHost, '/ptvapi');
}
