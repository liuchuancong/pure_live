// Module: test/recording_test.dart
// Purpose: Verify the ring buffer bound and drop count, guarded execution and timing that survives a throw.
// Author: liuchuancong
// Created: 2026-10-08
import 'dart:async';

import 'package:pure_live_diagnostics/pure_live_diagnostics.dart';
import 'package:test/test.dart';

void main() {
  test('test_ringBuffer_keepsTheNewestEntriesAndCountsDrops', () {
    final buffer = RingBuffer<int>(capacity: 3);

    for (final value in <int>[1, 2, 3, 4, 5]) {
      buffer.add(value);
    }

    expect(buffer.entries, <int>[3, 4, 5]);
    expect(buffer.droppedCount, 2);
    expect(buffer.newestFirst, <int>[5, 4, 3]);
  });

  test('test_ringBuffer_clear_resetsBothEntriesAndDropCount', () {
    final buffer = RingBuffer<String>(capacity: 1);
    buffer.add('a');
    buffer.add('b');

    buffer.clear();

    expect(buffer.isEmpty, isTrue);
    expect(buffer.droppedCount, 0);
  });

  test('test_ringBuffer_zeroCapacity_isRejected', () {
    expect(() => RingBuffer<int>(capacity: 0), throwsA(isA<ArgumentError>()));
  });

  test('test_runGuarded_syncThrow_isReportedAndReturnsTrue', () async {
    final caught = <Object>[];

    final failed = await runGuarded(
      () => throw StateError('sync'),
      onError: (error, stackTrace) => caught.add(error),
    );

    expect(failed, isTrue);
    expect(caught.single, isA<StateError>());
  });

  test('test_runGuarded_asyncThrow_isReported', () async {
    final caught = <Object>[];

    final failed = await runGuarded(
      () async => throw Exception('async'),
      onError: (error, stackTrace) => caught.add(error),
    );

    expect(failed, isTrue);
    expect(caught, hasLength(1));
  });

  test('test_runGuarded_unawaitedTimerError_isStillReported', () async {
    final caught = <Object>[];

    // body() finishes first; the error escapes later from a timer, which is the case a plain try/catch
    // around the call would miss entirely.
    final failed = await runGuarded(() {
      Timer.run(() {
        throw StateError('escaped the zone');
      });
      return Future<void>.delayed(const Duration(milliseconds: 20), Completer<void>().complete);
    }, onError: (error, stackTrace) => caught.add(error));

    expect(failed, isTrue);
    expect(caught.single, isA<StateError>());
  });

  test('test_runGuarded_success_reportsNoError', () async {
    var calls = 0;

    final failed = await runGuarded(
      () => calls++,
      onError: (error, stackTrace) => calls += 100,
    );

    expect(failed, isFalse);
    expect(calls, 1);
  });

  test('test_measure_returnsValueAndReportsElapsed', () async {
    final reports = <(String, bool)>[];

    final value = await measure<int>(
      'resolve',
      () async => 7,
      onComplete: (label, elapsed, failed) {
        expect(elapsed, greaterThanOrEqualTo(Duration.zero));
        reports.add((label, failed));
      },
    );

    expect(value, 7);
    expect(reports, <(String, bool)>[('resolve', false)]);
  });

  test('test_measure_reportsFailureAndRethrows', () async {
    final reports = <bool>[];

    await expectLater(
      measure<int>(
        'refresh',
        () async => throw StateError('slow and broken'),
        onComplete: (label, elapsed, failed) => reports.add(failed),
      ),
      throwsA(isA<StateError>()),
    );

    // The slow path is usually the failing path, so the measurement must not be lost with it.
    expect(reports, <bool>[true]);
  });
}
