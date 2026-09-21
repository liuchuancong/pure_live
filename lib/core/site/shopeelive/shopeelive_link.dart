final class ShopeeLiveRoomKey {
  const ShopeeLiveRoomKey({required this.region, required this.sessionId});

  final String region;
  final String sessionId;

  String get storageKey => '$region:$sessionId';
}

final class ShopeeLiveLink {
  const ShopeeLiveLink._();

  static const Set<String> _idHosts = {'live.shopee.co.id', 'shopee.co.id', 'www.shopee.co.id'};

  static ShopeeLiveRoomKey? parse(String raw) {
    final value = raw.trim();
    if (value.length > 8192 || RegExp(r'[\x00-\x20\x7f]').hasMatch(value)) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) ||
        !_idHosts.contains(uri.host.toLowerCase())) {
      return null;
    }
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList(growable: false);
    final path = '/${segments.join('/').toLowerCase()}';
    final isShare = uri.host.toLowerCase() == 'live.shopee.co.id' && path == '/share';
    final isMiddlePage = uri.host.toLowerCase() == 'live.shopee.co.id' && path == '/middle-page';
    final isMarketplaceLive = path == '/m/live';
    if (!isShare && !isMiddlePage && !isMarketplaceLive) return null;
    if (isMiddlePage && uri.queryParameters['type']?.toLowerCase() != 'live') return null;
    final id = normalizeSessionId(uri.queryParameters['session'] ?? uri.queryParameters['id']);
    return id == null ? null : ShopeeLiveRoomKey(region: 'id', sessionId: id);
  }

  static ShopeeLiveRoomKey? parseKey(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    final link = parse(value);
    if (link != null) return link;
    final match = RegExp(r'^(?:([a-z]{2}):)?([1-9][0-9]{0,19})$', caseSensitive: false).firstMatch(value);
    if (match == null) return null;
    final region = (match.group(1) ?? 'id').toLowerCase();
    if (region != 'id') return null;
    return ShopeeLiveRoomKey(region: region, sessionId: match.group(2)!);
  }

  static String? normalizeSessionId(Object? value) {
    if (value is! String && value is! int) return null;
    final id = value.toString().trim();
    return RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(id) ? id : null;
  }

  static String url(Object key) {
    final parsed = key is ShopeeLiveRoomKey ? key : parseKey(key);
    if (parsed == null) throw const FormatException('Invalid Shopee Live session key');
    return Uri.https('live.shopee.co.id', '/share', {'from': 'live', 'session': parsed.sessionId}).toString();
  }
}
