import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_content.dart';

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

  testWidgets('video-only sites do not reserve an empty interaction panel', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(fixture(showPanel: false));

    expect(find.byKey(const ValueKey('live-play-video-only-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('resolution')), findsNothing);
    expect(find.byKey(const ValueKey('danmaku')), findsNothing);
  });
}
