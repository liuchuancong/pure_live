import 'dart:convert';
import 'dart:math';

import 'package:live_sites/live_sites.dart';

/// Static parsers and request bodies for the Twitch GraphQL and usher
/// APIs.
abstract final class TwitchParser {
  /// The public web client id.
  static const String clientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';

  /// Web origin.
  static const String origin = 'https://www.twitch.tv';

  /// The GraphQL endpoint.
  static final Uri gqlUrl = Uri.https('gql.twitch.tv', '/gql');

  /// The user query (channel facts and current stream).
  static const String userQuery =
      r'query($login: String!) { user(login: $login) { id login displayName description '
      'profileImageURL(width: 300) stream { id title type viewersCount createdAt '
      'previewImageURL(width: 640, height: 360) restriction { type } game { id name displayName slug } } '
      'lastBroadcast { title game { name displayName } } } }';

  /// The persisted hash of the `PlaybackAccessToken` query.
  static const String accessTokenHash = 'ed230aa1e33e07eebb8928504583da78a5173989fadfb1ac94be06a04f3cdbe9';

  /// A `Device-Id`: 32 lower-case hexadecimal digits.
  static String deviceId() {
    final random = Random.secure();
    return [for (var i = 0; i < 32; i++) '0123456789abcdef'[random.nextInt(16)]].join();
  }

  /// GraphQL request headers with [deviceId].
  static Map<String, String> gqlHeaders({required String deviceId}) => {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'accept-language': 'en-US;q=0.9,en;q=0.8',
    'accept': 'application/vnd.twitchtv.v5+json',
    'client-id': clientId,
    'origin': origin,
    'referer': '$origin/',
    'device-id': deviceId,
    'content-type': 'text/plain;charset=UTF-8',
  };

  /// Media headers of channel [roomId].
  static Map<String, String> mediaHeaders(String roomId) => {
    'user-agent': gqlHeaders(deviceId: '').values.first,
    'origin': origin,
    'referer': '$origin/${Uri.encodeComponent(roomId.trim())}',
  };

  /// The `user` query body of [login].
  static Map<String, Object?> userOperation(String login) => {
    'query': userQuery,
    'variables': {'login': login},
  };

  /// The `PlaybackAccessToken` operation body of [login].
  static Map<String, Object?> accessTokenOperation(String login) => {
    'operationName': 'PlaybackAccessToken',
    'extensions': {
      'persistedQuery': {'version': 1, 'sha256Hash': accessTokenHash},
    },
    'variables': {
      'isLive': true,
      'login': login,
      'isVod': false,
      'vodID': '',
      'playerType': 'site',
      'isClip': false,
      'clipID': '',
      'platform': 'site',
    },
  };

  /// Validates a GraphQL answer and returns `data`.
  static Map<String, Object?> data(String body, {int status = 200, String what = 'gql'}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('twitch $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('twitch $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('twitch $what: body is not an object');
    }
    final data = decoded['data'];
    if (data is! Map<String, Object?>) {
      final errors = decoded['errors'];
      if (errors is List && errors.isNotEmpty) {
        final message = errors.first is Map<String, Object?>
            ? (errors.first as Map<String, Object?>)['message']?.toString() ?? ''
            : errors.first.toString();
        throw SiteApiChangedError('twitch $what: $message');
      }
      throw SiteApiChangedError('twitch $what: no data');
    }
    return data;
  }

  /// The `user` query answer → the room. A null user is "not found"; a
  /// null stream leaves the channel offline with its last broadcast.
  static LiveRoom room(String body, {required String login, int status = 200}) {
    final data = TwitchParser.data(body, status: status, what: 'user');
    final user = data['user'];
    if (user is! Map<String, Object?>) {
      throw SiteNotFoundError('twitch: no channel $login');
    }
    final echoed = user['login']?.toString() ?? '';
    if (echoed != login) {
      throw SiteApiChangedError('twitch user: asked $login, got $echoed');
    }
    final stream = user['stream'];
    final streamMap = stream is Map<String, Object?> ? stream : null;
    // A 404-restricted stream (type "404") plays only after settling an
    // ad; treat it as live with the restriction noted.
    final restricted = streamMap?['restriction'];
    final restrictionType = restricted is Map<String, Object?> ? restricted['type']?.toString() : null;
    final live = streamMap != null && (streamMap['type']?.toString() != '404');
    final game =
        streamMap?['game'] ??
        (user['lastBroadcast'] is Map<String, Object?>
            ? (user['lastBroadcast']! as Map<String, Object?>)['game']
            : null);
    final gameMap = game is Map<String, Object?> ? game : const <String, Object?>{};
    final createdAt = streamMap?['createdAt']?.toString();
    return LiveRoom(
      platform: SiteIds.twitch,
      roomId: login,
      title: streamMap?['title']?.toString() ?? '',
      nick: user['displayName']?.toString() ?? '',
      avatar: _image(user['profileImageURL']),
      cover: _image(streamMap?['previewImageURL']),
      areaName: (gameMap['displayName'] ?? gameMap['name'])?.toString(),
      watching: SiteCounts.integer(streamMap?['viewersCount']),
      status: live ? LiveStatus.live : LiveStatus.offline,
      restriction: live && restrictionType != null && restrictionType != 'NONE' ? LiveRestriction.regionBlocked : null,
      startedAt: live && createdAt != null ? DateTime.tryParse(createdAt) : null,
    );
  }

