import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/player/core/engine_fallback_manager.dart';
import 'package:pure_live/player/core/line_fallback_manager.dart';
import 'package:pure_live/player/core/playback_source.dart';
import 'package:pure_live/player/core/playback_source_transport.dart';
import 'package:pure_live/player/core/player_manager.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/player/models/player_error_type.dart';
import 'package:pure_live/player/models/player_exception.dart';

import 'support/owned_source_test_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Get.testMode = true;
    Get.put(GlobalPlayerState());
  });
  tearDown(Get.reset);

  test('manager opens private input and recreates recipe for replay/retry, not audio mode', () async {
    final f = _Fixture();
    final recipe = _Recipe('one');
    addTearDown(f.manager.dispose);
    await f.manager.playSource(recipe.source, room: f.room, sourceSelection: _quality('original'));
    expect(f.manager.hasActivePlaybackSession(f.room), true);
    final commit = f.manager.currentSourceCommit!;
    expect(commit.source, same(recipe.source));
    expect(commit.currentUrl, isEmpty);
    expect(commit.urls, isEmpty);
    expect(commit.headers, isEmpty);
    expect(f.manager.isSourceCommitCurrent(commit), true);
    final player = f.players.single;
    expect(player.openedUrls, [recipe.local(1)]);
    expect(player.openedChoices, [
      [recipe.local(1)],
    ]);
    expect(player.openedHeaders, [isEmpty]);
    expect(player.openedPrivateInputs, [true]);
    expect(player.openedSourceIdentities, ['one']);
    await f.manager.setAudioOnlyMode(true);
    await f.manager.setAudioOnlyMode(false);
    expect(recipe.opened, 1);
    await f.manager.replay();
    await f.manager.retry();
    expect(recipe.opened, 3);
    expect(recipe.closed, [1, 2]);
    expect(player.openedUrls, [recipe.local(1), recipe.local(2), recipe.local(3)]);
    await f.manager.close();
    expect(recipe.closed, [1, 2, 3]);
    expect(f.manager.currentSourceCommit, isNull);
  });

  test('engine switch creates a separate input and closes previous only after commit', () async {
    final f = _Fixture();
    final recipe = _Recipe('engine');
    addTearDown(f.manager.dispose);
    await f.manager.playSource(recipe.source, room: f.room, sourceSelection: _quality('high'));
    await f.manager.switchEngine(PlayerEngine.fijk, isManual: true);
    expect(f.players.length, 2);
    expect(recipe.opened, 2);
    expect(recipe.closed, [1]);
    expect(f.players.last.openedSourceIdentities, ['engine']);
    expect(f.manager.currentSourceCommit!.source, same(recipe.source));
    expect(f.manager.currentSourceCommit!.selection!.quality.quality, 'high');
  });

  test('distinct quality recipes with same public identity still warm-swap and commit independently', () async {
    final f = _Fixture();
    final first = _Recipe('same');
    final second = _Recipe('same');
    addTearDown(f.manager.dispose);
    await f.manager.playSource(first.source, room: f.room, sourceSelection: _quality('first'));
    final old = f.manager.currentSourceCommit!;
    await f.manager.playSource(second.source, room: f.room, sourceSelection: _quality('second'));
    expect(f.players.length, 2);
    expect(first.closed, [1]);
    expect(second.closed, isEmpty);
    expect(f.manager.currentSourceCommit!.source, same(second.source));
    expect(f.manager.currentSourceCommit!.selection!.quality.quality, 'second');
    expect(f.manager.isSourceCommitCurrent(old), false);
  }, skip: !Platform.isWindows);

  for (final action in ['pause', 'close', 'new-source']) {
    test('dispatch $action cancels creating input and joins cleanup before queued work', () async {
      final f = _Fixture();
      addTearDown(f.manager.dispose);
      final started = Completer<CancelToken>();
      final cleanup = Completer<void>();
      var cleaned = false;
      final source = OwnedPlaybackSource(
        identity: 'pending',
        createInput: (cancel) async {
          started.complete(cancel);
          await cancel.whenCancel;
          await cleanup.future;
          cleaned = true;
          throw cancel.cancelError!;
        },
      );
      final opening = f.manager.playSource(source, room: f.room);
      var openSettled = false;
      unawaited(opening.then((_) => openSettled = true));
      final token = await started.future;
      final replacement = _Recipe('replacement');
      final operation = switch (action) {
        'pause' => f.manager.pause(),
        'close' => f.manager.close(),
        _ => f.manager.playSource(replacement.source, room: f.room),
      };
      expect(token.isCancelled, true);
      await Future<void>.delayed(Duration.zero);
      expect(openSettled, false);
      expect(cleaned, false);
      cleanup.complete();
      await opening;
      await operation;
      expect(cleaned, true);
      // The cancelled input must never reach a player. Only Windows warm-swaps
      // the replacement onto a second player; other hosts reuse the first one.
      final firstOpened = f.players.first.openedUrls;
      if (action == 'new-source' && !Platform.isWindows) {
        expect(firstOpened, hasLength(1));
        expect(firstOpened.single, contains('/replacement/'));
      } else {
        expect(firstOpened, isEmpty);
      }
      expect(f.manager.currentSourceCommit?.source, action == 'new-source' ? same(replacement.source) : isNull);
      expect(f.manager.hasError.value, false);
    });
  }

  test('pause while native allocation is pending prevents later input creation', () async {
    final barrier = Completer<void>();
    final started = Completer<void>();
    final f = _Fixture(
      create: (engine) {
        started.complete();
        return OwnedSourceTestPlayer(engine, (_) => null, initBarrier: barrier.future);
      },
    );
    addTearDown(f.manager.dispose);
    final recipe = _Recipe('init');
    final opening = f.manager.playSource(recipe.source, room: f.room);
    await started.future;
    await f.manager.pause();
    barrier.complete();
    await opening;
    expect(recipe.opened, 0);
    expect(f.manager.currentSourceCommit, isNull);
    expect(f.players.single.openedUrls, isEmpty);
    await f.manager.resume();
    expect(recipe.opened, 1);
    expect(f.manager.currentSourceCommit!.source, same(recipe.source));
  });

  test('resume after creation cancellation reacquires instead of playing an empty decoder', () async {
    final f = _Fixture();
    addTearDown(f.manager.dispose);
    final started = Completer<void>();
    var calls = 0;
    final recipe = _Recipe('resume');
    final source = OwnedPlaybackSource(
      identity: 'resume',
      createInput: (cancel) async {
        if (++calls == 1) {
          started.complete();
          await cancel.whenCancel;
          throw cancel.cancelError!;
        }
        return recipe.source.createInput(cancel);
      },
    );
    final opening = f.manager.playSource(source, room: f.room);
    await started.future;
    await f.manager.pause();
    await opening;
    expect(f.players.single.openedUrls, isEmpty);
    await f.manager.resume();
    expect(calls, 2);
    expect(f.players.single.openedUrls, [recipe.local(1)]);
    expect(f.players.single.playCalls, 0);
    expect(f.manager.currentSourceCommit!.source, same(source));
  });

  test('failed engine candidate closes only its own lease and retains committed recipe', () async {
    final f = _Fixture(
      create: (engine) => OwnedSourceTestPlayer(
        engine,
        (_) => engine == PlayerEngine.fijk
            ? PlayerException(message: 'fixture failure', type: PlayerErrorType.codec)
            : null,
      ),
    );
    addTearDown(f.manager.dispose);
    final recipe = _Recipe('failure');
    await f.manager.playSource(recipe.source, room: f.room);
    final old = f.manager.currentSourceCommit!;
    await expectLater(f.manager.switchEngine(PlayerEngine.fijk), throwsA(isA<PlayerException>()));
    expect(recipe.closed, [2]);
    expect(f.manager.currentSourceCommit, same(old));
    expect(f.players.first.disposeCalls, 0);
  });

  test('owned-to-direct replacement clears private input while retaining actual remote headers', () async {
    final f = _Fixture();
    addTearDown(f.manager.dispose);
    final recipe = _Recipe('owned');
    await f.manager.playSource(recipe.source, room: f.room);
    const remote = 'https://cdn.example/real.flv';
    await f.manager.play(remote, [remote], {'X-Test': 'direct'}, room: f.room);
    expect(recipe.closed, [1]);
    final native = f.players.last;
    expect(native.openedUrls.last, remote);
    expect(native.openedPrivateInputs.last, false);
    expect(native.openedHeaders.last, {'X-Test': 'direct'});
    expect(f.manager.currentSourceCommit!.source, const UrlPlaybackSource(remote));
  });

  test('recovery resolver receives typed source and returns owned quality without URL fabrication', () async {
    final f = _Fixture();
    addTearDown(f.manager.dispose);
    final first = _Recipe('recover-first');
    final refreshed = _Recipe('recover-next');
    PlaybackSourceRefreshRequest? request;
    await f.manager.playSource(
      first.source,
      room: f.room,
      sourceSelection: _quality('before'),
      sourceResolver: (r) async {
        request = r;
        return PlaybackSourceRefreshResult.owned(source: refreshed.source, selection: _quality('after'));
      },
    );
    final committed = f.manager.onSourceCommitted.firstWhere((c) => c.source == refreshed.source);
    f.players.first.emitError(PlayerException(message: 'network fixture', type: PlayerErrorType.network));
    final next = await committed.timeout(const Duration(seconds: 2));
    expect(request!.currentSource, same(first.source));
    expect(request!.currentUrl, isNull);
    expect(request!.currentQuality!.quality, 'before');
    expect(next.urls, isEmpty);
    expect(next.currentUrl, isEmpty);
    expect(next.selection!.quality.quality, 'after');
    expect(first.closed, [1]);
  });

  test('native EOF recovery reopens a fresh owned input on replacement engine', () async {
    final f = _Fixture();
    addTearDown(f.manager.dispose);
    final recipe = _Recipe('eof');
    await f.manager.playSource(recipe.source, room: f.room);
    final revision = f.manager.currentSourceCommit!.revision;
    final committed = f.manager.onSourceCommitted.firstWhere((c) => c.revision > revision);
    f.players.first.emitCompleted();
    final next = await committed.timeout(const Duration(seconds: 2));
    expect(next.source, same(recipe.source));
    expect(recipe.opened, 2);
    expect(recipe.closed, [1]);
  });

  test(
    'floating snapshot retains recipe across quality commit and clears it for explicit direct replacement',
    () async {
      final f = _Fixture();
      addTearDown(f.manager.dispose);
      final first = _Recipe('floating-first');
      final next = _Recipe('floating-next');
      await f.manager.playSource(first.source, room: f.room, sourceSelection: _quality('before'));
      final session = RoomSessionSnapshot(
        room: f.room,
        qualities: [LivePlayQuality(quality: 'before')],
        currentQuality: 0,
        playUrls: const [],
        ownedSource: first.source,
        currentLineIndex: 0,
        headers: const {},
        isAudioOnly: false,
        isLiving: true,
      );
      f.manager.prepareAppFloating(onClose: () async {}, session: session);
      await f.manager.playSource(next.source, room: f.room, sourceSelection: _quality('after'));
      f.manager.prepareRoomSessionReentry(f.room);
      final reentry = f.manager.consumeRoomSessionReentry(f.room)!;
      expect(reentry.ownedSource, same(next.source));
      expect(reentry.playUrls, isEmpty);
      expect(reentry.dataSource, isEmpty);
      expect(reentry.qualities.single.quality, 'after');
      expect(reentry.copyWith(isAudioOnly: true).ownedSource, same(next.source));
      expect(reentry.copyWith(playUrls: const ['https://cdn.example/new.flv']).ownedSource, isNull);
      expect(reentry.copyWith(dataSource: 'https://cdn.example/new.flv').ownedSource, isNull);
      expect(
        reentry
            .copyWith(
              room: LiveRoom(roomId: 'different', platform: 'test'),
            )
            .ownedSource,
        isNull,
      );
      expect(reentry.copyWith(ownedSource: null).ownedSource, isNull);
    },
  );

  test('invalid mixed owned request is rejected before cancelling the active session', () async {
    final f = _Fixture();
    addTearDown(f.manager.dispose);
    final recipe = _Recipe('valid');
    await f.manager.playSource(recipe.source, room: f.room);
    final before = f.manager.currentSourceCommit!;
    expect(
      () => f.manager.playSource(recipe.source, playUrls: ['https://cdn.example/a'], room: f.room),
      throwsArgumentError,
    );
    expect(
      () => f.manager.playSource(recipe.source, headers: {'Cookie': 'fixture'}, room: f.room),
      throwsArgumentError,
    );
    expect(f.manager.currentSourceCommit, same(before));
    expect(recipe.closed, isEmpty);
  });

  test('pause cancels warm recipe creation but resume retains the already-open owned source', () async {
    final f = _Fixture();
    addTearDown(f.manager.dispose);
    final active = _Recipe('retained');
    await f.manager.playSource(active.source, room: f.room, sourceSelection: _quality('retained'));
    final old = f.manager.currentSourceCommit!;
    final started = Completer<void>();
    var cleaned = false;
    final pending = OwnedPlaybackSource(
      identity: 'candidate',
      createInput: (cancel) async {
        started.complete();
        await cancel.whenCancel;
        cleaned = true;
        throw cancel.cancelError!;
      },
    );
    final switching = f.manager.playSource(pending, room: f.room, sourceSelection: _quality('candidate'));
    await started.future;
    await f.manager.pause();
    await switching;
    expect(cleaned, true);
    expect(active.closed, isEmpty);
    expect(f.manager.currentSourceCommit, same(old));
    await f.manager.resume();
    expect(active.opened, 1);
    expect(f.players.first.playCalls, 1);
    expect(f.manager.currentSourceCommit!.selection!.quality.quality, 'retained');
  }, skip: !Platform.isWindows);
}

