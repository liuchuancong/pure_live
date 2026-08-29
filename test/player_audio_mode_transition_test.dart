import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/player/core/player_manager.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';
import 'package:pure_live/player/models/player_state.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/player/models/player_exception.dart';
import 'package:pure_live/player/core/line_fallback_manager.dart';
import 'package:pure_live/player/core/engine_fallback_manager.dart';
import 'package:pure_live/player/interface/unified_player_interface.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/states/player_state.dart' as room_state;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    Get.put(GlobalPlayerState());
  });

  tearDown(Get.reset);

  test('unrelated player-state updates retain the active route video controller', () {
    final controller = Object();

    expect(room_state.resolveVideoControllerUpdate<Object>(current: controller), same(controller));
    expect(
      room_state.resolveVideoControllerUpdate<Object>(current: controller, next: Object()),
      isNot(same(controller)),
    );
    expect(room_state.resolveVideoControllerUpdate<Object>(current: controller, clear: true), isNull);
  });

  test('Android Surface policy keeps requested audio-only state across lifecycle changes', () {
    expect(resolveVideoTrackForSurface(videoOutputEnabled: false, surfaceAttached: true), 'no');
    expect(resolveVideoTrackForSurface(videoOutputEnabled: false, surfaceAttached: false), 'no');
    expect(resolveVideoTrackForSurface(videoOutputEnabled: true, surfaceAttached: false), 'auto');
    expect(resolveVideoTrackForSurface(videoOutputEnabled: true, surfaceAttached: true), 'auto');
  });

  test('Android video mode stays active before and after a delayed Surface attach', () {
    final beforeAttach = resolveAndroidSurfaceProperties(
      width: 1920,
      height: 1080,
      wid: null,
      configuredVo: 'gpu',
      videoOutputEnabled: true,
    );
    final afterAttach = resolveAndroidSurfaceProperties(
      width: 1920,
      height: 1080,
      wid: 42,
      configuredVo: 'gpu',
      videoOutputEnabled: true,
    );

    // Regression: forcing `vid=no` here made a fresh room black on devices
    // whose SurfaceProducer callback had already fired.
    expect(beforeAttach, containsPair('vid', 'auto'));
    expect(beforeAttach, containsPair('vo', 'null'));
    expect(afterAttach, containsPair('vid', 'auto'));
    expect(afterAttach, containsPair('vo', 'gpu'));
    expect(afterAttach.keys.toList(), <String>['android-surface-size', 'wid', 'vo', 'vid']);
  });

  test('audio-only changes the current player in place without reopening the stream', () async {
    final player = _FakePlayer();
    final manager = _createManager(player);
    await manager.initialize(engine: PlayerEngine.mediaKit);
    final surfaceKey = manager.videoKey.value;
    final presentationRevision = manager.videoPresentationRevision.value;

    await manager.setAudioOnlyMode(true);

    expect(manager.currentPlayer, same(player));
    expect(manager.isAudioOnlyMode, isTrue);
    expect(player.audioOnlyChanges, <bool>[true]);
    expect(player.setDataSourceCalls, 0);
    expect(player.hardDisposeCalls, 0);
    expect(manager.videoKey.value, same(surfaceKey));
    expect(manager.videoPresentationRevision.value, presentationRevision + 1);

    await manager.setAudioOnlyMode(false);
    expect(manager.currentPlayer, same(player));
    expect(manager.isAudioOnlyMode, isFalse);
    expect(player.audioOnlyChanges, <bool>[true, false]);
    expect(player.setDataSourceCalls, 0);
    expect(manager.videoKey.value, same(surfaceKey));
    expect(manager.videoPresentationRevision.value, presentationRevision + 2);

    await manager.dispose();
  });

  test('configuring the default engine keeps native player allocation lazy', () async {
    final player = _FakePlayer();
    final manager = _createManager(player);

    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    expect(player.initCalls, 0);
    expect(manager.currentPlayer, isNull);
    expect(manager.currentEngine, PlayerEngine.mediaKit);

    await manager.play(
      'https://example.invalid/live.flv',
      const <String>['https://example.invalid/live.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'lazy-room', platform: 'test'),
    );

    expect(player.initCalls, 1);
    expect(manager.currentPlayer, same(player));
    await manager.dispose();
  });

  test('manual engine switch opens the active source before retiring the old decoder', () async {
    final oldPlayer = _FakePlayer(playerEngine: PlayerEngine.mediaKit);
    late final _FakePlayer candidate;
    candidate = _FakePlayer(
      playerEngine: PlayerEngine.fijk,
      onSetDataSource: (_, _, _, {room, required audioOnly}) async {
        expect(oldPlayer.hardDisposeCalls, 0);
      },
    );
    final manager = _createManager(
      oldPlayer,
      playerCreator: (engine) => engine == PlayerEngine.mediaKit ? oldPlayer : candidate,
    );
    await manager.initialize(engine: PlayerEngine.mediaKit);
    await manager.play(
      'https://example.invalid/live.flv',
      const <String>['https://example.invalid/live.flv'],
      const <String, String>{'referer': 'https://example.invalid'},
      room: LiveRoom(roomId: 'switch-room', platform: 'test'),
    );

    await manager.switchEngine(PlayerEngine.fijk, isManual: true);

    expect(manager.currentPlayer, same(candidate));
    expect(manager.currentEngine, PlayerEngine.fijk);
    expect(candidate.openedUrls, <String>['https://example.invalid/live.flv']);
    expect(oldPlayer.hardDisposeCalls, 1);
    expect(candidate.hardDisposeCalls, 0);
    await manager.dispose();
  });

  test('failed engine candidate preserves the active decoder and engine selection', () async {
    final oldPlayer = _FakePlayer(playerEngine: PlayerEngine.mediaKit);
    final candidate = _FakePlayer(
      playerEngine: PlayerEngine.fijk,
      sourceError: StateError('candidate source rejected'),
    );
    final manager = _createManager(
      oldPlayer,
      playerCreator: (engine) => engine == PlayerEngine.mediaKit ? oldPlayer : candidate,
    );
    await manager.initialize(engine: PlayerEngine.mediaKit);
    await manager.play(
      'https://example.invalid/live.flv',
      const <String>['https://example.invalid/live.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'rollback-room', platform: 'test'),
    );

    await expectLater(manager.switchEngine(PlayerEngine.fijk, isManual: true), throwsA(isA<PlayerException>()));

    expect(manager.currentPlayer, same(oldPlayer));
    expect(manager.currentEngine, PlayerEngine.mediaKit);
    expect(oldPlayer.hardDisposeCalls, 0);
    expect(candidate.hardDisposeCalls, 1);
    await manager.dispose();
  });

  test('play-time default engine replacement opens the requested source exactly once', () async {
    final initialPlayer = _FakePlayer(playerEngine: PlayerEngine.mediaKit);
    final fallbackPlayer = _FakePlayer(playerEngine: PlayerEngine.fijk);
    final candidate = _FakePlayer(playerEngine: PlayerEngine.mediaKit);
    var mediaKitCreations = 0;
    final manager = _createManager(
      initialPlayer,
      playerCreator: (engine) {
        if (engine == PlayerEngine.fijk) return fallbackPlayer;
        return mediaKitCreations++ == 0 ? initialPlayer : candidate;
      },
    );
    await manager.initialize(engine: PlayerEngine.mediaKit);
    await manager.switchEngine(PlayerEngine.fijk, isManual: false);

    await manager.play(
      'https://example.invalid/next.flv',
      const <String>['https://example.invalid/next.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'next-room', platform: 'test'),
    );

    expect(manager.currentPlayer, same(candidate));
    expect(candidate.setDataSourceCalls, 1);
    expect(candidate.openedUrls, <String>['https://example.invalid/next.flv']);
    expect(fallbackPlayer.setDataSourceCalls, 0);
    expect(initialPlayer.hardDisposeCalls, 1);
    expect(fallbackPlayer.hardDisposeCalls, 1);
    await manager.dispose();
  });

  test('lifecycle pause resumes only the same session and playback intent', () async {
    final player = _FakePlayer();
    final manager = _createManager(player);
    await manager.initialize(engine: PlayerEngine.mediaKit);

    final token = await manager.pauseForLifecycle();
    expect(token, isNotNull);
    expect(player.pauseCalls, 1);
    expect(player.isPlayingNow, isFalse);

    expect(await manager.resumeFromLifecycle(token!), isTrue);
    expect(player.playCalls, 1);
    expect(player.isPlayingNow, isTrue);

    final staleToken = await manager.pauseForLifecycle();
    expect(staleToken, isNotNull);
    await manager.pause();
    expect(await manager.resumeFromLifecycle(staleToken!), isFalse);
    expect(player.isPlayingNow, isFalse);

    await manager.dispose();
  });

  test('a new room clears stale portrait geometry before its metadata arrives', () async {
    final player = _FakePlayer();
    final manager = _createManager(player);
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    await manager.play(
      'https://example.invalid/portrait.flv',
      const <String>['https://example.invalid/portrait.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'portrait-room', platform: 'test'),
    );
    player.emitVideoSize(width: 1080, height: 1920);
    await manager.isVerticalVideo.stream.firstWhere((vertical) => vertical).timeout(const Duration(seconds: 2));

    expect(manager.isVerticalVideo.value, isTrue);
    expect(manager.currentVideoRatio, closeTo(9 / 16, 0.001));

    await manager.play(
      'https://example.invalid/landscape.flv',
      const <String>['https://example.invalid/landscape.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'landscape-room', platform: 'test'),
    );

    expect(manager.isVerticalVideo.value, isFalse);
    expect(manager.currentVideoRatio, closeTo(16 / 9, 0.001));

    player.emitVideoSize(width: 1920, height: 1080);
    await Future<void>.delayed(const Duration(milliseconds: 850));
    expect(manager.isVerticalVideo.value, isFalse);
    expect(manager.currentVideoRatio, closeTo(16 / 9, 0.001));

    player.emitVideoSize(width: 6000, height: 1000);
    await Future<void>.delayed(const Duration(milliseconds: 850));
    expect(manager.isVerticalVideo.value, isFalse);
    expect(
      manager.currentVideoRatio,
      closeTo(16 / 9, 0.001),
      reason: 'malformed landscape metadata must not resize fullscreen/PiP/floating presentation',
    );

    await manager.dispose();
  });

  test('a delayed media-service sync never blocks or rolls back the native mode change', () async {
    final player = _FakePlayer();
    final syncStarted = Completer<void>();
    final releaseSync = Completer<void>();
    final manager = _createManager(
      player,
      audioModeServiceSync: (_, _) async {
        if (!syncStarted.isCompleted) syncStarted.complete();
        await releaseSync.future;
      },
    );
    await manager.initialize(engine: PlayerEngine.mediaKit);

    await manager.setAudioOnlyMode(true).timeout(const Duration(milliseconds: 100));
    await syncStarted.future.timeout(const Duration(milliseconds: 100));

    expect(manager.isAudioOnlyMode, isTrue);
    expect(player.audioOnlyChanges, <bool>[true]);
    expect(player.hardDisposeCalls, 0);

    releaseSync.complete();
    await manager.dispose();
  });

  test('player initialization and room readiness never wait for the Android media service', () async {
    final player = _FakePlayer();
    final serviceSyncStarted = Completer<void>();
    final releaseServiceSync = Completer<void>();
    final sessionStartStarted = Completer<void>();
    final releaseSessionStart = Completer<void>();
    final manager = _createManager(
      player,
      audioModeServiceSync: (_, _) async {
        if (!serviceSyncStarted.isCompleted) serviceSyncStarted.complete();
        await releaseServiceSync.future;
      },
      audioSessionStart: (_) async {
        if (!sessionStartStarted.isCompleted) sessionStartStarted.complete();
        await releaseSessionStart.future;
      },
    );

    await manager
        .initialize(engine: PlayerEngine.mediaKit)
        .timeout(const Duration(seconds: 1), onTimeout: () => throw StateError('manager initialization was blocked'));
    await serviceSyncStarted.future.timeout(
      const Duration(seconds: 1),
      onTimeout: () => throw StateError('media-service binding did not start'),
    );
    await manager
        .play(
          'https://example.invalid/live.flv',
          const ['https://example.invalid/live.flv'],
          const {},
          room: LiveRoom(roomId: 'room-1', platform: 'test'),
        )
        .timeout(
          const Duration(seconds: 1),
          onTimeout: () => throw StateError('room playback was blocked by the media service'),
        );

    expect(player.setDataSourceCalls, 1);
    expect(manager.currentPlayer, same(player));

    releaseServiceSync.complete();
    await sessionStartStarted.future.timeout(
      const Duration(seconds: 1),
      onTimeout: () => throw StateError('latest room media session did not drain'),
    );
    releaseSessionStart.complete();
    await Future<void>.delayed(Duration.zero);
    await manager.dispose();
  });

  test('entering audio mode publishes its stable UI before a delayed native track reply', () async {
    final nativeStarted = Completer<void>();
    final releaseNative = Completer<void>();
    final player = _FakePlayer(
      onAudioOnlyChange: (value) async {
        if (value) {
          nativeStarted.complete();
          await releaseNative.future;
        }
      },
    );
    final manager = _createManager(player);
    await manager.initialize(engine: PlayerEngine.mediaKit);

    final switching = manager.setAudioOnlyMode(true);
    await nativeStarted.future.timeout(const Duration(milliseconds: 100));

    expect(manager.isAudioOnlyMode, isTrue);
    releaseNative.complete();
    await switching;
    expect(manager.isAudioOnlyMode, isTrue);

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

  test('a quick manual audio round-trip retains video decode and restores without a native wait', () async {
    final player = _FakePlayer(dedupeAudioMode: true);
    final manager = _createManager(player, warmRetention: const Duration(seconds: 30));
    await manager.initialize(engine: PlayerEngine.mediaKit);

    await manager.setAudioOnlyMode(true);
    expect(manager.isAudioOnlyMode, isTrue);
    expect(player.audioOnlyChanges, isEmpty, reason: 'the short warm window must keep video decode current');

    await manager.setAudioOnlyMode(false);
    expect(manager.isAudioOnlyMode, isFalse);
    expect(player.audioOnlyChanges, isEmpty, reason: 'restoring a warm decoder should be an adapter no-op');

    await manager.dispose();
  });

  test('the warm window eventually enters native low-power audio mode', () async {
    final player = _FakePlayer(dedupeAudioMode: true);
    final manager = _createManager(player, warmRetention: const Duration(milliseconds: 20));
    await manager.initialize(engine: PlayerEngine.mediaKit);

    await manager.setAudioOnlyMode(true);
    expect(player.audioOnlyChanges, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(player.audioOnlyChanges, <bool>[true]);
    // The timer deliberately starts the native change without blocking UI.
    // Let that asynchronous commit publish its final native state before the
    // restore request, rather than racing the fake adapter between its call log
    // and internal state assignment.
    await Future<void>.delayed(Duration.zero);

    await manager.setAudioOnlyMode(false);
    expect(player.audioOnlyChanges, <bool>[true, false]);
    await manager.dispose();
  });

  test('background power saving commits immediately and still restores deterministically', () async {
    final player = _FakePlayer(dedupeAudioMode: true);
    final manager = _createManager(player, warmRetention: const Duration(hours: 1));
    await manager.initialize(engine: PlayerEngine.mediaKit);

    await manager.setAudioOnlyMode(true);
    await manager.commitAudioOnlyPowerSaving();
    expect(player.audioOnlyChanges, <bool>[true]);

    await manager.setAudioOnlyMode(false);
    expect(player.audioOnlyChanges, <bool>[true, false]);
    await manager.dispose();
  });

  test('deep video restore keeps the audio presentation visible until native readiness', () async {
    final restoreStarted = Completer<void>();
    final releaseRestore = Completer<void>();
    final player = _FakePlayer(
      dedupeAudioMode: true,
      onAudioOnlyChange: (value) async {
        if (!value) {
          if (!restoreStarted.isCompleted) restoreStarted.complete();
          await releaseRestore.future;
        }
      },
    );
    final manager = _createManager(player);
    await manager.initialize(engine: PlayerEngine.mediaKit);
    await manager.setAudioOnlyMode(true);

    final restoring = manager.setAudioOnlyMode(false);
    await restoreStarted.future.timeout(const Duration(milliseconds: 100));

    expect(manager.isVideoRestorePending.value, isTrue);
    expect(manager.isAudioOnlyMode, isTrue, reason: 'the stable audio card must cover the keyframe wait');

    releaseRestore.complete();
    await restoring;
    expect(manager.isVideoRestorePending.value, isFalse);
    expect(manager.isAudioOnlyMode, isFalse);
    await manager.dispose();
  });

  test('a resumed manual audio room prewarms video behind the audio presentation', () async {
    final player = _FakePlayer(dedupeAudioMode: true);
    final manager = _createManager(player, warmRetention: null);
    await manager.initialize(engine: PlayerEngine.mediaKit);

    await manager.setAudioOnlyMode(true);
    expect(player.audioOnlyChanges, isEmpty);
    await manager.commitAudioOnlyPowerSaving();
    expect(player.audioOnlyChanges, <bool>[true]);

    await manager.prepareAudioOnlyVideoRestore();
    expect(manager.isAudioOnlyMode, isTrue, reason: 'prewarming must keep the audio card and room mode stable');
    expect(player.audioOnlyChanges, <bool>[true, false]);

    await manager.setAudioOnlyMode(false);
    expect(player.audioOnlyChanges, <bool>[true, false]);
    await manager.dispose();
  });

  testWidgets('audio presentation keeps the native video element mounted for fast restore', (tester) async {
    final lifecycle = _VideoMountLifecycle();
    final player = _FakePlayer(videoWidget: _VideoMountProbe(lifecycle));
    final manager = _createManager(player);
    await manager.initialize(engine: PlayerEngine.mediaKit);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 1280,
          height: 720,
          child: Obx(() => manager.getVideoWidget(0, fitList: const <BoxFit>[BoxFit.contain])),
        ),
      ),
    );
    await tester.pump();
    expect(lifecycle.mounts, 1);
    expect(lifecycle.disposals, 0);

    await manager.setAudioOnlyMode(true);
    await tester.pump();
    expect(lifecycle.mounts, 1, reason: 'entering audio mode must not recreate the native texture');
    expect(lifecycle.disposals, 0);

    manager.isVideoRestorePending.value = true;
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(lifecycle.mounts, 1, reason: 'the restore presentation must remain an overlay on the retained texture');
    expect(tester.takeException(), isNull);
    manager.isVideoRestorePending.value = false;

    await manager.setAudioOnlyMode(false);
    await tester.pump();
    expect(lifecycle.mounts, 1, reason: 'restoring video must reuse the registered Surface/WID');
    expect(lifecycle.disposals, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(lifecycle.disposals, 1);
    unawaited(manager.dispose());
  });

  testWidgets('portrait fullscreen constrains only video and never rewrites the shared fit', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final player = _FakePlayer(
      videoWidget: const ColoredBox(key: ValueKey('native-video-surface'), color: Colors.green),
    );
    final manager = _createManager(player);
    await manager.initialize(engine: PlayerEngine.mediaKit);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: manager.getVideoWidget(
            2,
            fitList: const <BoxFit>[BoxFit.contain, BoxFit.cover, BoxFit.fill],
            surfaceColor: Colors.transparent,
            videoViewportAspectRatio: 9 / 16,
            controls: const ColoredBox(key: ValueKey('fullscreen-controls'), color: Colors.transparent),
          ),
        ),
      ),
    );
    await tester.pump();

    final viewport = tester.getRect(find.byKey(const ValueKey('presentation-video-viewport')));
    final controls = tester.getRect(find.byKey(const ValueKey('fullscreen-controls')));
    expect(viewport.height, closeTo(720, 0.01));
    expect(viewport.width, closeTo(405, 0.01));
    expect(controls.size, const Size(1280, 720));
    expect(player.videoFitRequests, isNotEmpty);
    expect(
      player.videoFitRequests,
      everyElement(BoxFit.fill),
      reason: 'fullscreen geometry must not replace the user fit stored by the shared adapter',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: manager.getVideoWidget(2, fitList: const <BoxFit>[BoxFit.contain, BoxFit.cover, BoxFit.fill]),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('presentation-video-viewport')), findsNothing);
    expect(tester.getSize(find.byKey(const ValueKey('native-video-surface'))), const Size(1280, 720));
    expect(player.videoFitRequests, everyElement(BoxFit.fill));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    unawaited(manager.dispose());
  });

  testWidgets('portrait fullscreen balanced mode applies a bounded video-only zoom', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 3168));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: buildPresentationVideoViewport(
          aspectRatio: 9 / 16,
          mode: PortraitFullscreenDisplayMode.balanced,
          child: const ColoredBox(color: Colors.green),
        ),
      ),
    );

    final transform = tester.widget<Transform>(find.byKey(const ValueKey('presentation-video-balanced-scale')));
    final viewport = tester.getSize(find.byKey(const ValueKey('presentation-video-viewport')));
    expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.08, 0.0001));
    expect(viewport, const Size(1440, 2560));
    expect(tester.getSize(find.byKey(const ValueKey('presentation-video-balanced-clip'))), const Size(1440, 3168));
  });

  testWidgets('portrait fullscreen cover delegates the whole surface to the native cover fit', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final player = _FakePlayer(
      videoWidget: const ColoredBox(key: ValueKey('portrait-cover-native-video'), color: Colors.green),
    );
    final manager = _createManager(player);
    await manager.initialize(engine: PlayerEngine.mediaKit);

    await tester.pumpWidget(
      MaterialApp(
        home: manager.getVideoWidget(
          0,
          fitList: const <BoxFit>[BoxFit.contain],
          videoViewportAspectRatio: 9 / 16,
          portraitFullscreenDisplayMode: PortraitFullscreenDisplayMode.cover,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('presentation-video-viewport')), findsNothing);
    expect(find.byKey(const ValueKey('presentation-video-cover')), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('portrait-cover-native-video'))), const Size(390, 844));
    expect(player.videoFitRequests.last, BoxFit.cover);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    unawaited(manager.dispose());
  });

  test('balanced portrait fullscreen scale stops when the display is already filled', () {
    expect(resolvePortraitFullscreenBalancedScale(viewportSize: const Size(1080, 1920), contentAspectRatio: 9 / 16), 1);
    expect(
      resolvePortraitFullscreenBalancedScale(viewportSize: const Size(1440, 3168), contentAspectRatio: 9 / 16),
      closeTo(1.08, 0.0001),
    );
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

  test('an idle soft-stopped player releases native resources after the grace window', () async {
    final player = _FakePlayer();
    final manager = _createManager(player, idleReleaseDelay: const Duration(milliseconds: 20));
    await manager.initialize(engine: PlayerEngine.mediaKit);

    await manager.close();
    expect(manager.currentPlayer, same(player));
    expect(player.hardDisposeCalls, 0);

    await Future<void>.delayed(const Duration(milliseconds: 45));
    expect(manager.currentPlayer, isNull);
    expect(player.hardDisposeCalls, 1);
    await manager.dispose();
  });

  test('reopening during the idle grace window keeps and reuses the current player', () async {
    final player = _FakePlayer();
    final manager = _createManager(player, idleReleaseDelay: const Duration(milliseconds: 50));
    await manager.initialize(engine: PlayerEngine.mediaKit);

    await manager.close();
    await manager.play(
      'https://example.invalid/reopen.flv',
      const <String>['https://example.invalid/reopen.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'reopen-room', platform: 'test'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 75));

    expect(manager.currentPlayer, same(player));
    expect(player.hardDisposeCalls, 0);
    expect(player.openedUrls, <String>['https://example.invalid/reopen.flv']);
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
    final resumed = manager.consumeRoomSessionReentry(room);
    expect(resumed, isNotNull);
    expect(resumed!.room, room);
    expect(resumed.dataSource, 'https://example.invalid/live.flv');
    expect(manager.consumeRoomSessionReentry(room), isNull);

    manager.prepareRoomSessionReentry(room);
    expect(manager.consumeRoomSessionReentry(LiveRoom(roomId: 'room-2', platform: 'test')), isNull);

    await manager.dispose();
  });

  test('floating cleanup preserves the same-room re-entry handoff', () async {
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
    manager.prepareAppFloating(
      onClose: () async {},
      session: RoomSessionSnapshot(
        room: room,
        qualities: <LivePlayQuality>[LivePlayQuality(quality: '蓝光')],
        currentQuality: 0,
        playUrls: const <String>['https://example.invalid/live.flv'],
        currentLineIndex: 0,
        headers: const <String, String>{'referer': 'https://example.invalid'},
        isAudioOnly: false,
        isLiving: true,
      ),
    );

    manager.prepareRoomSessionReentry(room);
    await manager.closeAppFloating().timeout(const Duration(milliseconds: 500));

    final resumed = manager.consumeRoomSessionReentry(room);
    expect(resumed, isNotNull);
    expect(resumed!.qualities.single.quality, '蓝光');
    expect(resumed.headers, containsPair('referer', 'https://example.invalid'));
    expect(manager.currentPlayer, same(player));
    expect(player.setDataSourceCalls, 1);
    await manager.dispose();
  });

  test('floating cleanup releases route resources without waiting forever for a frame', () async {
    final player = _FakePlayer();
    final manager = _createManager(player);
    var released = false;
    await manager.initialize(engine: PlayerEngine.mediaKit);
    manager.prepareAppFloating(
      onClose: () async {
        released = true;
      },
    );

    await manager.closeAppFloating().timeout(const Duration(milliseconds: 500));

    expect(released, isTrue);
    expect(manager.isAppFloatingActive, isFalse);
    await manager.dispose();
  });
}

PlayerManager _createManager(
  _FakePlayer player, {
  Duration timeout = const Duration(seconds: 1),
  Duration? warmRetention = Duration.zero,
  Duration idleReleaseDelay = const Duration(seconds: 30),
  Future<void> Function(UnifiedPlayer player, bool audioOnly)? audioModeServiceSync,
  Future<void> Function(LiveRoom room)? audioSessionStart,
  UnifiedPlayerCreator? playerCreator,
}) {
  return PlayerManager(
    playerCreator: playerCreator ?? (_) => player,
    fallbackManager: EngineFallbackManager(
      defaultEngine: PlayerEngine.mediaKit,
      supportedEngines: const <PlayerEngine>[PlayerEngine.mediaKit],
    ),
    lineManager: LineFallbackManager(),
    audioModeSwitchTimeout: timeout,
    audioModeVideoWarmRetention: warmRetention,
    idlePlayerReleaseDelay: idleReleaseDelay,
    useHardStopOnExit: () => false,
    audioModeServiceSync: audioModeServiceSync,
    audioSessionStart: audioSessionStart,
  );
}

class _FakePlayer implements UnifiedPlayer {
  _FakePlayer({
    this.hangWhenEnablingAudioOnly = false,
    this.onAudioOnlyChange,
    this.onStop,
    this.videoWidget,
    this.dedupeAudioMode = false,
    this.playerEngine = PlayerEngine.fijk,
    this.sourceError,
    this.onSetDataSource,
  });

  final bool hangWhenEnablingAudioOnly;
  final Future<void> Function(bool value)? onAudioOnlyChange;
  final Future<void> Function()? onStop;
  final Widget? videoWidget;
  final bool dedupeAudioMode;
  final PlayerEngine playerEngine;
  final Object? sourceError;
  final Future<void> Function(
    String url,
    List<String> playUrls,
    Map<String, String> headers, {
    LiveRoom? room,
    required bool audioOnly,
  })?
  onSetDataSource;
  final List<bool> audioOnlyChanges = <bool>[];
  final List<BoxFit?> videoFitRequests = <BoxFit?>[];
  final List<String> openedUrls = <String>[];
  int setDataSourceCalls = 0;
  int initCalls = 0;
  int hardDisposeCalls = 0;
  int pauseCalls = 0;
  int playCalls = 0;
  bool _initialized = false;
  bool _audioOnly = false;
  bool _playing = true;
  final StreamController<int?> _widthController = StreamController<int?>.broadcast();
  final StreamController<int?> _heightController = StreamController<int?>.broadcast();

  void emitVideoSize({required int width, required int height}) {
    _widthController.add(width);
    _heightController.add(height);
  }

  @override
  Future<void> init({bool audioOnly = false}) async {
    initCalls++;
    _initialized = true;
    _audioOnly = audioOnly;
  }

  @override
  Future<void> setAudioOnly(bool audioOnly) async {
    if (dedupeAudioMode && _audioOnly == audioOnly) return;
    audioOnlyChanges.add(audioOnly);
    await onAudioOnlyChange?.call(audioOnly);
    if (audioOnly && hangWhenEnablingAudioOnly) {
      await Completer<void>().future;
    }
    _audioOnly = audioOnly;
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
    openedUrls.add(url);
    await onSetDataSource?.call(url, playUrls, headers, room: room, audioOnly: audioOnly);
    if (sourceError != null) throw sourceError!;
    _audioOnly = audioOnly;
  }

  @override
  Future<void> hardDispose() async {
    hardDisposeCalls++;
    _initialized = false;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _playing = false;
  }

  @override
  Future<void> play() async {
    playCalls++;
    _playing = true;
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> softStop() async {
    await onStop?.call();
  }

  @override
  Future<void> stop() async {}

  @override
  Widget getVideoWidget({BoxFit? fit}) {
    videoFitRequests.add(fit);
    return videoWidget ?? const SizedBox.shrink();
  }

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isPlayingNow => _playing;

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
  Stream<int?> get width => _widthController.stream;

  @override
  Stream<int?> get height => _heightController.stream;

  @override
  PlayerEngine get engine => playerEngine;
}

class _VideoMountLifecycle {
  int mounts = 0;
  int disposals = 0;
}

class _VideoMountProbe extends StatefulWidget {
  const _VideoMountProbe(this.lifecycle);

  final _VideoMountLifecycle lifecycle;

  @override
  State<_VideoMountProbe> createState() => _VideoMountProbeState();
}

class _VideoMountProbeState extends State<_VideoMountProbe> {
  @override
  void initState() {
    super.initState();
    widget.lifecycle.mounts++;
  }

  @override
  void dispose() {
    widget.lifecycle.disposals++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.green);
}
