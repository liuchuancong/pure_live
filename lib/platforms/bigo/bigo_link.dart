import 'bigo_api.dart';

final class BigoLink {
  const BigoLink._();

  static const _reserved = {'about', 'download', 'index', 'live', 'login', 'search', 'signup'};

  static String? parse(String raw) {
    if (raw.length > 8192 || RegExp(r'[\x00-\x20\x7f]').hasMatch(raw)) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
      return null;
    }
    final host = uri.host.toLowerCase();
    if (host != 'bigo.tv' && host != 'www.bigo.tv') return null;
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
    final candidate = switch (segments) {
      [final id] => id,
      [final locale, final id] when RegExp(r'^[a-zA-Z]{2}$').hasMatch(locale) => id,
      _ => null,
    };
    if (candidate == null || _reserved.contains(candidate.toLowerCase())) return null;
    try {
      return BigoApi.validateSiteId(candidate);
    } on BigoException {
      return null;
    }
  }

  static String? parseOrSiteId(String raw) {
    final value = raw.trim();
    final parsed = parse(value);
    if (parsed != null) return parsed;
    try {
      return BigoApi.validateSiteId(value);
    } on BigoException {
      return null;
    }
  }

  static String url(String siteId) => 'https://www.bigo.tv/${BigoApi.validateSiteId(siteId)}';
}