PlaybackSourceQualitySelection _quality(String label) =>
    PlaybackSourceQualitySelection(qualities: [LivePlayQuality(quality: label)], currentQuality: 0);

class _Recipe {
  _Recipe(this.identity);
  final String identity;
  int opened = 0;
  final closed = <int>[];
  String local(int index) => 'http://127.0.0.1:19001/$identity/$index/root.m3u8';
  late final source = OwnedPlaybackSource(
    identity: identity,
    createInput: (cancel) async {
      if (cancel.isCancelled) throw cancel.cancelError!;
      final index = ++opened;
      return PlaybackInputLease(Uri.parse(local(index)), () async {
        closed.add(index);
      });
    },
  );
}

class _Fixture {
  _Fixture({OwnedSourceTestPlayer Function(PlayerEngine)? create}) {
    manager = PlayerManager(
      playerCreator: (engine) {
        final player = create?.call(engine) ?? OwnedSourceTestPlayer(engine, (_) => null);
        players.add(player);
        return player;
      },
      fallbackManager: EngineFallbackManager(
        defaultEngine: PlayerEngine.mediaKit,
        supportedEngines: [PlayerEngine.mediaKit, PlayerEngine.fijk],
      ),
      lineManager: LineFallbackManager(),
      transientLiveRetryDelays: const [],
      sourceOpenTimeout: const Duration(seconds: 1),
      sourceReadyTimeout: const Duration(seconds: 1),
      useHardStopOnExit: () => false,
      audioModeServiceSync: (_, _) async {},
      audioSessionStart: (_) async {},
    )..configureDefaultEngine(PlayerEngine.mediaKit);
  }
  final room = LiveRoom(roomId: 'owned', platform: 'test');
  final players = <OwnedSourceTestPlayer>[];
  late final PlayerManager manager;
}
