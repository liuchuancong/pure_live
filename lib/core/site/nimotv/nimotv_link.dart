final class NimoTvChannelKey {
  const NimoTvChannelKey(this.value);

  final String value;

  String get storageKey => value.toLowerCase();
}

final class NimoTvLink {
  const NimoTvLink._();

  static const Set<String> _hosts = {'nimo.tv', 'www.nimo.tv', 'm.nimo.tv'};
  static const Set<String> _reserved = {'download', 'game', 'games', 'lives', 'login', 'p', 'search'};

  static NimoTvChannelKey? parse(String raw) {
    final value = raw.trim();
    if (value.length > 8192 || RegExp(r'[\x00-\x20\x7f]').hasMatch(value)) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasQuery ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) ||
        !_hosts.contains(uri.host.toLowerCase())) {
      return null;
    }
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList(growable: false);
    final rawKey = segments.length == 2 && segments.first.toLowerCase() == 'live'
        ? segments.last
        : segments.length == 1
        ? segments.single
        : null;
    final key = normalizeKey(rawKey);
    if (key == null || _reserved.contains(key)) return null;
    return NimoTvChannelKey(key);
  }

  static NimoTvChannelKey? parseKey(Object? raw) {
    if (raw is! String) return null;
    final parsed = parse(raw);
    if (parsed != null) return parsed;
    final key = normalizeKey(raw);
    return key == null || _reserved.contains(key) ? null : NimoTvChannelKey(key);
  }

  static String? normalizeKey(Object? value) {
    if (value is! String) return null;
    final key = value.trim().toLowerCase();
    return RegExp(r'^(?:[1-9][0-9]{0,19}|[a-z0-9_][a-z0-9_.-]{1,63})$').hasMatch(key) ? key : null;
  }

  static String url(Object key) {
    final parsed = key is NimoTvChannelKey ? key : parseKey(key);
    if (parsed == null) throw const FormatException('Invalid NimoTV channel');
    final path = RegExp(r'^[0-9]+$').hasMatch(parsed.storageKey)
        ? '/live/${parsed.storageKey}'
        : '/${parsed.storageKey}';
    return Uri.https('www.nimo.tv', path).toString();
  }

  static String mobileUrl(Object key) {
    final parsed = key is NimoTvChannelKey ? key : parseKey(key);
    if (parsed == null) throw const FormatException('Invalid NimoTV channel');
    final path = RegExp(r'^[0-9]+$').hasMatch(parsed.storageKey)
        ? '/live/${parsed.storageKey}'
        : '/${parsed.storageKey}';
    return Uri.https('m.nimo.tv', path).toString();
  }
}
