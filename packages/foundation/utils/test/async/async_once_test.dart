// Module: test/async/async_once_test.dart
// Purpose: Pins AsyncOnce's run-exactly-once rule, failure retry semantics
// and explicit reset.

import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

void main() {
  test('test_asyncOnce_runsComputationOncePerKey', () async {
    final once = AsyncOnce<int>();
    var calls = 0;
    Future<int> run() async {
      calls++;
      return calls;
    }

    final values = await Future.wait([1, 2, 3].map((_) => once.run('k', run)));
    expect(values, [1, 1, 1]);
    expect(calls, 1);
    expect(once.contains('k'), isTrue);
  });

  test('test_asyncOnce_failureIsNotRemembered_nextCallRetries', () async {
    final once = AsyncOnce<int>();
    var calls = 0;
    Future<int> run() async {
      calls++;
      if (calls == 1) {
        throw StateError('first fails');
      }
      return calls;
    }

    await expectLater(once.run('k', run), throwsA(isA<StateError>()));
    expect(await once.run('k', run), 2);
  });

  test('test_asyncOnce_differentKeys_runIndependently', () async {
    final once = AsyncOnce<String>();
    expect(await once.run('a', () async => 'A'), 'A');
    expect(await once.run('b', () async => 'B'), 'B');
    expect(once.length, 2);
  });

  test('test_asyncOnce_reset_forcesRerun', () async {
    final once = AsyncOnce<int>();
    var calls = 0;
    await once.run('k', () async => ++calls);
    once.reset('k');
    expect(await once.run('k', () async => ++calls), 2);
  });
}
