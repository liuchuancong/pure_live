// Module: lib/src/cancellation.dart
// Purpose: The cooperative cancellation signal a running task watches.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-contracts.md section 16 and section 18 ("取消不是错误").
//
// media_core already owns a cancel token for the player domain and platform-models.md section 2 asks for it
// to be reused; media_core depends on the Flutter SDK while this package must stay pure Dart, so this is the
// platform-side token and pure_live_media maps the two at the wiring layer. That is the same arrangement
// ADR 0016 reached for MediaTrack.

/// Thrown by a task that stopped because it was cancelled.
///
/// The scheduler treats it as a terminal `cancelled` state, not as a failure, so a user pressing stop does
/// not look like a broken source in the recovery ladder.
final class TaskCancelledException implements Exception {
  const TaskCancelledException([this.reason = 'cancelled']);

  final String reason;

  @override
  String toString() => 'TaskCancelledException($reason)';
}

/// A one-way cancellation signal shared between the scheduler and the running task.
final class CancellationToken {
  CancellationToken({this.label = 'task'});

  /// Names the signal in a diagnostic line; has no effect on behaviour.
  final String label;

  bool _cancelled = false;
  final List<void Function()> _handlers = <void Function()>[];

  bool get isCancelled => _cancelled;

  /// Signals cancellation and releases the handlers. A second call does nothing.
  void cancel() {
    if (_cancelled) {
      return;
    }
    _cancelled = true;
    final pending = List<void Function()>.of(_handlers);
    _handlers.clear();
    for (final handler in pending) {
      handler();
    }
  }

  /// Runs [handler] now if the token is already cancelled, otherwise when it becomes cancelled.
  ///
  /// The immediate path matters: a task that registers a cleanup handler after cancellation would otherwise
  /// never see it.
  void onCancel(void Function() handler) {
    if (_cancelled) {
      handler();
      return;
    }
    _handlers.add(handler);
  }

  /// Throws [TaskCancelledException] when cancelled, for the checks a task spreads through its loops.
  void throwIfCancelled() {
    if (_cancelled) {
      throw TaskCancelledException('$label was cancelled');
    }
  }
}
