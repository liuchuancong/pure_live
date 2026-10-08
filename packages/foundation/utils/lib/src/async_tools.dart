// Module: lib/src/async_tools.dart
// Purpose: Concurrency helpers shared by resolvers and refreshers: single-flight deduplication and bounded retry.
// Author: liuchuancong
// Created: 2026-10-08
//
// Both exist because the platform repeatedly issues the same request: several widgets opening one room, or
// a line switch retrying a dead url. docs/contracts/platform-models.md section 20 invariant 9 also requires
// cancellation not to be treated as an ordinary failure, so the retry loop can be told to stop on it.

import 'dart:async';

/// Runs one operation per key at a time, sharing the result with callers that arrive while it is in flight.
final class SingleFlight<T> {
  final Map<Object, Future<T>> _inFlight = <Object, Future<T>>{};

  /// Number of operations currently running.
  int get pendingCount => _inFlight.length;

  /// Returns the shared future for [key], starting [operation] when none is running.
  ///
  /// A failing operation still shares its error: the point is to avoid a stampede, not to hide failures.
  Future<T> run(Object key, Future<T> Function() operation) {
    final running = _inFlight[key];
    if (running != null) {
      return running;
    }
    late final Future<T> started;
    started = Future<T>.microtask(operation).whenComplete(() {
      // Only drop the entry if it is still ours; a newer call may already have replaced it.
      if (identical(_inFlight[key], started)) {
        _inFlight.remove(key);
      }
    });
    _inFlight[key] = started;
    return started;
  }
}

/// Thrown when an operation is cancelled by the caller rather than failing on its own.
final class OperationCancelledException implements Exception {
  const OperationCancelledException([this.message = 'cancelled']);

  final String message;

  @override
  String toString() => 'OperationCancelledException: $message';
}

/// Waits for [delay]; replaceable so tests do not sleep for real.
typedef Sleeper = Future<void> Function(Duration delay);

Future<void> _systemSleeper(Duration delay) => Future<void>.delayed(delay);

/// Calls [operation] until it succeeds or the attempt budget is exhausted.
///
/// Parameters:
///   [attempts] - total calls allowed, including the first; must be at least 1.
///   [delay] - wait before the second attempt; grows by [backoff] each round up to [maxDelay].
///   [shouldRetry] - decides whether an error is worth another try; cancellation never is.
///   [onRetry] - notified before each wait, with the error and the delay about to be applied.
///
/// Throws the last error when the budget runs out.
Future<T> retryAsync<T>(
  Future<T> Function() operation, {
  int attempts = 3,
  Duration delay = const Duration(milliseconds: 200),
  double backoff = 2,
  Duration maxDelay = const Duration(seconds: 5),
  bool Function(Object error) shouldRetry = _alwaysRetry,
  void Function(Object error, Duration wait) onRetry = _ignoreRetry,
  Sleeper sleep = _systemSleeper,
}) async {
  if (attempts < 1) {
    throw ArgumentError.value(attempts, 'attempts', 'must be at least 1');
  }
  var wait = delay;
  Object? lastError;
  for (var attempt = 1; attempt <= attempts; attempt++) {
    try {
      return await operation();
    } on OperationCancelledException {
      // Invariant 9: a cancellation is not a failure to be retried.
      rethrow;
    } catch (error) {
      lastError = error;
      if (attempt == attempts || !shouldRetry(error)) {
        rethrow;
      }
      onRetry(error, wait);
      await sleep(wait);
      wait = _nextDelay(wait, backoff, maxDelay);
    }
  }
  // Unreachable while attempts >= 1, kept so the contract stays total.
  throw StateError('retryAsync exhausted without an error: $lastError');
}

bool _alwaysRetry(Object error) => true;

void _ignoreRetry(Object error, Duration wait) {}

Duration _nextDelay(Duration current, double backoff, Duration maxDelay) {
  final grown = Duration(microseconds: (current.inMicroseconds * backoff).round());
  return grown > maxDelay ? maxDelay : grown;
}
