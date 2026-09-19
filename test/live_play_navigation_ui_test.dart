import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_tab.dart';
import 'package:pure_live/modules/live_play/widgets/content_first_panel_layout.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller_panel.dart';
import 'package:pure_live/modules/live_play/states/ui_state.dart';

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

  test('player expansion controls expose stable accessibility action labels', () {
    expect(fullscreenActionLabelKey(false), 'enter_fullscreen');
    expect(fullscreenActionLabelKey(true), 'exit_fullscreen');
    expect(playerWindowActionLabelKey(false), 'expand_player_window');
    expect(playerWindowActionLabelKey(true), 'collapse_player_window');
  });

  test('visible playback bars reserve their hit area from danmaku interactions', () {
    const size = Size(800, 450);

    expect(
      shouldHandleVideoSurfaceTap(localPosition: const Offset(400, 20), surfaceSize: size, controlsVisible: true),
      isFalse,
      reason: 'top actions such as audio, cast and PiP must keep the tap',
    );
    expect(
      shouldHandleVideoSurfaceTap(localPosition: const Offset(400, 430), surfaceSize: size, controlsVisible: true),
      isFalse,
      reason: 'bottom playback actions must keep the tap',
    );
    expect(
      shouldHandleVideoSurfaceTap(localPosition: const Offset(400, 225), surfaceSize: size, controlsVisible: true),
      isTrue,
    );
    expect(
      shouldHandleVideoSurfaceTap(localPosition: const Offset(400, 20), surfaceSize: size, controlsVisible: false),
      isTrue,
      reason: 'hidden bars leave the whole video surface interactive',
    );
  });

  test('portrait fullscreen reserves a two-row bottom controller while other modes keep one row', () {
    expect(resolveBottomActionBarHeight(VideoMode.portraitFullscreen), portraitFullscreenBottomBarHeight);
    expect(resolveBottomActionBarHeight(VideoMode.normal), 56);

    const size = Size(360, 780);
    expect(
      shouldHandleVideoSurfaceTap(
        localPosition: const Offset(300, 700),
        surfaceSize: size,
        controlsVisible: true,
        controlBarHeight: resolveBottomActionBarHeight(VideoMode.portraitFullscreen),
      ),
      isFalse,
      reason: 'both portrait controller rows must receive taps instead of the video/danmaku layer',
    );
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

  test('phone stream selector derives its whole height from both button grids', () {
    final common = resolveStreamSelectorPanelLayout(
      maximumDialogSize: const Size(449.5, 396),
      qualityCount: 4,
      lineCount: 6,
      splitContent: false,
    );
    expect(common.dialogHeight, 305);
    expect(common.qualityHeight, 126);
    expect(common.lineHeight, 126);

    final shortLists = resolveStreamSelectorPanelLayout(
      maximumDialogSize: const Size(449.5, 396),
      qualityCount: 1,
      lineCount: 1,
      splitContent: false,
    );
    expect(shortLists.dialogHeight, 211, reason: 'one quality and one line must not leave a full-height blank dialog');

    final manyChoices = resolveStreamSelectorPanelLayout(
      maximumDialogSize: const Size(449.5, 396),
      qualityCount: 12,
      lineCount: 18,
      splitContent: false,
    );
    expect(manyChoices.dialogHeight, 396);
    expect(manyChoices.qualityHeight, greaterThanOrEqualTo(78));
    expect(manyChoices.lineHeight, greaterThanOrEqualTo(78));

    final wide = resolveStreamSelectorPanelLayout(
      maximumDialogSize: const Size(700, 396),
      qualityCount: 4,
      lineCount: 6,
      splitContent: true,
    );
    expect(wide.splitContent, isTrue);
    expect(wide.dialogHeight, 221);
    expect(wide.qualityHeight, 173);
    expect(wide.lineHeight, 173);
  });

  test('stream selector reserves scaled title and choice rows at accessibility text sizes', () {
    final metrics = resolveStreamSelectorTextMetrics(textScaler: const TextScaler.linear(3));
    final layout = resolveStreamSelectorPanelLayout(
      maximumDialogSize: const Size(449.5, 396),
      qualityCount: 4,
      lineCount: 6,
      splitContent: false,
      textMetrics: metrics,
    );

    expect(metrics.dialogTitleRowHeight, greaterThan(35));
    expect(metrics.paneHeaderHeight, greaterThan(23));
    expect(metrics.itemHeight, greaterThan(42));
    expect(layout.dialogHeight, 396);
    expect(layout.qualityHeight, greaterThanOrEqualTo(metrics.minimumPaneHeight));
    expect(layout.lineHeight, greaterThanOrEqualTo(metrics.minimumPaneHeight));

    final shortViewport = resolveStreamSelectorPanelLayout(
      maximumDialogSize: const Size(300, 240),
      qualityCount: 12,
      lineCount: 18,
      splitContent: false,
      textMetrics: metrics,
    );
    final availableBodyHeight = 240 - metrics.dialogChromeHeight - 12;
    expect(
      shortViewport.qualityHeight + shortViewport.gap + shortViewport.lineHeight,
      lessThanOrEqualTo(availableBodyHeight),
    );
  });

  testWidgets('stream choice pane keeps 3x labels inside scaled rows', (tester) async {
    late StreamSelectorTextMetrics metrics;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            final textTheme = Theme.of(context).textTheme;
            metrics = resolveStreamSelectorTextMetrics(
              textScaler: const TextScaler.linear(3),
              paneTitleFontSize: textTheme.labelLarge?.fontSize ?? 14,
              paneTitleLineHeight: textTheme.labelLarge?.height ?? 1.25,
              itemFontSize: textTheme.bodyMedium?.fontSize ?? 14,
              itemLineHeight: textTheme.bodyMedium?.height ?? 1.25,
            );
            return Scaffold(
              body: Center(
                child: SizedBox(
                  width: 260,
                  height: metrics.minimumPaneHeight + 16,
                  child: StreamChoicePane(
                    icon: Icons.high_quality_rounded,
                    title: 'Quality',
                    itemCount: 2,
                    selectedIndex: 0,
                    labelBuilder: (index) => index == 0 ? 'Original' : 'High definition',
                    textMetrics: metrics,
                    onSelected: null,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(const ValueKey('stream-choice-0'))).height, metrics.itemHeight);
    expect(find.text('Quality'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('local style keeps its preview/settings split on a smaller landscape phone', () {
    const viewport = Size(720, 360);
    final style = resolveContentFirstPanelLayout(viewport, ContentFirstPanelKind.localDanmakuStyle);
    expect(style.splitContent, isTrue);
    expect(style.size.width / viewport.width, inInclusiveRange(.47, .51));
  });

  test('fullscreen local composer follows the global interaction switch', () {
    expect(shouldShowFullscreenLocalDanmakuComposer(false), isFalse);
    expect(shouldShowFullscreenLocalDanmakuComposer(true), isTrue);
  });

  test('large landscape windows keep dense panels split internally', () {
    const viewport = Size(1920, 1080);
    for (final kind in ContentFirstPanelKind.values) {
      expect(resolveContentFirstPanelLayout(viewport, kind).splitContent, isTrue);
    }
  });
}
