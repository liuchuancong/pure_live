import 'dart:io' show Platform, Process;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:live_device/src/network/system_proxy/system_proxy.dart';

/// Reads the operating system's own proxy configuration.
///
/// Windows asks the per-user Internet Settings key the way `reg.exe` prints it,
/// macOS asks `scutil --proxy`, and everything else (Linux, and the two mobile
/// platforms whose proxy lives in a settings API this package does not reach)
/// falls back to the environment variables the Dart stack itself would honour.
/// Both external commands are bounded by a timeout and every failure path
/// returns a [SystemProxyStatus] rather than throwing: a reading that cannot be
/// taken must not take the request path down with it.
final class PlatformSystemProxyService implements SystemProxyService {
  /// Creates a service that asks the running operating system.
  const new();

  /// How long a platform helper may take before the reading gives up.
  ///
  /// A registry query is a millisecond; the bound exists because a blocked
  /// process — a group policy prompt, an unresponsive shell — would otherwise
  /// stall the first request that asked for the proxy.
  static const Duration _probeTimeout = Duration(seconds: 3);

  @override
  Future<SystemProxyCapabilities> getCapabilities() async {
    if (kIsWeb) {
      return const SystemProxyCapabilities(canReadSystemProxy: false, platformName: 'web');
    }
    final platform = Platform.operatingSystem;
    final supported = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    return SystemProxyCapabilities(canReadSystemProxy: supported, platformName: platform);
  }

  @override
  Future<SystemProxyEndpoint> read() async {
    if (kIsWeb) {
      return const SystemProxyEndpoint(status: SystemProxyStatus.unsupported, detail: 'web');
    }
    try {
      if (Platform.isWindows) return await _readWindows();
      if (Platform.isMacOS) return await _readMacOS();
      if (Platform.isLinux) return _fromEnvironment();
      // Android and iOS keep the proxy in a system setting behind a platform
      // channel this package does not own; their environment is empty, so an
      // "unsupported" answer is the honest one rather than a false "none".
      return SystemProxyEndpoint(status: SystemProxyStatus.unsupported, detail: Platform.operatingSystem);
    } on Object catch (error) {
      return SystemProxyEndpoint(status: SystemProxyStatus.failed, detail: '$error');
    }
  }

  /// The per-user Internet Settings the Windows proxy UI writes.
  ///
  /// `ProxyEnable` is what the toggle sets, so a stale `ProxyServer` left by an
  /// earlier configuration stays a non-answer. `AutoConfigURL` alone is a PAC
  /// script — the proxy is picked per URL by a script this app cannot run — and
  /// a `socks=` entry in a scheme list is an endpoint mpv and ffmpeg both
  /// refuse, so neither becomes a silent direct route.
  Future<SystemProxyEndpoint> _readWindows() async {
    const key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
    final result = await Process.run('reg.exe', ['query', key])
        .timeout(_probeTimeout);
    if (result.exitCode != 0) {
      // A machine with no per-user Internet Settings writes at all: that is no
      // proxy, not a failed probe.
      return SystemProxyEndpoint.notConfigured;
    }
    final values = _parseRegistry('${result.stdout}');
    if (values['ProxyEnable'] != '0x1') {
      final pac = values['AutoConfigURL'];
      if (pac != null && pac.isNotEmpty) {
        return SystemProxyEndpoint(status: SystemProxyStatus.notExpressible, detail: 'pac: $pac');
      }
      return SystemProxyEndpoint.notConfigured;
    }
    final server = values['ProxyServer'];
    if (server == null || server.isEmpty) {
      return const SystemProxyEndpoint(status: SystemProxyStatus.notConfigured, detail: 'ProxyServer missing');
    }
    return _fromProxyServer(server);
  }

  /// macOS' SystemConfiguration answer, through the CLI that prints it.
  ///
  /// HTTPS is preferred over HTTP because the streams this app opens are
  /// almost always https, and `scutil` reports the two independently.
  Future<SystemProxyEndpoint> _readMacOS() async {
    final result = await Process.run('scutil', ['--proxy']).timeout(_probeTimeout);
    if (result.exitCode != 0) {
      return SystemProxyEndpoint(status: SystemProxyStatus.failed, detail: 'scutil exit ${result.exitCode}');
    }
    final values = _parseScutil('${result.stdout}');
    bool on(String key) => values[key] == '1';
    if (on('HTTPSEnable')) {
      final host = values['HTTPSProxy'] ?? '';
      if (host.isEmpty) {
        // Enabled with no host is macOS' shape for "a script decides": PAC.
        return const SystemProxyEndpoint(
          status: SystemProxyStatus.notExpressible,
          detail: 'HTTPS enabled without a host',
        );
      }
      return _endpoint(host, values['HTTPSPort']);
    }
    if (on('HTTPEnable')) {
      return _endpoint(values['HTTPProxy'] ?? '', values['HTTPPort']);
    }
    if (on('ProxyAutoConfigEnable')) {
      return SystemProxyEndpoint(
        status: SystemProxyStatus.notExpressible,
        detail: 'pac: ${values['ProxyAutoConfigURLString'] ?? ''}',
      );
    }
    if (on('SOCKSEnable')) {
      return const SystemProxyEndpoint(status: SystemProxyStatus.notExpressible, detail: 'socks');
    }
    return SystemProxyEndpoint.notConfigured;
  }

