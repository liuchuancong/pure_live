const int defaultProxyPort = 7897;
const int minProxyPort = 1;
const int maxProxyPort = 65535;

bool isValidProxyPort(int port) => port >= minProxyPort && port <= maxProxyPort;

/// Repairs a persisted or imported port instead of passing an invalid socket
/// endpoint into every application, player and recorder proxy consumer.
int normalizeStoredProxyPort(int port) => isValidProxyPort(port) ? port : defaultProxyPort;

/// Normalizes a proxy host entered with desktop or mobile input methods.
///
/// Chinese keyboards commonly turn an ASCII dot into `。` or `．`. Passing
/// that value to `HttpClient.findProxy` makes Android try to resolve the whole
/// string as a DNS name, so an otherwise valid `127.0.0.1` proxy silently
/// breaks every request.
String normalizeProxyHost(String value) {
  return value
      .trim()
      .replaceAll('。', '.')
      .replaceAll('．', '.')
      .replaceAll('：', ':')
      .replaceAll('［', '[')
      .replaceAll('］', ']')
      .replaceAll(RegExp(r'\s+'), '');
}

/// Returns a usable TCP port while an auto-saved settings field is edited.
///
/// An empty, partial or out-of-range value stays in the text field for the
/// user to finish, but must not replace the last working proxy endpoint.
int? parseProxyPortInput(String value) {
  final port = int.tryParse(value.trim());
  if (port == null || !isValidProxyPort(port)) return null;
  return port;
}

/// Builds the directive accepted by `dart:io`'s `HttpClient.findProxy`.
///
/// Invalid or incomplete values deliberately remain direct. This keeps a
/// half-edited settings field from turning all application requests into an
/// invalid proxy lookup.
String buildProxyDirective({required bool enabled, required String host, required int port}) {
  if (host.contains(';') || host.contains('\r') || host.contains('\n')) {
    return 'DIRECT';
  }
  final normalizedHost = normalizeProxyHost(host);
  if (!enabled || normalizedHost.isEmpty || !isValidProxyPort(port)) {
    return 'DIRECT';
  }

  final endpointHost = normalizedHost.contains(':') && !normalizedHost.startsWith('[') && !normalizedHost.endsWith(']')
      ? '[$normalizedHost]'
      : normalizedHost;
  return 'PROXY $endpointHost:$port';
}

/// Whether a proxy host is on the local network (a Clash instance on the PC,
/// a soft router), which Android 17 gates behind ACCESS_LOCAL_NETWORK for apps
/// targeting API 37. Loopback is the device itself and is not gated.
bool isLocalNetworkProxyHost(String value) {
  var host = normalizeProxyHost(value).toLowerCase();
  if (host.startsWith('[') && host.endsWith(']')) host = host.substring(1, host.length - 1);
  if (host.isEmpty) return false;
  if (host.endsWith('.local') || host.endsWith('.lan') || host.endsWith('.home.arpa')) return true;
  final v4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$').firstMatch(host);
  if (v4 != null) {
    final a = int.parse(v4.group(1)!);
    final b = int.parse(v4.group(2)!);
    if (a > 255 || b > 255) return false;
    return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168) || (a == 169 && b == 254);
  }
  if (host.contains(':')) {
    // IPv6 unique-local (fc00::/7) and link-local (fe80::/10).
    return RegExp(r'^f[cd][0-9a-f]{0,2}:').hasMatch(host) || RegExp(r'^fe[89ab][0-9a-f]?:').hasMatch(host);
  }
  return false;
}
