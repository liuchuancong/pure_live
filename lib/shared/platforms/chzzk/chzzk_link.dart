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
    final List<String> segments;
    try {
      segments = uri.pathSegments.where((value) => value.isNotEmpty).toList(growable: false);
    } on FormatException {
      return null;
    }
    final candidate = switch (segments) {
      ['live', final id] => id,
      [final id] || [final id, _] => id,
      _ => null,
    };
    final id = candidate?.trim().toLowerCase();
    return id != null && RegExp(r'^[a-f0-9]{32}$').hasMatch(id) ? id : null;
  }

  static String url(String channelId) {
    final id = channelId.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) throw const FormatException('Invalid CHZZK channel ID');
    return 'https://chzzk.naver.com/live/$id';
  }
}