  /// The environment the Dart HTTP stack itself would follow.
  ///
  /// Kept to the two variables with an HTTP meaning; `ALL_PROXY` is usually
  /// SOCKS and neither consumer can use it.
  SystemProxyEndpoint _fromEnvironment() {
    final environment = Platform.environment;
    for (final name in const ['https_proxy', 'HTTPS_PROXY', 'http_proxy', 'HTTP_PROXY']) {
      final raw = environment[name]?.trim();
      if (raw == null || raw.isEmpty) continue;
      return _fromProxyServer(raw);
    }
    return SystemProxyEndpoint.notConfigured;
  }

  /// Accepts `host:port`, a scheme URL, or Windows' `http=h;https=h;socks=h` list.
  SystemProxyEndpoint _fromProxyServer(String value) {
    if (value.contains('=')) {
      final entries = value
          .split(';')
          .map((entry) => entry.split('='))
          .where((parts) => parts.length == 2 && parts[1].trim().isNotEmpty)
          .toList();
      String? pick(String scheme) {
        for (final parts in entries) {
          if (parts[0].trim().toLowerCase() == scheme) return parts[1].trim();
        }
        return null;
      }
      final chosen = pick('https') ?? pick('http');
      if (chosen != null) return _fromProxyServer(chosen);
      final socks = pick('socks') ?? pick('socks5');
      if (socks != null) {
        return const SystemProxyEndpoint(status: SystemProxyStatus.notExpressible, detail: 'socks');
      }
      return SystemProxyEndpoint(status: SystemProxyStatus.failed, detail: 'unparsed: $value');
    }
    var authority = value.trim();
    final scheme = Uri.tryParse(authority)?.scheme;
    if (scheme != null && scheme.isNotEmpty) {
      if (scheme.startsWith('socks')) {
        return SystemProxyEndpoint(status: SystemProxyStatus.notExpressible, detail: scheme);
      }
      authority = authority.substring(authority.indexOf('://') + 3);
    }
    // Credentials belong to the proxy URL, not to its address; ffmpeg takes
    // them in its own option and neither consumer can carry them here.
    if (authority.contains('@')) {
      authority = authority.substring(authority.lastIndexOf('@') + 1);
    }
    return _endpointFromAuthority(authority, value);
  }

  SystemProxyEndpoint _endpoint(String host, String? port) => _endpointFromAuthority(
    host,
    port == null ? host : '$host:$port',
  );

  /// Splits `host:port`, leaving a bracketed IPv6 literal whole.
  SystemProxyEndpoint _endpointFromAuthority(String authority, String source) {
    var host = authority.trim();
    var portText = '';
    if (host.endsWith(']')) {
      // `[::1]:8888` — the address is everything before the last colon.
      final split = host.lastIndexOf(':');
      if (split > 0) {
        portText = host.substring(split + 1);
        host = host.substring(0, split);
      }
    } else {
      final split = host.lastIndexOf(':');
      final firstColon = host.indexOf(':');
      if (split > 0 && split == firstColon) {
        portText = host.substring(split + 1);
        host = host.substring(0, split);
      }
    }
    host = host.replaceAll(RegExp(r'^\[|\]$'), '');
    final port = int.tryParse(portText.trim());
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      return SystemProxyEndpoint(status: SystemProxyStatus.failed, detail: 'unparsed: $source');
    }
    return SystemProxyEndpoint(status: SystemProxyStatus.resolved, host: host, port: port);
  }

  /// `reg query` rows: `    Name    REG_SZ    value`.
  Map<String, String> _parseRegistry(String output) {
    final values = <String, String>{};
    for (final line in output.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s{2,}'));
      if (parts.length < 3) continue;
      values[parts[0]] = parts.sublist(2).join(' ').trim();
    }
    return values;
  }

  /// `scutil --proxy` rows: `  HTTPPort : 7897`.
  Map<String, String> _parseScutil(String output) {
    final values = <String, String>{};
    for (final line in output.split('\n')) {
      final split = line.indexOf(':');
      if (split < 0) continue;
      values[line.substring(0, split).trim()] = line.substring(split + 1).trim();
    }
    return values;
  }
}
