enum GoodGameLinkKind { channel, player }

final class GoodGameReference {
  const GoodGameReference(this.kind, this.value);

  final GoodGameLinkKind kind;
  final String value;

  String get storageKey => kind == GoodGameLinkKind.player ? 'id:$value' : value.toLowerCase();
}

abstract final class GoodGameLink {
  static final RegExp _channel = RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_.-]{0,79}$');
  static final RegExp _playerKey = RegExp(r'^id:(\d{1,12})$', caseSensitive: false);
  static const Set<String> _reserved = {
    'api',
    'chat',
    'clips',
    'games',
    'help',
    'login',
    'news',
    'player',
    'premium',
    'register',
    'search',
    'streams',
    'support',
    'tournaments',
  };

  static String channelUrl(String raw) => 'https://goodgame.ru/${requireChannel(raw)}';

  static String requireChannel(String raw) {
    final channel = parseChannel(raw);
    if (channel == null) throw const FormatException('Invalid GoodGame channel identity');
    return channel;
  }

  static String? parseChannel(String raw) {
    final input = raw.trim();
    final direct = _normalizeChannel(input);
    if (direct != null) return direct;
    final reference = parse(input);
    return reference?.kind == GoodGameLinkKind.channel ? reference!.value : null;
  }

  static GoodGameReference? parseReference(String raw) {
    final input = raw.trim();
    final player = _playerKey.firstMatch(input);
    if (player != null && _positiveId(player.group(1)!)) {
      return GoodGameReference(GoodGameLinkKind.player, player.group(1)!);
    }
    final channel = _normalizeChannel(input);
    if (channel != null) return GoodGameReference(GoodGameLinkKind.channel, channel);
    return parse(input);
  }

  static GoodGameReference? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        (uri.scheme.toLowerCase() != 'https' && uri.scheme.toLowerCase() != 'http') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      return null;
    }
    final host = uri.host.toLowerCase();
    if (host != 'goodgame.ru' && host != 'www.goodgame.ru') return null;
    late final List<String> segments;
    try {
      segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
    } on FormatException {
      return null;
    }
    if (segments.length == 1 && segments.single.toLowerCase() == 'player') {
      final id = uri.query.trim();
      if (_positiveId(id)) return GoodGameReference(GoodGameLinkKind.player, id);
      final src = uri.queryParameters['src']?.trim() ?? '';
      if (_positiveId(src)) return GoodGameReference(GoodGameLinkKind.player, src);
      return null;
    }
    if (segments.length != 1) return null;
    final channel = _normalizeChannel(segments.single);
    return channel == null ? null : GoodGameReference(GoodGameLinkKind.channel, channel);
  }

  static String? _normalizeChannel(String raw) {
    final value = raw.trim();
    if (!_channel.hasMatch(value) || _reserved.contains(value.toLowerCase())) return null;
    return value.toLowerCase();
  }

  static bool _positiveId(String raw) {
    final value = int.tryParse(raw);
    return value != null && value > 0 && value <= 0x7fffffff;
  }
}
