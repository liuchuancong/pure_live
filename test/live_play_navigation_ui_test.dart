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

  test('landscape playback panels occupy the compact right half of a phone viewport', () {
    const viewport = Size(915, 412);
    final rooms = resolveContentFirstPanelLayout(viewport, ContentFirstPanelKind.roomHistory);
    final streams = resolveContentFirstPanelLayout(viewport, ContentFirstPanelKind.streamSelector);
    final style = resolveContentFirstPanelLayout(viewport, ContentFirstPanelKind.localDanmakuStyle);

    expect(rooms.size.width / viewport.width, inInclusiveRange(.47, .51));
    expect(rooms.size.height / viewport.height, greaterThan(.9));
    expect(streams.size.width / viewport.width, inInclusiveRange(.47, .51));
    expect(style.size.width / viewport.width, inInclusiveRange(.47, .51));
    expect(style.size.height / viewport.height, greaterThan(.9));
    expect(streams.splitContent, isFalse);
    expect(style.splitContent, isTrue, reason: 'phone landscape keeps preview left and controls right');
    expect(resolveStreamChoiceColumns(streams.size.width - 24), 3);

    final roomGridSize = Size(rooms.size.width, rooms.size.height - 36 - 30 - 1);
    final cardHeight = resolveRoomHistoryCardHeight(contentSize: roomGridSize, columns: 2);
    expect(cardHeight * 2 + 6 * 2 + 5, lessThanOrEqualTo(roomGridSize.height));
  });

  test('stream choices scale down without dropping to a long single column', () {
    expect(resolveStreamChoiceColumns(420), 3);
    expect(resolveStreamChoiceColumns(260), 2);
    expect(resolveStreamChoiceColumns(180), 1);
    expect(resolveStreamChoiceColumns(420, itemCount: 4), 2, reason: 'four qualities form a balanced 2 x 2');
    expect(resolveStreamChoiceColumns(420, itemCount: 6), 3);
    expect(resolveStreamChoiceColumns(420, itemCount: 1), 1);
  });

  test('phone stream selector sizes quality to its rows and gives lines the remaining height', () {
    final common = resolveStreamSelectorStackLayout(contentSize: const Size(437, 345), qualityCount: 4);
    expect(common.qualityHeight, 108);
    expect(common.lineHeight, 232);
    expect(common.lineHeight, greaterThan(common.qualityHeight));
    expect(common.qualityHeight + common.gap + common.lineHeight, 345);

    final manyQualities = resolveStreamSelectorStackLayout(contentSize: const Size(437, 345), qualityCount: 12);
    expect(manyQualities.qualityHeight, 146);
    expect(manyQualities.lineHeight, greaterThanOrEqualTo(112));

    final shortViewport = resolveStreamSelectorStackLayout(contentSize: const Size(350, 180), qualityCount: 6);
    expect(shortViewport.lineHeight, greaterThanOrEqualTo(84));
  });

  test('local style keeps its preview/settings split on a smaller landscape phone', () {
    const viewport = Size(720, 360);
    final style = resolveContentFirstPanelLayout(viewport, ContentFirstPanelKind.localDanmakuStyle);
    expect(style.splitContent, isTrue);
    expect(style.size.width / viewport.width, inInclusiveRange(.47, .51));
  });

  test('large landscape windows keep dense panels split internally', () {
    const viewport = Size(1920, 1080);
    for (final kind in ContentFirstPanelKind.values) {
      expect(resolveContentFirstPanelLayout(viewport, kind).splitContent, isTrue);
    }
  });
}
