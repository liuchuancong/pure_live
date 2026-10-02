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
    // 直播页 `/live/<id>`，以及频道页 `/<id>`（后面最多跟一个页签，如
    // `/<id>/videos`）都是这个频道（上游 20-4，3.x 只认前者）。
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
