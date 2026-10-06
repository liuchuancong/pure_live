import 'xiaohongshu_api.dart';
import 'xiaohongshu_share.dart';

import 'package:pure_live/shared/platforms/live_short_link_session.dart';

/// Broadcast room identity only. Profile IDs, notes and recommended rooms are
/// not aliases. Resolve short links only within the observed share hosts/routes.
class XiaohongshuLink {
  /// The official app deep link names a room; flvUrl is only a preload hint.
  /// Import the identity and let the normal room API resolve current media.
  static String? deepLinkRoomId(String raw) {
    final value = raw.trim();
    if (value.length > 8192 || value.contains(RegExp(r'[\x00-\x20\x7f]'))) return null;
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
      if (room?.length != 1) return null;
      final id = room!.single;
      return RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(id) ? id : null;
    } on FormatException {
      return null;
    }
  }

  static bool _plainPath(String value) {
    if (value.length > 8192 || value.contains(RegExp(r'[\x00-\x20\x7f]'))) return false;
    final path = value.split(RegExp(r'[?#]')).first;
    return !path.contains('%') && !path.contains('\\') && !RegExp(r'(^|/)\.\.?(/|$)').hasMatch(path);
  }

  static Uri? _webUri(String raw) {
    final value = raw.trim();
    if (!_plainPath(value)) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !{'https', 'http'}.contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
      return null;
    }
    return uri;
  }

  static String? parse(String raw) {
    final value = raw.trim();
    if (RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(value)) return value;
    final deepLink = deepLinkRoomId(value);
    if (deepLink != null) return deepLink;
    final uri = _webUri(value);
    if (uri == null || !{'www.xiaohongshu.com', 'xiaohongshu.com'}.contains(uri.host)) {
      return null;
    }
    final canonical = RegExp(r'^/livestream/([1-9][0-9]{0,19})/?$').firstMatch(uri.path);
    if (canonical != null) return canonical[1];
    // Current shared redirects contain an eight-character routing component.
    final dynamic = RegExp(r'^/livestream/dynpath[A-Za-z0-9]{8}/([1-9][0-9]{0,19})/?$').firstMatch(uri.path);
    if (dynamic != null) return dynamic[1];
    // The official hina router declares :id/:antiBlockAlias?. The trailing
    // routing component is never a broadcaster or a second room identity.
    final legacy = RegExp(r'^/hina/livestream/([1-9][0-9]{0,19})(?:/[A-Za-z0-9_-]{1,64})?/?$').firstMatch(uri.path);
    return legacy?[1];
  }

  static Uri? shortUri(String raw) {
    final uri = _webUri(raw);
    if (uri == null ||
        uri.host != 'xhslink.com' ||
        !RegExp(r'^/(?:[A-Za-z]{1,4}/)?[A-Za-z0-9]{1,64}/?$').hasMatch(uri.path)) {
      return null;
    }
    return uri;
  }

  /// A share text mixes prose and a link, so a pasted message is searched too.
  static final RegExp _urlInText = RegExp(r'https?://[^\s，。；！？、【】《》「」『』（）·…]+');

  static List<String> extractUrls(String raw) {
    if (raw.length > 8192) return const [];
    final urls = <String>[];
    for (final match in _urlInText.allMatches(raw)) {
      var url = match.group(0)!;
      while (url.length > 1 && url.endsWith('.')) {
        url = url.substring(0, url.length - 1);
      }
      urls.add(url);
    }
    return urls;
  }

  static Future<String?> resolve(String raw, {required LiveShortLinkSession session}) async {
    if (session.isClosed) return null;
    final direct = parse(raw);
    if (direct != null) return direct;
    // first as a room link, then as a short link to follow.
    Uri? current = shortUri(raw);
    if (current == null) {
      for (final candidate in extractUrls(raw)) {
        final room = parse(candidate);
        if (room != null) return room;
        current = shortUri(candidate);
        if (current != null) break;
      }
    }
    while (current != null && !session.isClosed) {
      final response = await session.get(current, headers: XiaohongshuApi.headers);
      if (session.isClosed ||
          response == null ||
          !LiveShortLinkSession.redirectStatuses.contains(response.statusCode)) {
        return null;
      }
      final locations = response.headers['location'];
      if (locations == null || locations.length != 1) return null;
      final location = locations.single.trim();
      // Check spelling before Uri.resolve collapses dot segments/escapes.
      if (location.isEmpty || !_plainPath(location)) return null;
      final Uri target;
      try {
        target = current.resolve(location);
      } on FormatException {
        return null;
      }
      final room = parse(target.toString());
      if (room != null) return room;
      // No arbitrary landing-page, profile, note, other-platform or local fetch.
      current = shortUri(target.toString());
    }
    return null;
  }

  static String url(String roomId) =>
      'https://www.xiaohongshu.com/livestream/${XiaohongshuShare.validateRoomId(roomId)}';
}
