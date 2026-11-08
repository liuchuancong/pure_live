import 'dart:async' show Timer, unawaited;
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_device/live_device.dart' show SystemProxyEndpoint;
import 'package:live_net/live_net.dart';
import 'package:live_storage/live_storage.dart';

import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/app/providers/network/system_proxy_provider.dart' show systemProxyProvider;

// The vault's own store lives with the plugin that implements it.
import 'package:pure_live/features/backup/webdav/webdav_settings.dart' show appSecretStoreProvider;

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
typedef ProxySettings = ({
  ProxyMode mode,
  String host,
  int port,
  // The endpoint's credential, read from the device vault on the controller's
  // first build. Not a preference: a password does not belong in the settings
  // store that a backup writes out as plain JSON.
  String username,
  String password,
});

/// The reference's default app-proxy port.
const int kDefaultAppProxyPort = 7897;

const ProxySettings _defaults = (mode: ProxyMode.off, host: '', port: kDefaultAppProxyPort, username: '', password: '');

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
({String host, int port})? appProxyEndpoint(ProxySettings settings, SystemProxyEndpoint system) {
  final route = appProxyRoute(settings, system);
  return route is HttpProxyRoute ? (host: route.host, port: route.port) : null;
}

/// The route [settings] resolves to, credential included.
///
/// This is the one answer every consumer gets its proxy from — Dio's transport,
/// the process-wide HTTP override, the player option and the recorder's FFmpeg
/// arguments — because a credential only means something when all four carry it
/// rather than some of them.
ProxyRoute appProxyRoute(ProxySettings settings, SystemProxyEndpoint system) => switch (settings.mode) {
  ProxyMode.off => const DirectRoute(),
  // A typed endpoint with nothing in it is still the direct connection the app
  // had before this row was filled.
  ProxyMode.manual =>
    settings.host.isEmpty
        ? const DirectRoute()
        : HttpProxyRoute(
            host: settings.host,
            port: settings.port,
            username: settings.username.trim(),
            password: settings.password,
          ),
  ProxyMode.system => system.isUsable ? HttpProxyRoute(host: system.host, port: system.port) : const DirectRoute(),
};

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

/// The device vault every app secret is read through — a WebDAV account's
/// password, an account cookie, the app proxy's credential. The store itself is
/// built once, in `webdav_settings.dart`, which is where the plugin lives; this
/// is the name the rest of the app reaches it by.
///
/// A vault that never opens — an unsupported platform, a locked keychain — reads
/// as null, and every caller treats that as "no secret stored here" rather than
/// hanging on a future that never lands.
final secretVaultProvider = FutureProvider<SecretStore?>((ref) async {
  try {
    return await ref.watch(appSecretStoreProvider.future);
  } on Object {
    return null;
  }
});

/// The vault reference the app-proxy password is kept under.
const String kAppProxySecretRef = 'proxy.password';

/// Owns the proxy choice: the endpoint and its mode in the preferences, its
/// password in the device vault.
final class ProxySettingsController extends Notifier<ProxySettings> {
  @override
  ProxySettings build() {
    try {
      final stored = parseProxyMode(StoragePrefs.getString('proxy.mode'));
      // A store this build has never written: the builds before the modes kept
      // a single boolean, and its "on" could only ever have meant the typed
      // endpoint beside it.
      final legacyOn = StoragePrefs.getBool('proxy.enabled') ?? false;
      final username = (StoragePrefs.getString('proxy.username') ?? '').trim();
      // The vault opens on its own clock, so the first answer is the endpoint
      // with the password missing rather than a loading state: a route built
      // from it still works for an unauthenticated proxy, and the next read
      // sees the credential.
      unawaited(_readStoredPassword());
      ref.onDispose(() {
        final pending = _passwordWrite;
        _passwordWrite = null;
        if (pending == null || !pending.isActive) return;
        pending.cancel();
        unawaited(_commitPassword());
      });
      return (
        mode: stored ?? (legacyOn ? ProxyMode.manual : ProxyMode.off),
        host: normalizeAppProxyHost(StoragePrefs.getString('proxy.host') ?? _defaults.host),
        port: normalizeAppProxyPort(StoragePrefs.getInt('proxy.port') ?? _defaults.port),
        username: username,
        password: _password ?? '',
      );
    } on Object {
      return _defaults;
    }
  }

  String? _password;

