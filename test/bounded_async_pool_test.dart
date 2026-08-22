import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/utils/bounded_async_pool.dart';

void main() {
  test('a free worker starts the next item without waiting for a slow batch peer', () async {
    final gates = List<Completer<int>>.generate(4, (_) => Completer<int>());
    final started = <int>[];

    final operation = boundedAsyncMap<int, int>(
      [0, 1, 2, 3],
      maxConcurrent: 2,
      task: (item) {
        started.add(item);
        return gates[item].future;
      },
    );

    await Future<void>.delayed(Duration.zero);
    expect(started, [0, 1]);

    gates[1].complete(10);
    await Future<void>.delayed(Duration.zero);
    expect(started, [0, 1, 2]);

    gates[2].complete(20);
    await Future<void>.delayed(Duration.zero);
    expect(started, [0, 1, 2, 3]);

    gates[0].complete(0);
    gates[3].complete(30);
    expect(await operation, [0, 10, 20, 30]);
  });

  test('cancellation stops workers from pulling more items', () async {
    var cancelled = false;
    final gate = Completer<int>();
    final started = <int>[];

    final operation = boundedAsyncMap<int, int>(
      [0, 1, 2],
      maxConcurrent: 1,
      shouldCancel: () => cancelled,
      task: (item) {
        started.add(item);
        return gate.future;
      },
    );

    await Future<void>.delayed(Duration.zero);
    cancelled = true;
    gate.complete(0);
    expect(await operation, [0, null, null]);
    expect(started, [0]);
  });
}
