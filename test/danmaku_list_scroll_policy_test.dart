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

  test('phone danmaku surface is edge-to-edge while desktop keeps panel chrome', () {
    expect(useEdgeToEdgeDanmakuList(390), isTrue);
    expect(useEdgeToEdgeDanmakuList(680), isTrue);
    expect(useEdgeToEdgeDanmakuList(681), isFalse);
  });

  test('programmatic scroll start does not pause live following', () {
    final notification = ScrollStartNotification(metrics: metrics, context: null);
    expect(isDanmakuUserScrollStart(notification), isFalse);
  });

  test('pointer-down invalidates a tail jump queued by the previous frame', () {
    final guard = DanmakuTailFollowGuard();
    final queuedRevision = guard.capture();

    guard.invalidate();

    expect(guard.isCurrent(queuedRevision), isFalse);
    expect(guard.isCurrent(guard.capture()), isTrue);
  });

  test('a stale PiP drag notification without a live pointer is ignored', () {
    final notification = ScrollStartNotification(
      metrics: metrics,
      context: null,
      dragDetails: DragStartDetails(globalPosition: Offset.zero),
    );

    expect(isDanmakuUserScrollStart(notification, hasActivePointer: false), isFalse);
    expect(isDanmakuUserScrollStart(notification, hasActivePointer: true), isTrue);
  });

  testWidgets('Android PiP viewport direction event does not pause live following', (tester) async {
    const targetKey = ValueKey('target');
    await tester.pumpWidget(const MaterialApp(home: SizedBox(key: targetKey)));
    final notification = UserScrollNotification(
      metrics: metrics,
      context: tester.element(find.byKey(targetKey)),
      direction: ScrollDirection.forward,
    );
    expect(isDanmakuUserScrollStart(notification), isFalse);
  });

  testWidgets('desktop mouse wheel user direction pauses live following immediately', (
    tester,
  ) async {
    const targetKey = ValueKey('desktop-target');
    await tester.pumpWidget(const MaterialApp(home: SizedBox(key: targetKey)));
    final notification = UserScrollNotification(
      metrics: metrics,
      context: tester.element(find.byKey(targetKey)),
      direction: ScrollDirection.forward,
    );
    expect(isDanmakuUserScrollStart(notification, acceptDirectionOnlyUserScroll: true), isTrue);
  });

  testWidgets('PiP return follow state survives the Android viewport notification', (tester) async {
    const targetKey = ValueKey('pip-return-target');
    await tester.pumpWidget(const MaterialApp(home: SizedBox(key: targetKey)));

    // The PiP worker re-enables following before Android reattaches the list
    // viewport. The following direction notification is framework-generated,
    // not a finger drag, and must not cancel the restored state.
    var autoScrollEnabled = true;
    final viewportNotification = UserScrollNotification(
      metrics: metrics,
      context: tester.element(find.byKey(targetKey)),
      direction: ScrollDirection.forward,
    );
    if (isDanmakuUserScrollStart(viewportNotification)) {
      autoScrollEnabled = false;
    }

    expect(autoScrollEnabled, isTrue);

    // A subsequent real drag still lets the user pause the live list.
    final fingerDrag = ScrollStartNotification(
      metrics: metrics,
      context: tester.element(find.byKey(targetKey)),
      dragDetails: DragStartDetails(globalPosition: Offset.zero),
    );
    if (isDanmakuUserScrollStart(fingerDrag)) {
      autoScrollEnabled = false;
    }
    expect(autoScrollEnabled, isFalse);
  });

  test('emoji token cache remains bounded during long unique chat sessions', () {
    emojiCache.clear();

    for (var i = 0; i < emojiTokenCacheCapacity + 200; i++) {
      parseEmojis('unique live message $i', 14, Colors.white);
    }

    expect(emojiCache.length, emojiTokenCacheCapacity);
    expect(emojiCache.containsKey('unique live message 0'), isFalse);
    expect(emojiCache.containsKey('unique live message ${emojiTokenCacheCapacity + 199}'), isTrue);
  });
}
