import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the FC2 Live member API.
abstract final class Fc2LiveParser {
  /// Web origin.
  static const String origin = 'https://live.fc2.com';

  /// The member API endpoint.
  static const String memberPath = '/api/memberApi.php';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'accept': 'application/json, text/javascript, */*; q=0.01',
    'accept-language': 'ja,en-US;q=0.9,en;q=0.8',
    'origin': origin,
    'referer': '$origin/',
    'x-requested-with': 'XMLHttpRequest',
    'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
  };

  /// Media headers of the channel page.
  static Map<String, String> mediaHeaders(String channelId) => {
    'user-agent': headers['user-agent']!,
    'referer': '$origin/$channelId/',
  };

  /// The channel id of the input: a channel number or a channel link.
  static String? channelId(String raw) {
    final input = raw.trim();
    if (RegExp(r'^\d{1,12}$').hasMatch(input)) {
      return input;
    }
    final uri = Uri.tryParse(input);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host != 'live.fc2.com') {
      return null;
    }
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    for (final segment in segments.reversed) {
      if (RegExp(r'^\d{1,12}$').hasMatch(segment)) {
        return segment;
      }
    }
    return null;
  }

  /// `memberApi` → the room. `status` 1 with data means the channel exists;
  /// `is_publish` 1 means on air.
  static LiveRoom room(String body, {required String channelId, int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('fc2live memberApi: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('fc2live memberApi: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('fc2live memberApi: body is not an object');
    }
    if ((decoded['status'] as num?)?.toInt() != 1) {
      throw SiteNotFoundError('fc2live memberApi: no channel $channelId');
    }
    final data = decoded['data'];
    final channel = data is Map<String, Object?> ? data['channel_data'] : null;
    if (channel is! Map<String, Object?>) {
      throw const SiteApiChangedError('fc2live memberApi: no channel_data');
    }
    final id = channel['channelid']?.toString() ?? '';
    if (id != channelId) {
      throw SiteApiChangedError('fc2live memberApi: answered $id for $channelId');
    }
    final rawProfile = data is Map<String, Object?> ? data['profile_data'] : null;
    final profile = rawProfile is Map<String, Object?> ? rawProfile : const <String, Object?>{};
    final published = (channel['is_publish'] as num?)?.toInt() == 1;
    final emailOnly = (channel['is_limited'] as num?)?.toInt() == 1;
    final loginOnly = (channel['login_only'] as num?)?.toInt() == 1;
    final name = (profile['name'] ?? channel['tname'])?.toString() ?? '';
    final startSeconds = (channel['start'] as num?)?.toInt();
    return LiveRoom(
      platform: SiteIds.fc2Live,
      roomId: channelId,
      title: channel['title']?.toString() ?? name,
      nick: name,
      avatar: _image(profile['icon'] ?? profile['image']),
      cover: _image(channel['image']),
      watching: (channel['count'] as num?)?.toInt(),
      status: published ? LiveStatus.live : LiveStatus.offline,
      restriction: published && emailOnly
          ? LiveRestriction.needsLogin
          : published && loginOnly
          ? LiveRestriction.needsLogin
          : null,
      startedAt: published && startSeconds != null && startSeconds > 0
          ? DateTime.fromMillisecondsSinceEpoch(startSeconds * 1000, isUtc: true)
          : null,
    );
  }

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
