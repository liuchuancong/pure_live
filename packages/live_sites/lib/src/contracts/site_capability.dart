import 'dart:async';

import 'package:live_sites/src/models/live_message.dart';
import 'package:live_sites/src/models/live_room.dart';

/// A connected danmaku session for one room.
///
/// The session yields normalized [LiveMessage]s; transport, reconnects
/// and heartbeats are the adapter's business, rendering stays with the
/// UI layer. [close] is idempotent.
abstract interface class LiveDanmakuSession {
  /// The normalized message stream. Single subscription.
  Stream<LiveMessage> get messages;

  /// Stops the session and releases the transport.
  Future<void> close();
}

/// The danmaku capability a site may implement.
///
/// Sites whose protocol cannot connect a room simply do not implement
/// this interface — capability probing is `site is LiveDanmakuCapability`,
/// no flags and no null-returning methods.
abstract interface class LiveDanmakuCapability {
  /// Opens a danmaku session for [room]; the room's runtime cache may
  /// carry platform init payloads from an earlier detail fetch.
  Future<LiveDanmakuSession> connect(LiveRoom room);
}

/// Cooperative cancellation for long-lived site operations.
///
/// Transport-agnostic: adapters bridge it to their own cancellation
/// primitives. Cancelling is idempotent; the first [reason] wins.
final class CancellationToken {
  final Completer<Object?> _completer = Completer<Object?>();

  bool _isCancelled = false;
  Object? _reason;

  /// Whether [cancel] has been called.
  bool get isCancelled => _isCancelled;

  /// The reason of the first cancellation, if any.
  Object? get reason => _reason;

  /// Completes with the [reason] once cancelled.
  Future<Object?> get whenCancel => _completer.future;

  /// Marks the token cancelled. Later calls are ignored.
  void cancel([Object? reason]) {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;
    _reason = reason;
    _completer.complete(reason);
  }
}
