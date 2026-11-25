import 'dart:async' show Completer;

import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/shared/player/background_playback_gate.dart';

Future<void> _onAndroid(WidgetTester tester, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  testWidgets(
    'a foreground return waits for an in-flight background pause',
    (tester) => _onAndroid(tester, () async {
      final pause = Completer<void>();
      var playing = true;
      final calls = <String>[];
      final gate = BackgroundPlaybackGate(
        backgroundEnabled: () => false,
        shouldPause: () => playing,
        pause: () async {
          calls.add('pause');
          playing = false;
          await pause.future;
        },
        canResume: () => !playing,
        resume: () async => calls.add('resume'),
        delay: const Duration(seconds: 1),
      );
      addTearDown(gate.dispose);

      gate.handleLifecycle(AppLifecycleState.hidden);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, ['pause']);

      gate.handleLifecycle(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, ['pause']);

      pause.complete();
      await tester.pump();
      expect(calls, ['pause', 'resume']);
    }),
  );

  testWidgets(
    'a second background event supersedes an unfinished resume',
    (tester) => _onAndroid(tester, () async {
      final resume = Completer<void>();
      var playing = true;
      var pauses = 0;
      final gate = BackgroundPlaybackGate(
        backgroundEnabled: () => false,
        shouldPause: () => playing,
        pause: () async {
          pauses++;
          playing = false;
        },
        canResume: () => !playing,
        resume: () async {
          playing = true;
          await resume.future;
        },
        delay: const Duration(seconds: 1),
      );
      addTearDown(gate.dispose);

      gate.handleLifecycle(AppLifecycleState.hidden);
      await tester.pump(const Duration(seconds: 1));
      gate.handleLifecycle(AppLifecycleState.resumed);
      await tester.pump();
      expect(pauses, 1);

      gate.handleLifecycle(AppLifecycleState.hidden);
      await tester.pump(const Duration(seconds: 1));
      expect(pauses, 1);
      resume.complete();
      await tester.pump();
      expect(pauses, 2);
    }),
  );

  testWidgets(
    'dispose invalidates a queued foreground resume',
    (tester) => _onAndroid(tester, () async {
      final pause = Completer<void>();
      var resumes = 0;
      final gate = BackgroundPlaybackGate(
        backgroundEnabled: () => false,
        shouldPause: () => true,
        pause: () => pause.future,
        canResume: () => true,
        resume: () async => resumes++,
        delay: const Duration(seconds: 1),
      );

      // The pause must start before the return, so these calls cannot cascade.
      // ignore: cascade_invocations
      gate.handleLifecycle(AppLifecycleState.hidden);
      await tester.pump(const Duration(seconds: 1));
      gate
        ..handleLifecycle(AppLifecycleState.resumed)
        ..dispose();
      pause.complete();
      await tester.pump();
      expect(resumes, 0);
    }),
  );

  testWidgets(
    'a transient inactive event cancels the pending pause',
    (tester) => _onAndroid(tester, () async {
      var pauses = 0;
      final gate = BackgroundPlaybackGate(
        backgroundEnabled: () => false,
        shouldPause: () => true,
        pause: () async => pauses++,
        canResume: () => true,
        resume: () async {},
      );
      addTearDown(gate.dispose);

      gate.handleLifecycle(AppLifecycleState.hidden);
      await tester.pump(const Duration(milliseconds: 500));
      gate.handleLifecycle(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 2));
      expect(pauses, 0);
    }),
  );
}
