typedef UpstreamProxyDirectiveProvider = String Function(Uri uri);

UpstreamProxyDirectiveProvider? _provider;

/// Installs the live app settings without coupling relay IO to Get/Hive.
/// Only upstream requests use this callback; FFmpeg's loopback stays direct.
void configureUpstreamProxyRouting(UpstreamProxyDirectiveProvider? provider) {
  _provider = provider;
}

String resolveUpstreamProxyDirective(Uri uri) => _provider?.call(uri) ?? 'DIRECT';
