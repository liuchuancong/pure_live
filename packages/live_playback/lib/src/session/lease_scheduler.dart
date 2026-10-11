import 'dart:async';

import 'package:live_sites/live_sites.dart';

/// Schedules proactive renewal of a line's lease.
///
/// A [PlayLease] says when a URL should be refreshed ([PlayLease.refreshAt])
/// and when it dies ([PlayLease.expiresAt]); the scheduler fires [onRenew]
/// shortly before the refresh deadline (never after expiry) so the
/// session can re-resolve the URL before playback breaks. A line without
/// a lease schedules nothing.
final class LeaseScheduler {
  /// A scheduler whose callback fires at most once per armed lease;
  /// [now] is injectable for tests.
  new({required this.onRenew, DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Called when the current line should be renewed.
  final void Function() onRenew;

  final DateTime Function() _now;
  Timer? _timer;

  /// Arms the timer for [line]'s lease. Cancels any previous arm.
  ///
  /// The deadline is [PlayLease.refreshAt] when present, else a lead-time
  /// margin (60 seconds) before [PlayLease.expiresAt] — mirroring the
  /// site layers' lease conventions. A lease whose deadline has passed
  /// fires immediately.
  void arm(LivePlayLine line) {
    cancel();
    final lease = line.lease;
    if (lease == null) {
      return;
    }
    final deadline = lease.refreshAt ?? lease.expiresAt?.subtract(const Duration(seconds: 60));
    if (deadline == null) {
      return;
    }
    final delay = deadline.difference(_now());
    if (delay <= Duration.zero) {
      _timer = Timer(Duration.zero, onRenew);
      return;
    }
    _timer = Timer(delay, onRenew);
  }

  /// Cancels a scheduled renewal.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
