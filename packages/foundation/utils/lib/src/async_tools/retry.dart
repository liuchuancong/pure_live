// Module: lib/src/async_tools/retry.dart
// Purpose: Bounded retry with exponential backoff that treats cancellation as a stop, not a failure.
// Author: liuchuancong
// Created: 2026-10-08
//
// docs/contracts/platform-models.md section 20 invariant 9 requires cancellation not to be retried, so the
// loop recognises it separately from an ordinary error. The sleep is injectable because a retry test that
// waits for real time is a slow test that proves nothing about the backoff curve.

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

bool _alwaysRetry(Object error) => true;

void _ignoreRetry(Object error, Duration wait) {}

Duration _nextDelay(Duration current, double backoff, Duration maxDelay) {
  final grown = Duration(microseconds: (current.inMicroseconds * backoff).round());
  return grown > maxDelay ? maxDelay : grown;
}

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
  for (var attempt = 1; attempt <= attempts; attempt++) {
    try {
      return await operation();
    } on OperationCancelledException {
      // Invariant 9: a cancellation is not a failure to be retried.
      rethrow;
    } catch (error) {
      if (attempt == attempts || !shouldRetry(error)) {
        rethrow;
      }
      onRetry(error, wait);
      await sleep(wait);
      wait = _nextDelay(wait, backoff, maxDelay);
    }
  }
  // Unreachable while attempts >= 1: the loop either returns or rethrows.
  throw StateError('retryAsync exhausted without an error');
}
