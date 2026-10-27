import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_device/live_device.dart' show SystemProxyEndpoint;
import 'package:live_net/live_net.dart';
import 'package:live_storage/live_storage.dart';

import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/app/providers/network/system_proxy_provider.dart' show systemProxyProvider;

/// How the app reaches the network.
///
/// [system] exists because the ordinary desktop setup is a proxy client whose
/// address the operating system knows and nobody typed anywhere: the reading
/// comes from the platform instead of the keyboard (see [systemProxyProvider]).
enum ProxyMode {
  /// Direct, no proxy.
  off,

  /// Whatever HTTP proxy the operating system itself is configured to use.
  system,

  /// The host and port on the network page.
  manual,
}

/// The app-wide proxy: the mode in force and, for [ProxyMode.manual], the
/// endpoint every module's transport routes through (the reference's network
/// settings, applied at the shared factory so a change reaches every client's
/// next request without restarting).
typedef ProxySettings = ({ProxyMode mode, String host, int port});

/// The reference's default app-proxy port.
const int kDefaultAppProxyPort = 7897;

const ProxySettings _defaults = (mode: ProxyMode.off, host: '', port: kDefaultAppProxyPort);

/// The stored form of [mode]: the enum's own name, so a value written by a
/// newer build reads as unknown rather than as a different mode.
String proxyModeKey(ProxyMode mode) => mode.name;

/// The stored mode, or null for anything this build does not know.
ProxyMode? parseProxyMode(String? raw) => switch (raw) {
  'off' => ProxyMode.off,
  'system' => ProxyMode.system,
  'manual' => ProxyMode.manual,
  _ => null,
};

/// The route [settings] resolves to, given the platform's own reading.
///
/// A mode that cannot be honoured goes direct rather than guessed at: a system
/// proxy that turns out to be a PAC script, or a manual mode with nothing
/// typed, is still a request path the app can complete.
({String host, int port})? appProxyEndpoint(ProxySettings settings, SystemProxyEndpoint system) =>
    switch (settings.mode) {
      ProxyMode.off => null,
      ProxyMode.manual => settings.host.isEmpty ? null : (host: settings.host, port: settings.port),
      ProxyMode.system => system.isUsable ? (host: system.host, port: system.port) : null,
    };

/// The transport route for [settings], which is [appProxyEndpoint] in the form
/// the shared factory's policy hands to Dio.
ProxyRoute appProxyRoute(ProxySettings settings, SystemProxyEndpoint system) {
  final endpoint = appProxyEndpoint(settings, system);
  return endpoint == null ? const DirectRoute() : HttpProxyRoute(host: endpoint.host, port: endpoint.port);
}

/// Repairs a typed or restored app-proxy host the way the reference's
/// `normalizeProxyHost` does: a Chinese keyboard's full-width dot, colon and
/// brackets would otherwise resolve as one DNS name, and whitespace inside
/// the endpoint is never meaningful.
String normalizeAppProxyHost(String value) => value
    .trim()
    .replaceAll('。', '.')
    .replaceAll('．', '.')
    .replaceAll('：', ':')
    .replaceAll('［', '[')
    .replaceAll('］', ']')
    .replaceAll(RegExp(r'\s+'), '');

/// Repairs a persisted or imported app-proxy port; an invalid value falls
/// back to the reference's 7897 instead of leaving every request routed to a
/// meaningless endpoint.
int normalizeAppProxyPort(int? port) => port != null && port >= 1 && port <= 65535 ? port : kDefaultAppProxyPort;

/// Owns the proxy choice, persisted under `proxy.*`.
final class ProxySettingsController extends Notifier<ProxySettings> {
  @override
  ProxySettings build() {
    try {
      final stored = parseProxyMode(StoragePrefs.getString('proxy.mode'));
      // A store this build has never written: the builds before the modes kept
      // a single boolean, and its "on" could only ever have meant the typed
      // endpoint beside it.
      final legacyOn = StoragePrefs.getBool('proxy.enabled') ?? false;
      return (
        mode: stored ?? (legacyOn ? ProxyMode.manual : ProxyMode.off),
        host: normalizeAppProxyHost(StoragePrefs.getString('proxy.host') ?? _defaults.host),
        port: normalizeAppProxyPort(StoragePrefs.getInt('proxy.port') ?? _defaults.port),
      );
    } on Object {
      return _defaults;
    }
  }

  /// Moves to another mode, writing through.
  Future<void> setMode(ProxyMode mode) => _write((mode: mode, host: state.host, port: state.port));

  /// Moves the host, writing through.
  Future<void> setHost(String host) => _write((mode: state.mode, host: normalizeAppProxyHost(host), port: state.port));

  /// Moves the port, writing through.
  Future<void> setPort(int port) => _write((mode: state.mode, host: state.host, port: normalizeAppProxyPort(port)));

  /// The route the shared factory's policy hands out: consulted per request,
  /// so a system reading that lands late is used by the next one.
  ProxyRoute get route => appProxyRoute(state, ref.read(systemProxyProvider));

  Future<void> _write(ProxySettings next) async {
    state = next;
    try {
      await StoragePrefs.setString('proxy.mode', proxyModeKey(next.mode));
      await StoragePrefs.setString('proxy.host', next.host);
      await StoragePrefs.setInt('proxy.port', next.port);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }
}

/// The route the app's requests take right now: the setting and the system
/// reading, composed.
///
/// Anything that cannot consult the controller reads this instead — the
/// process-wide HTTP override, for one, which is asked while a connection is
/// being opened.
final appProxyRouteProvider = Provider<ProxyRoute>((ref) {
  return appProxyRoute(ref.watch(proxySettingsProvider), ref.watch(systemProxyProvider));
});

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
