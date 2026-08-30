import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/player/core/engine_fallback_manager.dart';
import 'package:pure_live/player/core/line_fallback_manager.dart';
import 'package:pure_live/player/core/player_manager.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';
import 'package:pure_live/player/interface/unified_player_interface.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/player/models/player_error_type.dart';
import 'package:pure_live/player/models/player_exception.dart';
import 'package:pure_live/player/models/player_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    Get.put(GlobalPlayerState());
  });

  tearDown(Get.reset);

  test('active content screenshot probing is opt-in', () async {
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: mediaKit});

    expect(manager.enableActiveContentProbe, isFalse);

    await manager.dispose();
  });

  test('consecutive source failures drain through the next line and engine', () async {
    final mediaKit = _RecoveryFakePlayer(
      PlayerEngine.mediaKit,
      (_) => PlayerException(message: 'source open failed', type: PlayerErrorType.source),
    );
    final fijk = _RecoveryFakePlayer(PlayerEngine.fijk, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: mediaKit,
      PlayerEngine.fijk: fijk,
    });
    final terminalErrors = <PlayerException>[];
    final subscription = manager.onError.listen(terminalErrors.add);

    await manager.initialize(engine: PlayerEngine.mediaKit);
    await manager.play(
      'https://cdn.example/line-1.flv',
      const <String>['https://cdn.example/line-1.flv', 'https://cdn.example/line-2.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: '1', platform: 'test'),
    );

    expect(mediaKit.openedUrls, <String>['https://cdn.example/line-1.flv', 'https://cdn.example/line-2.flv']);
    expect(fijk.openedUrls, <String>['https://cdn.example/line-2.flv']);
    expect(manager.currentEngine, PlayerEngine.fijk);
    expect(manager.hasError.value, isFalse);
    expect(terminalErrors, isEmpty);

    await subscription.cancel();
    await manager.dispose();
  });

  test('initial engine allocation failure stays private and falls back', () async {
    final mediaKit = _RecoveryFakePlayer(
      PlayerEngine.mediaKit,
      (_) => null,
      initFailure: StateError('libmpv initialization failed'),
    );
    final fijk = _RecoveryFakePlayer(PlayerEngine.fijk, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: mediaKit,
      PlayerEngine.fijk: fijk,
    });
    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    final terminalErrors = <PlayerException>[];
    final subscription = manager.onError.listen(terminalErrors.add);

    await manager.play(
      'https://cdn.example/live.flv',
      const <String>['https://cdn.example/live.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: '1', platform: 'test'),
    );

    expect(mediaKit.openedUrls, isEmpty);
    expect(fijk.openedUrls, <String>['https://cdn.example/live.flv']);
    expect(manager.currentEngine, PlayerEngine.fijk);
    expect(manager.hasError.value, isFalse);
    expect(terminalErrors, isEmpty);

    await subscription.cancel();
    await manager.dispose();
  });

  test('only the final exhausted failure reaches the public error stream', () async {
    _RecoveryFakePlayer failing(PlayerEngine engine, String name) => _RecoveryFakePlayer(
      engine,
      (_) => PlayerException(message: '$name decoder failed', type: PlayerErrorType.codec),
    );
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: failing(PlayerEngine.mediaKit, 'mpv'),
      PlayerEngine.fijk: failing(PlayerEngine.fijk, 'ijk'),
    });
    final terminalErrors = <PlayerException>[];
    final subscription = manager.onError.listen(terminalErrors.add);

    await manager.initialize(engine: PlayerEngine.mediaKit);
    await manager.play(
      'https://cdn.example/live.flv',
      const <String>['https://cdn.example/live.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: '1', platform: 'test'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(manager.hasError.value, isTrue);
    expect(terminalErrors, hasLength(1));
    expect(terminalErrors.single.message, contains('ijk'));

    await subscription.cancel();
    await manager.dispose();
  });

  test('a source that opens without playing reaches the next engine', () async {
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null, emitPlaying: false);
    final fijk = _RecoveryFakePlayer(PlayerEngine.fijk, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: mediaKit,
      PlayerEngine.fijk: fijk,
    }, sourceReadyTimeout: const Duration(milliseconds: 2));
    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    final terminalErrors = <PlayerException>[];
    final subscription = manager.onError.listen(terminalErrors.add);

    await manager.play(
      'https://cdn.example/live.flv',
      const <String>['https://cdn.example/live.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: '1', platform: 'test'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(mediaKit.openedUrls, <String>['https://cdn.example/live.flv']);
    expect(fijk.openedUrls, <String>['https://cdn.example/live.flv']);
    expect(manager.currentEngine, PlayerEngine.fijk);
    expect(terminalErrors, isEmpty);

    await subscription.cancel();
    await manager.dispose();
  });

  test('default policy never reopens a source from an inferred readiness timeout', () async {
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null, emitPlaying: false);
    final fijk = _RecoveryFakePlayer(PlayerEngine.fijk, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: mediaKit,
      PlayerEngine.fijk: fijk,
    });
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    await manager.play(
      'https://cdn.example/slow-live.flv',
      const <String>['https://cdn.example/slow-live.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: '1', platform: 'test'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(mediaKit.openedUrls, <String>['https://cdn.example/slow-live.flv']);
    expect(fijk.openedUrls, isEmpty);
    expect(manager.currentEngine, PlayerEngine.mediaKit);
    expect(manager.hasError.value, isFalse);

    await manager.dispose();
  });

  test('current source decoder dimensions reach portrait geometry without a path signal', () async {
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null, emittedWidth: 720, emittedHeight: 1280);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: mediaKit});
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    await manager.play(
      'https://api.example/portrait-live.flv',
      const <String>['https://api.example/portrait-live.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'portrait', platform: 'test'),
    );
    await manager.videoGeometry.stream
        .firstWhere((snapshot) => snapshot.orientation == VideoSourceOrientation.portrait && snapshot.isStable)
        .timeout(const Duration(seconds: 2));

    expect(manager.videoGeometry.value.width, 720);
    expect(manager.videoGeometry.value.height, 1280);
    expect(manager.videoGeometry.value.orientation, VideoSourceOrientation.portrait);

    await manager.dispose();
  });

  test('a native open Future that stalls is bounded and replaced by the next engine', () async {
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null, hangWhileOpening: true);
    final fijk = _RecoveryFakePlayer(PlayerEngine.fijk, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: mediaKit,
      PlayerEngine.fijk: fijk,
    }, sourceOpenTimeout: const Duration(milliseconds: 2));

    await manager.initialize(engine: PlayerEngine.mediaKit);
    await manager.play(
      'https://cdn.example/stalled-open.flv',
      const <String>['https://cdn.example/stalled-open.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: '1', platform: 'test'),
    );

    expect(mediaKit.openedUrls, <String>['https://cdn.example/stalled-open.flv']);
    expect(fijk.openedUrls, <String>['https://cdn.example/stalled-open.flv']);
    expect(manager.currentEngine, PlayerEngine.fijk);
    expect(manager.hasError.value, isFalse);

    await manager.dispose();
  });

  test('a codec failure retries software decode once before replacing the engine', () async {
    final mediaKit = _DecoderRecoveryFakePlayer();
    final fijk = _RecoveryFakePlayer(PlayerEngine.fijk, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: mediaKit,
      PlayerEngine.fijk: fijk,
    });
    final terminalErrors = <PlayerException>[];
    final subscription = manager.onError.listen(terminalErrors.add);

    await manager.initialize(engine: PlayerEngine.mediaKit);
    await manager.play(
      'https://cdn.example/hardware-incompatible.flv',
      const <String>['https://cdn.example/hardware-incompatible.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: '1', platform: 'test'),
    );

    expect(mediaKit.softwareFallbackRequests, 1);
    expect(mediaKit.openedUrls, hasLength(2));
    expect(fijk.openedUrls, isEmpty);
    expect(manager.currentEngine, PlayerEngine.mediaKit);
    expect(manager.hasError.value, isFalse);
    expect(terminalErrors, isEmpty);

    await subscription.cancel();
    await manager.dispose();
  });

  test('an audio decoder failure skips the video software retry and changes engine', () async {
    final mediaKit = _AudioDecoderRecoveryFakePlayer();
    final fijk = _RecoveryFakePlayer(PlayerEngine.fijk, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: mediaKit,
      PlayerEngine.fijk: fijk,
    });

    await manager.initialize(engine: PlayerEngine.mediaKit);
    await manager.play(
      'https://cdn.example/audio-decoder-failure.flv',
      const <String>['https://cdn.example/audio-decoder-failure.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: '1', platform: 'test'),
    );

    expect(mediaKit.softwareFallbackRequests, 0);
    expect(fijk.openedUrls, <String>['https://cdn.example/audio-decoder-failure.flv']);
    expect(manager.currentEngine, PlayerEngine.fijk);
    expect(manager.hasError.value, isFalse);

    await manager.dispose();
  });

  test('unexpected native pause reasserts the current live source once', () async {
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: mediaKit,
    }, unexpectedPauseGrace: const Duration(milliseconds: 2));
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    await manager.play(
      'https://cdn.example/live.flv',
      const <String>['https://cdn.example/live.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'continuity', platform: 'test'),
    );
    mediaKit.emitUnexpectedPlaying(false);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(mediaKit.playCalls, 1);
    expect(manager.isPlayingNow, isTrue);
    await manager.dispose();
  });

  test('native paused state stays transport-owned while live recovery is pending', () async {
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: mediaKit,
    }, unexpectedPauseGrace: const Duration(milliseconds: 20));
    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    final states = <PlayerState>[];
    final subscription = manager.onStateChanged.listen(states.add);

    await manager.play(
      'https://cdn.example/live.flv',
      const <String>['https://cdn.example/live.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'transport-pause', platform: 'test'),
    );
    mediaKit.emitUnexpectedPlaying(false);
    mediaKit.emitNativeState(PlayerState.paused);
    await Future<void>.delayed(Duration.zero);

    expect(states.last, isNot(PlayerState.paused));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(mediaKit.playCalls, 1);

    await subscription.cancel();
    await manager.dispose();
  });

  test('explicit user pause is still published as paused', () async {
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: mediaKit});
    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    final states = <PlayerState>[];
    final subscription = manager.onStateChanged.listen(states.add);

    await manager.play(
      'https://cdn.example/live.flv',
      const <String>['https://cdn.example/live.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'manual-state', platform: 'test'),
    );
    await manager.pause();
    mediaKit.emitNativeState(PlayerState.paused);
    await Future<void>.delayed(Duration.zero);

    expect(states.last, PlayerState.paused);
    await subscription.cancel();
    await manager.dispose();
  });

  test('explicit pause is never reversed by the continuity supervisor', () async {
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: mediaKit,
    }, unexpectedPauseGrace: const Duration(milliseconds: 2));
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    await manager.play(
      'https://cdn.example/live.flv',
      const <String>['https://cdn.example/live.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'manual-pause', platform: 'test'),
    );
    await manager.pause();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(mediaKit.playCalls, 0);
    expect(manager.isPlayingNow, isFalse);
    await manager.dispose();
  });

  test('a live buffering stall enters bounded source recovery', () async {
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final fijk = _RecoveryFakePlayer(PlayerEngine.fijk, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: mediaKit,
      PlayerEngine.fijk: fijk,
    }, bufferingStallTimeout: const Duration(milliseconds: 3));
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    await manager.play(
      'https://cdn.example/stalled-live.flv',
      const <String>['https://cdn.example/stalled-live.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'buffering-stall', platform: 'test'),
    );
    mediaKit.emitLoading(true);
    mediaKit.emitUnexpectedPlaying(false);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(manager.currentEngine, PlayerEngine.fijk);
    expect(fijk.openedUrls, <String>['https://cdn.example/stalled-live.flv']);
    await manager.dispose();
  });

  test('buffering remains supervised while native playing is true and recreates the sole engine', () async {
    final first = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final replacement = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    var creations = 0;
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: first},
      bufferingStallTimeout: const Duration(milliseconds: 3),
      playerCreator: (_) => creations++ == 0 ? first : replacement,
    );
    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    final terminalErrors = <PlayerException>[];
    final subscription = manager.onError.listen(terminalErrors.add);

    await manager.play(
      'https://cdn.example/windows-stalled-live.flv',
      const <String>['https://cdn.example/windows-stalled-live.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'windows-buffering-stall', platform: 'huya'),
    );
    expect(first.isPlayingNow, isTrue);

    // media_kit/libmpv can retain playing=true while its demuxer has stopped
    // producing frames. The persistent loading signal must still expire.
    first.emitLoading(true);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(creations, 2);
    expect(manager.currentPlayer, same(replacement));
    expect(replacement.openedUrls, <String>['https://cdn.example/windows-stalled-live.flv']);
    expect(terminalErrors, isEmpty);

    await subscription.cancel();
    await manager.dispose();
  });

  test('presented-frame stall recreates a playing Windows renderer', () async {
    final first = _FrameProgressFakePlayer();
    final replacement = _FrameProgressFakePlayer();
    var creations = 0;
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: first},
      videoFrameStallTimeout: const Duration(milliseconds: 25),
      playerCreator: (_) => creations++ == 0 ? first : replacement,
    );
    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    final terminalErrors = <PlayerException>[];
    final subscription = manager.onError.listen(terminalErrors.add);

    await manager.play(
      'https://cdn.example/huya-event.flv',
      const <String>['https://cdn.example/huya-event.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'huya-frame-stall', platform: 'huya'),
    );
    first.emitFrame();
    first.emitFrame();

    final candidateOpenDeadline = DateTime.now().add(const Duration(milliseconds: 300));
    while (replacement.openedUrls.isEmpty && DateTime.now().isBefore(candidateOpenDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(replacement.openedUrls, <String>['https://cdn.example/huya-event.flv']);
    // A native open/playing event is not enough on Windows. Commit only after
    // the replacement renderer has published a real frame.
    replacement.emitFrame();

    final deadline = DateTime.now().add(const Duration(milliseconds: 300));
    while (!identical(manager.currentPlayer, replacement) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(creations, 2);
    expect(manager.currentPlayer, same(replacement));
    replacement.emitFrame();
    expect(terminalErrors, isEmpty);

    await subscription.cancel();
    await manager.dispose();
  });

  test('presented-frame stall retains the active Windows texture when a replacement stays at zero size', () async {
    final active = _FrameProgressFakePlayer();
    final zeroSizeCandidate = _FrameProgressFakePlayer();
    var creations = 0;
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: active},
      sourceReadyTimeout: const Duration(milliseconds: 25),
      videoFrameStallTimeout: const Duration(milliseconds: 18),
      transientLiveRetryDelays: const <Duration>[],
      playerCreator: (_) => creations++ == 0 ? active : zeroSizeCandidate,
    );
    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    final terminalErrors = <PlayerException>[];
    final subscription = manager.onError.listen(terminalErrors.add);

    await manager.play(
      'https://cdn.example/huya-zero-size.flv',
      const <String>['https://cdn.example/huya-zero-size.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'huya-zero-size', platform: 'huya'),
    );
    active.emitFrame();

    final candidateDeadline = DateTime.now().add(const Duration(milliseconds: 300));
    while (zeroSizeCandidate.openedUrls.isEmpty && DateTime.now().isBefore(candidateDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(zeroSizeCandidate.openedUrls, <String>['https://cdn.example/huya-zero-size.flv']);

    // The candidate reports playing but deliberately never emits a presented
    // frame, matching a Huya 403/404 player which remains at VideoOutput 0x0.
    await Future<void>.delayed(const Duration(milliseconds: 90));

    expect(manager.currentPlayer, same(active));
    expect(active.disposeCalls, 0);
    expect(zeroSizeCandidate.disposeCalls, 1);
    expect(terminalErrors, isNotEmpty);

    await subscription.cancel();
    await manager.dispose();
  }, skip: !Platform.isWindows);

  test('presented-frame watchdog is cancelled by an explicit pause', () async {
    final first = _FrameProgressFakePlayer();
    final replacement = _FrameProgressFakePlayer();
    var creations = 0;
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: first},
      videoFrameStallTimeout: const Duration(milliseconds: 15),
      playerCreator: (_) => creations++ == 0 ? first : replacement,
    );
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    await manager.play(
      'https://cdn.example/paused-live.flv',
      const <String>['https://cdn.example/paused-live.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'paused-frame-watchdog', platform: 'huya'),
    );
    first.emitFrame();
    await manager.pause();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(creations, 1);
    expect(manager.currentPlayer, same(first));
    await manager.dispose();
  });

  test('an intentionally hidden Windows presentation never reopens the live transport', () async {
    final active = _FrameProgressFakePlayer();
    final replacement = _FrameProgressFakePlayer();
    var creations = 0;
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: active},
      videoFrameStallTimeout: const Duration(milliseconds: 18),
      playerCreator: (_) => creations++ == 0 ? active : replacement,
    );
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    await manager.play(
      'https://cdn.example/covered-huya-live.flv',
      const <String>['https://cdn.example/covered-huya-live.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'huya-covered-route', platform: 'huya'),
    );
    active.emitFrame();
    manager.setVideoPresentationVisible(false);

    // Stay beyond several watchdog periods, matching a user browsing recorder
    // centre while the Windows Texture is deliberately unmounted.
    await Future<void>.delayed(const Duration(milliseconds: 75));
    expect(creations, 1);
    expect(manager.currentPlayer, same(active));
    expect(active.disposeCalls, 0);

    manager.setVideoPresentationVisible(true);
    active.emitFrame();
    await Future<void>.delayed(const Duration(milliseconds: 8));
    expect(creations, 1);
    expect(manager.currentPlayer, same(active));

    await manager.dispose();
  }, skip: !Platform.isWindows);

  test('signed source recovery keeps the active Windows player visible until the fresh source is ready', () async {
    final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final replacement = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null, emitPlaying: false);
    var creations = 0;
    final requests = <PlaybackSourceRefreshRequest>[];
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: active},
      sourceReadyTimeout: const Duration(seconds: 1),
      playerCreator: (_) => creations++ == 0 ? active : replacement,
    );
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    await manager.play(
      'https://cdn.example/expired.flv',
      const <String>['https://cdn.example/expired.flv', 'https://backup.example/expired.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'huya-token-refresh', platform: 'huya'),
      sourceResolver: (request) async {
        requests.add(request);
        return const PlaybackSourceRefreshResult(
          urls: <String>['https://cdn.example/fresh.flv', 'https://backup.example/fresh.flv'],
          preferredLineIndex: 0,
        );
      },
    );
    active.emitError(PlayerException(message: 'token expired', type: PlayerErrorType.network));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(requests, hasLength(1));
    expect(requests.single.advanceLine, isFalse);
    expect(manager.currentPlayer, same(active));
    expect(active.isPlayingNow, isTrue);
    expect(replacement.openedUrls, <String>['https://cdn.example/fresh.flv']);

    replacement.emitUnexpectedPlaying(true);
    final deadline = DateTime.now().add(const Duration(milliseconds: 300));
    while (!identical(manager.currentPlayer, replacement) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(manager.currentPlayer, same(replacement));
    expect(active.isPlayingNow, isFalse);
    expect(manager.hasError.value, isFalse);
    await manager.dispose();
  }, skip: !Platform.isWindows);

  test('signed source lease hands off a healthy Windows transport before expiry', () async {
    final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final replacement = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    var creations = 0;
    var refreshCalls = 0;
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: active},
      playerCreator: (_) => creations++ == 0 ? active : replacement,
      windowsHuyaProactiveRefreshInterval: const Duration(milliseconds: 20),
    );
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    await manager.play(
      'https://al.flv.huya.com/src/leased.flv',
      const <String>['https://al.flv.huya.com/src/leased.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'huya-proactive-refresh', platform: 'huya'),
      sourceRefreshAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      sourceResolver: (request) async {
        refreshCalls++;
        return PlaybackSourceRefreshResult(
          urls: const <String>['https://tx.flv.huya.com/src/refreshed.flv'],
          preferredLineIndex: 0,
          refreshAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          invalidAt: DateTime.now().toUtc().add(const Duration(minutes: 6)),
        );
      },
    );

    final handoffDeadline = DateTime.now().add(const Duration(milliseconds: 1500));
    while (!identical(manager.currentPlayer, replacement) && DateTime.now().isBefore(handoffDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(refreshCalls, 1);
    expect(creations, 2);
    expect(manager.currentPlayer, same(replacement));
    expect(active.isPlayingNow, isFalse);
    expect(replacement.openedUrls, <String>['https://tx.flv.huya.com/src/refreshed.flv']);
    expect(manager.hasError.value, isFalse);
    await manager.dispose();
  }, skip: !Platform.isWindows);

  test('successive Windows Huya handoffs alternate two initialized players', () async {
    final first = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final second = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    var creations = 0;
    var refreshCalls = 0;
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: first},
      playerCreator: (_) {
        creations++;
        if (creations == 1) return first;
        if (creations == 2) return second;
        throw StateError('warm standby was not reused');
      },
      windowsHuyaProactiveRefreshInterval: const Duration(milliseconds: 20),
    );
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    await manager.play(
      'https://al.flv.huya.com/src/lease-1.flv',
      const <String>['https://al.flv.huya.com/src/lease-1.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'huya-ping-pong-refresh', platform: 'huya'),
      sourceRefreshAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      sourceResolver: (_) async {
        refreshCalls++;
        if (refreshCalls > 2) {
          return const PlaybackSourceRefreshResult(urls: <String>[], preferredLineIndex: 0);
        }
        return PlaybackSourceRefreshResult(
          urls: <String>['https://al.flv.huya.com/src/lease-${refreshCalls + 1}.flv'],
          preferredLineIndex: 0,
          refreshAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        );
      },
    );

    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while ((!identical(manager.currentPlayer, first) || refreshCalls < 2) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(refreshCalls, greaterThanOrEqualTo(2));
    expect(creations, 2);
    expect(manager.currentPlayer, same(first));
    expect(first.openedUrls, <String>[
      'https://al.flv.huya.com/src/lease-1.flv',
      'https://al.flv.huya.com/src/lease-3.flv',
    ]);
    expect(second.openedUrls, <String>['https://al.flv.huya.com/src/lease-2.flv']);
    expect(first.softStopCalls, 1);
    expect(second.softStopCalls, 1);
    expect(first.disposeCalls, 0);
    expect(second.disposeCalls, 0);

    await manager.dispose();
    expect(first.disposeCalls, 1);
    expect(second.disposeCalls, 1);
  }, skip: !Platform.isWindows);

  test('failed proactive Windows handoff retains the healthy active transport', () async {
    final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final replacement = _RecoveryFakePlayer(
      PlayerEngine.mediaKit,
      (_) => PlayerException(message: 'candidate TLS open failed', type: PlayerErrorType.network),
    );
    var creations = 0;
    var refreshCalls = 0;
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: active,
    }, playerCreator: (_) => creations++ == 0 ? active : replacement);
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    await manager.play(
      'https://cdn.example/leased.flv',
      const <String>['https://cdn.example/leased.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'huya-proactive-refresh-failure', platform: 'huya'),
      sourceRefreshAt: DateTime.now().toUtc().add(const Duration(milliseconds: 20)),
      sourceResolver: (_) async {
        refreshCalls++;
        return PlaybackSourceRefreshResult(
          urls: const <String>['https://cdn.example/refreshed.flv'],
          preferredLineIndex: 0,
          refreshAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        );
      },
    );

    await Future<void>.delayed(const Duration(milliseconds: 1200));

    expect(refreshCalls, 1);
    expect(creations, 2);
    expect(manager.currentPlayer, same(active));
    expect(active.isPlayingNow, isTrue);
    expect(active.openedUrls, <String>['https://cdn.example/leased.flv']);
    expect(replacement.disposeCalls, 1);
    expect(manager.hasError.value, isFalse);
    await manager.dispose();
  }, skip: !Platform.isWindows);

  test('reactive refresh reopens a dead Windows transport when the signed URL is unchanged', () async {
    final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final replacement = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    var creations = 0;
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: active,
    }, playerCreator: (_) => creations++ == 0 ? active : replacement);
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    await manager.play(
      'https://cdn.example/still-valid.flv',
      const <String>['https://cdn.example/still-valid.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'huya-same-lease', platform: 'huya'),
      sourceResolver: (_) async => const PlaybackSourceRefreshResult(
        urls: <String>['https://cdn.example/still-valid.flv'],
        preferredLineIndex: 0,
      ),
    );
    active.emitError(PlayerException(message: 'TLS transport ended', type: PlayerErrorType.network));

    final deadline = DateTime.now().add(const Duration(milliseconds: 500));
    while (!identical(manager.currentPlayer, replacement) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(creations, 2);
    expect(manager.currentPlayer, same(replacement));
    expect(replacement.openedUrls, <String>['https://cdn.example/still-valid.flv']);
    expect(manager.hasError.value, isFalse);
    await manager.dispose();
  }, skip: !Platform.isWindows);

  test('sustained frames restore the bounded same-engine recovery budget', () async {
    final players = <_FrameProgressFakePlayer>[
      _FrameProgressFakePlayer(),
      _FrameProgressFakePlayer(),
      _FrameProgressFakePlayer(),
    ];
    var creations = 0;
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: players.first},
      videoFrameStallTimeout: const Duration(milliseconds: 18),
      recoveryBudgetResetDelay: const Duration(milliseconds: 28),
      transientLiveRetryDelays: const <Duration>[],
      playerCreator: (_) => players[creations++],
    );
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    await manager.play(
      'https://cdn.example/long-session.flv',
      const <String>['https://cdn.example/long-session.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'huya-long-session', platform: 'huya'),
    );
    players.first.emitFrame();

    final firstCandidateDeadline = DateTime.now().add(const Duration(milliseconds: 300));
    while (players[1].openedUrls.isEmpty && DateTime.now().isBefore(firstCandidateDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    players[1].emitFrame();

    final firstRecoveryDeadline = DateTime.now().add(const Duration(milliseconds: 300));
    while (!identical(manager.currentPlayer, players[1]) && DateTime.now().isBefore(firstRecoveryDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(creations, 2);
    expect(manager.currentPlayer, same(players[1]));

    // Keep the replacement demonstrably healthy beyond the reset interval.
    // A later independent stall must receive a new bounded recovery attempt.
    for (var index = 0; index < 8; index++) {
      players[1].emitFrame();
      await Future<void>.delayed(const Duration(milliseconds: 6));
    }

    final secondCandidateDeadline = DateTime.now().add(const Duration(milliseconds: 300));
    while (players.first.openedUrls.length < 2 && DateTime.now().isBefore(secondCandidateDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    players.first.emitFrame();

    final secondRecoveryDeadline = DateTime.now().add(const Duration(milliseconds: 300));
    while (!identical(manager.currentPlayer, players.first) && DateTime.now().isBefore(secondRecoveryDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(creations, 2);
    expect(manager.currentPlayer, same(players.first));
    expect(manager.hasError.value, isFalse);
    await manager.dispose();
  });

  test('exhausted immediate recovery waits for a fresh bounded transport round', () async {
    var activeOpenCount = 0;
    final active = _RecoveryFakePlayer(
      PlayerEngine.mediaKit,
      (_) => activeOpenCount++ == 0
          ? null
          : PlayerException(message: 'active transport remains closed', type: PlayerErrorType.source),
    );
    _RecoveryFakePlayer failedCandidate() => _RecoveryFakePlayer(
      PlayerEngine.mediaKit,
      (_) => PlayerException(message: 'transient TLS failure', type: PlayerErrorType.source),
    );
    final candidates = <_RecoveryFakePlayer>[
      failedCandidate(),
      failedCandidate(),
      failedCandidate(),
      _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null),
    ];
    var creations = 0;
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: active},
      transientLiveRetryDelays: const <Duration>[Duration(milliseconds: 12)],
      playerCreator: (_) => creations++ == 0 ? active : candidates[(creations - 2).clamp(0, candidates.length - 1)],
    );
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    await manager.play(
      'https://cdn.example/retry-after-tls.flv',
      const <String>['https://cdn.example/retry-after-tls.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'huya-backoff', platform: 'huya'),
      sourceResolver: (_) async => const PlaybackSourceRefreshResult(
        urls: <String>['https://cdn.example/retry-after-tls.flv'],
        preferredLineIndex: 0,
      ),
    );
    active.emitError(PlayerException(message: 'socket EOF', type: PlayerErrorType.network));

    final recovered = candidates.last;
    final deadline = DateTime.now().add(const Duration(seconds: 1));
    while (!identical(manager.currentPlayer, recovered) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(manager.currentPlayer, same(recovered));
    expect(recovered.openedUrls, <String>['https://cdn.example/retry-after-tls.flv']);
    expect(manager.hasError.value, isFalse);
    await manager.dispose();
  }, skip: !Platform.isWindows);

  test('continuous presented frames keep the live renderer healthy', () async {
    final first = _FrameProgressFakePlayer();
    final replacement = _FrameProgressFakePlayer();
    var creations = 0;
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: first},
      videoFrameStallTimeout: const Duration(milliseconds: 18),
      playerCreator: (_) => creations++ == 0 ? first : replacement,
    );
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    await manager.play(
      'https://cdn.example/healthy-live.flv',
      const <String>['https://cdn.example/healthy-live.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'healthy-frame-watchdog', platform: 'huya'),
    );
    for (var i = 0; i < 8; i++) {
      first.emitFrame();
      await Future<void>.delayed(const Duration(milliseconds: 6));
    }

    expect(creations, 1);
    expect(manager.currentPlayer, same(first));
    await manager.dispose();
  });

  test('audio interruption resumes only the playback intent it suspended', () async {
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: mediaKit,
    }, unexpectedPauseGrace: const Duration(milliseconds: 2));
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    await manager.play(
      'https://cdn.example/live.flv',
      const <String>['https://cdn.example/live.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'audio-focus', platform: 'test'),
    );
    final token = await manager.pauseForAudioInterruption();
    expect(token, isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(mediaKit.playCalls, 0);

    expect(await manager.resumeFromAudioInterruption(token!), isTrue);
    expect(mediaKit.playCalls, 1);

    final staleToken = await manager.pauseForAudioInterruption();
    expect(staleToken, isNotNull);
    await manager.pause();
    expect(await manager.resumeFromAudioInterruption(staleToken!), isFalse);
    expect(mediaKit.playCalls, 1);
    await manager.dispose();
  });

  test('unexpected live completion enters the existing engine fallback path', () async {
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final fijk = _RecoveryFakePlayer(PlayerEngine.fijk, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: mediaKit,
      PlayerEngine.fijk: fijk,
    });
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    await manager.play(
      'https://cdn.example/live.flv',
      const <String>['https://cdn.example/live.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'completed-live', platform: 'test'),
    );
    mediaKit.emitCompleted();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(manager.currentEngine, PlayerEngine.fijk);
    expect(fijk.openedUrls, <String>['https://cdn.example/live.flv']);
    await manager.dispose();
  });
}

PlayerManager _manager(
  Map<PlayerEngine, _RecoveryFakePlayer> players, {
  Duration sourceOpenTimeout = const Duration(seconds: 18),
  Duration sourceReadyTimeout = Duration.zero,
  Duration unexpectedPauseGrace = const Duration(milliseconds: 1200),
  Duration? unexpectedPauseFailureGrace,
  Duration bufferingStallTimeout = const Duration(seconds: 12),
  Duration videoFrameStallTimeout = const Duration(seconds: 10),
  Duration recoveryBudgetResetDelay = const Duration(seconds: 30),
  Duration windowsHuyaProactiveRefreshInterval = const Duration(seconds: 40),
  List<Duration> transientLiveRetryDelays = const <Duration>[Duration(milliseconds: 750), Duration(seconds: 2)],
  UnifiedPlayerCreator? playerCreator,
}) {
  return PlayerManager(
    playerCreator: playerCreator ?? (engine) => players[engine]!,
    fallbackManager: EngineFallbackManager(
      defaultEngine: PlayerEngine.mediaKit,
      supportedEngines: players.keys.toList(growable: false),
    ),
    lineManager: LineFallbackManager(),
    sourceOpenTimeout: sourceOpenTimeout,
    sourceReadyTimeout: sourceReadyTimeout,
    unexpectedPauseGrace: unexpectedPauseGrace,
    unexpectedPauseFailureGrace: unexpectedPauseFailureGrace ?? unexpectedPauseGrace,
    bufferingStallTimeout: bufferingStallTimeout,
    videoFrameStallTimeout: videoFrameStallTimeout,
    recoveryBudgetResetDelay: recoveryBudgetResetDelay,
    windowsHuyaProactiveRefreshInterval: windowsHuyaProactiveRefreshInterval,
    transientLiveRetryDelays: transientLiveRetryDelays,
    useHardStopOnExit: () => false,
    audioModeServiceSync: (_, _) async {},
    audioSessionStart: (_) async {},
  );
}

class _RecoveryFakePlayer implements UnifiedPlayer {
  _RecoveryFakePlayer(
    this.engine,
    this.failureForUrl, {
    this.initFailure,
    this.emitPlaying = true,
    this.hangWhileOpening = false,
    this.emittedWidth,
    this.emittedHeight,
  });

  @override
  final PlayerEngine engine;
  final PlayerException? Function(String url) failureForUrl;
  final Object? initFailure;
  final bool emitPlaying;
  final bool hangWhileOpening;
  final int? emittedWidth;
  final int? emittedHeight;
  final List<String> openedUrls = <String>[];
  final StreamController<PlayerState> _state = StreamController<PlayerState>.broadcast(sync: true);
  final StreamController<bool> _playing = StreamController<bool>.broadcast(sync: true);
  final StreamController<bool> _loading = StreamController<bool>.broadcast(sync: true);
  final StreamController<bool> _complete = StreamController<bool>.broadcast(sync: true);
  final StreamController<PlayerException> _error = StreamController<PlayerException>.broadcast(sync: true);
  final StreamController<int?> _width = StreamController<int?>.broadcast(sync: true);
  final StreamController<int?> _height = StreamController<int?>.broadcast(sync: true);
  bool _initialized = false;
  bool _isPlaying = false;
  int playCalls = 0;
  int disposeCalls = 0;
  int softStopCalls = 0;

  void emitUnexpectedPlaying(bool playing) {
    _isPlaying = playing;
    _playing.add(playing);
  }

  void emitLoading(bool loading) {
    _loading.add(loading);
  }

  void emitNativeState(PlayerState state) {
    _state.add(state);
  }

  void emitCompleted() {
    _isPlaying = false;
    _playing.add(false);
    _complete.add(true);
  }

  void emitError(PlayerException error) {
    _error.add(error);
  }

  @override
  Future<void> init({bool audioOnly = false}) async {
    final error = initFailure;
    if (error != null) throw error;
    _initialized = true;
  }

  @override
  Future<void> setDataSource(
    String url,
    List<String> playUrls,
    Map<String, String> headers, {
    LiveRoom? room,
    bool audioOnly = false,
  }) async {
    openedUrls.add(url);
    if (hangWhileOpening) await Completer<void>().future;
    final failure = failureForUrl(url);
    if (failure != null) throw failure;
    if (emittedWidth != null && emittedHeight != null) {
      _width.add(emittedWidth);
      _height.add(emittedHeight);
    }
    if (emitPlaying) {
      _isPlaying = true;
      _state.add(PlayerState.playing);
      _playing.add(true);
      _loading.add(false);
    }
  }

  @override
  Future<void> hardDispose() async {
    disposeCalls++;
    _initialized = false;
    _isPlaying = false;
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _playing.add(false);
  }

  @override
  Future<void> play() async {
    playCalls++;
    _isPlaying = true;
    _playing.add(true);
  }

  @override
  Future<void> setAudioOnly(bool audioOnly) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> softStop() async {
    softStopCalls++;
    _isPlaying = false;
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
  }

  @override
  Widget getVideoWidget({BoxFit? fit}) => const SizedBox.shrink();

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isPlayingNow => _isPlaying;

  @override
  bool get isReusable => true;

  @override
  Stream<bool> get onComplete => _complete.stream;

  @override
  Stream<PlayerException> get onError => _error.stream;

  @override
  Stream<bool> get onLoading => _loading.stream;

  @override
  Stream<bool> get onPlaying => _playing.stream;

  @override
  Stream<PlayerState> get onStateChanged => _state.stream;

  @override
  Stream<int?> get width => _width.stream;

  @override
  Stream<int?> get height => _height.stream;
}

class _FrameProgressFakePlayer extends _RecoveryFakePlayer implements VideoFrameProgressAwarePlayer {
  _FrameProgressFakePlayer() : super(PlayerEngine.mediaKit, (_) => null);

  final StreamController<int> _frames = StreamController<int>.broadcast(sync: true);
  int _revision = 0;

  void emitFrame() => _frames.add(++_revision);

  @override
  Stream<int> get onVideoFrameProgress => _frames.stream;

  @override
  bool get supportsVideoFrameProgress => true;
}

class _DecoderRecoveryFakePlayer extends _RecoveryFakePlayer implements DecoderRecoveryAwarePlayer {
  _DecoderRecoveryFakePlayer() : super(PlayerEngine.mediaKit, (_) => null);

  int softwareFallbackRequests = 0;
  bool _softwarePrepared = false;

  @override
  Future<bool> prepareSoftwareDecoderFallback(PlayerException error) async {
    if (_softwarePrepared || error.type != PlayerErrorType.codec) return false;
    _softwarePrepared = true;
    softwareFallbackRequests++;
    return true;
  }

  @override
  Future<void> setDataSource(
    String url,
    List<String> playUrls,
    Map<String, String> headers, {
    LiveRoom? room,
    bool audioOnly = false,
  }) async {
    openedUrls.add(url);
    if (!_softwarePrepared) {
      throw PlayerException(message: 'MediaCodec rejected profile', type: PlayerErrorType.codec);
    }
    await super.setDataSource(url, playUrls, headers, room: room, audioOnly: audioOnly);
    // [super] records the successful open too; keep one entry per invocation.
    openedUrls.removeAt(openedUrls.length - 1);
  }
}

class _AudioDecoderRecoveryFakePlayer extends _RecoveryFakePlayer implements DecoderRecoveryAwarePlayer {
  _AudioDecoderRecoveryFakePlayer()
    : super(
        PlayerEngine.mediaKit,
        (_) => PlayerException(
          message: 'Audio decoder initialization failed',
          type: PlayerErrorType.codec,
          code: 'audio_decoder_runtime',
        ),
      );

  int softwareFallbackRequests = 0;

  @override
  Future<bool> prepareSoftwareDecoderFallback(PlayerException error) async {
    softwareFallbackRequests++;
    return true;
  }
}