  /// The persisted hash of the `SearchResultsPage_SearchResults` query.
  static const String searchHash = '7f3580f6ac6cd8aa1424cff7c974a07143827d6fa36bba1b54318fe7f0b68dc5';

  /// `SearchResultsPage_SearchResults` for [keyword]; a later page names the
  /// channel index's [cursor] in `options.targets` (a first page has none).
  static Map<String, Object?> searchOperation(String keyword, {String? cursor}) => {
    'operationName': 'SearchResultsPage_SearchResults',
    'variables': {
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
    },
    'extensions': {
      'persistedQuery': {'version': 1, 'sha256Hash': searchHash},
    },
  };

  /// `SearchResultsPage_SearchResults`: the channels, live or offline, each as
  /// a card (a channel whose `stream` and `lastBroadcast` share an id is on
  /// air), and the cursor of the next page when `pageInfo.hasNextPage` says
  /// there is one. A `channels` connection with no edges gives nothing and no
  /// cursor; a missing `searchFor` is an empty page (the query is the answer,
  /// not a changed endpoint).
  static ({List<LiveRoom> rooms, String? cursor}) searchPage(String body, {int status = 200}) {
    final data = TwitchParser.data(body, status: status, what: 'SearchResultsPage_SearchResults');
    final channels = SiteJson.object(SiteJson.object(data['searchFor'])['channels']);
    final edges = SiteJson.list(channels['edges']);
    final rooms = <LiveRoom>[];
    for (final edge in edges) {
      final item = SiteJson.object(SiteJson.object(edge)['item']);
      final login = SiteText.text(item['login']);
      if (login.isEmpty) {
        continue;
      }
      final stream = item['stream'] is Map<String, Object?> ? SiteJson.object(item['stream']) : null;
      final broadcast = SiteJson.object(item['lastBroadcast']);
      final streamId = stream?['id']?.toString() ?? '';
      final live = streamId.isNotEmpty && streamId == broadcast['id']?.toString();
      final game = SiteJson.object(stream?['game']);
      final displayName = SiteText.text(item['displayName']);
      rooms.add(
        LiveRoom(
          platform: SiteIds.twitch,
          roomId: login,
          title: SiteText.text(SiteJson.object(item['broadcastSettings'])['title']),
          nick: displayName.isEmpty ? login : displayName,
          avatar: _image(item['profileImageURL']),
          cover: _image(stream?['previewImageURL']),
          areaName: (game['displayName'] ?? game['name'])?.toString(),
          watching: SiteCounts.integer(stream?['viewersCount']),
          status: live ? LiveStatus.live : LiveStatus.offline,
        ),
      );
    }
    String? cursor;
    final pageInfo = SiteJson.object(channels['pageInfo']);
    if (pageInfo['hasNextPage'] == true && edges.isNotEmpty) {
      final last = SiteText.text(SiteJson.object(edges.last)['cursor']);
      cursor = last.isEmpty ? null : last;
    }
    return (rooms: rooms, cursor: cursor);
  }

  /// The `PlaybackAccessToken` answer → the token and signature.
  static ({String value, String signature}) accessToken(String body, {int status = 200}) {
    final data = TwitchParser.data(body, status: status, what: 'PlaybackAccessToken');
    final token = data['streamPlaybackAccessToken'];
    if (token is! Map<String, Object?>) {
      throw const SiteNotFoundError('twitch PlaybackAccessToken: no token');
    }
    final value = token['value']?.toString() ?? '';
    final signature = token['signature']?.toString() ?? '';
    if (value.isEmpty || signature.isEmpty) {
      throw const SiteApiChangedError('twitch PlaybackAccessToken: incomplete token');
    }
    return (value: value, signature: signature);
  }

