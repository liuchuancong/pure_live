import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the TikTok live web APIs.
abstract final class TikTokParser {
  /// Web origin.
  static const String origin = 'https://www.tiktok.com';

  /// Webcast origin (the room-info endpoint).
  static const String webcastOrigin = 'https://webcast.tiktok.com';

  /// Request headers, with the room as referer when [username] is known.
  static Map<String, String> headers({String? username}) => {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'en-US,en;q=0.9',
    'origin': origin,
    'referer': username == null ? '$origin/live' : roomUrl(username),
  };

  /// Media headers of [username]'s stream.
  static Map<String, String> mediaHeaders(String username) => {
    'user-agent': headers().values.first,
    'origin': origin,
    'referer': roomUrl(username),
  };

  /// A username: letters, digits, dots and underscores.
  static String? normalizeUsername(String value) {
    final username = value.trim().replaceFirst(RegExp('^@'), '');
    return RegExp(r'^[A-Za-z0-9._]{1,24}$').hasMatch(username) ? username : null;
  }

  /// The username a [raw] keyword names: a bare name, an `@name`, or a
  /// `tiktok.com/@name` link; null otherwise (a `share/live` room or a short
  /// link is resolved through the owner/redirect path, not here).
  static String? usernameFrom(String raw) {
    final value = raw.trim();
    final direct = normalizeUsername(value);
    if (direct != null && !value.contains('/')) {
      return direct;
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !(uri.host == 'tiktok.com' || uri.host.endsWith('.tiktok.com'))) {
      return null;
    }
    for (final segment in uri.pathSegments) {
      if (segment.startsWith('@')) {
        final name = normalizeUsername(segment.substring(1));
        if (name != null) {
          return name;
        }
      }
    }
    return null;
  }

  /// The room page URL.
  static String roomUrl(String username) => '$origin/@$username/live';

  /// The `user/room` URL of [username].
  static Uri userRoomUrl(String username) =>
      Uri.parse('$origin/api-live/user/room/')
          .replace(queryParameters: {'aid': '1988', 'sourceType': '54', 'staleTime': '600000', 'uniqueId': username});

  /// Validates the status envelope and returns `data`.
  static Map<String, Object?> data(String body, {int status = 200, String what = 'user/room'}) {
    switch (status) {
      case 200:
        break;
      case 400:
        throw SiteApiChangedError('tiktok $what: HTTP 400');
      case 401 || 403:
        throw SiteRiskControlError('tiktok $what: HTTP $status');
      case 404:
        throw SiteNotFoundError('tiktok $what: HTTP 404');
      case 420 || 429:
        throw SiteRateLimitedError('tiktok $what: HTTP $status');
      default:
        throw SiteApiChangedError('tiktok $what: HTTP $status');
    }
    if (body.isEmpty) {
      throw SiteRiskControlError('tiktok $what: empty answer');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('tiktok $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('tiktok $what: body is not an object');
    }
    final code = SiteCounts.integer(decoded['statusCode']) ?? 0;
    if (code != 0) {
      final message = decoded['message']?.toString() ?? '';
      final lower = message.toLowerCase();
      if (lower.contains('not exist') || lower.contains('not_found')) {
        throw SiteNotFoundError('tiktok $what: $message');
      }
      throw SiteApiChangedError('tiktok $what: statusCode $code $message'.trim());
    }
    final data = decoded['data'];
    if (data is! Map<String, Object?>) {
      throw SiteApiChangedError('tiktok $what: no data object');
    }
    return data;
  }

  /// `user/room` → the room with its play lines in `data`.
  static LiveRoom room(String body, {required String username, int status = 200}) {
    final data = TikTokParser.data(body, status: status);
    final user = data['user'];
    final live = data['liveRoom'];
    if (user is! Map<String, Object?> || live is! Map<String, Object?>) {
      throw const SiteApiChangedError('tiktok user/room: no user or liveRoom');
    }
    final actual = user['uniqueId']?.toString() ?? '';
    if (actual != username) {
      throw SiteApiChangedError('tiktok user/room: asked $username, got $actual');
    }
    final state = SiteCounts.integer(live['status'] ?? user['status']);
    final liveState = state == 2;
    final roomStats = live['liveRoomStats'];
    final roomStatsMap = roomStats is Map<String, Object?> ? roomStats : const <String, Object?>{};
    final nickname = user['nickname']?.toString() ?? '';
    final title = live['title']?.toString() ?? '';
    final startSeconds = SiteCounts.integer(live['startTime']);
    return LiveRoom(
      platform: SiteIds.tiktok,
      roomId: username,
      title: title.isEmpty ? nickname : title,
      nick: nickname,
      avatar: _image(user['avatarLarger'] ?? user['avatarMedium'] ?? user['avatarThumb']),
      cover: _image(live['coverUrl'] ?? live['squareCoverImg']),
      watching: liveState ? SiteCounts.integer(roomStatsMap['userCount']) : null,
      status: liveState
          ? LiveStatus.live
          : state == 4
          ? LiveStatus.offline
          : LiveStatus.unknown,
      startedAt: liveState && startSeconds != null && startSeconds > 0
          ? DateTime.fromMillisecondsSinceEpoch(startSeconds * 1000, isUtc: true)
          : null,
      data: liveState ? live : null,
    );
  }

  /// The play lines of a live room's stream data: the FLV and HLS URLs of
  /// every tier (`streamData` and `hevcStreamData`).
  static List<LivePlayLine> playLines(Object? live, String username) {
    if (live is! Map<String, Object?>) {
      return const [];
    }
    final lines = <LivePlayLine>[];
    final seen = <String>{};
    for (final key in const ['streamData', 'hevcStreamData']) {
      final value = live[key];
      if (value is! Map<String, Object?>) {
        continue;
      }
      final pullData = value['pull_data'];
      final pullMap = pullData is Map<String, Object?> ? pullData : const <String, Object?>{};
      final rawStream = pullMap['stream_data']?.toString() ?? '';
      if (rawStream.isEmpty) {
        continue;
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(rawStream);
      } on FormatException {
        continue;
      }
      final tiers = decoded is Map<String, Object?> ? decoded['data'] : null;
      if (tiers is! Map<String, Object?>) {
        continue;
      }
      for (final entry in tiers.entries) {
        final tier = value[entry.key];
        final main = tier is Map<String, Object?> ? tier['main'] : null;
        if (main is! Map<String, Object?>) {
          continue;
        }
        for (final protocol in const ['flv', 'hls', 'hls_main']) {
          final url = main[protocol]?.toString() ?? '';
          if (url.startsWith('http') && seen.add(url)) {
            lines.add(
              LivePlayLine(
                url: url,
                headers: mediaHeaders(username),
                format: protocol == 'flv' ? StreamFormat.flv : StreamFormat.hls,
                codec: key == 'hevcStreamData' ? 'hevc' : 'avc',
                lineId: entry.key,
              ),
            );
          }
        }
      }
    }
    return lines;
  }

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
