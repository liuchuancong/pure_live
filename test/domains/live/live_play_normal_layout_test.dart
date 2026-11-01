import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/player/core/portrait_stream_support.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/layout/live_play_content.dart';

/// Issue #927 的几何回归。
///
/// 断言只看布局约束与尺寸关系，不依赖播放器、网络或设备：
/// - 需求 A：`兼容 16:9` 下视频区高度由源宽高比决定，上限为可用高度的 0.6；
///   「约 6:4」是这个上限，不是固定的容器比例或固定区域切分。
/// - 需求 B：`均衡模式` 下弹幕区高度变化时，视频区必须用剩余空间重算，
///   而不是被弹幕面板盖住。
/// - 需求 C：宽窗口按直播源方向选择左右 / 上下分屏。
///
/// 生产代码传入的视频组件有两种形态，测试必须与之对齐，否则约束本身就不可比：
/// `expandToParent` 为真时是撑满父级的 surface（兼容模式 / 自适应竖屏面板），
/// 为假时是自带宽高比的 16:9 画面（普通堆叠 / 宽窗口左右分屏）。
const Key _videoKey = Key('probe-video');
const Key _danmakuKey = Key('probe-danmaku');

const double _resolutionHeight = 48;

Widget _probe(Key key) => SizedBox.expand(
  key: key,
  child: const ColoredBox(color: Color(0xFF102030)),
);

Widget _videoProbe({required bool expand}) => expand
    ? SizedBox.expand(
        key: _videoKey,
        child: const ColoredBox(color: Color(0xFF102030)),
      )
    : AspectRatio(
        key: _videoKey,
        aspectRatio: 16 / 9,
        child: const ColoredBox(color: Color(0xFF102030)),
      );

Widget _layout({
  required bool isPortraitSource,
  required double sourceAspectRatio,
  PortraitLayoutMode mode = PortraitLayoutMode.balanced,
  bool adaptivePortraitHeight = true,
  bool splitBySourceOrientation = false,
  double landscapeDanmakuHeight = LivePlayNormalLayout.defaultLandscapeDanmakuHeight,
  // 生产代码里 expandToParent 由 `!narrowWindow` 决定，宽窗口的两种拓扑都自己
  // 控制视频框（源比例 + 弹幕保底高度）。默认跟随窗口宽度，个别窄窗口场景显式覆盖。
  bool? expandVideo,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          final wide = MediaQuery.sizeOf(context).width > livePlayPortraitStackMaxWidth;
          return LivePlayNormalLayout(
            video: _videoProbe(expand: expandVideo ?? wide),
            resolution: const SizedBox(height: _resolutionHeight),
            danmaku: _probe(_danmakuKey),
            isPortraitSource: isPortraitSource,
            sourceAspectRatio: sourceAspectRatio,
            adaptivePortraitHeight: adaptivePortraitHeight,
            portraitLayoutMode: mode,
            splitBySourceOrientation: splitBySourceOrientation,
            landscapeDanmakuHeight: landscapeDanmakuHeight,
          );
        },
      ),
    ),
  );
}

/// 固定测试视口，避免默认 800×600 窗口把请求的尺寸截断。
void _useViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

