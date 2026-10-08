// Module: test/result_and_tools_test.dart
// Purpose: Verify Result, SingleFlight, retryAsync and the collection helpers against their edge cases.
// Author: liuchuancong
// Created: 2026-10-08
import 'dart:async';

import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

void main() {
  group('Result', () {
    test('test_result_ok_exposesValueAndKeepsErrorNull', () {
      const Result<String, String> result = Result.ok('live');

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, 'live');
      expect(result.errorOrNull, isNull);
      expect(result.unwrapOr('fallback'), 'live');
    });

    test('test_result_err_fallsBackThroughTheError', () {
      const Result<String, String> result = Result.err('resolver.failed');

      expect(result.isErr, isTrue);
      expect(result.unwrapOr('fallback'), 'fallback');
      expect(result.unwrapOrElse((error) => '[$error]'), '[resolver.failed]');
    });

    test('test_result_map_passesFailureThrough', () {
      const Result<String, String> failed = Result.err('e');
      const Result<String, String> ok = Result.ok('a');

      expect(ok.map((value) => '$value!').unwrapOr(''), 'a!');
      expect(failed.map((value) => '$value!'), const Result<String, String>.err('e'));
    });

    test('test_result_flatMap_stopsAtTheFirstFailure', () {
      final calls = <String>[];
      const Result<int, String> start = Result.err('nope');

      final outcome = start
          .flatMap<int>((value) {
            calls.add('first');
            return Result.ok(value + 1);
          })
          .flatMap<int>((value) {
            calls.add('second');
            return Result.ok(value + 1);
          });

      expect(outcome.isErr, isTrue);
      expect(calls, isEmpty);
    });

    test('test_result_callbacks_fireOnTheirSideOnly', () {
      var okHits = 0;
      var errHits = 0;
      const Result<int, String> ok = Result.ok(1);
      const Result<int, String> err = Result.err('x');

      ok.onOk((_) => okHits++).onErr((_) => errHits++);
      err.onOk((_) => okHits++).onErr((_) => errHits++);

      expect(okHits, 1);
      expect(errHits, 1);
    });
  });

  group('SingleFlight', () {
    test('test_singleFlight_sameKey_concurrentCallsRunTheOperationOnce', () async {
      var runs = 0;
      final flight = SingleFlight<int>();

      Future<int> work() async {
        runs++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return 7;
      }

      final results = await Future.wait(<Future<int>>[flight.run('room-1', work), flight.run('room-1', work)]);

      expect(results, <int>[7, 7]);
      expect(runs, 1);
      expect(flight.pendingCount, 0);
    });

    test('test_singleFlight_differentKeys_runIndependently', () async {
      var runs = 0;
      final flight = SingleFlight<int>();
      Future<int> work() async => ++runs;

      await Future.wait(<Future<int>>[flight.run('a', work), flight.run('b', work)]);

      expect(runs, 2);
    });

    test('test_singleFlight_failure_isSharedAndThenCleared', () async {
      final flight = SingleFlight<int>();
      Future<int> failing() async => throw StateError('boom');

      final first = flight.run('k', failing);
      final second = flight.run('k', failing);
      await expectLater(first, throwsA(isA<StateError>()));
      await expectLater(second, throwsA(isA<StateError>()));
      expect(flight.pendingCount, 0);

      // A later call must start fresh rather than reuse the settled entry.
      expect(await flight.run('k', () async => 3), 3);
    });
  });

  group('retryAsync', () {
    Future<void> noWait(Duration delay) async {}

    test('test_retryAsync_firstAttemptSucceeds_noRetry', () async {
      var calls = 0;

      final value = await retryAsync<int>(() async => ++calls, attempts: 3, sleep: noWait);

      expect(value, 1);
      expect(calls, 1);
    });

    test('test_retryAsync_transientFailure_recoversWithinBudget', () async {
      var calls = 0;

      final value = await retryAsync<String>(
        () async {
          calls++;
          if (calls < 3) {
            throw TimeoutException('late');
          }
          return 'ok';
        },
        attempts: 3,
        sleep: noWait,
      );

      expect(value, 'ok');
      expect(calls, 3);
    });

    test('test_retryAsync_budgetExhausted_rethrowsLastError', () async {
      var calls = 0;

      await expectLater(
        retryAsync<int>(
          () async {
            calls++;
            throw StateError('attempt $calls');
          },
          attempts: 2,
          sleep: noWait,
        ),
        throwsA(isA<StateError>()),
      );
      expect(calls, 2);
    });

    test('test_retryAsync_cancellation_isNotRetried', () async {
      // docs/contracts/platform-models.md section 20 invariant 9.
      var calls = 0;

      await expectLater(
        retryAsync<int>(
          () async {
            calls++;
            throw const OperationCancelledException();
          },
          attempts: 5,
          sleep: noWait,
        ),
        throwsA(isA<OperationCancelledException>()),
      );
      expect(calls, 1);
    });

    test('test_retryAsync_shouldRetryFalse_stopsImmediately', () async {
      var calls = 0;

      await expectLater(
        retryAsync<int>(
          () async {
            calls++;
            throw ArgumentError('permanent');
          },
          attempts: 5,
          shouldRetry: (error) => error is TimeoutException,
          sleep: noWait,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(calls, 1);
    });

    test('test_retryAsync_backoff_growsAndIsCapped', () async {
      final waits = <Duration>[];

      await retryAsync<int>(
        () async => throw StateError('again'),
        attempts: 4,
        delay: const Duration(milliseconds: 100),
        backoff: 3,
        maxDelay: const Duration(milliseconds: 500),
        onRetry: (error, wait) => waits.add(wait),
        sleep: noWait,
      ).catchError((_) => 0);

      expect(waits, <Duration>[
        const Duration(milliseconds: 100),
        const Duration(milliseconds: 300),
        const Duration(milliseconds: 500),
      ]);
    });

    test('test_retryAsync_zeroAttempts_isRejected', () async {
      await expectLater(retryAsync<int>(() async => 1, attempts: 0), throwsA(isA<ArgumentError>()));
    });
  });

  group('collections', () {
    test('test_groupBy_preservesFirstSeenKeyOrder', () {
      final grouped = groupBy<String, String>(<String>['b-1', 'a-1', 'b-2'], (item) => item.split('-').first);

      expect(grouped.keys, <String>['b', 'a']);
      expect(grouped['b'], <String>['b-1', 'b-2']);
    });

    test('test_mapNotNull_dropsNullResults', () {
      final lengths = mapNotNull<String, int?>(<String>['a', 'bb', 'ccc'], (item) {
        return item.length.isEven ? item.length : null;
      });

      expect(lengths, <int>[2]);
    });

    test('test_distinctBy_keepsTheFirstPerKey', () {
      final distinct = distinctBy<String, int>(<String>['aa', 'b', 'cc', 'd'], (item) => item.length);

      expect(distinct, <String>['aa', 'b']);
    });

    test('test_chunked_tailShorterThanSize_isStillReturned', () {
      expect(chunked<int>(<int>[1, 2, 3, 4, 5], 2), <List<int>>[
        <int>[1, 2],
        <int>[3, 4],
        <int>[5],
      ]);
      expect(chunked<int>(<int>[], 3), isEmpty);
    });

    test('test_chunked_zeroSize_isRejected', () {
      expect(() => chunked<int>(<int>[1], 0), throwsA(isA<ArgumentError>()));
    });
  });
}