  /// The usher master playlist URL of [login] with [token].
  static Uri usherUrl(String login, {required ({String value, String signature}) token}) =>
      Uri.https('usher.ttvnw.net', '/api/channel/hls/$login.m3u8', {
        'acmb': 'e30=',
        'allow_source': 'true',
        'cdm': 'wv',
        'fast_bread': 'true',
        'p': '${Random.secure().nextInt(10000000)}',
        'platform': 'web',
        'play_session_id': deviceId(),
        'player_backend': 'mediaplayer',
        'playlist_include_framerate': 'true',
        'reassignments_supported': 'true',
        'sig': token.signature,
        'supported_codecs': 'avc1',
        'token': token.value,
        'transcode_mode': 'cbr_v1',
      });

  /// The persisted hash of the `DirectoryPage_Game` query.
  static const String gameHash = '76cb069d835b8a02914c08dc42c421d0dafda8af5b113a3f19141824b901402f';

  /// Streams one `DirectoryPage_Game` request asks for: an area's list is
  /// fetched 100 at a time and paged locally, as the reference's popular page
  /// did with its recommendations.
  static const int directoryFetchLimit = 100;

  /// Streams one site-wide `streams` request may ask for (`first` is 1–30).
  static const int streamsLimit = 30;

  /// A broadcast language as Twitch's `Language` enum spells it (`ZH`,
  /// `ZH_HK`, `ASL`, `OTHER`).
  static final RegExp languagePattern = RegExp(r'^[A-Z]{2,5}(_[A-Z]{2,4})?$');

  /// The busiest live streams of the whole site, in the broadcast
  /// `languages` when given (the recommendations). The web client has no
  /// persisted query for it; `first` is at most 30. `$languages` is the
  /// `Language` enum: the schema rejects the query when it is declared
  /// `[String!]`.
  static const String streamsQuery =
      r'query($first: Int!, $after: Cursor, $languages: [Language!]) { streams(first: $first, after: $after, '
      r'options: {broadcasterLanguages: $languages}) { edges { cursor node { id title type viewersCount '
      'createdAt previewImageURL(width: 440, height: 248) restriction { type } broadcaster { id login '
      'displayName profileImageURL(width: 70) } game { id name displayName slug } } } '
      'pageInfo { hasNextPage } } }';

  /// The raw [streamsQuery]: [limit] (1–30) of the site's busiest streams
  /// after [cursor], in [languages] (all when empty).
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

  /// `DirectoryPage_Game` of the directory [slug]: [limit] streams by viewers
  /// after [cursor], in [languages] (all when empty).
  static Map<String, Object?> gameOperation(
    String slug, {
    required int limit,
    String? cursor,
    List<String> languages = const [],
  }) => {
    'operationName': 'DirectoryPage_Game',
    'extensions': {
      'persistedQuery': {'version': 1, 'sha256Hash': gameHash},
    },
    'variables': {
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
    },
  };

  /// The broadcast languages as Twitch spells them: upper case, `-` as `_`,
  /// each once; blanks and values that cannot be a language are left out (an
  /// unknown one fails the whole request).
  static List<String> normalizeLanguages(Iterable<String> languages) => [
    ...{
      for (final language in languages)
        if (language.trim().toUpperCase().replaceAll('-', '_') case final code when languagePattern.hasMatch(code))
          code,
    },
  ];

  /// The raw [streamsQuery]: the site's busiest streams as cards (the
  /// recommendations), each with its start time and restriction, and the
  /// cursor of the next page when `pageInfo` says there is one.
  static ({List<LiveRoom> rooms, String? cursor}) streams(String body, {required DateTime now, int status = 200}) {
    final data = TwitchParser.data(body, status: status, what: 'streams');
    final connection = _connection(data['streams']);
    return (
      rooms: [for (final edge in connection.edges) ?_streamCard(edge['node'], now: now)],
      cursor: _nextCursor(connection),
    );
  }

