abstract final class SteamBroadcastLink {
  static final RegExp _steamId = RegExp(r'^7656119\d{10}$');

  static String watchUrl(String raw) => 'https://steamcommunity.com/broadcast/watch/${requireSteamId(raw)}';

  static String requireSteamId(String raw) {
    final value = parseSteamId(raw);
    if (value == null) throw const FormatException('Invalid Steam broadcast identity');
    return value;
  }

  static String? parseSteamId(String raw) {
    final value = raw.trim();
    if (_steamId.hasMatch(value)) return value;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.host.toLowerCase() != 'steamcommunity.com' ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != 80 && uri.port != 443)) {
      return null;
    }
    late final List<String> segments;
    try {
      segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
    } on FormatException {
      return null;
    }
    if (segments.length != 3 || segments[0] != 'broadcast' || segments[1] != 'watch') return null;
    return _steamId.hasMatch(segments[2]) ? segments[2] : null;
  }
}
