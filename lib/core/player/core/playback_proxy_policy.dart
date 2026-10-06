import 'package:pure_live/core/config/settings_service.dart';
import 'package:pure_live/core/network/proxy_routing.dart';
import 'package:pure_live/core/platform/windows_system_proxy.dart';

/// 代理出口后面会拒绝吐流、而直连可达的媒体主机后缀。
///
/// Steam 广播 CDN（`*.steamcontent.com`）按请求 IP 做缓存会话亲和：代理出口拉
/// master/变体清单都是 200，分片却答 410 Gone；直连同一分片 200。Steam 的 CDN
/// 本身直连可达，所以这条线路不该进代理。
const List<String> proxyDirectHostSuffixes = ['steamcontent.com'];

/// [uri] 的主机是否命中 [proxyDirectHostSuffixes]。
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
      // 没有单独配置播放器代理时跟随 Windows 系统代理：Clash 这类工具打开的就是
      // 系统代理，用户不会想到还要在应用里再配一遍；而"能列出房间却播不动"的
      // 症状和平台挂了从外面看一模一样。
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
