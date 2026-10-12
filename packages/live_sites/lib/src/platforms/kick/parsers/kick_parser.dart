import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the Kick public web API.
abstract final class KickParser {
  /// Desktop Chrome 140, as pure_live_TV sends.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// Web origin.
  static const String origin = 'https://kick.com';

  /// API host (Cloudflare refuses dart:io's TLS handshake only on some
  /// hosts; kick.com answers).
  static const String apiHost = 'kick.com';

  /// Headers of every API request.
  static const Map<String, String> headers = {
    'user-agent': userAgent,
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'en-US,en;q=0.9',
    'origin': origin,
    'referer': '$origin/',
  };

  /// Media headers of channel [slug].
  static Map<String, String> mediaHeaders(String slug) => {
    'user-agent': userAgent,
    'origin': origin,
    'referer': '${roomPageUrl(slug)}/',
  };

  /// A slug: lower-case letters, digits, dashes and underscores.
  static String? normalizeSlug(String value) {
    final slug = value.trim().toLowerCase();
    return RegExp(r'^[a-z0-9_-]{1,64}$').hasMatch(slug) ? slug : null;
  }

  /// The channel page URL.
  static String roomPageUrl(String slug) => '$origin/$slug';

  /// The channel API URL of [slug].
  static Uri channelUrl(String slug) => Uri.https(apiHost, '/api/v2/channels/$slug');

  /// Decodes an answer.
  static Map<String, Object?> decode(String body, {int status = 200, String what = 'channel'}) {
    if (status == 404) {
      throw SiteNotFoundError('kick $what: no channel');
    }
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('kick $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('kick $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('kick $what: body is not an object');
    }
    return decoded;
  }

  /// A channel answer → the room with its signed master in `data`. A
  /// banned channel is banned; `is_live` marks on-air.
  static LiveRoom room(String body, {required String requestedSlug, int status = 200}) {
    final root = KickParser.decode(body, status: status);
    final slug = normalizeSlug(root['slug']?.toString() ?? '');
    final channelId = SiteCounts.integer(root['id']);
    final user = root['user'];
    if (slug == null || channelId == null || channelId <= 0 || user is! Map<String, Object?>) {
      throw const SiteApiChangedError('kick channel: no slug, id or user');
    }
    if (slug != requestedSlug.trim().toLowerCase()) {
      throw SiteApiChangedError('kick channel: asked "$requestedSlug", answered "$slug"');
    }
    final banned = root['is_banned'] == true;
    final stream = root['livestream'];
    final streamMap = stream is Map<String, Object?> ? stream : const <String, Object?>{};
    final live = !banned && stream is Map<String, Object?> && streamMap['is_live'] == true;
    final master = live ? _master(root['playback_url']?.toString()) : null;
    // The chatroom id is not the channel id (`xqcisoffline`: channel 101691,
    // chatroom 101689); the Pusher chat channel is named by the chatroom.
    final chatroomObj = root['chatroom'];
    final rawChatroom = chatroomObj is Map ? chatroomObj['id'] : null;
    final chatroomId = rawChatroom is num ? rawChatroom.toInt() : int.tryParse('$rawChatroom');
    return LiveRoom(
      platform: SiteIds.kick,
      roomId: slug,
      title: live ? streamMap['session_title']?.toString() ?? '' : '',
      nick: user['username']?.toString() ?? '',
      avatar: _image(user['profile_pic'] ?? user['profilePic']),
      cover: live
          ? _image(_nested(streamMap['thumbnail'], 'url') ?? _nested(streamMap['thumbnail'], 'src'))
          : _image(_nested(root['offline_banner_image'], 'src') ?? _nested(root['banner_image'], 'url')),
      areaName: _firstCategoryName(streamMap['categories']),
      watching: live ? SiteCounts.integer(streamMap['viewer_count']) : null,
      status: banned
          ? LiveStatus.banned
          : live
          ? LiveStatus.live
          : LiveStatus.offline,
      startedAt: live ? _time(streamMap['start_time']) : null,
      data: <String, Object?>{
        'channelId': channelId,
        if (chatroomId != null && chatroomId > 0) 'chatroomId': chatroomId,
        'master': ?master,
      },
    );
  }

  /// The play lines of a live room's master playlist.
  static List<LivePlayLine> playLines(Object? data, String slug) {
    final master = data is Map<String, Object?> ? data['master'] : null;
    if (master is! Uri) {
      return const [];
    }
    return [
      LivePlayLine(
        url: data.toString(),
        headers: mediaHeaders(slug),
        format: StreamFormat.hls,
        codec: 'avc',
        lineId: 'master',
      ),
    ];
  }

  /// The master playlist in a `playback_url`: https on IVS
  /// (`*.live-video.net`); an offline channel answers only `?token=…`.
  static Uri? _master(String? raw) {
    final uri = raw == null ? null : Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || !host.endsWith('.live-video.net')) {
      return null;
    }
    return uri;
  }

  /// `2026-09-30 19:24:14` (UTC) or ISO 8601.
  static DateTime? _time(Object? value) {
    final text = value?.toString();
    if (text == null) {
      return null;
    }
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|[+-]00:?00)?$')
        .firstMatch(text);
    if (match == null) {
      return null;
    }
    final parts = [for (var group = 1; group <= 6; group++) int.parse(match.group(group)!)];
    final time = DateTime.utc(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
    return time.year == parts[0] && time.month == parts[1] && time.day == parts[2] && time.year > 2000 ? time : null;
  }

  static String? _firstCategoryName(Object? categories) =>
      categories is List && categories.isNotEmpty ? _nested(categories.first, 'name') : null;

  static String? _nested(Object? value, String key) => value is Map<String, Object?> ? value[key]?.toString() : null;

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
