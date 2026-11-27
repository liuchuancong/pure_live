import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.g.dart';
import 'package:pure_live/shared/shared.dart';

/// The floating mini window's overlay mechanics, against a handoff whose
/// open always fails (a test host has no media engine): the window shows
/// its failed state, and the show/dismiss pair keeps its invariants — one
/// window at a time, a close path that runs on supersede.
void main() {
  Future<FloatingVideoHandoff> handoff() async =>
      FloatingVideoHandoff(title: '测试视频', open: (kernel) async => throw StateError('no engine in tests'));

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const Scaffold(body: Text('页面')),
          ),
        ),
      ),
    );
  }

  test('completion uses the final transport and a five second tail', () {
    const total = Duration(minutes: 10);
    expect(isFloatingVideoPlaybackComplete(const Duration(seconds: 594), total), isFalse);
    expect(isFloatingVideoPlaybackComplete(const Duration(seconds: 595), total), isTrue);
    expect(isFloatingVideoPlaybackComplete(const Duration(seconds: 600), total), isTrue);
    expect(isFloatingVideoPlaybackComplete(const Duration(seconds: 30), Duration.zero), isFalse);
    expect(isFloatingVideoPlaybackComplete(Duration.zero, const Duration(seconds: 3)), isFalse);
  });

  testWidgets('show inserts the window and dismiss removes it', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester);

    final shown = FloatingVideoWindow.show(await handoff());
    await tester.pump();
    expect(await shown, isTrue);
    await tester.pump();
    expect(FloatingVideoWindow.isShowing, isTrue);
    expect(find.byType(FloatingVideoView), findsOneWidget);

    // A failed open leaves the window's own words up, not a blank box —
    // the title reads twice (the drag bar and the failed-state line).
    expect(find.text('测试视频'), findsNWidgets(2));

    FloatingVideoWindow.dismiss();
    await tester.pump();
    expect(FloatingVideoWindow.isShowing, isFalse);
    expect(find.byType(FloatingVideoView), findsNothing);
  });

  testWidgets('a second handoff supersedes the window and stays single', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester);

    var firstCloses = 0;
    var secondCloses = 0;
    final first = FloatingVideoWindow.show(
      FloatingVideoHandoff(
        title: '第一个视频',
        open: (kernel) async => throw StateError('no engine in tests'),
        onClose: (_, {required reopen, duration = Duration.zero, completed = false}) => firstCloses++,
      ),
    );
    await tester.pump();
    expect(await first, isTrue);
    await tester.pump();

    final second = FloatingVideoWindow.show(
      FloatingVideoHandoff(
        title: '第二个视频',
        open: (kernel) async => throw StateError('no engine in tests'),
        onClose: (_, {required reopen, duration = Duration.zero, completed = false}) => secondCloses++,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(await second, isTrue);
    await tester.pump();
    // One window at a time: the old entry went with the supersede, and its
    // later disposal must not erase the replacement's close callback.
    expect(find.byType(FloatingVideoView), findsOneWidget);
    expect(firstCloses, 1);

    FloatingVideoWindow.dismiss();
    await tester.pump();
    expect(FloatingVideoWindow.isShowing, isFalse);
    expect(secondCloses, 1);
  });

  testWidgets('an inserted entry is removed before its first build when replaced', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester);

    final first = FloatingVideoWindow.show(
      FloatingVideoHandoff(title: '尚未构建的旧窗口', open: (kernel) async => throw StateError('no engine in tests')),
    );
    late Future<bool> second;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      second = FloatingVideoWindow.show(
        FloatingVideoHandoff(title: '取而代之的新窗口', open: (kernel) async => throw StateError('no engine in tests')),
      );
    });
    await tester.pump();
    expect(await first, isTrue);
    await tester.pump();
    expect(await second, isTrue);
    await tester.pump();

    expect(find.byType(FloatingVideoView), findsOneWidget);
    expect(find.text('取而代之的新窗口'), findsNWidgets(2));
    expect(find.text('尚未构建的旧窗口'), findsNothing);
    FloatingVideoWindow.dismiss();
    await tester.pump();
  });

  testWidgets('a handoff waiting for its frame is replaced by the newest one', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester);

    var firstCloses = 0;
    var secondCloses = 0;
    Duration? firstDuration;
    var firstCompleted = true;
    final first = FloatingVideoWindow.show(
      FloatingVideoHandoff(
        title: '排队中的旧视频',
        open: (kernel) async => throw StateError('no engine in tests'),
        onClose: (_, {required reopen, duration = Duration.zero, completed = false}) {
          firstCloses++;
          firstDuration = duration;
          firstCompleted = completed;
        },
      ),
    );
    final second = FloatingVideoWindow.show(
      FloatingVideoHandoff(
        title: '排队中的新视频',
        open: (kernel) async => throw StateError('no engine in tests'),
        onClose: (_, {required reopen, duration = Duration.zero, completed = false}) => secondCloses++,
      ),
    );
    await tester.pump();
    expect(await first, isFalse);
    expect(await second, isTrue);
    await tester.pump();

    expect(find.text('排队中的新视频'), findsWidgets);
    expect(find.text('排队中的旧视频'), findsNothing);
    FloatingVideoWindow.dismiss();
    await tester.pump();
    expect(firstCloses, 1);
    expect(firstDuration, Duration.zero);
    expect(firstCompleted, isFalse);
    expect(secondCloses, 1);
  });
}
