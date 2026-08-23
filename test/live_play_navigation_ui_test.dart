import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_tab.dart';
import 'package:pure_live/modules/live_play/widgets/content_first_panel_layout.dart';
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

  test('Android fullscreen places time and battery beside Back after swapping PiP', () {
    expect(resolveTopActionLeadingSlots(fullscreen: true, android: true), const <TopActionLeadingSlot>[
      TopActionLeadingSlot.back,
      TopActionLeadingSlot.datetime,
      TopActionLeadingSlot.battery,
    ]);
    expect(resolveTopActionLeadingSlots(fullscreen: true, android: false), const <TopActionLeadingSlot>[
      TopActionLeadingSlot.back,
    ]);
    expect(resolveTopActionLeadingSlots(fullscreen: false, android: true), isEmpty);
  });

  test('Android keeps audio, cast and PiP in the same trailing order in every orientation', () {
    for (final fullscreen in <bool>[false, true]) {
      final slots = resolveTopActionTrailingSlots(fullscreen: fullscreen, android: true, windows: false);
      expect(slots.sublist(slots.length - 3), const <TopActionTrailingSlot>[
        TopActionTrailingSlot.audioOnly,
        TopActionTrailingSlot.cast,
        TopActionTrailingSlot.pip,
      ]);
    }
  });

  test('landscape playback panels reserve most of a phone viewport for primary content', () {
    const viewport = Size(915, 412);
    final rooms = resolveContentFirstPanelLayout(viewport, ContentFirstPanelKind.roomHistory);
    final streams = resolveContentFirstPanelLayout(viewport, ContentFirstPanelKind.streamSelector);
    final style = resolveContentFirstPanelLayout(viewport, ContentFirstPanelKind.localDanmakuStyle);

    expect(rooms.size.width / viewport.width, greaterThan(.9));
    expect(rooms.size.height / viewport.height, greaterThan(.9));
    expect(streams.size.width / viewport.width, greaterThan(.7));
    expect(style.size.width / viewport.width, greaterThan(.8));
    expect(streams.splitContent, isTrue);
    expect(style.splitContent, isTrue);
  });
}
