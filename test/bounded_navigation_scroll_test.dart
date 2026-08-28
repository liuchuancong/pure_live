import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/widgets/pure_live_scroll_physics.dart';

void main() {
  test('bounded physics clamps an offset when selector contents shrink', () {
    const physics = PureLiveBoundedScrollPhysics();
    final oldMetrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 1200,
      pixels: 900,
      viewportDimension: 320,
      axisDirection: AxisDirection.right,
      devicePixelRatio: 1,
    );
    final newMetrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 160,
      pixels: 900,
      viewportDimension: 320,
      axisDirection: AxisDirection.right,
      devicePixelRatio: 1,
    );

    expect(
      physics.adjustPositionForNewDimensions(
        oldPosition: oldMetrics,
        newPosition: newMetrics,
        isScrolling: false,
        velocity: 0,
      ),
      160,
    );
  });

  testWidgets('scrollable navigation tabs stop at both horizontal edges', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 120));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 16,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: TabBar(
                key: const ValueKey('bounded-tabs'),
                isScrollable: true,
                physics: const PureLiveBoundedScrollPhysics(),
                tabs: List<Tab>.generate(16, (index) => Tab(text: 'Category $index')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('bounded-tabs')),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;

    await tester.drag(scrollable, const Offset(-5000, 0));
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(position.maxScrollExtent, 0.01));

    final maximum = position.maxScrollExtent;
    await tester.drag(scrollable, const Offset(-5000, 0));
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(maximum, 0.01));

    await tester.drag(scrollable, const Offset(5000, 0));
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(position.minScrollExtent, 0.01));
  });

  testWidgets('paged navigation stops at the first and last page', (tester) async {
    late TabController controller;
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 3,
          animationDuration: pureLiveTabTransitionDuration,
          child: Builder(
            builder: (context) {
              controller = DefaultTabController.of(context);
              return const Scaffold(
                body: TabBarView(
                  physics: PureLiveBoundedScrollPhysics(),
                  children: [Text('first'), Text('second'), Text('last')],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pages = find.byType(TabBarView);
    await tester.drag(pages, const Offset(1600, 0));
    await tester.pumpAndSettle();
    expect(controller.index, 0);

    controller.animateTo(2);
    await tester.pumpAndSettle();
    await tester.drag(pages, const Offset(-1600, 0));
    await tester.pumpAndSettle();
    expect(controller.index, 2);
  });
}
