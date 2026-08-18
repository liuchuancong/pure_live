import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/player/core/engine_fallback_manager.dart';
import 'package:pure_live/player/core/line_fallback_manager.dart';
import 'package:pure_live/player/core/player_manager.dart';
import 'package:pure_live/player/core/player_pool.dart';
import 'package:pure_live/player/core/preload_player_manager.dart';
import 'package:pure_live/player/interface/unified_player_interface.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/player/models/player_exception.dart';
import 'package:pure_live/player/models/player_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    Get.put(GlobalPlayerState());
  });

  tearDown(Get.reset);

  test('audio-only changes the current player in place without reopening the stream', () async {
    final player = _FakePlayer();
    final manager = _createManager(player);
    await manager.initialize(engine: PlayerEngine.mediaKit);
    final surfaceKey = manager.videoKey.value;

    await manager.setAudioOnlyMode(true);

    expect(manager.currentPlayer, same(player));
    expect(manager.isAudioOnlyMode, isTrue);
    expect(player.audioOnlyChanges, <bool>[true]);
    expect(player.setDataSourceCalls, 0);
    expect(player.hardDisposeCalls, 0);
    expect(manager.videoKey.value, same(surfaceKey));

    await manager.setAudioOnlyMode(false);
    expect(manager.currentPlayer, same(player));
    expect(manager.isAudioOnlyMode, isFalse);
    expect(player.audioOnlyChanges, <bool>[true, false]);
    expect(player.setDataSourceCalls, 0);
    expect(manager.videoKey.value, same(surfaceKey));

    await manager.dispose();
  });

  test('a stalled native switch times out, rolls back and releases the transition', () async {
    final player = _FakePlayer(hangWhenEnablingAudioOnly: true);
    final manager = _createManager(player, timeout: const Duration(milliseconds: 20));
    await manager.initialize(engine: PlayerEngine.mediaKit);

    await expectLater(manager.setAudioOnlyMode(true), throwsA(isA<PlayerException>()));

    expect(manager.currentPlayer, same(player));
    expect(manager.isAudioOnlyMode, isFalse);
    expect(player.audioOnlyChanges, <bool>[true, false]);
    expect(player.setDataSourceCalls, 0);
    expect(player.hardDisposeCalls, 0);

    await manager.dispose();
  });

  test('repeated audio and video toggles keep one player and one surface', () async {
    final player = _FakePlayer();
    final manager = _createManager(player);
    await manager.initialize(engine: PlayerEngine.mediaKit);
    final surfaceKey = manager.videoKey.value;

    for (var index = 0; index < 20; index++) {
      await manager.setAudioOnlyMode(true);
      await manager.setAudioOnlyMode(false);
    }

    expect(manager.currentPlayer, same(player));
    expect(manager.isAudioOnlyMode, isFalse);
    expect(manager.videoKey.value, same(surfaceKey));
    expect(player.setDataSourceCalls, 0);
    expect(player.hardDisposeCalls, 0);
    expect(player.audioOnlyChanges, hasLength(40));

    await manager.dispose();
  });

  test('a room re-entry request supersedes an in-flight audio-only request', () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final player = _FakePlayer(
      onAudioOnlyChange: (value) async {
        if (value) {
          firstStarted.complete();
          await releaseFirst.future;
        }
      },
    );
    final manager = _createManager(player);
    await manager.initialize(engine: PlayerEngine.mediaKit);

    final oldRoomRequest = manager.setAudioOnlyMode(true);
    await firstStarted.future;
    final reentryRequest = manager.setAudioOnlyMode(false);
    releaseFirst.complete();

    await Future.wait([oldRoomRequest, reentryRequest]);
    expect(player.audioOnlyChanges, <bool>[true, false]);
    expect(manager.isAudioOnlyMode, isFalse);
    expect(manager.desiredAudioOnlyMode, isFalse);

    await manager.dispose();
  });

  test('play waits for an in-flight close instead of silently returning', () async {
    final stopStarted = Completer<void>();
    final releaseStop = Completer<void>();
    final player = _FakePlayer(
      onStop: () async {
        stopStarted.complete();
        await releaseStop.future;
      },
    );
    final manager = _createManager(player);
    await manager.initialize(engine: PlayerEngine.mediaKit);

    final closing = manager.close();
    await stopStarted.future;
    final replaying = manager.play(
      'https://example.invalid/live.flv',
      const ['https://example.invalid/live.flv'],
      const {},
      room: LiveRoom(roomId: 'room-1', platform: 'test'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(player.setDataSourceCalls, 0);

    releaseStop.complete();
    await Future.wait([closing, replaying]);
    expect(player.setDataSourceCalls, 1);

    await manager.dispose();
  });

  test('floating re-entry handoff is explicit, room-scoped and single-use', () async {
    final player = _FakePlayer();
    final manager = _createManager(player);
    final room = LiveRoom(roomId: 'room-1', platform: 'test');
    await manager.initialize(engine: PlayerEngine.mediaKit);
    await manager.play(
      'https://example.invalid/live.flv',
      const ['https://example.invalid/live.flv'],
      const {},
      room: room,
    );
    manager.prepareAppFloating(onClose: () async {});

    manager.prepareRoomSessionReentry(room);
    expect(manager.consumeRoomSessionReentry(room), isTrue);
    expect(manager.consumeRoomSessionReentry(room), isFalse);

    manager.prepareRoomSessionReentry(room);
    expect(manager.consumeRoomSessionReentry(LiveRoom(roomId: 'room-2', platform: 'test')), isFalse);
  });

  testWidgets('floating cleanup preserves the same-room re-entry handoff', (tester) async {
    final player = _FakePlayer();
    final manager = _createManager(player);
    final room = LiveRoom(roomId: 'room-1', platform: 'test');
    await manager.initialize(engine: PlayerEngine.mediaKit);
    await manager.play(
      'https://example.invalid/live.flv',
      const ['https://example.invalid/live.flv'],
      const {},
      room: room,
    );
    manager.prepareAppFloating(onClose: () async {});

    manager.prepareRoomSessionReentry(room);
    final cleanup = manager.closeAppFloating();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await cleanup.timeout(const Duration(seconds: 2));

    expect(manager.consumeRoomSessionReentry(room), isTrue);
    expect(manager.currentPlayer, same(player));
  }, timeout: const Timeout(Duration(seconds: 10)));
}

PlayerManager _createManager(_FakePlayer player, {Duration timeout = const Duration(seconds: 1)}) {
  return PlayerManager(
    playerPool: PlayerPool(factory: (_) async => player),
    fallbackManager: EngineFallbackManager(
      defaultEngine: PlayerEngine.mediaKit,
      supportedEngines: const <PlayerEngine>[PlayerEngine.mediaKit],
    ),
    preloadManager: PreloadPlayerManager(),
    lineManager: LineFallbackManager(),
    audioModeSwitchTimeout: timeout,
    useHardStopOnExit: () => false,
  );
}

class _FakePlayer implements UnifiedPlayer {
  _FakePlayer({this.hangWhenEnablingAudioOnly = false, this.onAudioOnlyChange, this.onStop});

  final bool hangWhenEnablingAudioOnly;
  final Future<void> Function(bool value)? onAudioOnlyChange;
  final Future<void> Function()? onStop;
  final List<bool> audioOnlyChanges = <bool>[];
  int setDataSourceCalls = 0;
  int hardDisposeCalls = 0;
  bool _initialized = false;

  @override
  Future<void> init({bool audioOnly = false}) async {
    _initialized = true;
  }

  @override
  Future<void> setAudioOnly(bool audioOnly) async {
    audioOnlyChanges.add(audioOnly);
    await onAudioOnlyChange?.call(audioOnly);
    if (audioOnly && hangWhenEnablingAudioOnly) {
      await Completer<void>().future;
    }
  }

  @override
  Future<void> setDataSource(
    String url,
    List<String> playUrls,
    Map<String, String> headers, {
    LiveRoom? room,
    bool audioOnly = false,
  }) async {
    setDataSourceCalls++;
  }

  @override
  Future<void> hardDispose() async {
    hardDisposeCalls++;
    _initialized = false;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> softStop() async {
    await onStop?.call();
  }

  @override
  Future<void> stop() async {}

  @override
  Widget getVideoWidget() => const SizedBox.shrink();

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isPlayingNow => true;

  @override
  bool get isReusable => true;

  @override
  Stream<bool> get onComplete => const Stream<bool>.empty();

  @override
  Stream<PlayerException> get onError => const Stream<PlayerException>.empty();

  @override
  Stream<bool> get onLoading => const Stream<bool>.empty();

  @override
  Stream<bool> get onPlaying => const Stream<bool>.empty();

  @override
  Stream<PlayerState> get onStateChanged => const Stream<PlayerState>.empty();

  @override
  Stream<int?> get width => const Stream<int?>.empty();

  @override
  Stream<int?> get height => const Stream<int?>.empty();
}
