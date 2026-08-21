import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/get/get.dart';

void main() {
  test('Rx stream reconnects its notifier bridge after the last listener cancels', () async {
    final values = <int>[].obs;
    final firstEvents = <List<int>>[];
    final first = values.listen((event) => firstEvents.add(List<int>.from(event)));

    values.assignAll(<int>[1]);
    await Future<void>.delayed(Duration.zero);
    expect(firstEvents, <List<int>>[
      <int>[1],
    ]);

    await first.cancel();
    values.assignAll(<int>[1, 2]);
    await Future<void>.delayed(Duration.zero);

    final restoredEvents = <List<int>>[];
    final restored = values.listen((event) => restoredEvents.add(List<int>.from(event)));
    values.assignAll(<int>[1, 2, 3]);
    await Future<void>.delayed(Duration.zero);

    expect(restoredEvents, <List<int>>[
      <int>[1, 2, 3],
    ]);

    await restored.cancel();
    values.close();
  });

  test('Rx stream keeps its bridge until every concurrent listener is gone', () async {
    final value = 0.obs;
    final firstEvents = <int>[];
    final secondEvents = <int>[];
    final first = value.listen(firstEvents.add);
    final second = value.listen(secondEvents.add);

    value.value = 1;
    await Future<void>.delayed(Duration.zero);
    await first.cancel();
    value.value = 2;
    await Future<void>.delayed(Duration.zero);

    expect(firstEvents, <int>[1]);
    expect(secondEvents, <int>[1, 2]);

    await second.cancel();
    final restoredEvents = <int>[];
    final restored = value.listen(restoredEvents.add);
    value.value = 3;
    await Future<void>.delayed(Duration.zero);

    expect(restoredEvents, <int>[3]);
    await restored.cancel();
    value.close();
  });
}
