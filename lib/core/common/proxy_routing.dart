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
  if (!enabled || normalizedHost.isEmpty || port < 1 || port > 65535) {
    return 'DIRECT';
  }

  final endpointHost = normalizedHost.contains(':') && !normalizedHost.startsWith('[') && !normalizedHost.endsWith(']')
      ? '[$normalizedHost]'
      : normalizedHost;
  return 'PROXY $endpointHost:$port';
}
