import 'dart:collection';

import 'package:live_sites/live_sites.dart';

/// Deduplicates and throttle-gates a room's incoming messages.
///
/// Two behaviours from the interaction spec:
///
/// - **Dedup**: messages that carry a stable [LiveMessage.id] are dropped
///   when the same id was seen within [window] (platforms repeat packets
///   after reconnects and combo gifts stream many near-identical ids).
///   Messages without an id always pass.
/// - **Backlog drop**: right after a reconnect, platforms flush buffered
///   messages (chat history). [openReconnectWindow] marks the moment;
///   messages older than [LiveMessage.sentAt] reached before the window
///   opened are dropped until [closeReconnectWindow] or the window
///   expires.
final class MessageGate {
  /// A gate with [window] as the dedup memory and [reconnectBacklog] as
  /// the age above which post-reconnect messages are considered backlog.
  new({
    this.window = const Duration(minutes: 2),
    this.reconnectBacklog = const Duration(seconds: 20),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// How long a message id blocks its repeats.
  final Duration window;

  /// How old a message may be and still count as new after a reconnect.
  final Duration reconnectBacklog;

  final DateTime Function() _now;
  final ListQueue<({String id, DateTime at})> _seen = ListQueue();
  DateTime? _reconnectUntil;

  /// Opens the post-reconnect backlog window for [duration].
  void openReconnectWindow({Duration duration = const Duration(seconds: 10)}) {
    _reconnectUntil = _now().add(duration);
  }

  /// Closes the backlog window early.
  void closeReconnectWindow() => _reconnectUntil = null;

  /// Whether [message] passes the gate.
  bool allows(LiveMessage message) {
    if (!_isFreshAfterReconnect(message)) {
      return false;
    }
    if (!_isFreshId(message)) {
      return false;
    }
    return true;
  }

  bool _isFreshAfterReconnect(LiveMessage message) {
    final until = _reconnectUntil;
    if (until == null || _now().isAfter(until)) {
      _reconnectUntil = null;
      return true;
    }
    final sentAt = message.sentAt;
    if (sentAt == null) {
      return true;
    }
    return _now().difference(sentAt) <= reconnectBacklog;
  }

  bool _isFreshId(LiveMessage message) {
    final id = message.id;
    if (id == null || id.isEmpty) {
      return true;
    }
    final now = _now();
    while (_seen.isNotEmpty && now.difference(_seen.first.at) > window) {
      _seen.removeFirst();
    }
    for (final entry in _seen) {
      if (entry.id == id) {
        return false;
      }
    }
    _seen.add((id: id, at: now));
    return true;
  }
}
