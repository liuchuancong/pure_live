class ChzzkLink {
  const ChzzkLink._();

  static String? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.host.toLowerCase() != 'chzzk.naver.com') {
      return null;
    }
    final segments = uri.pathSegments.where((value) => value.isNotEmpty).toList(growable: false);
    if (segments.length != 2 || segments.first != 'live') return null;
    final id = segments[1].trim().toLowerCase();
    return RegExp(r'^[a-f0-9]{32}$').hasMatch(id) ? id : null;
  }

  static String url(String channelId) {
    final id = channelId.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) throw const FormatException('Invalid CHZZK channel ID');
    return 'https://chzzk.naver.com/live/$id';
  }
}
