enum DailymotionLinkKind { video, user }

final class DailymotionReference {
  const DailymotionReference(this.kind, this.id);

  final DailymotionLinkKind kind;
  final String id;
}

abstract final class DailymotionLink {
  static final RegExp _videoId = RegExp(r'^x[0-9a-z]{5,15}$', caseSensitive: false);
  static final RegExp _username = RegExp(r'^[A-Za-z0-9_-]{2,64}$');
  static const Set<String> _reserved = {
    'about',
    'embed',
    'help',
    'legal',
    'live',
    'login',
    'partner',
    'playlist',
    'privacy',
    'search',
    'settings',
    'signup',
    'terms',
    'user',
    'video',
    'videos',
  };

  static String videoUrl(String videoId) => 'https://www.dailymotion.com/video/${requireVideoId(videoId)}';

  static String requireVideoId(String raw) {
    final id = raw.trim().toLowerCase();
    if (!_videoId.hasMatch(id)) throw const FormatException('Invalid Dailymotion video identity');
    return id;
  }

  static String? parseVideoId(String raw) {
    final input = raw.trim();
    if (_videoId.hasMatch(input)) return input.toLowerCase();
    final reference = parse(input);
    return reference?.kind == DailymotionLinkKind.video ? reference!.id : null;
  }

  static String? parseUsername(String raw) {
    final input = raw.trim();
    final reference = parse(input);
    if (reference?.kind == DailymotionLinkKind.user) return reference!.id;
    if (_username.hasMatch(input) && !_videoId.hasMatch(input) && !_reserved.contains(input.toLowerCase())) {
      return input;
    }
    return null;
  }

  static DailymotionReference? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme.toLowerCase() != 'https' || uri.userInfo.isNotEmpty) return null;
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
    if (host == 'dai.ly') {
      if (segments.length != 1 || !_videoId.hasMatch(segments.single)) return null;
      return DailymotionReference(DailymotionLinkKind.video, segments.single.toLowerCase());
    }
    if (host != 'dailymotion.com' && host != 'www.dailymotion.com' && host != 'm.dailymotion.com') return null;
    if (segments.length == 2 && const {'video', 'live'}.contains(segments.first.toLowerCase())) {
      final id = segments[1];
      if (!_videoId.hasMatch(id)) return null;
      return DailymotionReference(DailymotionLinkKind.video, id.toLowerCase());
    }
    if (segments.length == 3 && segments[0].toLowerCase() == 'embed' && segments[1].toLowerCase() == 'video') {
      final id = segments[2];
      if (!_videoId.hasMatch(id)) return null;
      return DailymotionReference(DailymotionLinkKind.video, id.toLowerCase());
    }
    if (segments.length == 2 && segments.first.toLowerCase() == 'user') {
      final username = segments[1];
      if (!_username.hasMatch(username) || _reserved.contains(username.toLowerCase())) return null;
      return DailymotionReference(DailymotionLinkKind.user, username);
    }
    if (segments.length == 1) {
      final username = segments.single;
      if (!_username.hasMatch(username) || _reserved.contains(username.toLowerCase())) return null;
      return DailymotionReference(DailymotionLinkKind.user, username);
    }
    return null;
  }
}
