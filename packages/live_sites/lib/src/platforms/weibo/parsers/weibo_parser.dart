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
    final state = SiteCounts.integer(item['status']);
    final enabled = SiteCounts.integer(item['play_switch']) != 0;
    final limit = SiteCounts.integer(item['watch_limit']) ?? 0;
    final public = enabled && limit == 0;
    final live = state == 1;
    final replay = state == 3;
    final startMs = SiteCounts.integer(item['startTime']);
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

  /// A broadcast id: 3–8 digits, a colon and 16–48 letters or digits.
  static final RegExp liveIdPattern = RegExp(r'^[0-9]{3,8}:[0-9A-Za-z]{16,48}$');

  /// Whether [value] is a broadcast id.
  static bool isLiveId(String value) => liveIdPattern.hasMatch(value);

  /// The `id` of the one area, the recommendation snapshot.
  static const String areaId = 'live';

  /// The name of the one area.
  static const String areaName = '公开推荐';

  /// The snapshot request path.
  static const String recommendPath = '/l/!/2/wblive/pc_recommend/list.json';

  /// The count 3.x asked the snapshot for.
  static const int recommendCount = 100;

  /// The recommendation-snapshot URL (`?count=100&uid=`, 3.x's spelling).
  static Uri recommendUrl() => Uri.parse('$origin$recommendPath?count=$recommendCount&uid=');

  /// The room [input] names exactly: a broadcast id, or a room link; null for
  /// anything with a backslash or whitespace, and for a non-broadcast link.
  static String? exactRoom(String input) {
    final value = input.trim();
    if (RegExp(r'[\\\s]').hasMatch(value)) {
      return null;
    }
    return isLiveId(value) ? value : liveIdFromUrl(value);
  }

  /// The broadcast id of a `weibo.com/l/wblive/[pm]/show/<id>` room link, the
  /// `%3a` in its id decoded back to a colon; null for anything else.
  static String? liveIdFromUrl(String raw) {
    final value = raw.trim();
    if (RegExp(r'[\\\s]').hasMatch(value)) {
      return null;
    }
    final schemeIndex = value.indexOf('://');
    if (schemeIndex < 0) {
      return null;
    }
    final authorityAndPath = value.substring(schemeIndex + 3).split(RegExp('[?#]')).first;
    final slash = authorityAndPath.indexOf('/');
    if (slash < 0) {
      return null;
    }
    final match = RegExp(r'^/l/wblive/[pm]/show/([^/]+)/?$').firstMatch(authorityAndPath.substring(slash));
    if (match == null) {
      return null;
    }
    return match[1]!.replaceAll(RegExp('%3a', caseSensitive: false), ':');
  }

  /// The recommendation snapshot: each broadcast on air, one page, `hasMore`
  /// false. A bad row (not an object, no valid broadcast id, or listed before)
  /// is skipped; a `data.data` that is no list, over 500, or whose rows are
  /// none usable is a changed endpoint rather than an empty directory. The
  /// snapshot lists live broadcasts only and says nothing of restrictions.
  static LivePage<LiveRoom> recommendations(String body, {int status = 200}) {
    final rows = data(body, status: status, what: 'pc_recommend')['data'];
    if (rows is! List || rows.length > 500) {
      throw const SiteApiChangedError('weibo pc_recommend: data.data is not a list');
    }
    final seen = <String>{};
    final rooms = <LiveRoom>[];
    for (final row in SiteJson.objects(rows)) {
      final id = row['liveid']?.toString() ?? '';
      if (!isLiveId(id) || !seen.add(id)) {
        continue;
      }
      final nick = SiteText.title(SiteText.text(row['nickname']));
      rooms.add(
        LiveRoom(
          platform: SiteIds.weibo,
          roomId: id,
          nick: nick,
          title: nick,
          cover: _image(row['cover']),
          status: LiveStatus.live,
        ),
      );
    }
    if (rooms.isEmpty && rows.isNotEmpty) {
      throw const SiteApiChangedError('weibo pc_recommend: no usable row');
    }
    return LivePage<LiveRoom>(items: rooms);
  }

  /// 3.x's nickname search: the snapshot [rooms] whose nickname contains
  /// [keyword] (trimmed, case ignored), the first [pageSize]. There is no
  /// server search and no second page.
  static List<LiveRoom> searchSnapshot(String keyword, Iterable<LiveRoom> rooms, {int pageSize = 30}) {
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) {
      return const [];
    }
    return List.unmodifiable(rooms.where((room) => room.nick.toLowerCase().contains(query)).take(pageSize));
  }

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
