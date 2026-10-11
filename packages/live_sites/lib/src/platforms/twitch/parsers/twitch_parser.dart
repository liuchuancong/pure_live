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
      watching: (streamMap?['viewersCount'] as num?)?.toInt(),
      status: live ? LiveStatus.live : LiveStatus.offline,
      restriction: live && restrictionType != null && restrictionType != 'NONE' ? LiveRestriction.regionBlocked : null,
      startedAt: live && createdAt != null ? DateTime.tryParse(createdAt) : null,
    );
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

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
