import 'package:live_lan_sync/src/transport/http_auth.dart' show LanSyncHttpAuth;

/// Per-sender replay protection: timestamps must sit inside the clock
/// tolerance and nonces must be single-use within that window (spec §14.3,
/// §20).
final class ReplayGuard {
  /// A guard with the given clock tolerance.
  new({
    this.tolerance = LanSyncHttpAuth.clockTolerance,
    this.maxTrackedNoncesPerSender = 4096,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// How old (or how far ahead) a request timestamp may be.
  final Duration tolerance;

  /// The most nonces tracked per sender before the oldest are forgotten.
  final int maxTrackedNoncesPerSender;

  final DateTime Function() _now;
  final Map<String, Map<String, DateTime>> _seen = <String, Map<String, DateTime>>{};

  /// Whether the (sender, timestamp, nonce) triple is fresh. Accepting a
  /// triple records its nonce; the same nonce from the same sender is
  /// refused until it falls out of the tolerance window. Stale timestamps
  /// are refused without recording anything.
  bool accept({required String sender, required DateTime timestamp, required String nonce}) {
    final at = _now();
    if (timestamp.isBefore(at.subtract(tolerance)) || timestamp.isAfter(at.add(tolerance))) {
      return false;
    }
    final nonces = _seen.putIfAbsent(sender, () => <String, DateTime>{});
    if (nonces.containsKey(nonce)) return false;
    if (nonces.length >= maxTrackedNoncesPerSender) {
      _pruneSender(nonces, at);
    }
    nonces[nonce] = at;
    return true;
  }

  /// Forgets nonces that left the tolerance window.
  void prune() {
    final cutoff = _now().subtract(tolerance);
    for (final nonces in _seen.values) {
      nonces.removeWhere((_, at) => at.isBefore(cutoff));
    }
    _seen.removeWhere((_, nonces) => nonces.isEmpty);
  }

  void _pruneSender(Map<String, DateTime> nonces, DateTime at) {
    final cutoff = at.subtract(tolerance);
    nonces.removeWhere((_, seenAt) => seenAt.isBefore(cutoff));
    // Still full: drop the oldest entries. The request will be refused as
    // fresh rather than accepted twice — the guard errs on the side of
    // refusing.
    while (nonces.length >= maxTrackedNoncesPerSender) {
      nonces.remove(nonces.keys.first);
    }
  }
}
