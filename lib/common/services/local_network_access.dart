import 'dart:developer';
import 'dart:io';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/proxy_routing.dart' as proxy_routing;

/// Android 17 (API 37) blocks sockets to local-network addresses unless the
/// app holds ACCESS_LOCAL_NETWORK. A proxy on the PC or router is exactly such
/// an address, so every proxied request failed until this was granted.
class LocalNetworkAccess {
  LocalNetworkAccess._();

  static bool _requestedThisSession = false;

  /// Requests the permission once per session when an enabled proxy points at
  /// the local network; older Android versions report it as granted.
  static Future<void> ensureForProxies(Iterable<({bool enabled, String host})> proxies) async {
    if (!Platform.isAndroid) return;
    final needsLan = proxies.any((p) => p.enabled && proxy_routing.isLocalNetworkProxyHost(p.host));
    if (!needsLan) return;
    try {
      final status = await Permission.accessLocalNetwork.status;
      if (status.isGranted || status.isLimited) return;
      if (_requestedThisSession && !status.isDenied) return;
      _requestedThisSession = true;
      final result = await Permission.accessLocalNetwork.request();
      if (!result.isGranted && !result.isLimited) {
        ToastUtil.show(i18n('local_network_permission_denied'));
      }
    } catch (error) {
      log('Local network permission request failed: $error');
    }
  }
}
