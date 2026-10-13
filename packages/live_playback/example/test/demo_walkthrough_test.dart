import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_playback/live_playback.dart';
import 'package:live_playback_example/demo_runtime.dart';
import 'package:live_playback_example/main.dart';

/// Walks the demo the way a viewer would: pressing the buttons and reading the
/// chips and the log back.
///
/// This checks the *tour* — that every scenario is reachable from a button, that
/// the panel labels tell the truth, and that the states a viewer moves through
/// are visible on screen. The behaviours behind the buttons are covered by the
/// package's own `playback_scenarios_test.dart`, which runs outside a widget
/// test and therefore without its fake clock.
///
/// That division is not laziness: a widget test drives a *fake* clock, and the
/// kernel's release path (`kernel.release` → the adapter's close) is completed
/// by the real event loop, so a step that stops a session — returning from a
/// recorded video, closing everything, scrolling a list past its preload
/// window — never finishes under that clock. Those steps are asserted in the
/// package tests; here the buttons that trigger them are checked to be present.
///
/// The same reason makes [DemoRuntime.dispose] fire-and-forget here: awaiting
/// it would park the test on a future the fake clock cannot complete, and the
/// runner would report the test as never finishing. Nothing is leaked between
/// tests — each one builds its own runtime and kernel.
void main() {
  /// Pumps the demo with its own runtime and returns it.
  ///
  /// The surface is tall on purpose: the panels live in a `ListView`, so a
  /// default 800×600 test viewport would leave the lower buttons unbuilt and
  /// `find.byKey` would report them missing rather than off-screen.
  Future<DemoRuntime> pumpDemo(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final runtime = DemoRuntime();
    addTearDown(() => unawaited(runtime.dispose()));
    await tester.pumpWidget(MaterialApp(home: DemoHomePage(runtime: runtime)));
    await tester.pump();
    return runtime;
  }

  /// Scrolls [key] into view, taps it, and lets the work it started finish.
  ///
  /// Pumps are explicit rather than [WidgetTester.pumpAndSettle]: the demo runs
  /// a live player behind the buttons — a session that is playing keeps
  /// scheduling frames — so there is no "settled" state to wait for, and
  /// `pumpAndSettle` would burn its full timeout on every step. The `pump` with
  /// a duration is what moves the service's own clock: opening a session,
  /// running a request through the platform adapter and reading the window
  /// store all run on timers.
  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }

  /// The text of a state chip.
  String chip(WidgetTester tester, String key) {
    final finder = find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text));
    return tester.widget<Text>(finder.first).data ?? '';
  }

  /// The log panel's text.
  String log(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('log'))).data ?? '';

  group('demo wiring', () {
    testWidgets('every scenario has a button on screen', (tester) async {
      await pumpDemo(tester);

      const keys = <String>[
        'live-a',
        'live-b',
        'open-recorded',
        'return-live',
        'toggle-mute',
        'toggle-chat',
        'fullscreen',
        'to-floating',
        'to-pip',
        'exit-overlay',
        'close-all',
        'feed-preview',
        'feed-immersive',
        'feed-next',
        'feed-detail',
        'feed-close',
        'feed-close-overlay',
        'mv-add-room-1',
        'mv-add-room-2',
        'mv-add-room-3',
        'mv-focus-room-1',
        'mv-focus-room-2',
        'mv-focus-room-3',
        'mv-play',
        'mv-pause',
        'mv-mute',
        'mv-clear',
        'bg-back',
        'bg-front',
        'set-bg',
        'set-pip',
        'set-floating',
        'set-platform-pip',
        'set-platform-floating',
      ];

      for (final key in keys) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: '$key must exist');
      }
      expect(find.byKey(const Key('stage-main')), findsOneWidget);
      expect(find.byKey(const Key('log')), findsOneWidget);
    });

    testWidgets('the stage shows an empty state before anything opens', (tester) async {
      await pumpDemo(tester);

      expect(find.textContaining('没有会话'), findsOneWidget);
      expect(chip(tester, 'chip-sessions'), contains('0'));
      expect(chip(tester, 'chip-mode'), contains('normal'));
      expect(log(tester), contains('ready'));
    });
  });

  group('直播页', () {
    testWidgets('打开直播间到打开录播：直播被 park 而不是关闭', (tester) async {
      final runtime = await pumpDemo(tester);

      await tap(tester, 'live-a');
      expect(chip(tester, 'chip-primary'), contains('room-1'));
      expect(chip(tester, 'chip-playback'), contains('播放中'));

      await tap(tester, 'open-recorded');
      expect(chip(tester, 'chip-primary'), contains('video-1'));
      expect(chip(tester, 'chip-sessions'), contains('2'));
      expect(
        runtime.service.coordinator.sessionFor('room-1')!.currentState.phase,
        PlaybackPhase.paused,
        reason: 'the live room waits; it is not closed',
      );
      expect(runtime.service.suspendedSessionId, 'room-1');
      expect(log(tester), contains('audio owner -> video-1'));
    });

    testWidgets('全局静音与弹幕开关反映在状态条上', (tester) async {
      await pumpDemo(tester);

      await tap(tester, 'live-a');
      expect(chip(tester, 'chip-muted'), contains('否'));
      expect(chip(tester, 'chip-chat'), contains('显示'));

      await tap(tester, 'toggle-mute');
      expect(chip(tester, 'chip-muted'), contains('是'));

      await tap(tester, 'toggle-chat');
      expect(chip(tester, 'chip-chat'), contains('隐藏'));
      expect(chip(tester, 'chip-chat'), contains('全局关'));
      expect(log(tester), contains('chat off -> true'));
    });

    testWidgets('全屏与退出悬浮窗反映在状态条上', (tester) async {
      await pumpDemo(tester);

      await tap(tester, 'live-a');
      await tap(tester, 'fullscreen');
      expect(chip(tester, 'chip-mode'), contains('fullscreen'));

      await tap(tester, 'exit-overlay');
      expect(chip(tester, 'chip-mode'), contains('normal'));
    });
  });

  group('小窗与画中画', () {
    testWidgets('交给小窗后出现小窗，拖拽会被记住', (tester) async {
      await pumpDemo(tester);

      await tap(tester, 'live-a');
      await tap(tester, 'to-floating');

      expect(chip(tester, 'chip-mode'), contains('floating'));
      expect(chip(tester, 'chip-overlay'), contains('room-1'));
      expect(find.byKey(const Key('stage-window')), findsOneWidget);

      await tester.drag(find.byKey(const Key('stage-window')), const Offset(-60, -40));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(log(tester), contains('记住 room-1/floating'));
    });

    testWidgets('竖屏与横屏各记各的：切换方向后小窗形状随之改变', (tester) async {
      await pumpDemo(tester);

      await tap(tester, 'live-a');
      await tap(tester, 'to-floating');

      final portraitSize = tester.getSize(find.byKey(const Key('stage-window')));

      await tap(tester, 'stage-orientation');
      final landscapeSize = tester.getSize(find.byKey(const Key('stage-window')));

      expect(log(tester), contains('视频方向 -> 横屏'));
      expect(portraitSize.height, greaterThan(portraitSize.width), reason: 'a vertical room opens tall');
      expect(landscapeSize.width, greaterThan(landscapeSize.height), reason: 'a wide video opens wide');
    });

    testWidgets('平台没有画中画时被拒绝，打开能力后可用', (tester) async {
      await pumpDemo(tester);

      await tap(tester, 'live-a');
      await tap(tester, 'to-pip');

      expect(chip(tester, 'chip-overlay'), contains('无'), reason: 'the platform has no PiP yet');
      expect(log(tester), contains('画中画被拒绝'));

      await tap(tester, 'set-platform-pip');
      await tap(tester, 'to-pip');

      expect(chip(tester, 'chip-mode'), contains('pip'));
      expect(chip(tester, 'chip-overlay'), contains('room-1'));
    });
  });

  group('后台策略', () {
    testWidgets('允许画中画时退到后台会主动进画中画', (tester) async {
      await pumpDemo(tester);

      await tap(tester, 'live-a');
      await tap(tester, 'set-platform-pip');
      await tap(tester, 'bg-back');

      expect(chip(tester, 'chip-backgrounded'), contains('是'));
      expect(chip(tester, 'chip-mode'), contains('pip'));
      expect(
        chip(tester, 'chip-chat'),
        contains('隐藏'),
        reason: 'a PiP thumbnail shows no chat, without touching the global switch',
      );
      expect(chip(tester, 'chip-chat'), isNot(contains('全局关')));
    });

    testWidgets('关掉画中画只剩后台声音；两个都关就暂停', (tester) async {
      final runtime = await pumpDemo(tester);

      await tap(tester, 'live-a');
      final session = runtime.service.coordinator.sessionFor('room-1')!;

      await tap(tester, 'set-platform-pip');
      await tap(tester, 'set-pip');
      await tap(tester, 'bg-back');

      expect(chip(tester, 'chip-mode'), contains('normal'));
      expect(session.currentState.phase, isNot(PlaybackPhase.paused), reason: 'audio-only background playback');

      await tap(tester, 'bg-front');
      await tap(tester, 'set-bg');
      await tap(tester, 'bg-back');

      expect(session.currentState.phase, PlaybackPhase.paused, reason: 'neither PiP nor background audio is allowed');
    });
  });

  group('列表与详情', () {
    testWidgets('预览模式不占声音通道，进详情才可听', (tester) async {
      final runtime = await pumpDemo(tester);

      await tap(tester, 'feed-preview');
      await tap(tester, 'feed-next');
      await tap(tester, 'feed-next');

      expect(chip(tester, 'chip-primary'), contains('无'), reason: 'previews are silent and hold nothing');
      expect(runtime.service.feed.mode, FeedPlaybackMode.preview);

      await tap(tester, 'feed-detail');
      expect(chip(tester, 'chip-primary'), contains('v-1'), reason: 'detail opens the item on screen');
      expect(chip(tester, 'chip-playback'), contains('播放中'));
    });

    testWidgets('退出详情留给小窗的会话会被 pin 住', (tester) async {
      final runtime = await pumpDemo(tester);

      await tap(tester, 'feed-detail');
      await tap(tester, 'feed-close-overlay');

      expect(chip(tester, 'chip-overlay'), contains('v-0'));
      expect(chip(tester, 'chip-mode'), contains('floating'));

      // One step keeps index 0 inside the preload window, so this exercises the
      // pinning bookkeeping without the prune the widget clock cannot run.
      await tap(tester, 'feed-next');
      expect(runtime.service.coordinator.contains('v-0'), isTrue);
      expect(runtime.service.feed.pinnedSessionIds, contains('v-0'));
    });
  });

  group('多画面', () {
    testWidgets('第一个格子出声、点格子换声音', (tester) async {
      final runtime = await pumpDemo(tester);

      await tap(tester, 'mv-add-room-1');
      expect(chip(tester, 'chip-primary'), contains('room-1'));

      await tap(tester, 'mv-add-room-2');
      expect(chip(tester, 'chip-primary'), contains('room-1'), reason: 'the audible tile does not change by itself');

      await tap(tester, 'mv-focus-room-2');
      expect(chip(tester, 'chip-primary'), contains('room-2'));
      expect(runtime.service.coordinator.sessionFor('room-1')!.muted, isTrue);

      await tap(tester, 'mv-pause');
      expect(
        runtime.service.coordinator.sessions.values.every(
          (session) => session.currentState.phase == PlaybackPhase.paused,
        ),
        isTrue,
        reason: 'pauseAll parks every tile',
      );
    });
  });
}
