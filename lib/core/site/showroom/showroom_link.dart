class ShowroomLink {
  const ShowroomLink._();

  static const Set<String> _reserved = {
    'api',
    'room',
    'event',
    'ranking',
    'search',
    'login',
    'register',
    'mypage',
    'premium_live',
  };

  /// Returns either the durable numeric room ID or the public room_url_key.
  /// The adapter resolves room_url_key through the official status endpoint.
  static String? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        !_isHost(uri.host.toLowerCase())) {
      return null;
    }
    final segments = uri.pathSegments.where((value) => value.isNotEmpty).toList(growable: false);
    if (segments.length == 2 && segments[0] == 'room' && segments[1] == 'profile') {
      final roomId = uri.queryParameters['room_id']?.trim() ?? '';
      return RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(roomId) ? roomId : null;
    }
    if (segments.length == 2 && segments.first == 'r') return _slug(segments[1]);
    if (segments.length == 1) return _slug(segments.single);
    return null;
  }

  static String roomUrl(Object roomId) {
    final value = roomId.toString().trim();
    if (!RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(value)) throw const FormatException('Invalid SHOWROOM room ID');
    return 'https://www.showroom-live.com/room/profile?room_id=$value';
  }

  static bool _isHost(String host) => host == 'showroom-live.com' || host.endsWith('.showroom-live.com');

  static String? _slug(String value) {
    final normalized = value.trim();
    if (_reserved.contains(normalized.toLowerCase()) || !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }
}
