enum TikTokLinkKind { username, roomId }

class TikTokLink {
  const TikTokLink({required this.kind, required this.id});

  final TikTokLinkKind kind;
  final String id;

  static TikTokLink? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !_officialHost(uri.host.toLowerCase())) {
      return null;
    }
    final segments = uri.pathSegments.where((value) => value.isNotEmpty).toList(growable: false);
    if (segments.any((value) => value == '.' || value == '..')) return null;
    if (segments.length == 1 && segments.first.startsWith('@')) {
      final username = normalizeUsername(segments.first.substring(1));
      return username == null ? null : TikTokLink(kind: TikTokLinkKind.username, id: username);
    }
    if (segments.length == 2 && segments.first.startsWith('@') && segments[1].toLowerCase() == 'live') {
      final username = normalizeUsername(segments.first.substring(1));
      return username == null ? null : TikTokLink(kind: TikTokLinkKind.username, id: username);
    }
    if (segments.length == 3 && segments[0].toLowerCase() == 'share' && segments[1].toLowerCase() == 'live') {
      final roomId = normalizeRoomId(segments[2]);
      return roomId == null ? null : TikTokLink(kind: TikTokLinkKind.roomId, id: roomId);
    }
    return null;
  }

  static TikTokLink? parseOrUsername(String raw) {
    final parsed = parse(raw);
    if (parsed != null) return parsed;
    final value = raw.trim().startsWith('@') ? raw.trim().substring(1) : raw.trim();
    final username = normalizeUsername(value);
    return username == null ? null : TikTokLink(kind: TikTokLinkKind.username, id: username);
  }

  static String? parseDurableUsername(String raw) {
    final parsed = parse(raw);
    if (parsed?.kind == TikTokLinkKind.username) return parsed!.id;
    return null;
  }

  static String? normalizeUsername(String raw) {
    final value = raw.trim().toLowerCase();
    return RegExp(r'^[a-z0-9_](?:[a-z0-9._]{0,22}[a-z0-9_])?$').hasMatch(value) ? value : null;
  }

  static String? normalizeRoomId(String raw) {
    final value = raw.trim();
    return RegExp(r'^[1-9][0-9]{14,24}$').hasMatch(value) ? value : null;
  }

  static String url(String rawUsername) {
    final username = normalizeUsername(rawUsername);
    if (username == null) throw const FormatException('Invalid TikTok username');
    return 'https://www.tiktok.com/@$username/live';
  }

  static bool isShortHost(String host) {
    final value = host.trim().toLowerCase();
    return value == 'vm.tiktok.com' || value == 'vt.tiktok.com';
  }

  static bool _officialHost(String host) => host == 'tiktok.com' || host == 'www.tiktok.com' || host == 'm.tiktok.com';
}
