import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_content.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_video.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';

void main() {
  Widget fixture({bool showPanel = true}) {
    return MaterialApp(
      home: Scaffold(
        body: LivePlayNormalLayout(
          showPanel: showPanel,
          video: const SizedBox(key: ValueKey('video'), width: double.infinity, height: 180),
          resolution: const SizedBox(key: ValueKey('resolution'), width: double.infinity, height: 44),
          danmaku: const SizedBox(key: ValueKey('danmaku'), width: double.infinity, height: double.infinity),
        ),
      ),
    );
  }

  test('normal live layout uses the stable phone stack through the compact breakpoint', () {
    expect(resolveLivePlayNormalLayout(390), LivePlayNormalLayoutKind.portraitStack);
    expect(resolveLivePlayNormalLayout(680), LivePlayNormalLayoutKind.portraitStack);
    expect(resolveLivePlayNormalLayout(681), LivePlayNormalLayoutKind.desktopSplit);
  });

  testWidgets('phone room keeps video, quality and danmaku visible together', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(fixture());

    expect(find.byKey(const ValueKey('live-play-portrait-stack')), findsOneWidget);
    expect(find.byKey(const ValueKey('video')), findsOneWidget);
    expect(find.byKey(const ValueKey('resolution')), findsOneWidget);
    expect(find.byKey(const ValueKey('danmaku')), findsOneWidget);
    expect(find.byKey(const ValueKey('live-play-adaptive-video-frame')), findsNothing);

    final video = tester.getRect(find.byKey(const ValueKey('video')));
    final resolution = tester.getRect(find.byKey(const ValueKey('resolution')));
    final danmaku = tester.getRect(find.byKey(const ValueKey('danmaku')));
    expect(video.top, 0);
    expect(video.width, 390);
    expect(resolution.top, video.bottom);
    expect(danmaku.top, greaterThanOrEqualTo(resolution.bottom));
    expect(danmaku.height, greaterThan(0));
  });

  testWidgets('desktop room keeps a bounded visible side panel', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(fixture());

    expect(find.byKey(const ValueKey('live-play-desktop-split')), findsOneWidget);
    final video = tester.getRect(find.byKey(const ValueKey('video')));
    final panel = tester.getRect(find.byKey(const ValueKey('live-play-desktop-panel')));
    final resolution = tester.getRect(find.byKey(const ValueKey('resolution')));
    final danmaku = tester.getRect(find.byKey(const ValueKey('danmaku')));
    expect(panel.width, inInclusiveRange(300, 400));
    expect(video.right, panel.left);
    expect(resolution.width, panel.width);
    expect(danmaku.height, greaterThan(0));
  });

  testWidgets('portrait source grows video but preserves the interaction list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LivePlayNormalLayout(
            isPortraitSource: true,
            sourceAspectRatio: 9 / 16,
            adaptivePortraitHeight: true,
            portraitLayoutMode: PortraitLayoutMode.balanced,
            video: const ColoredBox(key: ValueKey('portrait-video'), color: Colors.black),
            resolution: const SizedBox(height: 44),
            danmaku: const ColoredBox(key: ValueKey('portrait-danmaku'), color: Colors.white),
          ),
        ),
      ),
    );

    final video = tester.getRect(find.byKey(const ValueKey('portrait-video')));
    final danmaku = tester.getRect(find.byKey(const ValueKey('portrait-danmaku')));
    expect(find.byKey(const ValueKey('live-play-adaptive-video-frame')), findsOneWidget);
    expect(find.byKey(const ValueKey('live-play-portrait-sheet')), findsOneWidget);
    expect(video.height, 780);
    expect(danmaku.height, greaterThanOrEqualTo(200));
  });

  testWidgets('portrait interaction sheet has bounded drag stops independent from list scrolling', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PortraitLiveRoomLayout(
            mode: PortraitLayoutMode.balanced,
            video: ColoredBox(color: Colors.black),
            resolution: SizedBox(height: 44),
            danmaku: ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );

    final before = tester.getSize(find.byKey(const ValueKey('live-play-portrait-sheet'))).height;
    await tester.drag(find.byKey(const ValueKey('live-play-portrait-sheet-handle')), const Offset(0, -180));
    await tester.pump();
    final after = tester.getSize(find.byKey(const ValueKey('live-play-portrait-sheet'))).height;
    final range = portraitPanelRange(780, PortraitLayoutMode.balanced);
    expect(after, greaterThan(before));
    expect(after, inInclusiveRange(range.minimum, range.maximum));
  });

  testWidgets('portrait room keeps an explicit landscape fullscreen action above the sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var requested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PortraitLiveRoomLayout(
            mode: PortraitLayoutMode.balanced,
            video: const ColoredBox(color: Colors.black),
            resolution: const SizedBox(height: 44),
            danmaku: const ColoredBox(color: Colors.white),
            onEnterLandscapeFullscreen: () => requested = true,
          ),
        ),
      ),
    );

    final action = find.byKey(const ValueKey('portrait-landscape-fullscreen'));
    final sheet = tester.getRect(find.byKey(const ValueKey('live-play-portrait-sheet')));
    expect(action, findsOneWidget);
    expect(tester.getRect(action).bottom, lessThan(sheet.top));
    await tester.tap(action);
    expect(requested, isTrue);
  });

  testWidgets('portrait fullscreen presentation keeps its child above the ambient layer', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PortraitFullscreenPresentation(
          coverUrl: '',
          child: ColoredBox(key: ValueKey('portrait-fullscreen-video'), color: Colors.transparent),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('fullscreen-portrait-presentation')), findsOneWidget);
    expect(find.byKey(const ValueKey('fullscreen-portrait-ambient-fallback')), findsOneWidget);
    expect(find.byKey(const ValueKey('portrait-fullscreen-video')), findsOneWidget);
  });

  test('portrait fullscreen background falls back through cover and avatar metadata', () {
    expect(
      resolvePortraitFullscreenBackgroundUrl(
        detailCover: '  ',
        roomCover: '',
        detailAvatar: 'https://example.invalid/detail-avatar.jpg',
        roomAvatar: 'https://example.invalid/room-avatar.jpg',
      ),
      'https://example.invalid/detail-avatar.jpg',
    );
    expect(
      resolvePortraitFullscreenBackgroundUrl(
        detailCover: 'https://example.invalid/detail-cover.jpg',
        roomCover: 'https://example.invalid/room-cover.jpg',
      ),
      'https://example.invalid/detail-cover.jpg',
    );
  });

  testWidgets('generic live video keeps 16:9 unless its caller owns an explicit frame', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: LivePlayVideoFrame(
            expandToParent: false,
            child: ColoredBox(key: ValueKey('legacy-landscape-surface'), color: Colors.black),
          ),
        ),
      ),
    );

    final legacy = tester.getRect(find.byKey(const ValueKey('legacy-landscape-surface')));
    expect(legacy.width, 390);
    expect(legacy.height, closeTo(390 / (16 / 9), 0.01));

    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 390,
            height: 500,
            child: LivePlayVideoFrame(
              expandToParent: true,
              child: ColoredBox(key: ValueKey('owned-adaptive-surface'), color: Colors.black),
            ),
          ),
        ),
      ),
    );
    final adaptive = tester.getRect(find.byKey(const ValueKey('owned-adaptive-surface')));
    expect(adaptive.size, const Size(390, 500));
  });

  testWidgets('video-only sites do not reserve an empty interaction panel', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(fixture(showPanel: false));

    expect(find.byKey(const ValueKey('live-play-video-only-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('resolution')), findsNothing);
    expect(find.byKey(const ValueKey('danmaku')), findsNothing);
  });
}
