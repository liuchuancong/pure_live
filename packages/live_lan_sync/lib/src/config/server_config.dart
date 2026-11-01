/// How this device serves peers on the LAN.
///
/// The defaults only listen where a LAN peer can reach them; a host that
/// needs something narrower narrows it here rather than in the engine.
final class LanSyncServerConfig {
  /// The serving defaults.
  const new({
    this.enabled = true,
    this.port = 0,
    this.maxConnections = 8,
    this.requestTimeout = const Duration(seconds: 30),
    this.maxRequestBodyBytes = 8 * 1024 * 1024,
    this.maxWebSocketMessageBytes = 1024 * 1024,
    this.pairedDevicesOnly = true,
    this.listenOnAllInterfaces = true,
  });

  /// Whether this device runs a local server other devices can connect to.
  final bool enabled;

  /// The TCP port to listen on; `0` lets the system pick a free port, which
  /// the discovery record then advertises.
  final int port;

  /// The most simultaneous peer connections the server accepts.
  final int maxConnections;

  /// How long a single control request may take before it is abandoned.
  final Duration requestTimeout;

  /// The largest accepted request body, JSON batches included.
  final int maxRequestBodyBytes;

  /// The largest accepted WebSocket frame.
  final int maxWebSocketMessageBytes;

  /// Whether unpaired devices are refused at the door.
  final bool pairedDevicesOnly;

  /// Whether the server listens on every LAN interface (`false` keeps it to
  /// loopback, for hosts that only ever sync on one machine's windows).
  final bool listenOnAllInterfaces;

  /// Returns the human-readable problems with this configuration, or an
  /// empty list when it is usable as is.
  List<String> validate() {
    final problems = <String>[];
    if (port < 0 || port > 65535) {
      problems.add('server.port must be 0 (system-picked) or 1..65535');
    }
    if (maxConnections < 1) {
      problems.add('server.maxConnections must be at least 1');
    }
    if (requestTimeout <= Duration.zero) {
      problems.add('server.requestTimeout must be positive');
    }
    if (maxRequestBodyBytes < 64 * 1024) {
      problems.add('server.maxRequestBodyBytes must allow at least 64 KiB');
    }
    if (maxWebSocketMessageBytes < 16 * 1024) {
      problems.add('server.maxWebSocketMessageBytes must allow at least 16 KiB');
    }
    return problems;
  }
}
