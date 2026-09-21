enum TaobaoLiveIdentityKind { live, creator }

final class TaobaoLiveIdentity {
  const TaobaoLiveIdentity._(this.kind, this.id);

  factory TaobaoLiveIdentity.live(String id) =>
      TaobaoLiveIdentity._(TaobaoLiveIdentityKind.live, TaobaoLiveLink.requireId(id));

  factory TaobaoLiveIdentity.creator(String id) =>
      TaobaoLiveIdentity._(TaobaoLiveIdentityKind.creator, TaobaoLiveLink.requireId(id));

  final TaobaoLiveIdentityKind kind;
  final String id;

  String get storageKey => '${kind.name}:$id';

  @override
  bool operator ==(Object other) => other is TaobaoLiveIdentity && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

abstract final class TaobaoLiveLink {
  static final RegExp _id = RegExp(r'^[1-9][0-9]{4,19}$');
  static const Set<String> _roomHosts = {'h5.m.taobao.com', 'huodong.m.taobao.com', 'tbzb.taobao.com'};

  static String requireId(Object? value) {
    final id = value is int
        ? '$value'
        : value is String
        ? value.trim()
        : '';
    if (!_id.hasMatch(id)) throw const FormatException('Invalid Taobao Live identity');
    return id;
  }

  static TaobaoLiveIdentity? parseStorageKey(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    if (_id.hasMatch(value)) return TaobaoLiveIdentity.live(value);
    final match = RegExp(r'^(live|creator):([1-9][0-9]{4,19})$', caseSensitive: false).firstMatch(value);
    if (match == null) return null;
    final id = match.group(2)!;
    return match.group(1)!.toLowerCase() == 'creator' ? TaobaoLiveIdentity.creator(id) : TaobaoLiveIdentity.live(id);
  }

  static TaobaoLiveIdentity? parse(String raw) {
    final value = raw.trim();
    final stored = parseStorageKey(value);
    if (stored != null) return stored;
    if (value.length > 8192 || RegExp(r'[\x00-\x20\x7f]').hasMatch(value)) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) ||
        !_roomHosts.contains(uri.host.toLowerCase())) {
      return null;
    }
    final path = '/${uri.pathSegments.where((part) => part.isNotEmpty).join('/').toLowerCase()}';
    final host = uri.host.toLowerCase();
    final validPath = switch (host) {
      'h5.m.taobao.com' => path == '/taolive/video.html',
      'huodong.m.taobao.com' => path == '/act/talent/live.html',
      'tbzb.taobao.com' => path == '/live',
      _ => false,
    };
    if (!validPath) return null;
    final liveId = _optionalId(uri.queryParameters['liveId'] ?? uri.queryParameters['id']);
    if (liveId != null) return TaobaoLiveIdentity.live(liveId);
    final creatorId = _optionalId(uri.queryParameters['creatorId'] ?? uri.queryParameters['userId']);
    return creatorId == null ? null : TaobaoLiveIdentity.creator(creatorId);
  }

  static Uri? shortUri(String raw) {
    final value = raw.trim();
    if (value.length > 2048 || RegExp(r'[\x00-\x20\x7f]').hasMatch(value)) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.host.toLowerCase() != 'm.tb.cn' ||
        (uri.hasPort && uri.port != 443)) {
      return null;
    }
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList(growable: false);
    if (segments.length != 1 || !RegExp(r'^h\.[A-Za-z0-9_-]{4,128}$', caseSensitive: false).hasMatch(segments.single)) {
      return null;
    }
    return uri;
  }

  static TaobaoLiveIdentity? parseLandingPage(String source) {
    if (source.length > 512 * 1024) return null;
    String? candidate;
    for (final expression in [
      RegExp(r'''\bvar\s+url\s*=\s*'([^']+)'\s*;'''),
      RegExp(r'''\bvar\s+url\s*=\s*"([^"]+)"\s*;'''),
    ]) {
      candidate = expression.firstMatch(source)?.group(1);
      if (candidate != null) break;
    }
    if (candidate == null || candidate.length > 8192) return null;
    final decoded = candidate
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\x26', '&')
        .replaceAll('&amp;', '&');
    return parse(decoded);
  }

  static String watchUrl(Object identity) {
    final parsed = identity is TaobaoLiveIdentity ? identity : parseStorageKey(identity);
    if (parsed == null) throw const FormatException('Invalid Taobao Live identity');
    return Uri.https(
      'h5.m.taobao.com',
      '/taolive/video.html',
      parsed.kind == TaobaoLiveIdentityKind.live ? {'id': parsed.id} : {'userId': parsed.id},
    ).toString();
  }

  static String? _optionalId(Object? value) {
    final text = value is int
        ? '$value'
        : value is String
        ? value.trim()
        : '';
    return _id.hasMatch(text) ? text : null;
  }
}
