import 'package:pure_live/core/config/settings_service.dart';
import 'package:pure_live/core/network/proxy_routing.dart';
import 'package:pure_live/core/platform/windows_system_proxy.dart';

const List<String> proxyDirectHostSuffixes = ['steamcontent.com'];

bool playsDirectBehindProxy(Uri uri) {
  final host = uri.host.toLowerCase();
  return proxyDirectHostSuffixes.any((suffix) => host == suffix || host.endsWith('.$suffix'));
}

/// Media transport settings, deliberately independent of the application/API
/// proxy used by recording's existing HTTP relay.
class PlaybackProxyPolicy {
  const PlaybackProxyPolicy._();

  static String currentDirective() {
    try {
      final proxy = SettingsService.to.proxy;
      final directive = buildProxyDirective(
        enabled: proxy.enableProxy.value,
        host: proxy.proxyHost.value,
        port: proxy.proxyPort.value,
      );
      if (directive != 'DIRECT') return directive;
      return WindowsSystemProxy.directive();
    } catch (_) {
      return 'DIRECT';
    }
  }

  static String nativeUrl(String directive, {required bool privateInput}) {
    if (privateInput || !directive.startsWith('PROXY ')) return '';
    return 'http://${directive.substring(6)}';
  }

  static String currentNativeUrl({required bool privateInput}) =>
      privateInput ? '' : nativeUrl(currentDirective(), privateInput: false);
}
