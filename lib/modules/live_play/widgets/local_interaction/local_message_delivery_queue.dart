import 'dart:async';

import 'package:pure_live/common/models/live_message.dart';

class LocalMessageDelivery {
  const LocalMessageDelivery({
    required this.message,
    required this.showAsDanmaku,
    required this.roomId,
    required this.platform,
  });

  final LiveMessage message;
  final bool showAsDanmaku;
  final String? roomId;
  final String? platform;

  /// A local message belongs to the room session, not to one particular
  /// stream-detail/quality request. Player retries and quality or line changes
  /// advance the room-load request generation while the user is still in the
  /// same room, so request epochs must not invalidate a queued local echo.
  bool matchesRoom({required String? roomId, required String? platform}) {
    return this.roomId == roomId && this.platform == platform;
  }
}

/// Keeps delayed local interactions ordered and makes cancellation explicit
/// when the room changes or the owning controller is disposed.
class LocalMessageDeliveryQueue {
  LocalMessageDeliveryQueue({required this.onDeliver});

  final void Function(LocalMessageDelivery delivery) onDeliver;
  final Set<Timer> _timers = <Timer>{};
  bool _disposed = false;

  int get pendingCount => _timers.length;

  void schedule(LocalMessageDelivery delivery, {required Duration delay}) {
    if (_disposed) return;
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      if (_disposed) return;
      onDeliver(delivery);
    });
    _timers.add(timer);
  }

  void cancelAll() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancelAll();
  }
}
