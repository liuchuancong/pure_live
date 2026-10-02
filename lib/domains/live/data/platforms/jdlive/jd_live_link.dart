abstract final class JdLiveLink {
  static final RegExp _liveId = RegExp(r'^[1-9]\d{4,17}$');
  static final RegExp _route = RegExp(r'^/?([1-9]\d{4,17})(?:/(?:live|notice|closed|replay))?(?:\?.*)?$');

  static String watchUrl(String raw) => 'https://lives.jd.com/#/${requireLiveId(raw)}';

  static String requireLiveId(String raw) {
    final value = parseLiveId(raw);
    if (value == null) throw const FormatException('Invalid JD Live identity');
    return value;
  }

  static String? parseLiveId(String raw) {
    final value = raw.trim();
    if (_liveId.hasMatch(value)) return value;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.host.toLowerCase() != 'lives.jd.com' ||
        (uri.hasPort && uri.port != 80 && uri.port != 443)) {
      return null;
    }
    final match = _route.firstMatch(uri.fragment);
    return match?.group(1);
  }
}
