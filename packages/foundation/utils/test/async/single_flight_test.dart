// Module: test/async/single_flight_test.dart
// Purpose: Pins SingleFlight's dedup, error sharing and in-flight bookkeeping.

import 'dart:async';

import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

void main() {
  test('test_singleFlight_concurrentCalls_shareOneOperation', () async {
    final flight = SingleFlight<int>();
    var calls = 0;
    Future<int> operation() async {
      calls++;
      return calls;
    }

    final first = flight.run('k', operation);
    final second = flight.run('k', operation);
    expect(identical(first, second), isTrue);
    expect(await first, 1);
    expect(calls, 1);
  });

  test('test_singleFlight_errorIsSharedWithJoiners', () async {
    final flight = SingleFlight<int>();
    final first = flight.run('k', () async => throw StateError('shared failure'));
    await expectLater(first, throwsA(isA<StateError>()));
    // After settle the entry is gone: the next run starts a new operation.
    expect(flight.pendingCount, 0);
  });

  test('test_singleFlight_differentKeys_doNotShare', () async {
    final flight = SingleFlight<String>();
    final a = flight.run('a', () async => 'A');
    final b = flight.run('b', () async => 'B');
    expect(await a, 'A');
    expect(await b, 'B');
  });

  test('test_singleFlight_reRunAfterSettle_executesAgain', () async {
    final flight = SingleFlight<int>();
    await flight.run('k', () async => 1);
    final second = await flight.run('k', () async => 2);
    expect(second, 2);
  });
}