  /// `DirectoryPage_Game`: the streams of a directory as cards, and the cursor
  /// of the next page when `pageInfo` says there is one. A stream is live, or
  /// a replay when it is a rerun. The answer has no start time or restriction.
  /// An unknown directory (`game == null`) is a [SiteNotFoundError].
  static ({List<LiveRoom> rooms, String? cursor}) gameStreams(
    String body, {
    required DateTime now,
    required String slug,
    int status = 200,
  }) {
    final data = TwitchParser.data(body, status: status, what: 'DirectoryPage_Game');
    final game = data['game'] is Map<String, Object?> ? SiteJson.object(data['game']) : null;
    if (game == null) {
      throw SiteNotFoundError('twitch: no directory $slug');
    }
    final connection = _connection(game['streams']);
    return (
      rooms: [for (final edge in connection.edges) ?_streamCard(edge['node'], now: now)],
      cursor: _nextCursor(connection),
    );
  }

  /// One stream node of a list as a card: the broadcaster's login as room,
  /// its display name (the login without one), live or a rerun's replay, the
  /// preview as cover, the game's name as area. The start time (`createdAt`)
  /// and restriction come with the raw [streamsQuery] only. Null without a
  /// broadcaster login.
  static LiveRoom? _streamCard(Object? value, {required DateTime now}) {
    final node = value is Map<String, Object?> ? value : null;
    final broadcaster = node?['broadcaster'] is Map<String, Object?> ? SiteJson.object(node?['broadcaster']) : null;
    final login = SiteText.text(broadcaster?['login']);
    if (node == null || broadcaster == null || login.isEmpty) {
      return null;
    }
    final game = node['game'] is Map<String, Object?> ? SiteJson.object(node['game']) : null;
    final viewers = SiteCounts.integer(node['viewersCount']);
    final displayName = SiteText.text(broadcaster['displayName']);
    return LiveRoom(
      platform: SiteIds.twitch,
      roomId: login,
      title: SiteText.text(node['title']),
      nick: displayName.isEmpty ? login : displayName,
      avatar: _image(broadcaster['profileImageURL']),
      cover: _cover(node['previewImageURL'], now),
      areaName: game == null ? null : _gameName(game),
      watching: viewers,
      status: _isRerun(node) ? LiveStatus.replay : LiveStatus.live,
      startedAt: _time(node['createdAt']),
      restriction: _restriction(node),
    );
  }

  /// The restriction of a stream node that was asked for its `restriction`
  /// ([streamsQuery]): none when it is null; subscribers only for Twitch's
  /// subscriber-only streams (a type naming `SUB`); another kind is
  /// `unplayable`. Null when the node has no such key (the persisted list
  /// queries do not ask for it).
  static LiveRestriction? _restriction(Map<String, Object?> stream) {
    if (!stream.containsKey('restriction')) {
      return null;
    }
    final value = stream['restriction'];
    if (value == null) {
      return LiveRestriction.none;
    }
    final type = SiteText.text(SiteJson.object(value)['type']).toUpperCase();
    return type.contains('SUB') ? LiveRestriction.subscribersOnly : LiveRestriction.unplayable;
  }

  static ({List<Map<String, Object?>> edges, bool hasNextPage}) _connection(Object? value) {
    final connection = SiteJson.object(value);
    return (
      edges: SiteJson.objects(connection['edges']),
      hasNextPage: SiteJson.object(connection['pageInfo'])['hasNextPage'] == true,
    );
  }

  static String? _nextCursor(({List<Map<String, Object?>> edges, bool hasNextPage}) connection) {
    if (!connection.hasNextPage || connection.edges.isEmpty) {
      return null;
    }
    final cursor = SiteText.text(connection.edges.last['cursor']);
    return cursor.isEmpty ? null : cursor;
  }

  static String _gameName(Map<String, Object?> game) {
    final display = SiteText.text(game['displayName']);
    return display.isEmpty ? SiteText.text(game['name']) : display;
  }

  static bool _isRerun(Map<String, Object?> stream) => stream['type'] == 'rerun';

  /// An ISO 8601 time (`2026-09-27T12:49:35Z`) as UTC; null when missing,
  /// unreadable or not after 1970.
  static DateTime? _time(Object? value) {
    final time = DateTime.tryParse(SiteText.text(value))?.toUtc();
    return time == null || time.millisecondsSinceEpoch <= 0 ? null : time;
  }

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }

  /// A stream preview with `?&t=<Unix seconds>` so a refresh fetches the
  /// current frame; null without a preview.
  static String? _cover(Object? value, DateTime now) {
    final url = SiteText.text(value).trim();
    return url.isEmpty ? null : '$url?&t=${now.millisecondsSinceEpoch ~/ 1000}';
  }
}
