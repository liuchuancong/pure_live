import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/core/playback_lifecycle_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hidden and paused share one lifecycle pause token', () async {
    var pauses = 0;
    var resumes = 0;
    final coordinator = _coordinator(
      pause: () async {
        pauses++;
        return (sessionId: 4, intentRevision: 7);
      },
      resume: (token) async {
        expect(token, (sessionId: 4, intentRevision: 7));
        resumes++;
        return true;
      },
    );

    await coordinator.handleState(AppLifecycleState.hidden);
    await coordinator.handleState(AppLifecycleState.paused);
    await coordinator.handleState(AppLifecycleState.resumed);

    expect(pauses, 1);
    expect(resumes, 1);
    await coordinator.dispose();
  });

  test('background playback policy leaves playback running', () async {
    var pauses = 0;
    final coordinator = _coordinator(
      continueInBackground: true,
      pause: () async {
        pauses++;
        return (sessionId: 1, intentRevision: 1);
      },
    );

    await coordinator.handleState(AppLifecycleState.hidden);
    await coordinator.handleState(AppLifecycleState.paused);
    await coordinator.handleState(AppLifecycleState.resumed);

    expect(pauses, 0);
    await coordinator.dispose();
  });

  test('audio-only power transition is idempotent across hidden and paused', () async {
    var commits = 0;
    var prepares = 0;
    final coordinator = _coordinator(
      audioOnly: true,
      pause: () async => null,
      commitPowerSaving: () async => commits++,
      prepareVideoRestore: () async => prepares++,
    );

    await coordinator.handleState(AppLifecycleState.hidden);
    await coordinator.handleState(AppLifecycleState.paused);
    await coordinator.handleState(AppLifecycleState.resumed);

    expect(commits, 1);
    expect(prepares, 1);
    await coordinator.dispose();
  });

  test('a new lifecycle cycle receives a new pause token', () async {
    var session = 1;
    final resumedSessions = <int>[];
    final coordinator = _coordinator(
      pause: () async => (sessionId: session++, intentRevision: 0),
      resume: (token) async {
        resumedSessions.add(token.sessionId);
        return true;
      },
    );

    await coordinator.handleState(AppLifecycleState.paused);
    await coordinator.handleState(AppLifecycleState.resumed);
    await coordinator.handleState(AppLifecycleState.paused);
    await coordinator.handleState(AppLifecycleState.resumed);

    expect(resumedSessions, <int>[1, 2]);
    await coordinator.dispose();
  });
}

PlaybackLifecycleCoordinator _coordinator({
  required LifecyclePauseCallback pause,
  LifecycleResumeCallback? resume,
  bool continueInBackground = false,
  bool audioOnly = false,
  bool sleepSessionActive = false,
  Future<void> Function()? commitPowerSaving,
  Future<void> Function()? prepareVideoRestore,
}) {
  return PlaybackLifecycleCoordinator(
    pauseForLifecycle: pause,
    resumeFromLifecycle: resume ?? (_) async => true,
    shouldContinueInBackground: () => continueInBackground,
    isAudioOnly: () => audioOnly,
    isSleepSessionActive: () => sleepSessionActive,
    commitAudioOnlyPowerSaving: commitPowerSaving ?? () async {},
    prepareAudioOnlyVideoRestore: prepareVideoRestore ?? () async {},
  );
}
