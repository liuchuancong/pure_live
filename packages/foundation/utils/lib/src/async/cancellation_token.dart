// Module: lib/src/async/cancellation_token.dart
// Purpose: A cooperative, one-way cancellation signal shared by everyone working on one operation.
// Author: liuchuancong
// Created: 2026-10-08
//
// The repository already had two private versions of this - a bool inside the task package and per-store
// flags elsewhere - which is how cancellation becomes inconsistent: one layer stops, the next keeps
// fetching. docs/contracts/platform-models.md section 20 invariant 9 requires a cancellation to be reported
// as itself and never retried, so the signal and the exception live together here.
//
// Cancellation is cooperative, not preemptive: nothing can stop a future mid-await. What a token does is
// give every participant one question to ask at its own boundaries, so an operation that was abandoned
// finishes its current io call and then stops instead of starting the next one.

/// Thrown when an operation is cancelled by the caller rather than failing on its own.
///
/// A distinct type exists because the difference decides what happens next: a retryer re-tries a failure
/// and never re-tries a cancellation, and a reporter logs one and stays quiet about the other.
final class OperationCancelledException implements Exception {
  const OperationCancelledException([this.message = 'cancelled']);

  final String message;

  @override
  String toString() => 'OperationCancelledException: $message';
}

/// A latch that flips once and stays flipped.
final class CancellationToken {
  final List<void Function()> _listeners = <void Function()>[];
  bool _cancelled = false;

  /// True once [cancel] has run.
  bool get isCancelled => _cancelled;

  /// Registers [listener] to run on cancellation, or runs it immediately if already cancelled.
  ///
  /// The immediate path matters: an operation that installs its cleanup after the abort arrived would
  /// otherwise wait for a signal that can never come again, and leak the handle it was supposed to close.
  void addListener(void Function() listener) {
    if (_cancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  /// Drops a listener that has not fired yet.
  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// Signals cancellation and releases every listener exactly once.
  ///
  /// Repeating it is a no-op: two owners of one composite operation both noticing an abort is normal, and
  /// neither should be able to make a cleanup run twice.
  void cancel() {
    if (_cancelled) {
      return;
    }
    _cancelled = true;
    // The list is copied before the round starts, so a listener that registers another one cannot extend
    // the round it is already part of.
    final pending = List<void Function()>.of(_listeners);
    _listeners.clear();
    for (final listener in pending) {
      listener();
    }
  }

  /// Throws [OperationCancelledException] when cancellation was requested.
  ///
  /// Call it at every await boundary that can still be stopped; between two io calls is where a line switch
  /// or a page fetch otherwise finishes work nobody asked for any more.
  void throwIfCancelled() {
    if (_cancelled) {
      throw const OperationCancelledException();
    }
  }

  /// Runs [operation], then throws if cancellation arrived while it was waiting.
  ///
  /// The wrapper exists because an io call cannot be interrupted: this is how a caller says "let it finish
  /// the current request, but do not treat its answer as wanted".
  Future<T> guard<T>(Future<T> Function() operation) async {
    final value = await operation();
    throwIfCancelled();
    return value;
  }
}
