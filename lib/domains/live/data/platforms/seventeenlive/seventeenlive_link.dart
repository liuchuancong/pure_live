class SeventeenLiveLink {
  const SeventeenLiveLink._();

  static String? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.host.toLowerCase() != '17.live') {
      return null;
    }
    final segments = uri.pathSegments.where((value) => value.isNotEmpty).toList(growable: false);
    if (segments.length == 2 && segments[0].toLowerCase() == 'live') {
      return normalizeRoomId(segments[1]);
    }
    if (segments.length == 3 && _locale(segments[0]) && segments[1].toLowerCase() == 'live') {
      return normalizeRoomId(segments[2]);
    }
    if (segments.length == 3 && segments[0].toLowerCase() == 'profile' && segments[1].toLowerCase() == 'r') {
      return normalizeRoomId(segments[2]);
    }
    if (segments.length == 4 &&
        _locale(segments[0]) &&
        segments[1].toLowerCase() == 'profile' &&
        segments[2].toLowerCase() == 'r') {
      return normalizeRoomId(segments[3]);
    }
    return null;
  }

  static String? parseOrId(String raw) => parse(raw) ?? normalizeRoomId(raw);

  static String? normalizeRoomId(String raw) {
    final roomId = raw.trim();
    return RegExp(r'^[1-9][0-9]{0,11}$').hasMatch(roomId) ? roomId : null;
  }

  static String url(String raw) {
    final roomId = normalizeRoomId(raw);
    if (roomId == null) throw const FormatException('Invalid 17LIVE room ID');
    return 'https://17.live/en/live/$roomId';
  }

  static bool _locale(String value) => RegExp(r'^[a-z]{2}(?:-[a-z]{2,4})?$', caseSensitive: false).hasMatch(value);
}
