import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/base/local_reactive_page_controller.dart';

class _TestLocalController extends LocalReactivePageController<int> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first empty snapshot leaves the indeterminate loading state', () {
    final controller = _TestLocalController();

    controller.updateLocalReactivePool(const <int>[]);

    expect(controller.totalCount.value, 0);
    expect(controller.pageEmpty.value, isTrue);
    expect(controller.list, isEmpty);
  });

  test('refresh waits for the external snapshot transaction', () async {
    final controller = _TestLocalController();
    final gate = Completer<void>();
    var finished = false;
    controller.onExternalRefresh = () async {
      await gate.future;
      controller.updateLocalReactivePool([1, 2, 3]);
      finished = true;
    };

    final operation = controller.refreshData();
    await Future<void>.delayed(Duration.zero);
    expect(finished, isFalse);

    gate.complete();
    await operation;
    expect(finished, isTrue);
    expect(controller.list, [1, 2, 3]);
  });
}
