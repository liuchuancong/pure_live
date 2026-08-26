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
    expect(video.height, greaterThan(390 / (16 / 9)));
    expect(danmaku.height, greaterThanOrEqualTo(200));
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
