typedef RecorderProxyDirectiveProvider = String Function(Uri uri);

RecorderProxyDirectiveProvider? _provider;

/// Installs the live app settings without coupling relay IO to Get/Hive.
/// Only upstream requests use this callback; FFmpeg's loopback stays direct.
void configureRecorderProxyRouting(RecorderProxyDirectiveProvider? provider) {
  _provider = provider;
}

String resolveRecorderProxyDirective(Uri uri) => _provider?.call(uri) ?? 'DIRECT';
