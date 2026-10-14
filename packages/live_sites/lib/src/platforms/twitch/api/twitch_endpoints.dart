import 'dart:math';

/// Twitch's request surface: the web client's constants, the GraphQL
/// operations and the usher URL.
///
/// Everything here is a literal the web player sends; a persisted query hash
/// that no longer resolves fails its operation with `PersistedQueryNotFound`
/// (the parsers read that as api-changed), so the hashes are named constants
/// rather than inlined at each call.
abstract final class TwitchEndpoints {
  /// Desktop Chrome 137 — the UA sent to GraphQL, usher and the CDN.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/137.0.0.0 Safari/537.36';

  /// The web client's `Client-Id`.
  static const String clientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';

  /// The site, and the `Origin` of every request.
  static const String origin = 'https://www.twitch.tv';

  /// `POST https://gql.twitch.tv/gql` — every catalog, list, search and room
  /// request goes here.
  static final Uri gql = Uri.https('gql.twitch.tv', '/gql');

  /// The `accept` header of GraphQL and usher answers.
  static const String accept = 'application/vnd.twitchtv.v5+json';

  /// Operations one GraphQL request may carry (above this Twitch answers
  /// `BATCH_LIMIT_EXCEEDED`).
  static const int batchLimit = 35;

  /// Directories per page of a category tag.
  static const int tagDirectoryLimit = 30;

  /// Streams one `DirectoryPage_Game` request asks for; an area's list is
  /// fetched 100 at a time and cut into pages locally.
  static const int directoryFetchLimit = 100;

  /// Streams one site-wide `streams` request may ask for (`first` is 1–30).
  static const int streamsLimit = 30;

  /// Pages of one category tag at most; a tag whose cursor repeats ends
  /// earlier.
  static const int tagPageLimit = 50;

  /// `Accept-Language`: the web client's own value, so Twitch answers in
  /// English (a game's `displayName`, else its `name`).
  static const String acceptLanguage = 'en-US,en;q=0.9';

  /// The broadcast languages the 3.x client always filtered by (Chinese and
  /// Korean); nothing is filtered unless the caller gives languages.
  static const List<String> legacyLanguages = ['ZH', 'KO'];

  /// A broadcast language as Twitch's `Language` enum spells it (`ZH`,
  /// `ZH_HK`, `ASL`, `OTHER`).
  static final RegExp languagePattern = RegExp(r'^[A-Z]{2,5}(_[A-Z]{2,4})?$');

  /// The channel login pattern (the lower-cased room id).
  static final RegExp loginPattern = RegExp(r'^[a-z0-9_]{1,25}$');

  /// A channel login as links spell it (case kept).
  static final RegExp linkLogin = RegExp(r'^[a-zA-Z0-9_]{1,25}$');

  /// Hosts whose first path segment is a channel.
  static const Set<String> channelHosts = {'twitch.tv', 'www.twitch.tv', 'm.twitch.tv', 'go.twitch.tv'};

  /// Twitch's own pages: a first path segment in here is not a channel.
  static const Set<String> sitePages = {
    'about',
    'apps',
    'community',
    'directory',
    'downloads',
    'drops',
    'following',
    'friends',
    'games',
    'inventory',
    'jobs',
    'login',
    'messages',
    'moderator',
    'p',
    'payments',
    'popout',
    'prime',
    'privacy',
    'search',
    'settings',
    'signin',
    'store',
    'subscriptions',
    'turbo',
    'user',
    'videos',
    'wallet',
  };

  /// usher's `supported_codecs` when H.264 is preferred.
  static const String h264Codecs = 'h264';

  /// usher's `supported_codecs` that also allow HEVC and AV1 (Enhanced
  /// Broadcasting).
  static const String enhancedCodecs = 'av1,h265,h264';

  /// The two `play_session_id`s the web player has been seen sending; one is
  /// picked per playlist request.
  static const List<String> playSessionIds = ['bdd22331a986c7f1073628f2fc5b19da', '064bc3ff1722b6f53b0b5b8c01e46ca5'];

