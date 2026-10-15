import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_endpoints.dart';

/// Pure link reading of Xiaohongshu (3.x's `XiaohongshuLink`): the room a
/// pasted room id, app deep link or share page names, the `xhslink.com`
/// short links, and the deep links of a share text. Nothing here requests.
abstract final class XiaohongshuLink {
  static final RegExp _deepLinks = RegExp(
    r'(?<![A-Za-z0-9:/=?&._-])xhsdiscover://live_audience\?[^\s<>]+',
    caseSensitive: false,
  );
  static final RegExp _chineseProse = RegExp('[，。！？、；：）》」』”’]');
  static final RegExp _trailingPunctuation = RegExp(r'''[,!?;:)\]}"']+$''');
  static final RegExp _controls = RegExp(r'[\x00-\x20\x7f]');
  static final RegExp _canonicalPath = RegExp(r'^/livestream/([1-9][0-9]{0,19})/?$');
  static final RegExp _dynamicPath = RegExp(r'^/livestream/dynpath[A-Za-z0-9]{8}/([1-9][0-9]{0,19})/?$');
  static final RegExp _hinaPath = RegExp(r'^/hina/livestream/([1-9][0-9]{0,19})(?:/[A-Za-z0-9_-]{1,64})?/?$');

  /// `/<code>` or `/<prefix>/<code>` with a prefix of one to four letters:
  /// 3.x knew `/m/`; the app's shares give `/o/` (seen 2026-10-06).
  static final RegExp _shortPath = RegExp(r'^/(?:[A-Za-z]{1,4}/)?[A-Za-z0-9]{1,64}/?$');

  /// The room [raw] names without a request (3.x's `XiaohongshuLink.parse`):
  /// a bare room id, an app deep link ([deepLinkRoomId]) or a share page
  /// ([webRoomId]); null otherwise.
  static String? roomIdFrom(String raw) {
    final value = raw.trim();
    if (XiaohongshuEndpoints.isRoomId(value)) return value;
    return deepLinkRoomId(value) ?? webRoomId(value);
  }

  /// The room of an app deep link `xhsdiscover://live_audience?room_id=…`:
  /// exactly one `room_id`, no path, user, port or fragment (3.x). 3.x also
  /// wanted one non-empty `source`; any `source`, or none, is accepted
  /// now. Its `flvUrl` is only a preload hint.
  static String? deepLinkRoomId(String raw) {
    final value = raw.trim();
    if (value.length > 8192 || value.contains(_controls)) return null;
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
      if (room == null || room.length != 1) return null;
      return XiaohongshuEndpoints.isRoomId(room.single) ? room.single : null;
    } on FormatException {
      return null;
    }
  }

  /// The room of a share page on `www.xiaohongshu.com` or
  /// `xiaohongshu.com` (3.x): `/livestream/<room>`,
  /// `/livestream/dynpath<8>/<room>` (the share redirect) or
  /// `/hina/livestream/<room>[/<alias>]`, http(s) on the default port,
  /// without user, escapes, backslashes or dot segments in the path as
  /// written.
  static String? webRoomId(String raw) {
    final uri = _webUri(raw);
    if (uri == null || !(uri.host == 'www.xiaohongshu.com' || uri.host == 'xiaohongshu.com')) return null;
    return (_canonicalPath.firstMatch(uri.path) ?? _dynamicPath.firstMatch(uri.path) ?? _hinaPath.firstMatch(uri.path))
        ?.group(1);
  }

  /// A short link `xhslink.com/<code>` or `xhslink.com/<prefix>/<code>`
  /// (3.x's `shortUri` knew only the prefix `m`; `/o/` and any prefix of
  /// one to four letters since the app's shares changed), else null.
  static Uri? shortLink(String raw) {
    final uri = _webUri(raw);
    return uri != null && uri.host == 'xhslink.com' && _shortPath.hasMatch(uri.path) ? uri : null;
  }

  /// The rooms of the app deep links in a share text, in order (3.x's
  /// `_sharedXhsDeepLinks`): a deep link not glued to a preceding URL, cut
  /// at the first Chinese punctuation mark and trailing ASCII punctuation.
  static Iterable<String> shareTextRoomIds(String text) sync* {
    for (final match in _deepLinks.allMatches(text)) {
      final candidate = match.group(0)!.split(_chineseProse).first.replaceFirst(_trailingPunctuation, '');
      final roomId = deepLinkRoomId(candidate);
      if (roomId != null) yield roomId;
    }
  }

  static bool _plainPath(String value) {
    if (value.length > 8192 || value.contains(_controls)) return false;
    final path = value.split(RegExp('[?#]')).first;
    return !path.contains('%') && !path.contains(r'\') && !RegExp(r'(^|/)\.\.?(/|$)').hasMatch(path);
  }

  static Uri? _webUri(String raw) {
    final value = raw.trim();
    if (!_plainPath(value)) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
      return null;
    }
    return uri;
  }
}
