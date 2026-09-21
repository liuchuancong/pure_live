final class LangLiveLink {
  const LangLiveLink._();

  static const _hosts = {'lang.live', 'www.lang.live'};
  static const _routes = {'main', 'room'};

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
    if (segments.length != 2 || !_routes.contains(segments.first.toLowerCase())) return null;
    return normalizeRoomId(segments.last);
  }

  static String? parseOrId(String raw) => parse(raw.trim()) ?? normalizeRoomId(raw.trim());

  static String? normalizeRoomId(Object? value) {
    final text = switch (value) {
      int number => '$number',
      String string => string,
      _ => '',
    };
    return RegExp(r'^[1-9][0-9]{0,11}$').hasMatch(text) ? text : null;
  }

  static String url(String roomId) {
    final normalized = normalizeRoomId(roomId);
    if (normalized == null) throw const FormatException('Invalid Lang Live room ID');
    return 'https://www.lang.live/main/$normalized';
  }
}
