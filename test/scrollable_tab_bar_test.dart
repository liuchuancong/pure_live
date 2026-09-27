import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/widgets/scrollable_tab_bar.dart';

void main() {
  testWidgets('the first mouse-wheel turn scrolls the tabs and not the page behind them', (tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final page = ScrollController();
    addTearDown(page.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 30,
          child: Scaffold(
            body: ListView(
              controller: page,
              children: [
                ScrollableTabBar(
                  key: const ValueKey('tabs'),
                  isScrollable: true,
                  tabs: [for (var i = 0; i < 30; i++) Tab(text: 'Platform $i')],
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      ),
    );

    ScrollPosition tabs() => tester
        .state<ScrollableState>(
          find.descendant(of: find.byKey(const ValueKey('tabs')), matching: find.byType(Scrollable)),
        )
        .position;
    expect(tabs().pixels, 0);

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(tester.getCenter(find.byKey(const ValueKey('tabs')))));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
    await tester.pumpAndSettle();

    expect(tabs().pixels, greaterThan(0), reason: 'no earlier scroll notification is needed');
    expect(page.offset, 0, reason: 'the page does not scroll with the tabs');
  });
}
