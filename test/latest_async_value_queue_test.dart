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
}
