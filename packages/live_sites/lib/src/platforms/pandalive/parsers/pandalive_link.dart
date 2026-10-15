import 'package:live_sites/src/platforms/pandalive/api/pandalive_endpoints.dart';

/// A PandaTV room link: the live or channel page of a broadcaster, whose
/// last path segment is the broadcaster id. Pure parsing, no request.
abstract final class PandaliveLink {
  static final RegExp _unsafe = RegExp(r'[\x00-\x20\x7f]');

  /// The broadcaster of a room link: http(s) on [PandaliveEndpoints
  /// .roomHosts] with the default port, without user info, fragment, blank
  /// or control character, and the path (empty segments ignored, `live`,
  /// `play`, `channel`, `home` in any case) `/live/play/<id>`,
  /// `/channel/<id>`, `/channel/<id>/home` or the website's live page
  /// `/play/<id>`. The id as written; null for anything else, a path that
  /// does not decode included.
  static String? roomIdFromUrl(String url) {
    if (url.length > 8192 || _unsafe.hasMatch(url)) return null;
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        (!uri.isScheme('http') && !uri.isScheme('https')) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) ||
        !PandaliveEndpoints.roomHosts.contains(uri.host.toLowerCase())) {
      return null;
    }
    final List<String> segments;
    try {
      segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
    } on FormatException {
      return null;
    }
    final id = switch ([for (final segment in segments) segment.toLowerCase()]) {
      ['live', 'play', _] => segments[2],
      ['play', _] || ['channel', _] || ['channel', _, 'home'] => segments[1],
      _ => null,
    };
    return PandaliveEndpoints.normalizeUserId(id);
  }
}
