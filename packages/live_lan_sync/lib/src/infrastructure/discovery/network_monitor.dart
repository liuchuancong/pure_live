import 'dart:async' show StreamController, Timer, unawaited;
import 'dart:io' show NetworkInterface;

/// Watches the machine's network interfaces and reports changes.
///
/// mDNS binds are interface-scoped: after a Wi-Fi switch, a dock event or a
/// VPN toggle the old browser keeps listening on a dead interface and the
/// device silently vanishes from the LAN (spec §8.3, §19). The monitor
/// polls the interface list — cheap, dependency-free, and works on every
/// desktop and mobile platform — and emits whenever the effective address
/// set changes. Polling is injectable for tests.
final class NetworkMonitor {
  /// A monitor polling every [pollInterval].
  ///
  /// [addressProvider] defaults to the real interface list; tests inject a
  /// fake. A null [pollInterval] disables the timer so the host can drive
  /// [checkNow] itself.
  new({this.pollInterval = const Duration(seconds: 15), Future<Set<String>> Function()? addressProvider})
    : _addressProvider = addressProvider ?? _listInterfaceAddresses {
    if (pollInterval != null) {
      _timer = Timer.periodic(pollInterval!, (_) => unawaited(checkNow()));
    }
  }

  /// How often the interface list is polled; null disables the timer.
  final Duration? pollInterval;

  final Future<Set<String>> Function() _addressProvider;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Set<String> _lastAddresses = <String>{};
  Timer? _timer;
  bool _running = false;

  /// Fires whenever the effective address set changed.
  Stream<void> get changes => _changes.stream;

  /// Starts polling. Repeated calls are harmless.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    await checkNow();
  }

  /// Stops polling and forgets the last snapshot, so a later [start]
  /// re-emits the current state as a baseline.
  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _lastAddresses = <String>{};
  }

  /// Polls once and emits when the address set differs from the last poll.
  Future<void> checkNow() async {
    try {
      final addresses = await _addressProvider();
      final changed = _running && _lastAddresses.isNotEmpty && !_setEquals(addresses, _lastAddresses);
      _lastAddresses = addresses;
      if (changed && !_changes.isClosed) {
        _changes.add(null);
      }
    } on Object {
      // A transient interface-list failure must not kill the monitor; the
      // next poll retries.
    }
  }

  /// Releases the timer and closes the stream.
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    _running = false;
    await _changes.close();
  }

  static Future<Set<String>> _listInterfaceAddresses() async {
    final interfaces = await NetworkInterface.list();
    return {for (final interface in interfaces) ...interface.addresses.map((a) => a.address)};
  }

  static bool _setEquals(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);
}
