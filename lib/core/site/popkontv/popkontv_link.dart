final class PopkonChannelKey {
  const PopkonChannelKey({required this.signId, this.partnerCode});

  final String signId;
  final String? partnerCode;

  String get storageKey => partnerCode == null ? signId : '$signId@$partnerCode';
}

final class PopkonLink {
  const PopkonLink._();

  static const _hosts = {'popkontv.com', 'www.popkontv.com', 'm.popkontv.com'};

  static PopkonChannelKey? parse(String raw) {
    final value = raw.trim();
    if (value.length > 8192 || RegExp(r'[\x00-\x20\x7f]').hasMatch(value)) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) ||
        !_hosts.contains(uri.host.toLowerCase())) {
      return null;
    }
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList(growable: false);
    final isCurrentRoom = segments.length == 2 && segments[0].toLowerCase() == 'live' && segments[1] == 'view';
    final isLegacyRoom = segments.isNotEmpty && const {'live', 'channel'}.contains(segments.first.toLowerCase());
    if (!isCurrentRoom && !isLegacyRoom) return null;
    final signId = normalizeSignId(uri.queryParameters['castId'] ?? uri.queryParameters['mcid']);
    if (signId == null) return null;
    final rawPartner = uri.queryParameters['partnerCode'] ?? uri.queryParameters['mcPartnerCode'];
    final partner = normalizePartnerCode(rawPartner);
    if (rawPartner != null && partner == null) return null;
    return PopkonChannelKey(signId: signId, partnerCode: partner);
  }

  static PopkonChannelKey? parseKey(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    final parsed = parse(value);
    if (parsed != null) return parsed;
    final separator = value.lastIndexOf('@');
    if (separator > 0) {
      final signId = normalizeSignId(value.substring(0, separator));
      final partner = normalizePartnerCode(value.substring(separator + 1));
      if (signId != null && partner != null) return PopkonChannelKey(signId: signId, partnerCode: partner);
    }
    final signId = normalizeSignId(value);
    return signId == null ? null : PopkonChannelKey(signId: signId);
  }

  static String? normalizeSignId(Object? value) {
    if (value is! String) return null;
    final signId = value.trim();
    return RegExp(r'^[A-Za-z0-9_]{2,64}$').hasMatch(signId) ? signId : null;
  }

  static String? normalizePartnerCode(Object? value) {
    if (value is! String) return null;
    final code = value.trim().toUpperCase();
    return RegExp(r'^P-[0-9]{5}$').hasMatch(code) ? code : null;
  }

  static String url(Object key) {
    final parsed = key is PopkonChannelKey ? key : parseKey(key);
    if (parsed == null) throw const FormatException('Invalid PopkonTV channel key');
    return Uri.https('www.popkontv.com', '/live/view', {
      'castId': parsed.signId,
      'partnerCode': parsed.partnerCode ?? 'P-00001',
    }).toString();
  }
}
