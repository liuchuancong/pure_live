import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart';
import 'package:live_storage/live_storage.dart';

import 'package:pure_live/app/logging/app_log.dart' show appLog;

/// The app-wide proxy: off, or an HTTP CONNECT proxy that every module's
/// transport routes through (the reference's network settings, applied at
/// the shared factory so a change reaches every client's next request
/// without restarting).
typedef ProxySettings = ({bool enabled, String host, int port});

const ProxySettings _defaults = (enabled: false, host: '127.0.0.1', port: 7897);

/// Owns the proxy choice, persisted under `proxy.*`.
final class ProxySettingsController extends Notifier<ProxySettings> {
  @override
  ProxySettings build() {
    try {
      return (
        enabled: StoragePrefs.getBool('proxy.enabled') ?? _defaults.enabled,
        host: StoragePrefs.getString('proxy.host') ?? _defaults.host,
        port: StoragePrefs.getInt('proxy.port') ?? _defaults.port,
      );
    } on Object {
      return _defaults;
    }
  }

  /// Flips the proxy, writing through.
  Future<void> setEnabled({required bool value}) => _write((enabled: value, host: state.host, port: state.port));

  /// Moves the host, writing through.
  Future<void> setHost(String host) => _write((enabled: state.enabled, host: host.trim(), port: state.port));

  /// Moves the port, writing through.
  Future<void> setPort(int port) => _write((enabled: state.enabled, host: state.host, port: port));

  /// The route the shared factory's policy hands out: the configured proxy
  /// when enabled, direct otherwise.
  ProxyRoute get route => state.enabled ? HttpProxyRoute(host: state.host, port: state.port) : const DirectRoute();

  Future<void> _write(ProxySettings next) async {
    state = next;
    try {
      await StoragePrefs.setBool('proxy.enabled', next.enabled);
      await StoragePrefs.setString('proxy.host', next.host);
      await StoragePrefs.setInt('proxy.port', next.port);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }
}

/// The proxy choice.
final proxySettingsProvider = NotifierProvider<ProxySettingsController, ProxySettings>(ProxySettingsController.new);

/// The policy the shared transport factory carries: it asks the controller
/// on every request, so a change in the settings surface reaches the next
/// request without rebuilding a single client.
final class _SettingsProxyPolicy implements ProxyPolicy {
  const _SettingsProxyPolicy(this._route);

  final ProxyRoute Function() _route;

  @override
  ProxyRoute? routeFor(Uri url, {String? site}) => _route();
}

/// The app's shared transport factory: one place wires the proxy policy,
/// so the player-adjacent modules (vod, iptv, backups) all honour the
/// same network settings.
final networkFactoryProvider = Provider<DioFactory>((ref) {
  return DioFactory(
    log: appLog.forCategory('network'),
    proxyPolicy: _SettingsProxyPolicy(() => ref.read(proxySettingsProvider.notifier).route),
  );
});
