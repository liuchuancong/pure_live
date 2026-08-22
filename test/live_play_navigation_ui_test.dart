import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_tab.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller_panel.dart';

void main() {
  testWidgets('portrait danmaku section tabs fill the row and stay horizontally fixed', (tester) async {
    const tabs = <String>['弹幕列表', '醒目留言', '弹幕设置', '屏蔽管理'];
    await tester.pumpWidget(
      const MaterialApp(
        home: DefaultTabController(
          length: 4,
          child: Scaffold(
            body: SizedBox(width: 360, child: DanmakuSectionTabBar(tabs: tabs)),
          ),
        ),
      ),
    );

    final finder = find.byKey(const ValueKey('live-danmaku-section-tabs'));
    final tabBar = tester.widget<TabBar>(finder);
    expect(tabBar.isScrollable, isFalse);
    expect(tabBar.tabAlignment, TabAlignment.fill);
    for (final label in tabs) {
      expect(find.text(label), findsOneWidget);
    }

    final before = tester.getRect(finder);
    await tester.drag(finder, const Offset(220, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(finder), before, reason: 'the section row itself must not pan horizontally');
  });

  test('Android fullscreen places the PiP shortcut beside Back in the leading group', () {
    expect(resolveTopActionLeadingSlots(fullscreen: true, android: true), const <TopActionLeadingSlot>[
      TopActionLeadingSlot.back,
      TopActionLeadingSlot.pip,
    ]);
    expect(resolveTopActionLeadingSlots(fullscreen: true, android: false), const <TopActionLeadingSlot>[
      TopActionLeadingSlot.back,
    ]);
    expect(resolveTopActionLeadingSlots(fullscreen: false, android: true), isEmpty);
  });
}
