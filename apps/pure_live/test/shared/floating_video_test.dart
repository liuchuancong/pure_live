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

    final first = FloatingVideoWindow.show(await handoff());
    await tester.pump();
    expect(await first, isTrue);
    await tester.pump();

    final second = FloatingVideoWindow.show(await handoff());
    await tester.pump();
    await tester.pump();
    expect(await second, isTrue);
    await tester.pump();
    // One window at a time: the old entry went with the supersede.
    expect(find.byType(FloatingVideoView), findsOneWidget);

    FloatingVideoWindow.dismiss();
    await tester.pump();
    expect(FloatingVideoWindow.isShowing, isFalse);
  });
}
