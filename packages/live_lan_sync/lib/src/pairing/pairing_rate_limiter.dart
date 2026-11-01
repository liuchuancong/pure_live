import 'package:live_lan_sync/src/config/config.dart' show LanSyncSecurityConfig;

/// Sliding-window rate limiting for pairing attempts, per device.
///
/// After [LanSyncSecurityConfig.maxPairingAttempts] recorded failures
/// inside [LanSyncSecurityConfig.rateLimitWindow], the device is locked out
/// until the window slides past its oldest failure (spec §9.3, §20).
final class PairingRateLimiter {
  /// A limiter over the given security parameters.
  new({required this.maxAttempts, required this.window, DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// The failures allowed per device inside [window].
  final int maxAttempts;

  /// The sliding window the limit applies over.
  final Duration window;

  final DateTime Function() _now;
  final Map<String, List<DateTime>> _failures = <String, List<DateTime>>{};

  /// Whether [deviceId] may attempt pairing right now.
  bool allows(String deviceId) => remainingAttempts(deviceId) > 0;

  /// How many attempts [deviceId] has left in the current window.
  int remainingAttempts(String deviceId) {
    final windowStart = _now().subtract(window);
    final live = _liveFailures(deviceId, windowStart);
    return maxAttempts - live.length;
  }

  /// Records a failed pairing attempt for [deviceId].
  void recordFailure(String deviceId) {
    final windowStart = _now().subtract(window);
    final live = _liveFailures(deviceId, windowStart)..add(_now());
    _failures[deviceId] = live;
  }

  /// Clears [deviceId]'s record, called after a successful pairing.
  void reset(String deviceId) => _failures.remove(deviceId);

  List<DateTime> _liveFailures(String deviceId, DateTime windowStart) {
    final recorded = _failures[deviceId] ?? <DateTime>[];
    final live = recorded.where((at) => at.isAfter(windowStart)).toList();
    if (live.isEmpty) {
      _failures.remove(deviceId);
    } else {
      _failures[deviceId] = live;
    }
    return live;
  }
}
