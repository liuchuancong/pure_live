import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/widgets/recorder_bounded_scroll.dart';

void main() {
  testWidgets('recorder status tabs clamp at their horizontal boundaries', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 9,
          child: Scaffold(
            appBar: AppBar(
              bottom: const RecorderStatusTabBar(
                labels: <String>['全部', '录制中', '等待开播', '队列', '重连', '处理中', '已完成', '失败', '已停止'],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.descendant(of: find.byType(RecorderStatusTabBar), matching: find.byType(Scrollable));
    final position = tester.state<ScrollableState>(scrollable).position;
    await tester.drag(scrollable, const Offset(2000, 0));
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(position.minScrollExtent, 0.01));

    await tester.drag(scrollable, const Offset(-5000, 0));
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(position.maxScrollExtent, 0.01));
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

    final scrollable = find.descendant(of: find.byType(RecorderBoundedTaskList), matching: find.byType(Scrollable));
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

    final scrollable = find.descendant(of: find.byType(RecorderBoundedTaskList), matching: find.byType(Scrollable));
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.minScrollExtent, position.maxScrollExtent);
    await tester.drag(scrollable, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(position.pixels, position.minScrollExtent);
  });
}
