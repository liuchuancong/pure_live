class KickLink {
  const KickLink._();

  static const _reserved = {
    'auth',
    'browse',
    'categories',
    'category',
    'dashboard',
    'following',
    'search',
    'settings',
    'video',
  };

  static String? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        !_isHost(uri.host.toLowerCase())) {
      return null;
    }
    final segments = uri.pathSegments.where((value) => value.isNotEmpty).toList(growable: false);
    if (segments.length != 1) return null;
    return normalize(segments.single);
  }

  static String? normalize(String raw) {
    final slug = raw.trim().toLowerCase();
    if (slug.isEmpty || slug.length > 100 || _reserved.contains(slug) || !RegExp(r'^[a-z0-9_-]+$').hasMatch(slug)) {
      return null;
    }
    return slug;
  }

  static String url(String raw) {
    final slug = normalize(raw);
    if (slug == null) throw const FormatException('Invalid Kick channel slug');
    return 'https://kick.com/$slug';
  }

  static bool _isHost(String host) => host == 'kick.com' || host == 'www.kick.com';
}