void main() {
  group('resolveLivePlayNormalLayout', () {
    test('窄窗口始终上下堆叠', () {
      for (final portrait in [true, false]) {
        expect(
          resolveLivePlayNormalLayout(width: 360, isPortraitSource: portrait, splitBySourceOrientation: true),
          LivePlayNormalLayoutKind.portraitStack,
        );
      }
      expect(
        resolveLivePlayNormalLayout(
          width: livePlayPortraitStackMaxWidth,
          isPortraitSource: false,
          splitBySourceOrientation: true,
        ),
        LivePlayNormalLayoutKind.portraitStack,
      );
    });

    test('宽窗口按直播源方向选择分屏拓扑', () {
      expect(
        resolveLivePlayNormalLayout(width: 900, isPortraitSource: true, splitBySourceOrientation: true),
        LivePlayNormalLayoutKind.desktopSplit,
      );
      expect(
        resolveLivePlayNormalLayout(width: 900, isPortraitSource: false, splitBySourceOrientation: true),
        LivePlayNormalLayoutKind.landscapeStack,
      );
      expect(
        resolveLivePlayNormalLayout(
          width: livePlayPortraitStackMaxWidth + 0.5,
          isPortraitSource: false,
          splitBySourceOrientation: true,
        ),
        LivePlayNormalLayoutKind.landscapeStack,
      );
    });

    test('未开启源方向分屏的平台保持原有左右分屏', () {
      expect(resolveLivePlayNormalLayout(width: 900, isPortraitSource: false), LivePlayNormalLayoutKind.desktopSplit);
      expect(resolveLivePlayNormalLayout(width: 900, isPortraitSource: true), LivePlayNormalLayoutKind.desktopSplit);
    });
  });

  group('resolveCompatibilityVideoHeight', () {
    test('竖屏源受 0.6 上限约束，而不是按源比例拉满', () {
      // 360 / (9/16) = 640 > 700 * 0.6 = 420
      expect(
        resolveCompatibilityVideoHeight(availableWidth: 360, availableHeight: 700, sourceAspectRatio: 9 / 16),
        closeTo(420, 0.01),
      );
    });

    test('横屏源沿用自身 16:9 高度', () {
      // 360 / (16/9) = 202.5 < 420
      expect(
        resolveCompatibilityVideoHeight(availableWidth: 360, availableHeight: 700, sourceAspectRatio: 16 / 9),
        closeTo(202.5, 0.01),
      );
    });

    test('源比例未知或非法时退回 16:9', () {
      for (final ratio in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          resolveCompatibilityVideoHeight(availableWidth: 360, availableHeight: 700, sourceAspectRatio: ratio),
          closeTo(202.5, 0.01),
          reason: 'ratio=$ratio',
        );
      }
    });

    test('极端窄高约束不会挤掉画质栏与弹幕区', () {
      final height = resolveCompatibilityVideoHeight(
        availableWidth: 360,
        availableHeight: 100,
        sourceAspectRatio: 9 / 16,
      );
      expect(height, lessThanOrEqualTo(100 - 56));
      expect(height, greaterThanOrEqualTo(0));
    });

    test('零宽返回 0 而不是 NaN', () {
      expect(resolveCompatibilityVideoHeight(availableWidth: 0, availableHeight: 700, sourceAspectRatio: 9 / 16), 0);
    });
  });

  group('LivePlayNormalLayout · 兼容 16:9（需求 A）', () {
    testWidgets('T1 竖屏源：画面按源比例完整显示，弹幕区仍有可用高度', (tester) async {
      _useViewport(tester, const Size(360, 700));
      await tester.pumpWidget(
        _layout(
          isPortraitSource: true,
          sourceAspectRatio: 9 / 16,
          mode: PortraitLayoutMode.compatibility,
          expandVideo: true,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('live-play-compatibility-video')), findsOneWidget);
      expect(find.byKey(const ValueKey('live-play-portrait-danmaku')), findsOneWidget);

      final video = tester.getSize(find.byKey(_videoKey));
      final danmaku = tester.getSize(find.byKey(_danmakuKey));

      // 视频区 = min(360/(9/16), 0.6*700) = 420，而不是固定的 16:9 高度 202.5。
      expect(video.width, closeTo(360, 0.01));
      expect(video.height, closeTo(420, 0.01));
      // 弹幕区拿到剩余空间，不会被压成一两条。
      expect(danmaku.height, closeTo(700 - 420 - _resolutionHeight - 1, 0.01));
      expect(danmaku.height, greaterThan(200));
    });

    testWidgets('T10 横屏源：兼容 16:9 不改变原有画面比例与弹幕布局', (tester) async {
      _useViewport(tester, const Size(360, 700));
      await tester.pumpWidget(
        _layout(
          isPortraitSource: false,
          sourceAspectRatio: 16 / 9,
          mode: PortraitLayoutMode.compatibility,
          expandVideo: true,
        ),
      );

      expect(tester.takeException(), isNull);
      final video = tester.getSize(find.byKey(_videoKey));
      expect(video.height, closeTo(202.5, 0.01));
      expect(tester.getSize(find.byKey(_danmakuKey)).height, closeTo(700 - 202.5 - _resolutionHeight - 1, 0.01));
    });

    testWidgets('T11 源尺寸未知：使用稳定回退且不溢出', (tester) async {
      _useViewport(tester, const Size(360, 700));
      await tester.pumpWidget(
        _layout(
          isPortraitSource: false,
          sourceAspectRatio: double.nan,
          mode: PortraitLayoutMode.compatibility,
          expandVideo: true,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(_videoKey)).height, closeTo(202.5, 0.01));
    });

    testWidgets('T16 极端窗口尺寸不溢出', (tester) async {
      for (final size in const [Size(320, 240), Size(240, 180), Size(900, 260)]) {
        _useViewport(tester, size);
        await tester.pumpWidget(
          _layout(
            isPortraitSource: true,
            sourceAspectRatio: 9 / 16,
            mode: PortraitLayoutMode.compatibility,
            expandVideo: true,
          ),
        );
        expect(tester.takeException(), isNull, reason: 'size=$size');
      }
    });
  });

  group('LivePlayNormalLayout · 均衡模式（需求 B）', () {
    testWidgets('T2/T3 弹幕区高度变化时视频区用剩余空间重算', (tester) async {
      const size = Size(360, 700);
      _useViewport(tester, size);
      await tester.pumpWidget(_layout(isPortraitSource: true, sourceAspectRatio: 9 / 16, expandVideo: true));
      expect(tester.takeException(), isNull);

      final range = portraitPanelRange(size.height, PortraitLayoutMode.balanced);

      double sheetHeight() => tester.getSize(find.byKey(const ValueKey('live-play-portrait-sheet'))).height;
      double videoHeight() => tester.getSize(find.byKey(_videoKey)).height;

      // 初始：视频区 + 弹幕面板正好占满页面，二者不重叠。
      expect(sheetHeight(), closeTo(range.initial, 0.01));
      expect(videoHeight(), closeTo(size.height - range.initial, 0.01));

      // T2 弹幕区调大：视频区相应收缩。
      await tester.drag(find.byKey(const ValueKey('live-play-portrait-sheet-handle')), const Offset(0, -120));
      await tester.pumpAndSettle();
      final grownSheet = sheetHeight();
      final shrunkVideo = videoHeight();
      expect(grownSheet, greaterThan(range.initial));
      expect(shrunkVideo, lessThan(size.height - range.initial));
      expect(shrunkVideo + grownSheet, closeTo(size.height, 0.01));

      // T3 弹幕区调小：视频区相应扩大，且连续调整不回弹到旧尺寸。
      await tester.drag(find.byKey(const ValueKey('live-play-portrait-sheet-handle')), const Offset(0, 120));
      await tester.pumpAndSettle();
      final shrunkSheet = sheetHeight();
      final grownVideo = videoHeight();
      expect(shrunkSheet, lessThan(grownSheet));
      expect(grownVideo, greaterThan(shrunkVideo));
      expect(grownVideo + shrunkSheet, closeTo(size.height, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2 弹幕面板不会覆盖视频区', (tester) async {
      const size = Size(360, 700);
      _useViewport(tester, size);
      await tester.pumpWidget(_layout(isPortraitSource: true, sourceAspectRatio: 9 / 16, expandVideo: true));
      await tester.drag(find.byKey(const ValueKey('live-play-portrait-sheet-handle')), const Offset(0, -160));
      await tester.pumpAndSettle();

      final videoRect = tester.getRect(find.byKey(_videoKey));
      final sheetRect = tester.getRect(find.byKey(const ValueKey('live-play-portrait-sheet')));
      expect(videoRect.bottom, lessThanOrEqualTo(sheetRect.top + 0.01));
      expect(videoRect.height, greaterThan(0));
    });

    testWidgets('T9 沉浸模式仍使用自适应面板的初始收起高度', (tester) async {
      const size = Size(360, 700);
      _useViewport(tester, size);
      await tester.pumpWidget(
        _layout(
          isPortraitSource: true,
          sourceAspectRatio: 9 / 16,
          mode: PortraitLayoutMode.immersive,
          expandVideo: true,
        ),
      );
      final range = portraitPanelRange(size.height, PortraitLayoutMode.immersive);
      expect(
        tester.getSize(find.byKey(const ValueKey('live-play-portrait-sheet'))).height,
        closeTo(range.minimum, 0.01),
      );
      expect(tester.getSize(find.byKey(_videoKey)).height, closeTo(size.height - range.minimum, 0.01));
    });
  });

  group('LivePlayNormalLayout · 分屏拓扑（需求 C）', () {
    testWidgets('T4 展开 + 竖屏源：保持左右分屏，画面按竖屏比例撑满高度', (tester) async {
      _useViewport(tester, const Size(900, 700));
      await tester.pumpWidget(
        _layout(isPortraitSource: true, sourceAspectRatio: 9 / 16, splitBySourceOrientation: true),
      );
      expect(find.byKey(const ValueKey('live-play-desktop-split')), findsOneWidget);
      expect(find.byKey(const ValueKey('live-play-landscape-stack')), findsNothing);

      final videoRect = tester.getRect(find.byKey(_videoKey));
      final danmakuRect = tester.getRect(find.byKey(_danmakuKey));
      expect(videoRect.right, lessThanOrEqualTo(danmakuRect.left + 0.01));

      // 左区宽度由源比例决定（700 × 9/16 = 393.75），不再是把 9:16 塞进
      // 16:9 横框后剩下的中间一条；高度撑满整个可用高度。
      expect(videoRect.width, closeTo(700 * 9 / 16, 0.01));
      expect(videoRect.height, closeTo(700, 0.01));
      expect(videoRect.width / videoRect.height, closeTo(9 / 16, 0.001));
      // 省下来的宽度归弹幕区。
      expect(danmakuRect.width, closeTo(900 - 700 * 9 / 16, 0.01));
    });

    testWidgets('T14 展开 + 竖屏源 + 旋转成宽扁窗口：左区按比例收窄且不溢出', (tester) async {
      _useViewport(tester, const Size(1100, 450));
      await tester.pumpWidget(
        _layout(isPortraitSource: true, sourceAspectRatio: 9 / 16, splitBySourceOrientation: true),
      );
      expect(tester.takeException(), isNull);
      final videoRect = tester.getRect(find.byKey(_videoKey));
      expect(videoRect.height, closeTo(450, 0.01));
      expect(videoRect.width, closeTo(450 * 9 / 16, 0.01));
      // 弹幕区至少保留最小宽度。
      expect(
        tester.getRect(find.byKey(_danmakuKey)).width,
        greaterThanOrEqualTo(LivePlayNormalLayout.minimumDesktopSplitPanelWidth - 0.01),
      );
    });

    testWidgets('T5 展开 + 横屏源：改为上下分屏，弹幕区拿到保底高度', (tester) async {
      _useViewport(tester, const Size(900, 700));
      await tester.pumpWidget(
        _layout(isPortraitSource: false, sourceAspectRatio: 16 / 9, splitBySourceOrientation: true),
      );
      expect(find.byKey(const ValueKey('live-play-landscape-stack')), findsOneWidget);
      expect(find.byKey(const ValueKey('live-play-desktop-split')), findsNothing);

      final videoRect = tester.getRect(find.byKey(_videoKey));
      final danmakuRect = tester.getRect(find.byKey(_danmakuKey));
      expect(videoRect.bottom, lessThanOrEqualTo(danmakuRect.top + 0.01));
      // 默认保底 220，视频拿剩下的高度。
      expect(danmakuRect.height, closeTo(220, 0.01));
      expect(videoRect.height, closeTo(700 - 220 - _resolutionHeight - 1, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('T15 展开 + 横屏源 + 旋转成宽扁窗口：弹幕区仍保留设置的高度', (tester) async {
      // 旋转后宽度暴涨：16:9 视频按宽度撑满会吃掉整页，这正是 Issue 里
      // 「视频挤占下方弹幕列表空间」的场景。
      _useViewport(tester, const Size(1100, 450));
      await tester.pumpWidget(
        _layout(
          isPortraitSource: false,
          sourceAspectRatio: 16 / 9,
          splitBySourceOrientation: true,
          landscapeDanmakuHeight: 240,
        ),
      );
      expect(tester.takeException(), isNull);
      final videoRect = tester.getRect(find.byKey(_videoKey));
      final danmakuRect = tester.getRect(find.byKey(_danmakuKey));
      expect(danmakuRect.height, closeTo(240, 0.01));
      expect(videoRect.bottom, lessThanOrEqualTo(danmakuRect.top + 0.01));
      expect(videoRect.height, closeTo(450 - 240 - _resolutionHeight - 1, 0.01));
      // 视频在剩余高度里按 16:9 内缩，宽度不再撑满整页。
      expect(videoRect.width, lessThanOrEqualTo(1100 + 0.01));
      expect(videoRect.width / videoRect.height, closeTo(16 / 9, 0.01));
    });

    testWidgets('T6 折叠状态：竖屏与横屏源都保持原有上下堆叠', (tester) async {
      _useViewport(tester, const Size(360, 700));
      for (final portrait in [true, false]) {
        await tester.pumpWidget(
          _layout(
            isPortraitSource: portrait,
            sourceAspectRatio: portrait ? 9 / 16 : 16 / 9,
            splitBySourceOrientation: true,
            // 竖屏源自适应面板时画面撑满，横屏源沿用 16:9 画面。
            expandVideo: portrait,
          ),
        );
        expect(find.byKey(const ValueKey('live-play-desktop-split')), findsNothing);
        expect(find.byKey(const ValueKey('live-play-landscape-stack')), findsNothing);
        expect(find.byKey(const ValueKey('live-play-portrait-stack')), findsOneWidget);
      }
    });

    testWidgets('T7 窗口尺寸变化后重新选择拓扑', (tester) async {
      // 折叠态（窄窗口）先建立上下堆叠，再展开成宽窗口，布局必须重算。
      _useViewport(tester, const Size(360, 700));
      await tester.pumpWidget(
        _layout(isPortraitSource: false, sourceAspectRatio: 16 / 9, splitBySourceOrientation: true),
      );
      expect(find.byKey(const ValueKey('live-play-portrait-stack')), findsOneWidget);

      tester.view.physicalSize = const Size(900, 700);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('live-play-landscape-stack')), findsOneWidget);
      expect(find.byKey(const ValueKey('live-play-portrait-stack')), findsNothing);
    });

    testWidgets('T8 直播源方向变化后重新选择拓扑', (tester) async {
      _useViewport(tester, const Size(900, 700));
      await tester.pumpWidget(
        _layout(isPortraitSource: false, sourceAspectRatio: 16 / 9, splitBySourceOrientation: true),
      );
      expect(find.byKey(const ValueKey('live-play-landscape-stack')), findsOneWidget);

      await tester.pumpWidget(
        _layout(isPortraitSource: true, sourceAspectRatio: 9 / 16, splitBySourceOrientation: true),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('live-play-desktop-split')), findsOneWidget);
      expect(find.byKey(const ValueKey('live-play-landscape-stack')), findsNothing);
    });

    testWidgets('T13 非 Android 宽窗口不受源方向分屏影响', (tester) async {
      _useViewport(tester, const Size(900, 700));
      await tester.pumpWidget(
        _layout(isPortraitSource: false, sourceAspectRatio: 16 / 9, splitBySourceOrientation: false),
      );
      expect(find.byKey(const ValueKey('live-play-desktop-split')), findsOneWidget);
    });
  });
}
