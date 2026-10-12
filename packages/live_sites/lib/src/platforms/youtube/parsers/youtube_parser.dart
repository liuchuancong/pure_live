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
      restriction: live || restricted ? (restricted ? LiveRestriction.needsLogin : null) : null,
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

  // Chat (the WEB InnerTube client) -------------------------------------------

  /// The web client's InnerTube context of the live chat's `next`,
  /// `get_live_chat` and `updated_metadata`.
  static const Map<String, Object?> webContext = {
    'client': {'clientName': 'WEB', 'clientVersion': '2.20260925.01.00', 'hl': 'en', 'gl': 'US'},
  };

  /// The web client's desktop UA (Chrome 140).
  static const String webUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// The web client's InnerTube endpoint [endpoint], without a key (the WEB
  /// client needs none; only the ANDROID player does).
  static Uri apiUrl(String endpoint) => Uri.parse('$origin/youtubei/v1/$endpoint?prettyPrint=false');

  /// Headers of the web client's InnerTube calls (the JSON content type comes
  /// with the request): English, the `SOCS=CAI` consent cookie and the site.
  static Map<String, String> get apiHeaders => {
    'user-agent': webUserAgent,
    'accept': 'application/json',
    'accept-language': 'en-US,en;q=0.9',
    'cookie': 'SOCS=CAI',
    'origin': origin,
    'referer': '$origin/',
  };

  /// The watch page's `next` body for [videoId].
  static Map<String, Object?> nextBody(String videoId) => {'context': webContext, 'videoId': videoId};

  /// The chat's `get_live_chat` body for [continuation].
  static Map<String, Object?> chatBody(String continuation) => {'context': webContext, 'continuation': continuation};

  // Directory and search (the WEB InnerTube client) --------------------------

  /// The InnerTube search filter "Live".
  static const String liveFilter = 'EgJAAQ%3D%3D';

  /// The channel browse id of the site's "Live" tab (the recommendations).
  static const String liveDestination = 'UC4R8DWoMoI7CAwX8_LjQHig';

  /// The `browse` body of the live destination.
  static Map<String, Object?> browseBody() => {'context': webContext, 'browseId': liveDestination};

  /// The `search` body of [query] filtered to live broadcasts.
  static Map<String, Object?> searchBody(String query) => {'context': webContext, 'query': query, 'params': liveFilter};

  static const int _walkBudget = 250000;

  /// The live rooms of a `browse` ([search] false) or `search` answer: the
  /// live `videoRenderer` rows (ended and upcoming rows are left out), each
  /// keyed by its video id (this adapter opens rooms by video id), a video
  /// once. A failed status or a non-JSON body is an API change.
  ///
  /// Archived from the reference, whose rooms are keyed by the owner's channel
  /// id; here they are keyed by the broadcast's video id so `getRoomDetail`
  /// (the ANDROID player) opens them. Deep continuation paging is not done: the
  /// first answer's rooms are returned whole, `hasMore` false.
  static LivePage<LiveRoom> listing(String body, {required bool search, int status = 200}) {
    final what = search ? 'search' : 'browse';
    checkStatus(status, body, what);
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('youtube not a JSON object');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('youtube not a JSON object');
    }
    final rooms = <LiveRoom>[];
    final seen = <String>{};
    for (final item in _findAll(decoded, 'videoRenderer')) {
      final renderer = _object(item);
      if (!_rowLive(renderer)) {
        continue;
      }
      final room = _liveCard(renderer);
      if (room != null && seen.add(room.roomId)) {
        rooms.add(room);
      }
    }
    return LivePage(items: rooms);
  }

  static LiveRoom? _liveCard(Map<String, Object?> renderer) {
    final videoId = normalizeVideoId(renderer['videoId']?.toString() ?? '');
    if (videoId == null) {
      return null;
    }
    final owner = renderer['ownerText'] ?? renderer['longBylineText'] ?? renderer['shortBylineText'];
    final title = _text(renderer['title']);
    final nick = _text(owner);
    if (title.isEmpty || nick.isEmpty) {
      return null;
    }
    final avatar = _object(_object(renderer['channelThumbnailSupportedRenderers'])['channelThumbnailWithLinkRenderer']);
    final viewers = _watching(renderer['viewCountText']);
    final badges = renderer['badges'];
    final members =
        badges is List &&
        badges.any(
          (badge) => _object(_object(badge)['metadataBadgeRenderer'])['style'] == 'BADGE_STYLE_TYPE_MEMBERS_ONLY',
        );
    final cover = _thumbnail(renderer['thumbnail']);
    return LiveRoom(
      platform: SiteIds.youtube,
      roomId: videoId,
      title: title,
      nick: nick,
      avatar: _nullIfEmpty(_thumbnail(avatar['thumbnail'], avatar: true)),
      cover: _nullIfEmpty(cover),
      status: LiveStatus.live,
      restriction: members ? LiveRestriction.subscribersOnly : null,
      watching: viewers,
      onlineViewers: viewers,
      httpHeaders: mediaHeaders(videoId),
    );
  }

  static bool _rowLive(Map<String, Object?> renderer) {
    if (renderer.containsKey('upcomingEventData')) {
      return false;
    }
    final badges = renderer['badges'];
    if (badges is List) {
      for (final badge in badges) {
        if (_object(_object(badge)['metadataBadgeRenderer'])['style'] == 'BADGE_STYLE_TYPE_LIVE_NOW') {
          return true;
        }
      }
    }
    final overlays = renderer['thumbnailOverlays'];
    if (overlays is List) {
      for (final overlay in overlays) {
        if (_object(_object(overlay)['thumbnailOverlayTimeStatusRenderer'])['style'] == 'LIVE') {
          return true;
        }
      }
    }
    return _watching(renderer['viewCountText']) != null;
  }

  static final RegExp _watchingCount = RegExp(r'^(\d[\d,.]*)\s*watching', caseSensitive: false);

  static int? _watching(Object? value) {
    final match = _watchingCount.firstMatch(_text(value));
    final digits = match?.group(1)?.replaceAll(RegExp(r'\D'), '');
    return digits == null || digits.isEmpty ? null : int.tryParse(digits);
  }

  static List<Object?> _findAll(Object? root, String key) {
    final found = <Object?>[];
    var visited = 0;
    void walk(Object? value) {
      if (++visited > _walkBudget) {
        throw SiteApiChangedError('youtube answer too large looking for $key');
      }
      if (value is List) {
        value.forEach(walk);
      } else if (value is Map) {
        for (final entry in value.entries) {
          if (entry.key == key) found.add(entry.value);
          walk(entry.value);
        }
      }
    }

    walk(root);
    return found;
  }

  /// The last (largest) https picture of a `thumbnails` list on a YouTube or
  /// Google image host (a `googleusercontent` one only for [avatar]), else empty.
  static String _thumbnail(Object? value, {bool avatar = false}) {
    final items = _object(value)['thumbnails'];
    if (items is! List || items.length > 64) {
      return '';
    }
    for (final item in items.reversed) {
      final raw = _object(item)['url'];
      final uri = raw is String ? Uri.tryParse(raw) : null;
      final host = uri?.host.toLowerCase() ?? '';
      if (uri != null &&
          uri.scheme == 'https' &&
          uri.userInfo.isEmpty &&
          !uri.hasFragment &&
          (_imageHost(host) ||
              (avatar && (host == 'googleusercontent.com' || host.endsWith('.googleusercontent.com'))))) {
        return uri.toString();
      }
    }
    return '';
  }

  static bool _imageHost(String host) =>
      host == 'ytimg.com' || host.endsWith('.ytimg.com') || host == 'ggpht.com' || host.endsWith('.ggpht.com');

  /// The text of a `{simpleText}` or `{runs: [...]}` object, joined and trimmed.
  static String _text(Object? value) {
    final map = _object(value);
    final simple = map['simpleText'];
    if (simple is String) {
      return simple.trim();
    }
    final runs = map['runs'];
    if (runs is! List) {
      return '';
    }
    return [
      for (final run in runs)
        if (_object(run)['text'] case final String text) text,
    ].join().trim();
  }

  static Map<String, Object?> _object(Object? value) =>
      value is Map<String, Object?> ? value : (value is Map ? value.cast<String, Object?>() : const {});

  static String? _nullIfEmpty(String value) => value.isEmpty ? null : value;

  static Map<String, Object?> _map(Object? value) => value is Map<String, Object?> ? value : const <String, Object?>{};
}
