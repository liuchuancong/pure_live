import 'dart:async';

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
}) {
  return PlayerManager(
    playerCreator: (engine) => players[engine]!,
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

  void emitUnexpectedPlaying(bool playing) {
    _isPlaying = playing;
    _playing.add(playing);
  }

  void emitLoading(bool loading) {
    _loading.add(loading);
  }

  void emitCompleted() {
    _isPlaying = false;
    _playing.add(false);
    _complete.add(true);
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
