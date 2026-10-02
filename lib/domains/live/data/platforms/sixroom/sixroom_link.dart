abstract final class SixRoomLink {
  static final RegExp _roomId = RegExp(r'^[1-9]\d{1,11}$');
  static const Set<String> _hosts = {'v.6.cn', 'm.6.cn'};

  static String watchUrl(String raw) => 'https://v.6.cn/${requireRoomId(raw)}';

  static String requireRoomId(String raw) {
    final value = parseRoomId(raw);
    if (value == null) throw const FormatException('Invalid Six Rooms room identity');
    return value;
  }

  static String? parseRoomId(String raw) {
    final value = raw.trim();
    if (_roomId.hasMatch(value)) return value;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        !_hosts.contains(uri.host.toLowerCase()) ||
        (uri.hasPort && uri.port != 80 && uri.port != 443) ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList(growable: false);
    if (segments.length == 1 && _roomId.hasMatch(segments.single)) return segments.single;
    if (segments.length == 2 && segments.first.toLowerCase() == 'profile' && _roomId.hasMatch(segments.last)) {
      return segments.last;
    }
    return null;
  }
}