  Future<void> _readStoredPassword() async {
    final vault = await ref.read(secretVaultProvider.future);
    final value = vault?.value(kAppProxySecretRef) ?? '';
    _password = value;
    // The vault opens on its own clock. Rebuilding is the quiet way to put the
    // credential into every route taken after it lands — and it settles at once,
    // because the second read of a resolved future matches and stops.
    if (state.password != value) ref.invalidateSelf();
  }

  /// Moves to another mode, writing through.
  Future<void> setMode(ProxyMode mode) => _write(copyProxySettings(state, mode: mode));

  /// Moves the host, writing through.
  Future<void> setHost(String host) => _write(copyProxySettings(state, host: normalizeAppProxyHost(host)));

  /// Moves the port, writing through.
  Future<void> setPort(int port) => _write(copyProxySettings(state, port: normalizeAppProxyPort(port)));

  /// Moves the proxy's username. The password rides beside it, so changing the
  /// name without a password leaves an endpoint nothing to present.
  Future<void> setUsername(String username) {
    final value = username.trim();
    return _write(copyProxySettings(state, username: value));
  }

  /// Stores the proxy's password in the vault; an empty one removes it.
  ///
  /// The field reports every keystroke, and a keychain write per character
  /// (Android's Keystore, Windows DPAPI) is slow and pointless. The state takes
  /// the value at once, so the row stays truthful while typing; the preference
  /// and the vault are written once the typing pauses. A dispose flushes what is
  /// still pending, so leaving the page mid-word does not lose the secret.
  Future<void> setPassword(String password) async {
    _password = password;
    state = copyProxySettings(state, password: password);
    _passwordWrite?.cancel();
    _passwordWrite = Timer(const Duration(milliseconds: 500), () => unawaited(_commitPassword()));
  }

  Timer? _passwordWrite;

  Future<void> _commitPassword() async {
    final password = _password ?? '';
    await _write(copyProxySettings(state, password: password));
    try {
      final vault = await ref.read(secretVaultProvider.future);
      if (vault == null) return;
      if (password.isEmpty) {
        await vault.remove(kAppProxySecretRef);
      } else {
        await vault.set(kAppProxySecretRef, password);
      }
    } on Object catch (error) {
      // A locked keychain loses the secret; the endpoint still routes, only
      // without a credential, and the row says so when it is read back empty.
      appLog
          .forCategory('network.proxy')
          .warning('proxy credential write failed; requests will 407', fields: {'error': '$error'});
    }
  }

  /// The route the shared factory's policy hands out: consulted per request,
  /// so a system reading that lands late is used by the next one.
  ProxyRoute get route => appProxyRoute(state, ref.read(systemProxyProvider));

  Future<void> _write(ProxySettings next) async {
    state = next;
    try {
      await StoragePrefs.setString('proxy.mode', proxyModeKey(next.mode));
      await StoragePrefs.setString('proxy.host', next.host);
      await StoragePrefs.setInt('proxy.port', next.port);
      await StoragePrefs.setString('proxy.username', next.username);
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

/// A [ProxySettings] record with the named parts replaced.
///
/// A record type has no `copyWith`, and spelling all five fields out in every
/// setter is how a renamed field gets missed; this is the one place the shape is
/// written out, and the one place the record type is named.
ProxySettings copyProxySettings(
  ProxySettings settings, {
  ProxyMode? mode,
  String? host,
  int? port,
  String? username,
  String? password,
}) => (
  mode: mode ?? settings.mode,
  host: host ?? settings.host,
  port: port ?? settings.port,
  username: username ?? settings.username,
  password: password ?? settings.password,
);

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

/// The platforms whose Cloudflare-blocked API this host can reach through a
/// native TLS channel: Windows now has one (WinHTTP/Schannel), the other
/// hosts have none yet, so their lists leave Kick out.
final nativeTlsPlatformsProvider = Provider<Set<String>>((ref) {
  return Platform.isWindows ? const {'kick'} : const <String>{};
});

/// The app's shared transport factory: one place wires the proxy policy,
/// so the player-adjacent modules (vod, iptv, backups) all honour the
/// same network settings.
final networkFactoryProvider = Provider<DioFactory>((ref) {
  return DioFactory(
    log: appLog.forCategory('network'),
    proxyPolicy: _SettingsProxyPolicy(() => ref.read(proxySettingsProvider.notifier).route),
  );
});
