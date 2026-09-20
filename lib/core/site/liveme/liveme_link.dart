enum LiveMeLinkKind { shortId, userId, videoId }

class LiveMeLink {
  const LiveMeLink({required this.kind, required this.id});

  final LiveMeLinkKind kind;
  final String id;

  static LiveMeLink? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        !_officialHost(uri.host.toLowerCase())) {
      return null;
    }
    final segments = uri.pathSegments.where((value) => value.isNotEmpty).toList(growable: false);
    if (segments.isEmpty || segments.any((value) => value == '.' || value == '..')) return null;
    var offset = 0;
    if (_locale(segments.first)) offset = 1;
    final tail = segments.sublist(offset);
    if (tail.length == 3 && tail[0].toLowerCase() == 'livehot' && tail[1].toLowerCase() == 'streaming') {
      final id = normalizeShortId(tail[2]);
      return id == null ? null : LiveMeLink(kind: LiveMeLinkKind.shortId, id: id);
    }
    if (tail.length == 2 && tail[0].toLowerCase() == 'u') {
      final id = normalizeLongId(tail[1]);
      return id == null ? null : LiveMeLink(kind: LiveMeLinkKind.userId, id: id);
    }
    if (tail.length == 2 && tail[0].toLowerCase() == 'v') {
      final id = normalizeLongId(tail[1]);
      return id == null ? null : LiveMeLink(kind: LiveMeLinkKind.videoId, id: id);
    }
    if (tail.length == 4 &&
        tail[0].toLowerCase() == 'm' &&
        tail[1].toLowerCase() == 'v' &&
        tail[3].toLowerCase() == 'index.html') {
      final id = normalizeLongId(tail[2]);
      return id == null ? null : LiveMeLink(kind: LiveMeLinkKind.videoId, id: id);
    }
    return null;
  }

  static LiveMeLink? parseOrShortId(String raw) {
    final parsed = parse(raw);
    if (parsed != null) return parsed;
    final id = normalizeShortId(raw);
    return id == null ? null : LiveMeLink(kind: LiveMeLinkKind.shortId, id: id);
  }

  static String? parseDurableRoomId(String raw) {
    final reference = parse(raw);
    if (reference?.kind == LiveMeLinkKind.shortId) return reference!.id;
    return normalizeShortId(raw);
  }

  static String? normalizeShortId(String raw) {
    final value = raw.trim();
    return RegExp(r'^[1-9][0-9]{4,11}$').hasMatch(value) ? value : null;
  }

  static String? normalizeLongId(String raw) {
    final value = raw.trim();
    return RegExp(r'^[1-9][0-9]{12,23}$').hasMatch(value) ? value : null;
  }

  static String url(String raw) {
    final id = normalizeShortId(raw);
    if (id == null) throw const FormatException('Invalid LiveMe short ID');
    return 'https://www.liveme.com/livehot/streaming/$id';
  }

  static bool _officialHost(String host) => host == 'liveme.com' || host == 'www.liveme.com';

  static bool _locale(String value) => RegExp(r'^[a-z]{2}(?:-[a-z]{2,4})?$', caseSensitive: false).hasMatch(value);
}
