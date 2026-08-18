import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/utils/latest_async_value_queue.dart';

void main() {
  test('serializes transitions and applies the latest queued value', () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final applied = <bool>[];
    late final LatestAsyncValueQueue<bool> queue;

    queue = LatestAsyncValueQueue<bool>((value) async {
      applied.add(value);
      if (applied.length == 1) {
        firstStarted.complete();
        await releaseFirst.future;
      }
    });

    final first = queue.submit(true);
    await firstStarted.future;
    final joined = queue.submit(true);
    queue.submit(false);
    expect(queue.isRunning, isTrue);

    releaseFirst.complete();
    await Future.wait([first, joined]);

    expect(applied, <bool>[true, false]);
    expect(queue.isRunning, isFalse);
  });

  test('a failed stale transition still drains the latest queued value', () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final applied = <bool>[];
    final queue = LatestAsyncValueQueue<bool>((value) async {
      applied.add(value);
      if (value) {
        firstStarted.complete();
        await releaseFirst.future;
        throw StateError('stale transition failed');
      }
    });

    final first = queue.submit(true);
    await firstStarted.future;
    final latest = queue.submit(false);
    releaseFirst.complete();

    await Future.wait([first, latest]);
    expect(applied, <bool>[true, false]);
    expect(queue.isRunning, isFalse);
  });

  test('an identical active value joins without applying twice', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var applyCount = 0;
    final queue = LatestAsyncValueQueue<bool>((value) async {
      applyCount++;
      started.complete();
      await release.future;
    });

    final first = queue.submit(true);
    await started.future;
    final joined = queue.submit(true);
    release.complete();
    await Future.wait([first, joined]);

    expect(applyCount, 1);
  });
}
