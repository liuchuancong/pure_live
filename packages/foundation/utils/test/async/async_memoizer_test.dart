// Module: test/async/async_memoizer_test.dart
// Purpose: Pins AsyncMemoizer's cache, ttl expiry, bounded eviction and
// in-flight dedup, using an injected clock so expiry is deterministic.

import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

void main() {
  test('test_asyncMemoizer_cachesValuePerKey', () async {
    final memoizer = AsyncMemoizer<int>(ttl: Duration.zero, maxEntries: 8);
    var calls = 0;
    final first = await memoizer.run('k', () async {
      calls++;
      return 1;
    });
    final second = await memoizer.run('k', () async {
      calls++;
      return 2;
    });
    expect(first, 1);
    expect(second, 1);
    expect(calls, 1);
  });

  test('test_asyncMemoizer_ttlExpiry_rerunsComputation', () async {
    final clock = FixedClock(DateTime.utc(2026, 1, 1));
    final memoizer = AsyncMemoizer<int>(ttl: const Duration(minutes: 5), clock: clock);
    var calls = 0;
    Future<int> run() => memoizer.run('k', () async => ++calls);

    expect(await run(), 1);
    clock.advance(const Duration(minutes: 4));
    expect(await run(), 1);
    expect(calls, 1);

    clock.advance(const Duration(minutes: 2));
    expect(await run(), 2);
    expect(calls, 2);
  });

  test('test_asyncMemoizer_errorIsNotCached_nextCallRetries', () async {
    final memoizer = AsyncMemoizer<int>(ttl: Duration.zero, maxEntries: 8);
    var calls = 0;
    Future<int> run() => memoizer.run('k', () async {
      calls++;
      if (calls == 1) {
        throw StateError('first fails');
      }
      return calls;
    });
    await expectLater(run(), throwsA(isA<StateError>()));
    expect(await run(), 2);
  });

  test('test_asyncMemoizer_concurrentCallsWithSameKey_shareOneRun', () async {
    final memoizer = AsyncMemoizer<int>(ttl: Duration.zero, maxEntries: 8);
    var calls = 0;
    final values = await Future.wait(
      [1, 2, 3].map(
        (_) => memoizer.run('k', () async {
          calls++;
          return calls;
        }),
      ),
    );
    expect(calls, 1);
    expect(values, [1, 1, 1]);
  });

  test('test_asyncMemoizer_maxEntriesEvictsOldest', () async {
    final memoizer = AsyncMemoizer<int>(ttl: Duration.zero, maxEntries: 2);
    var calls = 0;
    Future<int> run(String key) => memoizer.run(key, () async => ++calls);

    await run('a');
    await run('b');
    await run('c');
    expect(memoizer.length, 2);
    // 'a' was the oldest: it was evicted, so it re-runs.
    final a = await memoizer.run('a', () async => ++calls);
    expect(a, 4);
  });

  test('test_asyncMemoizer_invalidate_dropsKeyOnly', () async {
    final memoizer = AsyncMemoizer<int>(ttl: Duration.zero, maxEntries: 8);
    var calls = 0;
    Future<int> run(String key) => memoizer.run(key, () async => ++calls);
    await run('a');
    await run('b');
    memoizer.invalidate(key: 'a');
    // 'a' and 'b' consumed calls 1 and 2; only 'a' was dropped, so its rerun is the third computation.
    expect(await run('a'), 3);
    expect(memoizer.length, 2);
  });
}
