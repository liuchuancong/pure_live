import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/widgets/recorder_bounded_scroll.dart';

void main() {
  testWidgets('recorder status selector is fixed and switches explicitly', (tester) async {
    late TabController controller;
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 9,
          child: Builder(
            builder: (context) {
              controller = DefaultTabController.of(context);
              return const Scaffold(
                body: RecorderStatusSelector(
                  labels: <String>['全部', '录制中', '等待开播', '队列', '重连', '处理中', '已完成', '失败', '已停止'],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(RecorderStatusSelector), matching: find.byType(Scrollable)),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('recorder-status-8')));
    await tester.pumpAndSettle();
    expect(controller.index, 8);
  });

  testWidgets('recorder tasks clamp at their vertical boundaries', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecorderBoundedTaskList(
            itemCount: 30,
            itemBuilder: (_, index) => SizedBox(height: 80, child: Text('task $index')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(RecorderBoundedTaskList),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    await tester.drag(scrollable, const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(position.minScrollExtent, 0.01));

    await tester.drag(scrollable, const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(position.maxScrollExtent, 0.01));
  });

  testWidgets('short recorder task lists have no draggable vertical range', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecorderBoundedTaskList(
            itemCount: 1,
            itemBuilder: (_, index) => SizedBox(height: 80, child: Text('task $index')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(RecorderBoundedTaskList),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.minScrollExtent, position.maxScrollExtent);
    await tester.drag(scrollable, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(position.pixels, position.minScrollExtent);
  });

  testWidgets('recorder tasks clamp stale offset when the filtered list shrinks', (tester) async {
    var itemCount = 30;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return RecorderBoundedTaskList(
                itemCount: itemCount,
                itemBuilder: (_, index) => SizedBox(height: 80, child: Text('task $index')),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(RecorderBoundedTaskList),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    await tester.drag(scrollable, const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(position.maxScrollExtent, 0.01));

    rebuild(() => itemCount = 1);
    await tester.pumpAndSettle();
    expect(position.pixels, inInclusiveRange(position.minScrollExtent, position.maxScrollExtent));
    expect(position.minScrollExtent, position.maxScrollExtent);
  });
}
