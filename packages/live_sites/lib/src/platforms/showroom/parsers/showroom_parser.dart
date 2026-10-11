import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the SHOWROOM APIs.
abstract final class ShowroomParser {
  /// Web origin.
  static const String origin = 'https://www.showroom-live.com';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': '$origin/',
  };

  /// Media headers of room [roomId].
  static Map<String, String> mediaHeaders(int roomId) => {
    'user-agent': headers['user-agent']!,
    'referer': '$origin/$roomId',
  };

  /// A room number from a reference; null for a url key or anything else.
  static int? roomNumber(String reference) {
    final digits = int.tryParse(reference.trim());
    return digits != null && digits > 0 ? digits : null;
  }

  /// Whether [reference] is a room url key (non-numeric).
  static bool isUrlKey(String reference) {
    final value = reference.trim();
    return int.tryParse(value) == null && RegExp(r'^[A-Za-z0-9_\-]{1,64}$').hasMatch(value);
  }

  /// Decodes an answer and returns it. SHOWROOM puts fields at the top
  /// level of the payload (no envelope); `error` marks refusals.
  static Map<String, Object?> data(String body, {int status = 200, String what = 'response'}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('showroom $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('showroom $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('showroom $what: body is not an object');
    }
    final error = decoded['error'];
    if (error is String || (error is num && error != 0)) {
      throw SiteNotFoundError('showroom $what: $error');
    }
    return decoded;
  }

  /// `room/status` → the numeric room id.
  static int roomIdOfStatus(String body, {int status = 200}) {
    final data = ShowroomParser.data(body, status: status, what: 'room/status');
    final id = (data['room_id'] as num?)?.toInt();
    if (id == null || id <= 0) {
      throw const SiteNotFoundError('showroom room/status: no room id');
    }
    return id;
  }

  /// `room/profile` + `live/live_info` → the room snapshot. `live_status`
  /// 2 is on air.
  static LiveRoom room(Map<String, Object?> profile, Map<String, Object?> info, {required int roomId}) {
    final actual = (profile['room_id'] as num?)?.toInt();
    if (actual != roomId) {
      throw SiteApiChangedError('showroom room/profile: answered $actual for $roomId');
    }
    final state = (info['live_status'] as num?)?.toInt();
    final live = state == 2;
    final startSeconds = (profile['current_live_started_at'] as num?)?.toInt();
    return LiveRoom(
      platform: SiteIds.showroom,
      roomId: '$roomId',
      title: (profile['main_name'] ?? profile['room_name'])?.toString() ?? '',
      nick: (profile['main_name'] ?? profile['room_name'])?.toString() ?? '',
      cover: _image(profile['image_square']),
      areaName: profile['genre_name']?.toString(),
      watching: (profile['follower_num'] as num?)?.toInt(),
      status: live ? LiveStatus.live : LiveStatus.offline,
      startedAt: live && startSeconds != null && startSeconds > 0
          ? DateTime.fromMillisecondsSinceEpoch(startSeconds * 1000, isUtc: true)
          : null,
    );
  }

  /// `streaming_url` rows → the play lines: the `hls` and `hls_all` tiers
  /// with their labels, each URL once.
  static List<LivePlayLine> playLines(String body, {required int roomId, int status = 200}) {
    final data = ShowroomParser.data(body, status: status, what: 'streaming_url');
    final rows = data['streaming_url_list'];
    if (rows is! List) {
      throw const SiteApiChangedError('showroom streaming_url: no streaming_url_list');
    }
    final lines = <LivePlayLine>[];
    final seen = <String>{};
    for (final row in rows) {
      if (row is! Map<String, Object?>) {
        continue;
      }
      final type = row['type']?.toString();
      if (type != 'hls' && type != 'hls_all') {
        continue;
      }
      final url = row['url']?.toString() ?? '';
      if (!url.startsWith('https://') || !seen.add(url)) {
        continue;
      }
      final label = row['label']?.toString() ?? (type == 'hls_all' ? '自动' : '');
      lines.add(
        LivePlayLine(
          url: url,
          headers: mediaHeaders(roomId),
          format: StreamFormat.hls,
          codec: 'avc',
          lineId: label.isEmpty ? type : label,
        ),
      );
    }
    if (lines.isEmpty) {
      throw SiteNotFoundError('showroom streaming_url: no HLS tier for $roomId');
    }
    return lines;
  }

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
