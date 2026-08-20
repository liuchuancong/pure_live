import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_list_view.dart';

void main() {
  final metrics = FixedScrollMetrics(
    minScrollExtent: 0,
    maxScrollExtent: 1000,
    pixels: 0,
    viewportDimension: 400,
    axisDirection: AxisDirection.down,
    devicePixelRatio: 1,
  );

  test('the first Android drag pauses live following before it moves', () {
    final notification = ScrollStartNotification(
      metrics: metrics,
      context: null,
      dragDetails: DragStartDetails(globalPosition: Offset.zero),
    );
    expect(isDanmakuUserScrollStart(notification), isTrue);
  });

  test('programmatic scroll start does not pause live following', () {
    final notification = ScrollStartNotification(metrics: metrics, context: null);
    expect(isDanmakuUserScrollStart(notification), isFalse);
  });

  testWidgets('mouse wheel user direction pauses live following immediately', (tester) async {
    const targetKey = ValueKey('target');
    await tester.pumpWidget(const MaterialApp(home: SizedBox(key: targetKey)));
    final notification = UserScrollNotification(
      metrics: metrics,
      context: tester.element(find.byKey(targetKey)),
      direction: ScrollDirection.forward,
    );
    expect(isDanmakuUserScrollStart(notification), isTrue);
  });
}
