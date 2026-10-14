/// Kick endpoints, user agents and protocol constants (ARCHITECTURE.md §7.2:
/// endpoint shapes live here; the parsers read the answers).
abstract final class KickEndpoints {
  /// Desktop Chrome 140, the UA the web client sends.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// The web origin: every API and media request names it.
  static const String origin = 'https://kick.com';

  /// Host of the API (`/api/v2/channels`, `/api/v1/categories`,
  /// `/stream/livestreams` and `/api/search` all answer from here).
  static const String apiHost = 'kick.com';

  /// The suffix an IVS master playlist host must end with for a
  /// `playback_url` to be playable.
  static const String ivsHostSuffix = '.live-video.net';

  /// Headers of every API request (no auth, no csrf, no client id: Kick's
  /// web API is anonymous).
  static const Map<String, String> headers = {
    'user-agent': userAgent,
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'en-US,en;q=0.9',
    'origin': origin,
    'referer': 'https://kick.com/',
  };

  /// Headers of the media requests of channel [slug]: the IVS playback token
  /// names kick.com as its origin.
  static Map<String, String> mediaHeaders(String slug) => {
    'user-agent': userAgent,
    'origin': origin,
    'referer': '${roomPageUrl(slug)}/',
  };

  /// Largest live-list page the API serves (`limit` above 30 is refused).
  static const int pageSize = 30;

  /// Subcategories asked for per top-level category: the most the API gives
  /// in one page (`limit` above 32 is answered with 32).
  static const int subcategoryLimit = 32;

  /// Longest search keyword sent.
  static const int maxKeywordLength = 50;

  /// The room notice of a broadcast Kick marks as mature (18+).
  static const String matureNotice = 'This broadcast is marked as mature (18+) content on Kick.';

  /// Kick's own pages, never channels.
  static const Set<String> reservedSlugs = {
    'about',
    'auth',
    'browse',
    'categories',
    'category',
    'clips',
    'community-guidelines',
    'dashboard',
    'dmca-policy',
    'following',
    'legal',
    'popout',
    'privacy-policy',
    'search',
    'settings',
    'subscriptions',
    'terms-of-service',
    'video',
    'videos',
  };

  static final RegExp _slug = RegExp(r'^[a-z0-9_-]{1,100}$');

  /// A subcategory slug as the live directory filters by it (Kick's own
  /// slugs carry `+` and `:` besides the channel charset).
  static final RegExp subcategoryPattern = RegExp(r'^[a-z0-9:+_-]{1,100}$');

  /// [raw] as a channel slug (lower case), or null when it cannot be one.
  static String? normalizeSlug(String raw) {
    final slug = raw.trim().toLowerCase();
    return _slug.hasMatch(slug) && !reservedSlugs.contains(slug) ? slug : null;
  }

  /// The channel page of [slug].
  static String roomPageUrl(String slug) => '$origin/${slug.trim().toLowerCase()}';

  /// The channel answer of [slug] (`api/v2/channels/<slug>`).
  static Uri channel(String slug) => Uri.https(apiHost, '/api/v2/channels/${slug.trim().toLowerCase()}');

  /// The top-level categories (`api/v1/categories`).
  static Uri categories() => Uri.https(apiHost, '/api/v1/categories');

  /// The subcategories of category [slug] (`api/v1/subcategories`).
  static Uri subcategories(String slug, {int page = 1}) =>
      Uri.https(apiHost, '/api/v1/subcategories', {'category': slug, 'limit': '$subcategoryLimit', 'page': '$page'});

  /// A page of the live directory (`stream/livestreams`), by viewers, of
  /// subcategory [subcategory] when given.
  static Uri livestreams(int page, int limit, {String? subcategory}) => Uri.https(apiHost, '/stream/livestreams/en', {
    'page': '${page < 1 ? 1 : page}',
    'limit': '${limit.clamp(1, pageSize)}',
    'sort': 'desc',
    if (subcategory != null && subcategory.isNotEmpty) 'subcategory': subcategory,
  });

  /// The search answer for [keyword] (`api/search`); Kick searches with one
  /// page and no continuation.
  static Uri search(String keyword) => Uri.https(apiHost, '/api/search', {'searched_word': keyword});

  /// The full page URL of a channel slug (the resolver's canonical answer).
  static Uri roomPage(String slug) => Uri.parse(roomPageUrl(slug));

  /// Kick's Pusher app key, as the web client sends it.
  static const String pusherAppKey = '32cbd69e4b950bf97679';

  /// Kick's Pusher endpoint: the US2 socket of Kick's own app (protocol 7,
  /// the web client's `pusher-js` version).
  static Uri pusherEndpoint() =>
      Uri.parse('wss://ws-us2.pusher.com/app/$pusherAppKey?protocol=7&client=js&version=8.4.0&flash=false');

  /// Handshake headers of the chat socket: the site's origin and the UA.
  static const Map<String, String> socketHeaders = {'origin': origin, 'user-agent': userAgent};
}
