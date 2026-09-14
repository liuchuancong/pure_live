import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/player/utils/fullscreen.dart';

void main() {
  test('Windows PiP snapshot retains widescreen presentation', () {
    final state = GlobalPlayerState();
    state.isWindowFullscreen.value = true;

    final snapshot = WindowPresentationSnapshot.capture(state);

    expect(snapshot.fullscreen, isFalse);
    expect(snapshot.widescreen, isTrue);
  });

  test('fullscreen presentation takes precedence over widescreen state', () {
    final state = GlobalPlayerState();
    state.isFullscreen.value = true;
    state.isWindowFullscreen.value = true;

    final snapshot = WindowPresentationSnapshot.capture(state);

    expect(snapshot.fullscreen, isTrue);
    expect(snapshot.widescreen, isTrue);
  });

  test('failed Windows PiP entry restores presentation and keeps the original snapshot for retry', () async {
    var presentation = const WindowPresentationSnapshot(fullscreen: true, widescreen: false);
    var enterCalls = 0;
    var hostActive = false;
    final service = WindowService.test(
      enterHostPip: (_) async {
        enterCalls++;
        if (enterCalls == 1) throw StateError('enter fixture failure');
        hostActive = true;
      },
      exitHostPip: () async {
        hostActive = false;
      },
      capturePresentation: () => presentation,
      preparePresentation: () async {
        presentation = const WindowPresentationSnapshot(fullscreen: false, widescreen: false);
      },
      restorePresentation: (snapshot) async {
        presentation = snapshot;
      },
    );

    await expectLater(service.enterWinPiP(16 / 9), throwsStateError);
    expect(presentation.fullscreen, isTrue);
    expect(hostActive, isFalse);

    await service.enterWinPiP(16 / 9);
    expect(hostActive, isTrue);
    await service.exitWinPiP();
    expect(hostActive, isFalse);
    expect(presentation.fullscreen, isTrue);
  });

  test('failed presentation restoration rolls an exited host back to PiP and remains retryable', () async {
    var presentation = const WindowPresentationSnapshot(fullscreen: true, widescreen: false);
    var restoreCalls = 0;
    var enterCalls = 0;
    var exitCalls = 0;
    var hostActive = false;
    final service = WindowService.test(
      enterHostPip: (_) async {
        enterCalls++;
        hostActive = true;
      },
      exitHostPip: () async {
        exitCalls++;
        hostActive = false;
      },
      capturePresentation: () => presentation,
      preparePresentation: () async {
        presentation = const WindowPresentationSnapshot(fullscreen: false, widescreen: false);
      },
      restorePresentation: (snapshot) async {
        restoreCalls++;
        if (restoreCalls == 1) {
          presentation = const WindowPresentationSnapshot(fullscreen: false, widescreen: false);
          throw StateError('restore fixture failure');
        }
        presentation = snapshot;
      },
    );
    await service.enterWinPiP(16 / 9);

    await expectLater(service.exitWinPiP(), throwsStateError);

    expect(hostActive, isTrue);
    expect(enterCalls, 2);
    expect(exitCalls, 1);
    await service.exitWinPiP();
    expect(hostActive, isFalse);
    expect(exitCalls, 2);
    expect(presentation.fullscreen, isTrue);
  });

  test('failed PiP host rollback reports that the main host exit committed', () async {
    var presentation = const WindowPresentationSnapshot(fullscreen: true, widescreen: false);
    var enterCalls = 0;
    var exitCalls = 0;
    var restoreCalls = 0;
    final service = WindowService.test(
      enterHostPip: (_) async {
        enterCalls++;
        if (enterCalls == 2) throw StateError('host rollback fixture failure');
      },
      exitHostPip: () async {
        exitCalls++;
      },
      capturePresentation: () => presentation,
      preparePresentation: () async {
        presentation = const WindowPresentationSnapshot(fullscreen: false, widescreen: false);
      },
      restorePresentation: (snapshot) async {
        restoreCalls++;
        if (restoreCalls == 1) throw StateError('presentation fixture failure');
        presentation = snapshot;
      },
    );
    await service.enterWinPiP(16 / 9);

    await expectLater(
      service.exitWinPiP(),
      throwsA(isA<WindowsPipExitFailure>().having((error) => error.hostIsInPip, 'hostIsInPip', isFalse)),
    );

    expect(enterCalls, 2);
    expect(exitCalls, 1);
    expect(presentation.fullscreen, isTrue);
    await service.exitWinPiP();
    expect(exitCalls, 1);
  });

  test('Windows presentation service coalesces repeated enter and exit requests', () async {
    var presentation = const WindowPresentationSnapshot(fullscreen: false, widescreen: true);
    final enterGate = Completer<void>();
    final exitGate = Completer<void>();
    var enterCalls = 0;
    var exitCalls = 0;
    final service = WindowService.test(
      enterHostPip: (_) async {
        enterCalls++;
        await enterGate.future;
      },
      exitHostPip: () async {
        exitCalls++;
        await exitGate.future;
      },
      capturePresentation: () => presentation,
      preparePresentation: () async {},
      restorePresentation: (snapshot) async {
        presentation = snapshot;
      },
    );

    final firstEnter = service.enterWinPiP(16 / 9);
    final secondEnter = service.enterWinPiP(16 / 9);
    await Future<void>.delayed(Duration.zero);
    expect(enterCalls, 1);
    enterGate.complete();
    await Future.wait([firstEnter, secondEnter]);

    final firstExit = service.exitWinPiP();
    final secondExit = service.exitWinPiP();
    await Future<void>.delayed(Duration.zero);
    expect(exitCalls, 1);
    exitGate.complete();
    await Future.wait([firstExit, secondExit]);
    expect(presentation.widescreen, isTrue);
  });
}
