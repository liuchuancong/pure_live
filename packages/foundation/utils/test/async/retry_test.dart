// Module: test/async/retry_test.dart
// Purpose: Pins retryAsync's budget, backoff curve, cancellation invariant and notification contract.

import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

void main() {
  // Replaces the global jitter with the identity so the backoff curve is exact.
  setUp(() {
    final previous = jitter;
    jitter = (base) => base;
    addTearDown(() => jitter = previous);
  });

  test('test_retryAsync_firstAttemptSucceeds_noRetry', () async {
    var calls = 0;
    final result = await retryAsync<int>(() async {
      calls++;
      return calls;
    }, attempts: 3);

    expect(result, 1);
    expect(calls, 1);
  });

  test('test_retryAsync_failsThenSucceeds_returnsSecondValue', () async {
    var calls = 0;
    final result = await retryAsync<int>(() async {
      calls++;
      if (calls == 1) {
        throw StateError('first fails');
      }
      return calls;
    }, attempts: 3);

    expect(result, 2);
    expect(calls, 2);
  });

  test('test_retryAsync_budgetExhausted_throwsLastError', () async {
    var calls = 0;
    await expectLater(
      retryAsync<int>(
        () async {
          calls++;
          throw StateError('always fails');
        },
        attempts: 3,
        delay: Duration.zero,
      ),
      throwsA(isA<StateError>()),
    );
    expect(calls, 3);
  });

  test('test_retryAsync_shouldRetryFalse_rethrowsImmediately', () async {
    var calls = 0;
    await expectLater(
      retryAsync<int>(
        () async {
          calls++;
          throw StateError('no');
        },
        attempts: 3,
        shouldRetry: (_) => false,
      ),
      throwsA(isA<StateError>()),
    );
    expect(calls, 1);
  });

  test('test_retryAsync_backoffDoubles_upToMaxDelay', () async {
    final waits = <Duration>[];
    var calls = 0;
    // The budget is exhausted, so the last error rethrows; the waits are what this test pins.
    await expectLater(
      retryAsync<int>(
        () async {
          calls++;
          throw StateError('no');
        },
        attempts: 4,
        delay: const Duration(milliseconds: 100),
        backoff: 2,
        maxDelay: const Duration(milliseconds: 300),
        sleep: (_) async {},
        onRetry: (_, wait) => waits.add(wait),
      ),
      throwsA(isA<StateError>()),
    );
    expect(waits, [
      const Duration(milliseconds: 100),
      const Duration(milliseconds: 200),
      const Duration(milliseconds: 300),
    ]);
    expect(calls, 4);
  });

  test('test_retryAsync_cancellationIsNeverRetried', () async {
    var calls = 0;
    await expectLater(
      retryAsync<int>(() async {
        calls++;
        throw const OperationCancelledException('viewer left');
      }, attempts: 5),
      throwsA(isA<OperationCancelledException>()),
    );
    expect(calls, 1);
  });

  test('test_retryAsync_onRetryReceivesErrorAndDelay', () async {
    final seen = <(Object, Duration)>[];
    // Two attempts both fail, so the second error escapes; only one retry was notified.
    await expectLater(
      retryAsync<int>(
        () async => throw StateError('boom'),
        attempts: 2,
        delay: const Duration(milliseconds: 40),
        sleep: (_) async {},
        onRetry: (error, wait) => seen.add((error, wait)),
      ),
      throwsA(isA<StateError>()),
    );
    expect(seen.length, 1);
    expect(seen.single.$1, isA<StateError>());
    expect(seen.single.$2, const Duration(milliseconds: 40));
  });

  test('test_retryAsync_attemptsBelowOne_throwsArgumentError', () {
    expect(() => retryAsync<int>(() async => 1, attempts: 0), throwsArgumentError);
  });
}
