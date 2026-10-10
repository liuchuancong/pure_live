// Module: lib/src/async/operation_guard.dart
// Purpose: Refuse to start an operation that is already running, instead of queueing a second copy of it.
// Author: liuchuancong
// Created: 2026-10-10
//
// A remote on a TV sends a repeat event while a request is in flight, and the difference between "the user
// pressed refresh twice" and "the page loaded twice" is decided here. SingleFlight shares an in-flight
// result between callers, which is right for reading one room's state; for user-initiated actions a second
// call has to be *visible* as refused, not quietly served from the first one's result.

import 'dart:async';

/// Thrown when an operation is refused because another one is still running.
final class OperationInProgressException implements Exception {
  const OperationInProgressException([this.message = 'operation already running']);

  final String message;

  @override
  String toString() => 'OperationInProgressException: $message';
}

/// Allows one operation at a time and names the refusal.
final class OperationGuard {
  Completer<void>? _running;

  /// True while an operation holds the guard.
  bool get isRunning => _running != null;

  /// Completes when the current operation finishes, or immediately when none is running.
  Future<void> get onIdle => _running?.future ?? Future<void>.value();

  /// Runs [operation] when idle, otherwise throws [OperationInProgressException].
  ///
  /// [operation] is started in the same turn the guard is taken, so two callers cannot both pass the idle
  /// check before either begins.
  Future<T> run<T>(Future<T> Function() operation) {
    if (_running != null) {
      throw const OperationInProgressException();
    }
    final completion = _running = Completer<void>();
    return () async {
      try {
        return await operation();
      } finally {
        // The slot clears before the waiter is resumed, so a caller that reacts to onIdle cannot re-enter a
        // guard that still looks busy.
        _running = null;
        completion.complete();
      }
    }();
  }

  /// Runs [operation] once the guard is idle, giving up after [patience].
  ///
  /// This is the shape a queue wants: a line switch that must happen is not the same as a duplicate tap, so
  /// it waits its turn instead of being refused.
  Future<T> runWhenIdle<T>(Future<T> Function() operation, {Duration patience = const Duration(seconds: 2)}) async {
    final deadline = DateTime.now().add(patience);
    while (_running != null) {
      if (!DateTime.now().isBefore(deadline)) {
        throw const OperationInProgressException('guard stayed busy past the patience window');
      }
      await onIdle;
    }
    return run(operation);
  }
}
