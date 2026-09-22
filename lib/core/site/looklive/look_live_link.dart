abstract final class LookLiveLink {
  static final RegExp _roomId = RegExp(r'^[1-9][0-9]{1,17}$');

  static String watchUrl(String raw) => 'https://look.163.com/live?id=${requireRoomId(raw)}';

  static String requireRoomId(String raw) {
    final value = parseRoomId(raw);
    if (value == null) throw const FormatException('Invalid LOOK Live room identity');
    return value;
  }

  static String? parseRoomId(String raw) {
    final value = raw.trim();
    if (_roomId.hasMatch(value)) return value;
    if (value.length > 8192 || RegExp(r'[\x00-\x20\x7f]').hasMatch(value)) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.toLowerCase() != 'look.163.com' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 80 && uri.port != 443) ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    try {
      final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList(growable: false);
      if (segments.length != 1 || segments.single.toLowerCase() != 'live') return null;
      final ids = uri.queryParametersAll['id'];
      if (ids == null || ids.length != 1 || !_roomId.hasMatch(ids.single)) return null;
      return ids.single;
    } on FormatException {
      return null;
    }
  }
}
