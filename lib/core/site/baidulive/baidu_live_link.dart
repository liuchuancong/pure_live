abstract final class BaiduLiveLink {
  static final RegExp _roomId = RegExp(r'^[1-9]\d{5,19}$');
  static const String _host = 'live.baidu.com';

  static String watchUrl(String raw) => 'https://live.baidu.com/m/room/${requireRoomId(raw)}';

  static String requireRoomId(String raw) {
    final roomId = parseRoomId(raw);
    if (roomId == null) throw const FormatException('Invalid Baidu Live room identity');
    return roomId;
  }

  static String? parseRoomId(String raw) {
    final value = raw.trim();
    if (_roomId.hasMatch(value)) return value;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.host.toLowerCase() != _host ||
        (uri.hasPort && uri.port != 443) ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
    if (segments.length == 3 && segments[0] == 'm' && segments[1] == 'room' && _roomId.hasMatch(segments[2])) {
      return segments[2];
    }
    final roomId = uri.queryParameters['room_id']?.trim();
    if (roomId == null || !_roomId.hasMatch(roomId)) return null;
    final path = '/${segments.join('/')}';
    if (path == '/m/media/pclive/pchome/live.html') return roomId;
    if (segments.length == 6 &&
        segments.take(5).join('/') == 'm/media/multipage/liveshow/index' &&
        RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(segments.last)) {
      return roomId;
    }
    return null;
  }
}
