import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the Xiaohongshu live share page.
abstract final class XiaohongshuParser {
  /// Web origin.
  static const String origin = 'https://www.xiaohongshu.com';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': 'https://www.xiaohongshu.com/',
  };

  /// Media headers of [roomId].
  static Map<String, String> mediaHeaders(String roomId) => {
    'user-agent': headers['user-agent']!,
    'referer': '$origin/livestream/$roomId',
  };

  /// Whether [value] is a Xiaohongshu room id.
  static bool isRoomId(String value) => RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(value);

  /// The share page URL of [roomId].
  static Uri roomUrl(String roomId) => Uri.parse('$origin/livestream/$roomId');

  static final RegExp _controls = RegExp(r'[\x00-\x20\x7f]');
  static final RegExp _canonicalPath = RegExp(r'^/livestream/([1-9][0-9]{0,19})/?$');
  static final RegExp _dynamicPath = RegExp(r'^/livestream/dynpath[A-Za-z0-9]{8}/([1-9][0-9]{0,19})/?$');
  static final RegExp _hinaPath = RegExp(r'^/hina/livestream/([1-9][0-9]{0,19})(?:/[A-Za-z0-9_-]{1,64})?/?$');

  /// The room [raw] names exactly: a bare id, an app deep link, or a share
  /// page; null for anything else (a short link's hops are not resolved).
  static String? roomIdFrom(String raw) {
    final value = raw.trim();
    if (isRoomId(value)) {
      return value;
    }
    return deepLinkRoomId(value) ?? webRoomId(value);
  }

  /// The room of an app deep link `xhsdiscover://live_audience?room_id=…`:
  /// exactly one `room_id`, no path, user, port or fragment.
  static String? deepLinkRoomId(String raw) {
    final value = raw.trim();
    if (value.length > 8192 || value.contains(_controls)) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'xhsdiscover' ||
        uri.host.toLowerCase() != 'live_audience' ||
        uri.path.isNotEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment) {
      return null;
    }
    try {
      final room = uri.queryParametersAll['room_id'];
      if (room == null || room.length != 1) {
        return null;
      }
      return isRoomId(room.single) ? room.single : null;
    } on FormatException {
      return null;
    }
  }

  /// The room of a `www.xiaohongshu.com`/`xiaohongshu.com` share page:
  /// `/livestream/<room>`, the `/livestream/dynpath<8>/<room>` share redirect,
  /// or `/hina/livestream/<room>[/<alias>]`, http(s) on the default port and
  /// a plain path.
  static String? webRoomId(String raw) {
    final uri = _webUri(raw);
    if (uri == null || !(uri.host == 'www.xiaohongshu.com' || uri.host == 'xiaohongshu.com')) {
      return null;
    }
    return (_canonicalPath.firstMatch(uri.path) ?? _dynamicPath.firstMatch(uri.path) ?? _hinaPath.firstMatch(uri.path))
        ?.group(1);
  }

  /// Whether a written value has no control characters, escapes, backslashes
  /// or dot segments in its path, and is short enough to parse.
  static bool _plainPath(String value) {
    if (value.length > 8192 || value.contains(_controls)) {
      return false;
    }
    final path = value.split(RegExp('[?#]')).first;
    return !path.contains('%') && !path.contains(r'\') && !RegExp(r'(^|/)\.\.?(/|$)').hasMatch(path);
  }

  /// A written http(s) link on the default port with no user info, or null.
  static Uri? _webUri(String raw) {
    final value = raw.trim();
    if (!_plainPath(value)) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
      return null;
    }
    return uri;
  }

  static const String _marker = 'window.__INITIAL_STATE__=';

  /// Extracts the `liveStream` object of the share page.
  static Map<String, Object?> liveStream(String page, {int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('xiaohongshu share page: HTTP $status');
    }
    final marker = page.indexOf(_marker);
    if (marker < 0) {
      throw const SiteApiChangedError('xiaohongshu share page: no hydration state');
    }
    var source = page.substring(marker + _marker.length).trimLeft();
    // The script ends at the literal's closing brace followed by `;` and
    // the next tag; take up to the last `};` — the state object has no
    // nested `};` outside strings in practice, and jsonDecode rejects
    // anything wrong anyway.
    final end = source.indexOf('</script>');
    if (end >= 0) {
      source = source.substring(0, end);
    }
    source = source.trimRight();
    if (source.endsWith(';')) {
      source = source.substring(0, source.length - 1).trimRight();
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(_hydrationJson(source));
    } on FormatException {
      throw const SiteApiChangedError('xiaohongshu share page: hydration state is not JSON');
    }
    final state = decoded is Map<String, Object?> ? decoded['liveStream'] : null;
    if (state is! Map<String, Object?>) {
      throw const SiteApiChangedError('xiaohongshu share page: no liveStream state');
    }
    return state;
  }

  /// [source] with every bare `undefined` token outside strings written
  /// as `null`.
  static String _hydrationJson(String source) {
    final result = StringBuffer();
    var quoted = false;
    var escaped = false;
    var index = 0;
    while (index < source.length) {
      final char = source[index];
      if (quoted) {
        result.write(char);
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          quoted = false;
        }
        index++;
        continue;
      }
      if (char == '"') {
        quoted = true;
        result.write(char);
        index++;
        continue;
      }
      if (source.startsWith('undefined', index)) {
        result.write('null');
        index += 'undefined'.length;
        continue;
      }
      result.write(char);
      index++;
    }
    return result.toString();
  }

  /// The share page state → the room. `pageStatus` "error" is
  /// "not found"; status 2 is live, 3 ended.
  static LiveRoom room(String page, {required String roomId, int status = 200}) {
    if (!isRoomId(roomId)) {
      throw SiteNotFoundError('xiaohongshu: "$roomId" is not a room id');
    }
    final state = liveStream(page, status: status);
    final pageStatus = state['pageStatus'];
    if (pageStatus == 'error') {
      throw SiteNotFoundError('xiaohongshu share page $roomId: ${state['errorMessage'] ?? 'error'}');
    }
    if (pageStatus != 'success') {
      throw const SiteApiChangedError('xiaohongshu share page: pageStatus is not success');
    }
    final data = state['roomData'];
    final info = data is Map<String, Object?> ? data['roomInfo'] : null;
    final host = data is Map<String, Object?> ? data['hostInfo'] : null;
    if (info is! Map<String, Object?>) {
      throw const SiteApiChangedError('xiaohongshu share page: no roomInfo');
    }
    final hostMap = host is Map<String, Object?> ? host : const <String, Object?>{};
    final echoed = info['roomId'];
    if (echoed != null && echoed != roomId) {
      throw SiteApiChangedError('xiaohongshu share page: asked $roomId, got $echoed');
    }
    final code = SiteCounts.integer(info['status']);
    final liveStatus = state['liveStatus'];
    final live = code == 2;
    if (live && liveStatus != 'success') {
      throw const SiteApiChangedError('xiaohongshu share page: live without a success state');
    }
    return LiveRoom(
      platform: SiteIds.xiaohongshu,
      roomId: roomId,
      title: info['roomTitle']?.toString() ?? '',
      nick: hostMap['nickName']?.toString() ?? '',
      avatar: _image(hostMap['avatar']),
      cover: _image(info['roomCover']),
      status: live
          ? LiveStatus.live
          : code == 3
          ? LiveStatus.offline
          : LiveStatus.unknown,
      data: live ? info['pullConfig'] : null,
    );
  }

  /// The play lines of a live room's `pullConfig`: the h264 and h265 rows
  /// with their quality labels, each URL once.
  static List<LivePlayLine> playLines(Object? pullConfig, String roomId) {
    var value = pullConfig;
    if (value is String) {
      if (value.isEmpty) {
        return const [];
      }
      try {
        value = jsonDecode(value);
      } on FormatException {
        return const [];
      }
    }
    if (value is! Map<String, Object?>) {
      return const [];
    }
    final lines = <LivePlayLine>[];
    final seen = <String>{};
    for (final codec in const ['h264', 'h265']) {
      final rows = value[codec];
      if (rows is! List) {
        continue;
      }
      for (final row in rows) {
        if (row is! Map<String, Object?>) {
          continue;
        }
        final url = row['master_url']?.toString() ?? '';
        final label = row['quality_type_name']?.toString() ?? row['quality_type']?.toString() ?? '';
        if (!url.startsWith('http') || !seen.add(url)) {
          continue;
        }
        lines.add(
          LivePlayLine(
            url: url,
            headers: mediaHeaders(roomId),
            format: url.contains('.m3u8') ? StreamFormat.hls : StreamFormat.flv,
            codec: codec,
            lineId: label.isEmpty ? codec : label,
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
