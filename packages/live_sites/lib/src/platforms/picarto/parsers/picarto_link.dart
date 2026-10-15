import 'package:live_sites/src/platforms/picarto/api/picarto_endpoints.dart';

/// Picarto's links: the channel page a URL names, or null.
abstract final class PicartoLink {
  /// The channel of a channel page: http(s) on `picarto.tv` or
  /// `www.picarto.tv`, no user info, the default port, and exactly one path
  /// segment (a trailing `/` allowed) that is a channel name. Search,
  /// explore and other pages, `//name`, `name/videos` and undecodable paths
  /// are not.
  static String? channelFromUrl(Uri uri) {
    if (!(uri.isScheme('http') || uri.isScheme('https')) ||
        !PicartoEndpoints.linkHosts.contains(uri.host.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != (uri.isScheme('https') ? 443 : 80))) {
      return null;
    }
    final List<String> parts;
    try {
      parts = uri.pathSegments.toList();
    } on FormatException {
      return null;
    }
    if (parts.isNotEmpty && parts.last.isEmpty) parts.removeLast();
    if (parts.length != 1) return null;
    final name = parts.single.trim();
    return PicartoEndpoints.isChannelName(name) && !PicartoEndpoints.pagePaths.contains(name.toLowerCase())
        ? name
        : null;
  }

  /// Whether [host] (lower-case) is one of Picarto's, so a link there that
  /// names no channel is this site's, not a foreign one.
  static bool ownsHost(String host) => PicartoEndpoints.linkHosts.contains(host) || host.endsWith('.picarto.tv');
}
