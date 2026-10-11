import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the Weibo live APIs.
abstract final class WeiboParser {
  /// Web origin.
  static const String origin = 'https://weibo.com';

  /// The per-broadcast detail endpoint.
  static const String detailPath = '/l/!/2/wblive/room/show_pc_live.json';

  /// The detail URL of [liveId].
  static Uri detailUrl(String liveId) => Uri.parse('$origin$detailPath?live_id=${Uri.encodeQueryComponent(liveId)}');

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': 'https://weibo.com/',
  };

  /// Media headers of [liveId].
  static Map<String, String> mediaHeaders(String liveId) => {
    'user-agent': headers['user-agent']!,
    'referer': '$origin/l/wblive/p/show/$liveId',
  };

  /// Validates the envelope (`code` 100000) and returns `data`; a missing
  /// payload is "not found".
  static Map<String, Object?> data(String body, {int status = 200, String what = 'response'}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('weibo $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('weibo $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('weibo $what: body is not an object');
    }
    final code = decoded['code']?.toString();
    if (code != null && code != '100000') {
      throw SiteApiChangedError('weibo $what: code $code ${decoded['msg'] ?? ''}'.trim());
    }
    final data = decoded['data'];
    if (data is! Map<String, Object?>) {
      throw SiteNotFoundError('weibo $what: no payload');
    }
    return data;
  }

  /// `show_pc_live` → the room of one broadcast. Status 1 is live, 3
  /// replay, 2 ended; `play_switch` 0 means playing is disabled and a
  /// non-zero `watch_limit` means a restricted broadcast.
  static LiveRoom room(String body, {required String liveId, int status = 200}) {
    final item = data(body, status: status, what: 'show_pc_live');
    final id = item['liveId']?.toString() ?? '';
    if (id != liveId) {
      throw SiteApiChangedError('weibo show_pc_live: asked $liveId, got $id');
    }
    final user = item['user'];
    final userMap = user is Map<String, Object?> ? user : const <String, Object?>{};
    final state = (item['status'] as num?)?.toInt();
    final enabled = (item['play_switch'] as num?)?.toInt() != 0;
    final limit = (item['watch_limit'] as num?)?.toInt() ?? 0;
    final public = enabled && limit == 0;
    final live = state == 1;
    final replay = state == 3;
    final startMs = (item['startTime'] as num?)?.toInt();
    return LiveRoom(
      platform: SiteIds.weibo,
      roomId: liveId,
      title: item['title']?.toString() ?? '',
      nick: (userMap['screenName'] ?? userMap['screen_name'])?.toString() ?? '',
      avatar: _image(userMap['avatar'] ?? userMap['profileImageUrl']),
      cover: _image(item['cover']),
      status: live
          ? LiveStatus.live
          : replay
          ? LiveStatus.replay
          : state == 2
          ? LiveStatus.offline
          : LiveStatus.unknown,
      startedAt: live && startMs != null && startMs >= 1000000000000 && startMs < 10000000000000
          ? DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true)
          : null,
      data: live && public
          ? {'flv': item['live_origin_flv_url']?.toString() ?? '', 'hls': item['live_origin_hls_url']?.toString() ?? ''}
          : replay && public
          ? {'replay': item['replay_origin_url']?.toString() ?? ''}
          : null,
    );
  }

  /// The play lines of a room whose data carries the media URLs.
  static List<LivePlayLine> playLines(Object? data, String liveId) {
    if (data is! Map<String, Object?>) {
      return const [];
    }
    final lines = <LivePlayLine>[];
    final seen = <String>{};
    for (final (key, format) in const [
      ('flv', StreamFormat.flv),
      ('hls', StreamFormat.hls),
      ('replay', StreamFormat.flv),
    ]) {
      final url = data[key]?.toString() ?? '';
      if (url.startsWith('http') && seen.add(url)) {
        lines.add(
          LivePlayLine(
            url: url,
            headers: mediaHeaders(liveId),
            format: url.contains('.m3u8') ? StreamFormat.hls : format,
            lineId: key,
          ),
        );
      }
    }
    return lines;
  }

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
