import 'weibo_api.dart';

/// Broadcast watch URLs only. A profile UID is not a persistent live room.
class WeiboLink {
  static String? parse(String raw) {
    final value = raw.trim();
    if (RegExp(r'[\\\s]').hasMatch(value)) return null;
    if (_valid(value)) return value;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        !{'weibo.com', 'www.weibo.com'}.contains(uri.host) ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
      return null;
    }
    // Inspect the original path before Uri normalizes dot segments. Only the
    // identifier's colon may be escaped; no double decoding or encoded slashes.
    final authorityAndPath = value.substring(value.indexOf('://') + 3).split(RegExp(r'[?#]')).first;
    final slash = authorityAndPath.indexOf('/');
    if (slash < 0) return null;
    final match = RegExp(r'^/l/wblive/[pm]/show/([^/]+)/?$').firstMatch(authorityAndPath.substring(slash));
    if (match == null) return null;
    final id = match[1]!.replaceAll(RegExp('%3a', caseSensitive: false), ':');
    try {
      return WeiboApi.validateLiveId(id);
    } on WeiboException {
      return null;
    }
  }

  static bool _valid(String value) {
    try {
      WeiboApi.validateLiveId(value);
      return true;
    } on WeiboException {
      return false;
    }
  }

  static String url(String id) => 'https://weibo.com/l/wblive/p/show/${WeiboApi.validateLiveId(id)}';
}
