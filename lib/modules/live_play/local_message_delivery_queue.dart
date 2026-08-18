import 'dart:async';

import 'package:pure_live/common/models/live_message.dart';

class LocalMessageDelivery {
  const LocalMessageDelivery({required this.message, required this.showAsDanmaku, required this.roomEpoch});

  final LiveMessage message;
  final bool showAsDanmaku;
  final int roomEpoch;
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
