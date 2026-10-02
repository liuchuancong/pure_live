enum YouTubeLinkKind { video, channel }

class YouTubeLink {
  const YouTubeLink({required this.kind, required this.id, this.channelPath = ''});

  final YouTubeLinkKind kind;
  final String id;
  final String channelPath;

  static YouTubeLink? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !_officialHost(uri.host.toLowerCase())) {
      return null;
    }
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments.where((value) => value.isNotEmpty).toList(growable: false);
    if (segments.any((value) => value == '.' || value == '..')) return null;
    if (host == 'youtu.be') {
      if (segments.length != 1) return null;
      final id = normalizeVideoId(segments.single);
      return id == null ? null : YouTubeLink(kind: YouTubeLinkKind.video, id: id);
    }
    if (segments.length == 1 && segments.first == 'watch') {
      final id = normalizeVideoId(uri.queryParameters['v'] ?? '');
      return id == null ? null : YouTubeLink(kind: YouTubeLinkKind.video, id: id);
    }
    if (segments.length == 2 && segments.first.toLowerCase() == 'embed' && segments[1].toLowerCase() == 'live_stream') {
      final channelId = uri.queryParameters['channel'] ?? '';
      if (RegExp(r'^UC[A-Za-z0-9_-]{20,30}$').hasMatch(channelId)) {
        final path = 'channel/$channelId';
        return YouTubeLink(kind: YouTubeLinkKind.channel, id: path, channelPath: path);
      }
      return null;
    }
    if (segments.length == 2 && const {'live', 'embed', 'v'}.contains(segments.first.toLowerCase())) {
      final id = normalizeVideoId(segments[1]);
      return id == null ? null : YouTubeLink(kind: YouTubeLinkKind.video, id: id);
    }
    final channelPath = _channelPath(segments);
    if (channelPath == null) return null;
    return YouTubeLink(kind: YouTubeLinkKind.channel, id: channelPath, channelPath: channelPath);
  }

  static YouTubeLink? parseOrReference(String raw) {
    final parsed = parse(raw);
    if (parsed != null) return parsed;
    final value = raw.trim();
    final videoId = normalizeVideoId(value);
    if (videoId != null) return YouTubeLink(kind: YouTubeLinkKind.video, id: videoId);
    final handle = normalizeHandle(value);
    return handle == null ? null : YouTubeLink(kind: YouTubeLinkKind.channel, id: '@$handle', channelPath: '@$handle');
  }

  static String? parseDurableVideoId(String raw) {
    final parsed = parse(raw);
    return parsed?.kind == YouTubeLinkKind.video ? parsed!.id : null;
  }

  static String? normalizeVideoId(String raw) {
    final value = raw.trim();
    return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(value) ? value : null;
  }

  static String? normalizeHandle(String raw) {
    final value = raw.trim().startsWith('@') ? raw.trim().substring(1) : raw.trim();
    if (value.length < 3 || value.length > 30) return null;
    return RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(value) ? value : null;
  }

  static String videoUrl(String rawVideoId) {
    final videoId = normalizeVideoId(rawVideoId);
    if (videoId == null) throw const FormatException('Invalid YouTube video ID');
    return 'https://www.youtube.com/watch?v=$videoId';
  }

  String get url => switch (kind) {
    YouTubeLinkKind.video => videoUrl(id),
    YouTubeLinkKind.channel => 'https://www.youtube.com/$channelPath/live',
  };

  static String? _channelPath(List<String> segments) {
    if (segments.isEmpty || segments.length > 3) return null;
    final values = [...segments];
    if (values.last.toLowerCase() == 'live') values.removeLast();
    if (values.length == 1 && values.single.startsWith('@')) {
      final handle = normalizeHandle(values.single);
      return handle == null ? null : '@$handle';
    }
    if (values.length != 2) return null;
    final prefix = values.first.toLowerCase();
    final id = values[1];
    if (prefix == 'channel' && RegExp(r'^UC[A-Za-z0-9_-]{20,30}$').hasMatch(id)) return 'channel/$id';
    if (const {'c', 'user'}.contains(prefix) && RegExp(r'^[A-Za-z0-9_.-]{1,100}$').hasMatch(id)) {
      return '$prefix/$id';
    }
    return null;
  }

  static bool _officialHost(String host) =>
      host == 'youtu.be' ||
      host == 'youtube.com' ||
      host.endsWith('.youtube.com') ||
      host == 'youtube-nocookie.com' ||
      host.endsWith('.youtube-nocookie.com');
}
