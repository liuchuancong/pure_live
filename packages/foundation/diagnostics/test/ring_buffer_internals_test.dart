// Module: test/ring_buffer_internals_test.dart
// Purpose: Verify the ring actually recycles slots and that a failing reporter cannot hang the guarded call.
// Author: liuchuancong
// Created: 2026-10-10

import 'dart:async';

import 'package:pure_live_diagnostics/pure_live_diagnostics.dart';
import 'package:test/test.dart';

void main() {
  group('test_ring_buffer', () {
    test('test_ringBuffer_wraparound_keepsTheNewestInOrder', () {
      final buffer = RingBuffer<int>(capacity: 3);
      for (final value in <int>[1, 2, 3, 4, 5]) {
        buffer.add(value);
      }

      expect(buffer.entries, <int>[3, 4, 5]);
      expect(buffer.newestFirst, <int>[5, 4, 3]);
      expect(buffer.length, 3);
      expect(buffer.isFull, isTrue);
      expect(buffer.droppedCount, 2);
    });

    test('test_ring_buffer_fillingWithoutOverflowDropsNothing', () {
      final buffer = RingBuffer<String>(capacity: 4)
        ..add('a')
        ..add('b');

      expect(buffer.entries, <String>['a', 'b']);
      expect(buffer.droppedCount, 0);
      expect(buffer.isFull, isFalse);
    });

    test('test_ringBuffer_clearResetsBothViewAndAccounting', () {
      final buffer = RingBuffer<int>(capacity: 2)
        ..add(1)
        ..add(2)
        ..add(3)
        ..clear();

      expect(buffer.isEmpty, isTrue);
      expect(buffer.entries, isEmpty);
      expect(buffer.droppedCount, 0);
      // Reuse after a clear has to start from the head again, not from wherever the ring had rotated to.
      buffer.add(9);
      expect(buffer.entries, <int>[9]);
    });

    test('test_ringBuffer_capacityOneKeepsOnlyTheLatest', () {
      final buffer = RingBuffer<int>(capacity: 1)
        ..add(1)
        ..add(2);

      expect(buffer.entries, <int>[2]);
      expect(buffer.droppedCount, 1);
    });

    test('test_ringBuffer_survivesFarMoreAddsThanCapacity', () {
      // The old implementation shifted a list on every add once full; this is the shape that makes the
      // difference observable rather than theoretical.
      final buffer = RingBuffer<int>(capacity: 8);
      for (var i = 0; i < 1000; i++) {
        buffer.add(i);
      }
      expect(buffer.entries, List<int>.generate(8, (index) => 992 + index));
      expect(buffer.length, 8);
      expect(buffer.newestFirst.first, 999);
      expect(buffer.droppedCount, 992);
    });
  });

  group('test_guarded_execution', () {
    test('test_runGuarded_handlerThrowingIsReportedInsteadOfHanging', () async {
      // The failure this replaces: an unguarded onError left the caller awaiting a future that could never
      // complete, so a locked diagnostics file became a frozen feature. The timeout is the assertion: if the
      // guard hangs, this never reaches expect.
      Object? outcome;
      await runGuarded(
            () => throw StateError('body failed'),
            onError: (_, _) => throw ArgumentError('reporter is broken too'),
          )
          .then<void>((failed) => outcome = failed)
          .catchError((Object error) {
            outcome = error;
            return Future<bool>.value(true);
          })
          .timeout(const Duration(seconds: 2), onTimeout: () => fail('runGuarded hung on a broken reporter'));

      expect(outcome, isA<ArgumentError>(), reason: 'the reporter failure is surfaced, and nothing hung');
    });

    test('test_runGuarded_handlerFailureIsRethrownAfterReporting', () async {
      await expectLater(
        runGuarded(() => throw StateError('first'), onError: (_, _) => throw ArgumentError('reporter')),
        throwsA(isA<ArgumentError>()),
        reason: 'a broken diagnostics path has to be loud, not swallowed',
      );
    });

    test('test_runGuarded_bodyErrorStillWinsWhenTheReporterIsFine', () async {
      final seen = <Object>[];
      final failed = await runGuarded(() => throw StateError('body'), onError: (error, _) => seen.add(error));

      expect(failed, isTrue);
      expect(seen.single, isA<StateError>());
    });

    test('test_measure_elapsedIsNeverNegativeAndFollowsTheWork', () async {
      final reports = <Duration>[];
      await measure<void>(
        'slow',
        () async => Future<void>.delayed(const Duration(milliseconds: 25)),
        onComplete: (_, elapsed, _) => reports.add(elapsed),
      );

      expect(reports.single, greaterThanOrEqualTo(const Duration(milliseconds: 20)));
      expect(reports.single.isNegative, isFalse);
    });
  });
}
