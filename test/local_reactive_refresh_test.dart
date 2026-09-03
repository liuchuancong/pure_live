import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:pure_live/common/base/base_page_view.dart';
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

  testWidgets('tabbed content remains mounted after an empty filtered snapshot', (tester) async {
    final controller = _TestLocalController();
    final pageController = PageController();
    controller.updateLocalReactivePool(const <int>[1]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BasePageView<_TestLocalController, int>(
            controller: controller,
            enableRefresh: false,
            enableLoadMore: false,
            preserveContentWhenEmpty: true,
            showScrollToTopBtn: false,
            contentBuilder: (context, list, scrollController) => PageView(
              key: const ValueKey('persistent-empty-tab-view'),
              controller: pageController,
              children: const [
                SizedBox.expand(key: ValueKey('first-tab')),
                SizedBox.expand(key: ValueKey('second-tab')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    controller.updateLocalReactivePool(const <int>[]);
    await tester.pump();
    expect(find.byKey(const ValueKey('persistent-empty-tab-view')), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('persistent-empty-tab-view')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(pageController.page, closeTo(1, 0.001));

    await tester.pumpWidget(const SizedBox.shrink());
    pageController.dispose();
    controller.onClose();
  });

  testWidgets('nested mobile pages can own the refresh wrapper', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _TestLocalController()..updateLocalReactivePool(const <int>[1]);
    addTearDown(controller.onClose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BasePageView<_TestLocalController, int>(
            controller: controller,
            enableLoadMore: false,
            wrapMobileRefresh: false,
            showScrollToTopBtn: false,
            contentBuilder: (context, list, scrollController) => ListView(
              key: const ValueKey('nested-refresh-owner'),
              controller: scrollController,
              children: const [SizedBox(height: 900)],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('nested-refresh-owner')), findsOneWidget);
    expect(find.byType(EasyRefresh), findsNothing);
  });
}