  static const String _tagsHash = 'b4cb189d8d17aadf29c61e9d7c7e7dcfc932e93b77b3209af5661bffb484195f';
  static const String _directoriesHash = '2f67f71ba89f3c0ed26a141ec00da1defecb2303595f5cda4298169549783d9e';
  static const String _gameHash = '76cb069d835b8a02914c08dc42c421d0dafda8af5b113a3f19141824b901402f';
  static const String _searchHash = '7f3580f6ac6cd8aa1424cff7c974a07143827d6fa36bba1b54318fe7f0b68dc5';
  static const String _accessTokenHash = 'ed230aa1e33e07eebb8928504583da78a5173989fadfb1ac94be06a04f3cdbe9';

  /// One channel with its stream. The web client has no persisted query for
  /// it, so it goes as raw text.
  static const String userQuery =
      r'query($login: String!) { user(login: $login) { id login displayName description '
      'profileImageURL(width: 300) stream { id title type viewersCount createdAt '
      'previewImageURL(width: 640, height: 360) restriction { type } game { id name displayName slug } } '
      'lastBroadcast { title game { name displayName } } } }';

  /// The busiest live streams of the whole site. `$languages` is the
  /// `Language` enum: since 2026-10 the schema rejects the query when it is
  /// declared `[String!]`, sent or not.
  static const String streamsQuery =
      r'query($first: Int!, $after: Cursor, $languages: [Language!]) { streams(first: $first, after: $after, '
      r'options: {broadcasterLanguages: $languages}) { edges { cursor node { id title type viewersCount '
      'createdAt previewImageURL(width: 440, height: 248) restriction { type } broadcaster { id login '
      'displayName profileImageURL(width: 70) } game { id name displayName slug } } } '
      'pageInfo { hasNextPage } } }';

  /// A persisted-query operation.
  static Map<String, Object?> persisted(String operation, String hash, Map<String, Object?> variables) => {
    'operationName': operation,
    'extensions': {
      'persistedQuery': {'version': 1, 'sha256Hash': hash},
    },
    'variables': variables,
  };

  /// `SearchCategoryTags`: every category tag.
  static Map<String, Object?> tagsOperation() =>
      persisted('SearchCategoryTags', _tagsHash, {'userQuery': '', 'limit': 100});

  /// `BrowsePage_AllDirectories` of one tag, by viewers, after [cursor].
  static Map<String, Object?> directoriesOperation(String tagId, {String? cursor}) =>
      persisted('BrowsePage_AllDirectories', _directoriesHash, {
        'limit': tagDirectoryLimit,
        'options': {
          'recommendationsContext': {'platform': 'web'},
          'requestID': 'JIRA-VXP-2397',
          'sort': 'VIEWER_COUNT',
          'tags': [tagId],
        },
        'cursor': ?cursor,
      });

  /// `DirectoryPage_Game` of the directory [slug]: [limit] streams by viewers
  /// after [cursor], broadcast in [languages] (all when empty).
  static Map<String, Object?> gameOperation(
    String slug, {
    required int limit,
    String? cursor,
    List<String> languages = const [],
  }) => persisted('DirectoryPage_Game', _gameHash, {
    'imageWidth': 50,
    'slug': slug,
    'options': {
      'sort': 'VIEWER_COUNT',
      'recommendationsContext': {'platform': 'web'},
      'requestID': 'JIRA-VXP-2397',
      'freeformTags': null,
      'tags': <String>[],
      'broadcasterLanguages': languages,
      'systemFilters': <String>[],
    },
    'sortTypeIsRecency': false,
    'limit': limit,
    'includeCostreaming': true,
    'cursor': ?cursor,
  });

  /// The raw [streamsQuery]: [limit] (1–30) of the site's busiest streams
  /// after [cursor], broadcast in [languages] (all when empty).
  static Map<String, Object?> streamsOperation({
    required int limit,
    String? cursor,
    List<String> languages = const [],
  }) => {
    'query': streamsQuery,
    'variables': {
      'first': limit.clamp(1, streamsLimit),
      'after': ?cursor,
      if (languages.isNotEmpty) 'languages': languages,
    },
  };

  /// The raw [userQuery] for [login].
  static Map<String, Object?> userOperation(String login) => {
    'query': userQuery,
    'variables': {'login': login},
  };

