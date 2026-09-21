import 'zhanqi_api.dart';

final class ZhanqiLink {
  const ZhanqiLink._();

  static const _hosts = {'zhanqi.tv', 'www.zhanqi.tv', 'm.zhanqi.tv'};

  static String? parse(String raw) {
    if (raw.length > 8192 || RegExp(r'[\x00-\x20\x7f]').hasMatch(raw)) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) ||
        !_hosts.contains(uri.host.toLowerCase())) {
      return null;
    }
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
    if (segments.length != 1) return null;
    return normalizeCode(segments.single);
  }

  static String? parseOrCode(String raw) => parse(raw.trim()) ?? normalizeCode(raw.trim());

  static String? normalizeCode(String value) => RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(value) ? value : null;

  static String url(String code) {
    final value = normalizeCode(code);
    if (value == null) throw const ZhanqiException(ZhanqiFailure.identity);
    return 'https://www.zhanqi.tv/$value';
  }
}
