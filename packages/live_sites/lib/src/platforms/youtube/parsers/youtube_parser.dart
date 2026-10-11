import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the YouTube InnerTube player API.
abstract final class YouTubeParser {
  /// InnerTube origin.
  static const String origin = 'https://www.youtube.com';

  /// The public fallback API key (the watch page carries the current one).
  static const String fallbackApiKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

  /// The watch page URL of [videoId].
  static String videoUrl(String videoId) => '$origin/watch?v=$videoId';

  /// A video id: 11 characters of [A-Za-z0-9_-].
  static String? normalizeVideoId(String value) {
    final id = value.trim();
    return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id) ? id : null;
  }

  /// Request headers of the ANDROID player client.
  static Map<String, String> playerHeaders(String videoId) => {
    'user-agent': 'com.google.android.youtube/21.08.266 (Linux; U; Android 14) gzip',
    'accept': 'application/json',
    'origin': origin,
    'referer': videoId.isEmpty ? '$origin/' : videoUrl(videoId),
  };

  /// Media headers of [videoId]'s manifest.
  static Map<String, String> mediaHeaders(String videoId) => {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'origin': origin,
    'referer': videoId.isEmpty ? '$origin/' : videoUrl(videoId),
  };

  /// The player endpoint URL with [apiKey].
  static Uri playerUrl(String apiKey) =>
      Uri.parse('$origin/youtubei/v1/player').replace(queryParameters: {'key': apiKey});

  /// The ANDROID player body of [videoId] (anonymous requests get an HLS
  /// manifest; the web client needs browser proofs).
  static Map<String, Object?> playerBody(String videoId) => {
    'videoId': videoId,
    'contentCheckOk': true,
    'racyCheckOk': true,
    'context': {
      'client': {
        'clientName': 'ANDROID',
        'clientVersion': '21.08.266',
        'platform': 'DESKTOP',
        'clientScreen': 'EMBED',
        'clientFormFactor': 'UNKNOWN_FORM_FACTOR',
        'browserName': 'Chrome',
      },
      'user': {'lockedSafetyMode': false},
      'request': {'useSsl': true},
    },
  };

  /// Maps 3.x's status rules: 200 with a body is the answer; 400 and an
  /// empty body are API changes, 401/403 risk control, 404 not-found, 429
  /// rate limit.
  static void checkStatus(int status, String body, String what) {
    switch (status) {
      case 200:
        if (body.isEmpty) {
          throw SiteApiChangedError('youtube $what: empty body');
        }
        return;
      case 400:
        throw SiteApiChangedError('youtube $what: HTTP 400');
      case 401 || 403:
        throw SiteRiskControlError('youtube $what: HTTP $status');
      case 404:
        throw SiteNotFoundError('youtube $what: HTTP 404');
      case 429:
        throw SiteRateLimitedError('youtube $what: HTTP 429');
    }
    throw SiteApiChangedError('youtube $what: HTTP $status');
  }

  /// The player answer → the room. The state follows the playability
  /// code: live by `isLive`/`isLiveNow` with `LIVE_STREAM_OFFLINE`
  /// excluded, restricted non-live content as banned, an empty code as
  /// unknown, everything else offline. The HLS manifest rides in `data`.
  static LiveRoom video(String body, {required String videoId, int status = 200}) {
    checkStatus(status, body, 'player');
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('youtube player: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('youtube player: body is not an object');
    }
    final details = _map(decoded['videoDetails']);
    final playability = _map(decoded['playabilityStatus']);
    final code = (playability['status']?.toString() ?? '').toUpperCase();
    final reason = playability['reason']?.toString() ?? '';
    final actual = normalizeVideoId(details['videoId']?.toString() ?? '');
    if (actual == null) {
      final detail = 'player: no video for $videoId ($code $reason)'.trim();
      throw switch (code) {
        'ERROR' => SiteNotFoundError('youtube $detail'),
        'LOGIN_REQUIRED' || 'AGE_CHECK_REQUIRED' || 'CONTENT_CHECK_REQUIRED' => SiteNeedsLoginError('youtube $detail'),
        'UNPLAYABLE' => SiteNotFoundError('youtube $detail'),
        _ => SiteApiChangedError('youtube $detail'),
      };
    }
    if (actual != videoId) {
      throw SiteApiChangedError('youtube player: asked $videoId, answered $actual');
    }
    final micro = _map(_map(decoded['microformat'])['playerMicroformatRenderer']);
    final broadcast = _map(micro['liveBroadcastDetails']);
    final live = (details['isLive'] == true || broadcast['isLiveNow'] == true) && code != 'LIVE_STREAM_OFFLINE';
    final lowerReason = reason.toLowerCase();
    final private = details['isPrivate'] == true;
    final restricted =
        private ||
        const {'LOGIN_REQUIRED', 'AGE_CHECK_REQUIRED', 'CONTENT_CHECK_REQUIRED'}.contains(code) ||
        lowerReason.contains('sign in') ||
        lowerReason.contains('private');
    final start = micro['startTimestamp']?.toString() ?? broadcast['startTimestamp']?.toString();
    final streaming = _map(decoded['streamingData']);
    final hls = streaming['hlsManifestUrl']?.toString() ?? '';
    return LiveRoom(
      platform: SiteIds.youtube,
      roomId: videoId,
      title: details['title']?.toString() ?? '',
      nick: details['author']?.toString() ?? '',
      status: live
          ? LiveStatus.live
          : restricted
          ? LiveStatus.banned
          : code.isEmpty
          ? LiveStatus.unknown
          : LiveStatus.offline,
      restriction: live || restricted ? (restricted ? LiveRestriction.loginRequired : null) : null,
      startedAt: live && start != null ? DateTime.tryParse(start) : null,
      data: live && hls.startsWith('http') ? hls : null,
    );
  }

  /// The play lines of a live room's HLS manifest URL.
  static List<LivePlayLine> playLines(Object? data, String videoId) {
    if (data is! String || !data.startsWith('http')) {
      return const [];
    }
    return [
      LivePlayLine(url: data, headers: mediaHeaders(videoId), format: StreamFormat.hls, codec: 'avc', lineId: 'auto'),
    ];
  }

  static Map<String, Object?> _map(Object? value) => value is Map<String, Object?> ? value : const <String, Object?>{};
}