  /// `SearchResultsPage_SearchResults` for [keyword]; a later page names the
  /// channel index's [cursor] in `options.targets` — a top-level `cursor` is
  /// ignored by the server.
  static Map<String, Object?> searchOperation(String keyword, {String? cursor}) =>
      persisted('SearchResultsPage_SearchResults', _searchHash, {
        'platform': 'web',
        'query': keyword,
        'options': {
          'targets': cursor == null
              ? null
              : [
                  {'index': 'CHANNEL', 'cursor': cursor},
                ],
          'shouldSkipDiscoveryControl': false,
        },
        'requestID': '808c9f2e-f52e-431c-8dc7-d2e3c1831d77',
        'includeIsDJ': true,
      });

  /// `PlaybackAccessToken` of a live channel.
  static Map<String, Object?> accessTokenOperation(String login) => persisted('PlaybackAccessToken', _accessTokenHash, {
    'isLive': true,
    'login': login,
    'isVod': false,
    'vodID': '',
    'playerType': 'site',
    'isClip': false,
    'clipID': '',
    'platform': 'site',
  });

  /// The broadcast languages of a setting as Twitch spells them: upper case,
  /// `-` as `_`, each once; blanks and values that cannot name a language are
  /// left out (an unknown one fails the whole request).
  static List<String> normalizeLanguages(Iterable<String> languages) => [
    ...{
      for (final language in languages)
        if (language.trim().toUpperCase().replaceAll('-', '_') case final code when languagePattern.hasMatch(code))
          code,
    },
  ];

  /// usher's `supported_codecs`: [h264Codecs] when [preferH264]; else the
  /// web player's [enhancedCodecs] limited to the codecs the engine decodes
  /// ([codecs]; null means unknown, so all of them). H.264 is always last,
  /// as the web player asks.
  static String supportedCodecs({required bool preferH264, Set<String>? codecs}) {
    if (preferH264) return h264Codecs;
    return [
      if (codecs == null || codecs.contains('av1')) 'av1',
      if (codecs == null || codecs.contains('hevc')) 'h265',
      'h264',
    ].join(',');
  }

  /// A `Device-Id`: 32 lower-case hexadecimal digits.
  static String deviceId(Random random) => [for (var index = 0; index < 32; index++) _hex[random.nextInt(16)]].join();

  /// usher's master playlist of [login] signed by [value] and [signature], with
  /// the web player's parameters (a random `p`, one of [playSessionIds]) and the
  /// codecs asked for.
  static Uri usherUrl(
    String login, {
    required String value,
    required String signature,
    required Random random,
    bool preferH264 = true,
    Set<String>? codecs,
  }) => Uri.https('usher.ttvnw.net', '/api/channel/hls/$login.m3u8', {
    'acmb': 'e30=',
    'allow_source': 'true',
    'cdm': 'wv',
    'fast_bread': 'true',
    'p': '${random.nextInt(10000000)}',
    'platform': 'web',
    'play_session_id': playSessionIds[random.nextInt(playSessionIds.length)],
    'player_backend': 'mediaplayer',
    'player_version': '1.28.0-rc.1',
    'playlist_include_framerate': 'true',
    'reassignments_supported': 'true',
    'sig': signature,
    'supported_codecs': supportedCodecs(preferH264: preferH264, codecs: codecs),
    'token': value,
    'transcode_mode': 'cbr_v1',
  });

  /// The channel page of [login] (a pop-out chat's Referer, and the
  /// resolver's canonical link).
  static String roomPageUrl(String login) => '$origin/${Uri.encodeComponent(login.trim())}';

  static const String _hex = '0123456789abcdef';
}

/// The value of cookie [name] in [cookie] (names compared without case, `=`
/// kept inside the value); null when missing or empty.
String? twitchCookieValue(String cookie, String name) {
  for (final part in cookie.split(';')) {
    final separator = part.indexOf('=');
    if (separator <= 0 || part.substring(0, separator).trim().toLowerCase() != name) continue;
    final value = part.substring(separator + 1).trim();
    return value.isEmpty ? null : value;
  }
  return null;
}

/// The OAuth token of a stored cookie (`auth-token`).
String? twitchAuthToken(String cookie) => twitchCookieValue(cookie, 'auth-token');

/// The chat login of a stored cookie: `login` (lower case) with `auth-token`,
/// null unless both are there.
({String login, String token})? twitchChatLogin(String cookie) {
  final token = twitchAuthToken(cookie);
  final login = twitchCookieValue(cookie, 'login')?.toLowerCase();
  return token == null || login == null ? null : (login: login, token: token);
}
