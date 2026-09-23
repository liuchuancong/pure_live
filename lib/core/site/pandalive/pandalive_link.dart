final class PandaLiveLink {
  const PandaLiveLink._();

  static const _hosts = {'pandalive.co.kr', 'www.pandalive.co.kr', 'm.pandalive.co.kr'};

  static String? parse(String raw) {
    if (raw.length > 8192 || RegExp(r'[\x00-\x20\x7f]').hasMatch(raw)) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) ||
        !_hosts.contains(uri.host.toLowerCase())) {
      return null;
    }
    final segments = uri.pathSegments.where((value) => value.isNotEmpty).toList(growable: false);
    if (segments.length == 3 && segments[0].toLowerCase() == 'live' && segments[1].toLowerCase() == 'play') {
      return normalizeUserId(segments[2]);
    }
    if (segments.length == 2 && segments[0].toLowerCase() == 'channel') {
      return normalizeUserId(segments[1]);
    }
    if (segments.length == 3 && segments[0].toLowerCase() == 'channel' && segments[2].toLowerCase() == 'home') {
      return normalizeUserId(segments[1]);
    }
    return null;
  }

  static String? parseOrId(String raw) => parse(raw.trim()) ?? normalizeUserId(raw.trim());

  static String? normalizeUserId(Object? value) {
    if (value is! String) return null;
    final userId = value.trim();
    // The official BJ index also contains social-login IDs such as
    // 1506087545@ka, which the public member endpoint resolves directly.
    return RegExp(r'^[A-Za-z0-9_]{1,64}(?:@[A-Za-z0-9_]{2,16})?$').hasMatch(userId) ? userId : null;
  }

  static String url(String rawUserId) {
    final userId = normalizeUserId(rawUserId);
    if (userId == null) throw const FormatException('Invalid PandaTV user ID');
    return Uri.https('www.pandalive.co.kr', '/live/play/$userId').toString();
  }
}
