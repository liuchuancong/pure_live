import 'package:pure_live/core/interface/live_input_recipe.dart';
import 'package:pure_live/player/core/playback_source.dart';

import 'dart:async';
import 'dart:io';

import 'package:pure_live/core/common/hls_source_query_policy.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/modules/live_play/controllers/player_controller.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/states/load_type.dart';
import 'package:pure_live/modules/live_play/states/player_state.dart' as ui;
import 'package:pure_live/modules/live_play/states/room_state.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/player/core/engine_fallback_manager.dart';
import 'package:pure_live/player/core/line_fallback_manager.dart';
import 'package:pure_live/player/core/player_manager.dart';
import 'package:pure_live/player/core/playback_source_transport.dart';
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

  for (final outcome in ['commit', 'pause', 'close']) {
    test('owned route receipt follows actual manager transaction on $outcome', () async {
      final room = LiveRoom(roomId: 'owned-receipt', platform: 'test');
      final host = _ReceiptHost(room, 'https://cdn.example/old/master.m3u8?token=old');
      var oldClosed = 0;
      var nextClosed = 0;
      final original = OwnedPlaybackSource(
        identity: 'old',
        createInput: (_) async => PlaybackInputLease(Uri.parse('http://127.0.0.1:19001/old/root.m3u8'), () async {
          oldClosed++;
        }),
      );
      final started = Completer<void>();
      final creating = Completer<void>();
      final next = OwnedPlaybackSource(
        identity: 'next',
        createInput: (_) async {
          started.complete();
          await creating.future;
          return PlaybackInputLease(Uri.parse('http://127.0.0.1:19001/next/root.m3u8'), () async {
            nextClosed++;
          });
        },
      );
      final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
      final candidate = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
      var creates = 0;
      final manager = _manager({
        PlayerEngine.mediaKit: active,
      }, playerCreator: (_) => creates++ == 0 ? active : candidate)..configureDefaultEngine(PlayerEngine.mediaKit);
      final controller = PlayerController(host, streamPlayerManager: manager, inputPlaybackBinder: (_) => next)
        ..initSite(Site(id: 'test', name: 'Test', logo: '', liveSite: _OwnedReceiptSite()));
      Future<bool>? switching;
      Future<void>? closing;
      try {
        await manager.playSource(
          original,
          room: room,
          sourceSelection: PlaybackSourceQualitySelection(
            qualities: host.state.value.player.qualites,
            currentQuality: 0,
          ),
        );
        controller.applySourceCommit(manager.currentSourceCommit!);
        switching = controller.switchStreamSelection(type: ReloadDataType.changeQuality, qualityIndex: 1, lineIndex: 3);
        await started.future;
        expect(host.state.value.player.ownedSource, same(original));
        expect(host.state.value.player.currentQuality, 0);
        if (outcome == 'pause') await manager.pause();
        if (outcome == 'close') closing = manager.close();
        creating.complete();
        expect(await switching, outcome == 'commit');
        if (closing != null) await closing;
        final after = host.state.value.player;
        expect(after.ownedSource, same(outcome == 'commit' ? next : original));
        expect(after.currentQuality, outcome == 'commit' ? 1 : 0);
        expect(after.playUrls, isEmpty);
        expect(after.playUrlSafe, isEmpty);
        expect(after.lineCount, 1);
        expect(oldClosed, outcome == 'pause' ? 0 : 1);
        expect(nextClosed, outcome == 'commit' ? 0 : 1);
        expect(candidate.openedUrls, outcome == 'commit' ? ['http://127.0.0.1:19001/next/root.m3u8'] : isEmpty);
      } finally {
        if (!creating.isCompleted) creating.complete();
        if (switching != null) await switching;
        if (closing != null) await closing;
        controller.onClose();
        await manager.dispose();
      }
    }, skip: !Platform.isWindows);
  }

  for (final outcome in ['commit', 'pause', 'close']) {
    test('route native receipt preserves the committed selection on $outcome', () async {
      const old = 'https://cdn.example/old/master.m3u8?token=old';
      const next = 'https://cdn.example/new/master.m3u8?token=new';
      final room = LiveRoom(roomId: 'route-receipt', platform: 'test');
      final host = _ReceiptHost(room, old);
      final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
      final started = Completer<void>();
      final opening = Completer<void>();
      final candidate = _RecoveryFakePlayer(
        PlayerEngine.mediaKit,
        (_) => null,
        openBarrier: opening.future,
        onOpenSource: () => started.complete(),
      );
      var creations = 0;
      final manager = _manager(
        {PlayerEngine.mediaKit: active},
        playerCreator: (_) => creations++ == 0 ? active : candidate,
        sourceInputFactory: (_, _, _) async =>
            PlaybackInputLease(Uri.parse('http://127.0.0.1:19001/fixture/root.m3u8'), () async {}),
      )..configureDefaultEngine(PlayerEngine.mediaKit);
      final controller = PlayerController(host, streamPlayerManager: manager)
        ..initSite(Site(id: 'test', name: 'Test', logo: '', liveSite: _ReceiptSite(next)));
      Future<bool>? switching;
      Future<void>? closing;
      try {
        await manager.play(
          old,
          const [old],
          const {},
          room: room,
          sourceSelection: PlaybackSourceQualitySelection(
            qualities: host.state.value.player.qualites,
            currentQuality: 0,
            sourceQueryPolicies: host.state.value.player.sourceQueryPolicies,
          ),
        );
        controller.applySourceCommit(manager.currentSourceCommit!);
        final before = host.state.value.player;
        switching = controller.switchStreamSelection(type: ReloadDataType.changeQuality, qualityIndex: 1, lineIndex: 0);
        await started.future.timeout(const Duration(seconds: 2));
        expect(host.state.value.player.currentQuality, 0);
        if (outcome == 'pause') await manager.pause();
        if (outcome == 'close') closing = manager.close();
        opening.complete();
        final committed = await switching;
        if (closing != null) await closing;
        expect(committed, outcome == 'commit');
        final after = host.state.value.player;
        expect(after.currentQuality, outcome == 'commit' ? 1 : before.currentQuality);
        expect(after.playUrls, outcome == 'commit' ? [next] : before.playUrls);
        expect(after.currentLineIndex, 0);
        expect(after.sourceQueryPolicies.keys, outcome == 'commit' ? [next] : before.sourceQueryPolicies.keys);
        expect(controller.isStreamSwitching.value, isFalse);
        expect(
          manager.currentSourceCommit?.currentUrl,
          outcome == 'close'
              ? null
              : outcome == 'commit'
              ? next
              : old,
        );
        if (outcome == 'pause') expect(active.isPlayingNow, isFalse);
      } finally {
        if (!opening.isCompleted) opening.complete();
        if (switching != null) await switching;
        if (closing != null) await closing;
        controller.onClose();
        await manager.dispose();
      }
    }, skip: !Platform.isWindows);
  }

  for (final outcome in ['pause-with-resolver', 'pause-with-null', 'commit-with-resolver', 'rollback-with-resolver']) {
    test('retained source refresh owner follows $outcome', () async {
      const old = 'https://cdn.example/old.flv';
      const next = 'https://cdn.example/new.flv';
      final room = LiveRoom(roomId: 'refresh-owner', platform: 'test');
      final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
      final opening = Completer<void>();
      final started = Completer<void>();
      final candidate = outcome == 'rollback-with-resolver'
          ? _BindingFailureFakePlayer(opening.future, () => started.complete())
          : _RecoveryFakePlayer(
              PlayerEngine.mediaKit,
              (_) => null,
              openBarrier: opening.future,
              onOpenSource: () => started.complete(),
            );
      var creations = 0;
      final manager = _manager(
        {PlayerEngine.mediaKit: active},
        playerCreator: (_) => creations++ == 0 ? active : candidate,
        transientLiveRetryDelays: const [],
      )..configureDefaultEngine(PlayerEngine.mediaKit);
      final invoked = Completer<String>();
      final resolved = Completer<PlaybackSourceRefreshResult>();
      PlaybackSourceResolver resolver(String owner) => (request) {
        if (!invoked.isCompleted) invoked.complete(owner);
        return resolved.future;
      };
      Future<void>? switching;
      try {
        await manager.play(old, const [old], const {}, room: room, sourceResolver: resolver('old'));
        switching = manager.play(
          next,
          const [next],
          const {},
          room: room,
          sourceResolver: outcome == 'pause-with-null' ? null : resolver('new'),
        );
        await started.future.timeout(const Duration(seconds: 2));
        final paused = outcome.startsWith('pause');
        if (paused) await manager.pause();
        opening.complete();
        await switching;
        final retained = outcome != 'commit-with-resolver';
        expect(manager.currentSourceCommit!.currentUrl, retained ? old : next);
        if (paused) await manager.resume();
        (manager.currentPlayer! as _RecoveryFakePlayer).emitError(
          PlayerException(message: 'fixture source failure', type: PlayerErrorType.source),
        );
        expect(await invoked.future.timeout(const Duration(seconds: 2)), retained ? 'old' : 'new');
      } finally {
        if (!opening.isCompleted) opening.complete();
        if (switching != null) await switching;
        await manager.pause();
        if (!resolved.isCompleted) {
          resolved.complete(const PlaybackSourceRefreshResult(urls: [], preferredLineIndex: 0));
        }
        await manager.dispose();
      }
    }, skip: !Platform.isWindows);
  }

  test('warming keeps proactive credentials bound to the still-active source', () async {
    const old = 'https://cdn.example/active.flv';
    const next = 'https://cdn.example/candidate.flv';
    final room = LiveRoom(roomId: 'pending-refresh-owner', platform: 'test');
    final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final opening = Completer<void>();
    final started = Completer<void>();
    final candidate = _RecoveryFakePlayer(
      PlayerEngine.mediaKit,
      (_) => null,
      openBarrier: opening.future,
      onOpenSource: () => started.complete(),
    );
    var creations = 0;
    final manager = _manager({
      PlayerEngine.mediaKit: active,
    }, playerCreator: (_) => creations++ == 0 ? active : candidate)..configureDefaultEngine(PlayerEngine.mediaKit);
    final invoked = Completer<String>();
    final resolved = Completer<PlaybackSourceRefreshResult>();
    PlaybackSourceResolver resolver(String owner) => (request) {
      expect(request.currentUrl, old);
      if (!invoked.isCompleted) invoked.complete(owner);
      return resolved.future;
    };
    Future<void>? switching;
    try {
      await manager.play(
        old,
        const [old],
        const {},
        room: room,
        sourceRefreshAt: DateTime.now().toUtc(),
        sourceResolver: resolver('old'),
      );
      switching = manager.play(next, const [next], const {}, room: room, sourceResolver: resolver('new'));
      await started.future.timeout(const Duration(seconds: 2));
      expect(await invoked.future.timeout(const Duration(seconds: 3)), 'old');
      expect(manager.currentSourceCommit!.currentUrl, old);
    } finally {
      await manager.pause();
      if (!resolved.isCompleted) {
        resolved.complete(const PlaybackSourceRefreshResult(urls: [], preferredLineIndex: 0));
      }
      if (!opening.isCompleted) opening.complete();
      if (switching != null) await switching;
      await manager.dispose();
    }
  }, skip: !Platform.isWindows);

  for (final dispose in [false, true]) {
    test(
      '${dispose ? 'dispose' : 'close dispatch'} retires pending input creation before it can start native playback',
      () async {
        const url = 'https://cdn.example/late/master.m3u8?token=fixture';
        final player = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
        final started = Completer<void>();
        final creating = Completer<PlaybackInputLease>();
        var closes = 0;
        final manager = _manager(
          {PlayerEngine.mediaKit: player},
          sourceInputFactory: (_, _, _) {
            started.complete();
            return creating.future;
          },
        )..configureDefaultEngine(PlayerEngine.mediaKit);
        final playing = manager.play(
          url,
          const [url],
          const {},
          room: LiveRoom(roomId: 'late', platform: 'test'),
          sourceSelection: PlaybackSourceQualitySelection(
            qualities: [LivePlayQuality(quality: 'Original')],
            currentQuality: 0,
            sourceQueryPolicies: {url: HlsSourceQueryPolicy.fromSource(Uri.parse(url))},
          ),
        );
        try {
          await started.future.timeout(const Duration(seconds: 2));
          final closing = dispose ? manager.dispose() : manager.close();
          creating.complete(
            PlaybackInputLease(Uri.parse('http://127.0.0.1:19001/late/root.m3u8'), () async {
              closes++;
            }),
          );
          await playing;
          await closing;
          expect(player.openedUrls, isEmpty);
          expect(closes, 1);
          expect(manager.currentSourceCommit, isNull);
        } finally {
          if (!creating.isCompleted) creating.completeError(StateError('fixture cleanup'));
          await playing;
          await manager.dispose();
        }
      },
    );
  }

  for (final cancel in [false, true]) {
    test('Windows warm input uses candidate policy and closes only its owner (pause=$cancel)', () async {
      const old = 'https://cdn.example/old/master.m3u8?token=old';
      const next = 'https://cdn.example/new/master.m3u8?token=new';
      final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
      final opening = Completer<void>();
      final started = Completer<void>();
      final candidate = _RecoveryFakePlayer(
        PlayerEngine.mediaKit,
        (_) => null,
        emitPlaying: false,
        openBarrier: opening.future,
        onOpenSource: () => started.complete(),
      );
      var creations = 0;
      final closes = <int>[];
      final sources = <String>[];
      final manager = _manager(
        {PlayerEngine.mediaKit: active},
        playerCreator: (_) => creations++ == 0 ? active : candidate,
        sourceInputFactory: (url, _, policy) async {
          expect(policy.matchesSource(Uri.parse(url)), isTrue);
          sources.add(url);
          final index = closes.length;
          closes.add(0);
          return PlaybackInputLease(Uri.parse('http://127.0.0.1:19001/$index/root.m3u8'), () async {
            closes[index]++;
          });
        },
      )..configureDefaultEngine(PlayerEngine.mediaKit);
      final room = LiveRoom(roomId: 'warm-input', platform: 'test');
      PlaybackSourceQualitySelection selection(String url) => PlaybackSourceQualitySelection(
        qualities: [LivePlayQuality(quality: 'Original')],
        currentQuality: 0,
        sourceQueryPolicies: {url: HlsSourceQueryPolicy.fromSource(Uri.parse(url))},
      );
      try {
        await manager.play(old, const [old], const {}, room: room, sourceSelection: selection(old));
        final switching = manager.play(next, const [next], const {}, room: room, sourceSelection: selection(next));
        await started.future.timeout(const Duration(seconds: 2));
        expect(sources, [old, next]);
        expect(closes, [0, 0]);
        if (cancel) await manager.pause();
        candidate.emitUnexpectedPlaying(true);
        opening.complete();
        await switching;
        expect(manager.currentPlayer, same(cancel ? active : candidate));
        expect(manager.currentSourceCommit!.currentUrl, cancel ? old : next);
        expect(closes, cancel ? [0, 1] : [1, 0]);
      } finally {
        if (!opening.isCompleted) opening.complete();
        await manager.dispose();
      }
      expect(closes, [1, 1]);
    }, skip: !Platform.isWindows);
  }

  test('manager owns scoped native input while commits, pause and audio retain remote source identity', () async {
    const url = 'https://cdn.example/scoped/master.m3u8?token=fixture';
    final policy = HlsSourceQueryPolicy.fromSource(Uri.parse(url));
    final player = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    var closes = 0;
    final manager = _manager(
      {PlayerEngine.mediaKit: player},
      sourceInputFactory: (source, headers, actualPolicy) async {
        expect(source, url);
        expect(actualPolicy, same(policy));
        expect(headers, {'Cookie': 'fixture=yes'});
        return PlaybackInputLease(Uri.parse('http://127.0.0.1:19001/private/root.m3u8'), () async {
          closes++;
        });
      },
    )..configureDefaultEngine(PlayerEngine.mediaKit);
    try {
      await manager.play(
        url,
        const [url, 'https://backup.example/direct.flv'],
        const {'Cookie': 'fixture=yes'},
        room: LiveRoom(roomId: 'input', platform: 'test'),
        sourceSelection: PlaybackSourceQualitySelection(
          qualities: [LivePlayQuality(quality: 'Original')],
          currentQuality: 0,
          sourceQueryPolicies: {url: policy},
        ),
      );
      expect(player.openedUrls.single, 'http://127.0.0.1:19001/private/root.m3u8');
      expect(player.openedChoices.single, [player.openedUrls.single]);
      expect(player.openedHeaders.single, isEmpty);
      expect(player.openedPrivateInputs.single, isTrue);
      expect(player.openedSourceIdentities.single, url);
      expect(manager.currentSourceCommit!.currentUrl, url);
      expect(manager.currentSourceCommit!.urls, const [url, 'https://backup.example/direct.flv']);
      await manager.pause();
      await manager.resume();
      await manager.setAudioOnlyMode(true);
      expect(player.openedUrls, hasLength(1));
      expect(closes, 0);
      await manager.play(
        'https://direct.example/next.flv',
        const ['https://direct.example/next.flv'],
        const {},
        room: LiveRoom(roomId: 'direct', platform: 'test'),
      );
      expect(player.openedPrivateInputs.last, isFalse);
      expect(closes, 1);
    } finally {
      await manager.dispose();
    }
    expect(closes, 1);
  });

  for (final soft in [false, true]) {
    test('manager ${soft ? 'soft stop' : 'hard disposal'} closes the selected relay exactly once', () async {
      const url = 'https://cdn.example/stop/master.m3u8?token=fixture';
      final player = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
      var closes = 0;
      final manager = _manager(
        {PlayerEngine.mediaKit: player},
        sourceInputFactory: (_, _, _) async =>
            PlaybackInputLease(Uri.parse('http://127.0.0.1:19001/private/root.m3u8'), () async {
              closes++;
            }),
      )..configureDefaultEngine(PlayerEngine.mediaKit);
      await manager.play(
        url,
        const [url],
        const {},
        room: LiveRoom(roomId: 'stop', platform: 'test'),
        sourceSelection: PlaybackSourceQualitySelection(
          qualities: [LivePlayQuality(quality: 'Original')],
          currentQuality: 0,
          sourceQueryPolicies: {url: HlsSourceQueryPolicy.fromSource(Uri.parse(url))},
        ),
      );
      if (soft) await manager.softStop();
      await manager.dispose();
      expect(closes, 1);
    });
  }

  test('engine fallback closes timed-out input and opens the next engine with the same remote policy', () async {
    const url = 'https://cdn.example/fallback/master.m3u8?token=fixture';
    final barrier = Completer<void>();
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null, openBarrier: barrier.future);
    final fijk = _RecoveryFakePlayer(PlayerEngine.fijk, (_) => null);
    final closes = <int>[];
    final policy = HlsSourceQueryPolicy.fromSource(Uri.parse(url));
    final manager = _manager(
      {PlayerEngine.mediaKit: mediaKit, PlayerEngine.fijk: fijk},
      sourceOpenTimeout: const Duration(milliseconds: 30),
      sourceInputFactory: (source, _, actualPolicy) async {
        expect(source, url);
        expect(actualPolicy, same(policy));
        final index = closes.length;
        closes.add(0);
        return PlaybackInputLease(Uri.parse('http://127.0.0.1:19001/input$index/root.m3u8'), () async {
          closes[index]++;
        });
      },
    )..configureDefaultEngine(PlayerEngine.mediaKit);
    try {
      await manager.play(
        url,
        const [url],
        const {},
        room: LiveRoom(roomId: 'timeout', platform: 'test'),
        sourceSelection: PlaybackSourceQualitySelection(
          qualities: [LivePlayQuality(quality: 'Original')],
          currentQuality: 0,
          sourceQueryPolicies: {url: policy},
        ),
      );
      expect(manager.currentEngine, PlayerEngine.fijk);
      expect(manager.currentSourceCommit!.currentUrl, url);
      expect(closes, [1, 0]);
      barrier.complete();
      await Future<void>.delayed(Duration.zero);
      expect(closes, [1, 0], reason: 'late native completion must not close the replacement input');
    } finally {
      if (!barrier.isCompleted) barrier.complete();
      await manager.dispose();
    }
    expect(closes, [1, 1]);
  });

  test('source commit snapshot is published only after a successful native open', () async {
    final player = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: player})
      ..configureDefaultEngine(PlayerEngine.mediaKit);
    final room = LiveRoom(roomId: 'source-commit', platform: 'test');
    final mutableQualities = <LivePlayQuality>[LivePlayQuality(quality: '蓝光', id: 1)];
    final selection = PlaybackSourceQualitySelection(qualities: mutableQualities, currentQuality: 0);
    final commits = <PlaybackSourceCommitSnapshot>[];
    final subscription = manager.onSourceCommitted.listen(commits.add);

    try {
      await manager.play(
        'https://cdn.example/committed.flv',
        const ['https://cdn.example/backup.flv', 'https://cdn.example/committed.flv'],
        const {'referer': 'https://example.invalid'},
        room: room,
        sourceSelection: selection,
      );
      await Future<void>.delayed(Duration.zero);

      mutableQualities.add(LivePlayQuality(quality: '原画', id: 2));
      final committed = manager.currentSourceCommit;
      expect(committed, isNotNull);
      expect(commits, hasLength(1));
      expect(committed, same(commits.single));
      expect(manager.isSourceCommitCurrent(committed!), isTrue);
      expect(committed.currentLineIndex, 1);
      expect(committed.selection?.quality.quality, '蓝光');
      expect(committed.selection?.qualities, hasLength(1), reason: 'selection must not retain a mutable caller list');
      await manager.pause();
      expect(
        manager.isSourceCommitCurrent(committed),
        isTrue,
        reason: 'pause changes playback intent but not the committed source metadata',
      );
      await manager.resume();
      expect(manager.isSourceCommitCurrent(committed), isTrue);
    } finally {
      await subscription.cancel();
      await manager.dispose();
    }
  });

  test('failed native open does not publish or retain a source commit', () async {
    final failure = PlayerException(message: 'source rejected', type: PlayerErrorType.source);
    final player = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => failure);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: player,
    }, transientLiveRetryDelays: const [])..configureDefaultEngine(PlayerEngine.mediaKit);
    final commits = <PlaybackSourceCommitSnapshot>[];
    final subscription = manager.onSourceCommitted.listen(commits.add);

    try {
      await manager.play(
        'https://cdn.example/rejected.flv',
        const ['https://cdn.example/rejected.flv'],
        const {},
        room: LiveRoom(roomId: 'source-rejected', platform: 'test'),
        sourceSelection: PlaybackSourceQualitySelection(
          qualities: <LivePlayQuality>[LivePlayQuality(quality: '蓝光', id: 1)],
          currentQuality: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(commits, isEmpty);
      expect(manager.currentSourceCommit, isNull);
    } finally {
      await subscription.cancel();
      await manager.dispose();
    }
  });

  test('signed recovery commits returned selection and requests it on the next refresh', () async {
    final player = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: player,
    }, transientLiveRetryDelays: const [])..configureDefaultEngine(PlayerEngine.mediaKit);
    final room = LiveRoom(roomId: 'selection-refresh', platform: 'test');
    final selections = <PlaybackSourceQualitySelection>[
      PlaybackSourceQualitySelection(
        qualities: <LivePlayQuality>[LivePlayQuality(quality: '初始', id: 0)],
        sourceQueryPolicies: {
          'https://cdn.example/generation-0.m3u8?token=g0': HlsSourceQueryPolicy.fromSource(
            Uri.parse('https://cdn.example/generation-0.m3u8?token=g0'),
          ),
        },
        currentQuality: 0,
      ),
      PlaybackSourceQualitySelection(
        qualities: <LivePlayQuality>[LivePlayQuality(quality: '确认一', id: 1)],
        sourceQueryPolicies: {
          'https://cdn.example/generation-1.m3u8?token=g1': HlsSourceQueryPolicy.fromSource(
            Uri.parse('https://cdn.example/generation-1.m3u8?token=g1'),
          ),
        },
        currentQuality: 0,
      ),
      PlaybackSourceQualitySelection(
        qualities: <LivePlayQuality>[LivePlayQuality(quality: '确认二', id: 2)],
        sourceQueryPolicies: {
          'https://cdn.example/generation-2.m3u8?token=g2': HlsSourceQueryPolicy.fromSource(
            Uri.parse('https://cdn.example/generation-2.m3u8?token=g2'),
          ),
        },
        currentQuality: 0,
      ),
    ];
    final requests = <PlaybackSourceRefreshRequest>[];
    final commits = <PlaybackSourceCommitSnapshot>[];
    final subscription = manager.onSourceCommitted.listen(commits.add);

    try {
      await manager.play(
        'https://cdn.example/generation-0.m3u8?token=g0',
        const ['https://cdn.example/generation-0.m3u8?token=g0'],
        const {},
        room: room,
        sourceSelection: selections[0],
        sourceResolver: (request) async {
          requests.add(request);
          final generation = requests.length;
          return PlaybackSourceRefreshResult(
            urls: <String>['https://cdn.example/generation-$generation.m3u8?token=g$generation'],
            preferredLineIndex: 0,
            selection: selections[generation],
          );
        },
      );

      player.emitError(PlayerException(message: 'first expiry', type: PlayerErrorType.network));
      var deadline = DateTime.now().add(const Duration(seconds: 1));
      while (manager.currentSourceCommit?.currentUrl != 'https://cdn.example/generation-1.m3u8?token=g1' &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(requests, hasLength(1));
      expect(requests.single.currentQuality?.selectionId, 0);
      expect(manager.currentSourceCommit?.selection, same(selections[1]));

      player.emitError(PlayerException(message: 'second expiry', type: PlayerErrorType.network));
      deadline = DateTime.now().add(const Duration(seconds: 1));
      while (manager.currentSourceCommit?.currentUrl != 'https://cdn.example/generation-2.m3u8?token=g2' &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await Future<void>.delayed(Duration.zero);

      expect(requests, hasLength(2));
      expect(
        requests.last.currentQuality?.selectionId,
        1,
        reason: 'the resolver must receive the last committed quality instead of its original closure value',
      );
      expect(manager.currentSourceCommit?.selection, same(selections[2]));
      expect(commits.map((event) => event.selection).toList(), selections);
      for (final commit in commits) {
        expect(commit.selection!.sourceQueryPolicies.keys, [commit.currentUrl]);
        expect(
          commit.selection!.sourceQueryPolicies[commit.currentUrl]!.matchesSource(Uri.parse(commit.currentUrl)),
          isTrue,
        );
      }
      final policyBeforePause = manager.currentSourceCommit!.selection!.sourceQueryPolicies;
      await manager.pause();
      await manager.resume();
      expect(manager.currentSourceCommit!.selection!.sourceQueryPolicies, same(policyBeforePause));
    } finally {
      await subscription.cancel();
      await manager.dispose();
    }
  });

  test('engine fallback keeps the fresh source cohort selection after its first open fails', () async {
    const initialUrl = 'https://cdn.example/cohort-0.flv';
    const freshUrl = 'https://cdn.example/cohort-1.flv';
    final mediaKit = _RecoveryFakePlayer(
      PlayerEngine.mediaKit,
      (url) => url == freshUrl
          ? PlayerException(message: 'fresh source rejected by first engine', type: PlayerErrorType.source)
          : null,
    );
    final fijk = _RecoveryFakePlayer(PlayerEngine.fijk, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: mediaKit,
      PlayerEngine.fijk: fijk,
    }, transientLiveRetryDelays: const [])..configureDefaultEngine(PlayerEngine.mediaKit);
    final initialSelection = PlaybackSourceQualitySelection(
      qualities: <LivePlayQuality>[LivePlayQuality(quality: '初始', id: 0)],
      currentQuality: 0,
    );
    final freshSelection = PlaybackSourceQualitySelection(
      qualities: <LivePlayQuality>[LivePlayQuality(quality: '服务端确认', id: 1)],
      currentQuality: 0,
    );
    final requests = <PlaybackSourceRefreshRequest>[];
    final commits = <PlaybackSourceCommitSnapshot>[];
    final subscription = manager.onSourceCommitted.listen(commits.add);

    try {
      await manager.play(
        initialUrl,
        const [initialUrl],
        const {},
        room: LiveRoom(roomId: 'fresh-cohort-fallback', platform: 'test'),
        sourceSelection: initialSelection,
        sourceResolver: (request) async {
          requests.add(request);
          if (requests.length > 1) {
            return const PlaybackSourceRefreshResult(urls: <String>[], preferredLineIndex: 0);
          }
          return PlaybackSourceRefreshResult(
            urls: const <String>[freshUrl],
            preferredLineIndex: 0,
            selection: freshSelection,
          );
        },
      );
      mediaKit.emitError(PlayerException(message: 'initial transport expired', type: PlayerErrorType.network));

      final deadline = DateTime.now().add(const Duration(seconds: 1));
      while (!identical(manager.currentPlayer, fijk) && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await Future<void>.delayed(Duration.zero);

      expect(manager.currentPlayer, same(fijk));
      expect(fijk.openedUrls, <String>[freshUrl]);
      expect(requests, hasLength(2));
      expect(
        requests.last.currentQuality?.selectionId,
        1,
        reason: 'fallback resolution must inherit metadata for the fresh URL cohort',
      );
      expect(commits, hasLength(2), reason: 'the failed first fresh open must not emit a commit');
      expect(commits.last.currentUrl, freshUrl);
      expect(commits.last.selection, same(freshSelection));
      expect(manager.currentSourceCommit, same(commits.last));
    } finally {
      await subscription.cancel();
      await manager.dispose();
    }
  });

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

  test('automatic MPV fallback suppresses audio before the replacement engine initializes', () async {
    final mediaKit = _RecoveryFakePlayer(
      PlayerEngine.mediaKit,
      (_) => PlayerException(message: 'mpv output rejected', type: PlayerErrorType.native),
    );
    final fijk = _RecoveryFakePlayer(PlayerEngine.fijk, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: mediaKit,
      PlayerEngine.fijk: fijk,
    }, suppressAutomaticFallbackAudio: () => true);

    await manager.initialize(engine: PlayerEngine.mediaKit);
    await manager.play(
      'https://cdn.example/null-output.flv',
      const <String>['https://cdn.example/null-output.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'null-output', platform: 'test'),
    );

    expect(manager.currentEngine, PlayerEngine.fijk);
    expect(fijk.audioOutputSuppressionWrites, <bool>[true]);
    expect(fijk.audioOutputWasSuppressedBeforeInit, isTrue);
    expect(fijk.openedUrls, <String>['https://cdn.example/null-output.flv']);

    await manager.dispose();
  });

  test('manual switch away from MPV keeps the selected engine audio enabled', () async {
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final fijk = _RecoveryFakePlayer(PlayerEngine.fijk, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: mediaKit,
      PlayerEngine.fijk: fijk,
    }, suppressAutomaticFallbackAudio: () => true);

    await manager.initialize(engine: PlayerEngine.mediaKit);
    await manager.play(
      'https://cdn.example/manual-engine.flv',
      const <String>['https://cdn.example/manual-engine.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'manual-engine', platform: 'test'),
    );
    await manager.switchEngine(PlayerEngine.fijk, isManual: true);

    expect(manager.currentEngine, PlayerEngine.fijk);
    expect(fijk.audioOutputSuppressionWrites, <bool>[false]);
    expect(fijk.audioOutputWasSuppressedBeforeInit, isFalse);

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

  test('repeated decoder dimensions cannot starve portrait detection', () async {
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null, emittedWidth: 720, emittedHeight: 1280);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: mediaKit});
    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    await manager.play(
      'https://cdn.example/portrait.flv',
      const ['https://cdn.example/portrait.flv'],
      const {},
      room: LiveRoom(roomId: 'portrait', platform: 'test'),
    );
    for (var frame = 0; frame < 60; frame++) {
      mediaKit._width.add(720);
      mediaKit._height.add(1280);
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    // Keep the producer active while checking; waiting for it to become quiet
    // would conceal an indefinitely postponed trailing-edge geometry timer.
    final snapshot = manager.videoGeometry.value;
    await manager.dispose();
    expect(snapshot.orientation, VideoSourceOrientation.portrait);
    expect(snapshot.isStable, isTrue);
  });

  test('PiP return and temporary null dimensions preserve the current source geometry', () async {
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null, emittedWidth: 720, emittedHeight: 1280);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: mediaKit});
    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    await manager.play(
      'https://cdn.example/portrait.flv',
      const ['https://cdn.example/portrait.flv'],
      const {},
      room: LiveRoom(roomId: 'portrait', platform: 'test'),
    );
    // Wait for the decoder's stable geometry rather than assuming its
    // observation and stability timers finish within a fixed wall-clock wait
    // while the full suite runs other test isolates concurrently.
    if (!manager.videoGeometry.value.isStable) {
      await manager.videoGeometry.stream
          .firstWhere((snapshot) => snapshot.orientation == VideoSourceOrientation.portrait && snapshot.isStable)
          .timeout(const Duration(seconds: 5));
    }
    expect(manager.isVerticalVideo.value, isTrue);
    for (var cycle = 0; cycle < 3; cycle++) {
      manager.isInPip.value = true;
      mediaKit._width.add(null);
      mediaKit._height.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      manager.isInPip.value = false;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(manager.isVerticalVideo.value, isTrue);
      expect(manager.currentPresentationAspectRatio, closeTo(9 / 16, 0.001));
      mediaKit._width.add(720);
      mediaKit._height.add(1280);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    expect(mediaKit.openedUrls, hasLength(1));
    await manager.dispose();
  });

  test('a pending portrait sample cannot contaminate a new landscape source', () async {
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null, emittedWidth: 720, emittedHeight: 1280);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: mediaKit});
    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    final room = LiveRoom(roomId: 'switching', platform: 'test');
    await manager.play('https://cdn.example/portrait.flv', const [], const {}, room: room);
    mediaKit.emittedWidth = null;
    mediaKit.emittedHeight = null;
    await manager.play('https://cdn.example/landscape.flv', const [], const {}, room: room);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(manager.videoGeometry.value.hasValidDimensions, isFalse);
    expect(manager.isVerticalVideo.value, isFalse);
    mediaKit._width.add(1920);
    mediaKit._height.add(1080);
    final snapshot = await manager.videoGeometry.stream
        .firstWhere((snapshot) => snapshot.orientation == VideoSourceOrientation.landscape && snapshot.isStable)
        .timeout(const Duration(seconds: 5));
    expect(snapshot.effectiveAspectRatio, closeTo(16 / 9, 0.001));
    expect(manager.isVerticalVideo.value, isFalse);
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

  test('a hung unexpected-pause resume command is bounded before engine recovery', () async {
    final resumeBarrier = Completer<void>();
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null, playBarrier: resumeBarrier.future);
    final fijk = _RecoveryFakePlayer(PlayerEngine.fijk, (_) => null);
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: mediaKit, PlayerEngine.fijk: fijk},
      unexpectedPauseGrace: const Duration(milliseconds: 2),
      unexpectedPauseFailureGrace: const Duration(milliseconds: 5),
    );
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    try {
      await manager.play(
        'https://cdn.example/hung-resume.flv',
        const <String>['https://cdn.example/hung-resume.flv'],
        const <String, String>{},
        room: LiveRoom(roomId: 'hung-resume', platform: 'test'),
      );
      mediaKit.emitUnexpectedPlaying(false);

      final deadline = DateTime.now().add(const Duration(milliseconds: 300));
      while (manager.currentEngine != PlayerEngine.fijk && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(mediaKit.playCalls, 1);
      expect(manager.currentEngine, PlayerEngine.fijk);
      expect(fijk.openedUrls, <String>['https://cdn.example/hung-resume.flv']);
    } finally {
      if (!resumeBarrier.isCompleted) resumeBarrier.complete();
      await manager.dispose();
    }
  });

  for (final notification in ['paused-state', 'playing-toggle']) {
    test('continuous buffering deadline survives repeated $notification notifications', () async {
      final first = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
      final replacement = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
      var creations = 0;
      final manager = _manager(
        {PlayerEngine.mediaKit: first},
        bufferingStallTimeout: const Duration(seconds: 2),
        playerCreator: (_) => creations++ == 0 ? first : replacement,
      );
      manager.configureDefaultEngine(PlayerEngine.mediaKit);
      const url = 'https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100';
      try {
        await manager.play(
          url,
          const [url],
          const {},
          room: LiveRoom(roomId: 'deadline', platform: 'huya'),
        );
        first.emitLoading(true);
        for (var i = 0; i < 4; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          if (notification == 'paused-state') {
            first.emitNativeState(PlayerState.paused);
          } else {
            first.emitUnexpectedPlaying(i.isOdd);
          }
        }
        expect(creations, 1, reason: 'a short buffering episode must not reopen a live source');
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(creations, 2, reason: 'state notifications are not media progress and must not extend the deadline');
        expect(manager.currentPlayer, same(replacement));
      } finally {
        await manager.dispose();
      }
    });
  }

  for (final outcome in ['resumed', 'user-pause', 'new-buffer']) {
    test('buffering deadline retires on $outcome without a stale source replacement', () async {
      final first = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
      final replacement = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
      var creations = 0;
      final manager = _manager(
        {PlayerEngine.mediaKit: first},
        bufferingStallTimeout: const Duration(seconds: 2),
        playerCreator: (_) => creations++ == 0 ? first : replacement,
      );
      manager.configureDefaultEngine(PlayerEngine.mediaKit);
      const url = 'https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100';
      try {
        await manager.play(
          url,
          const [url],
          const {},
          room: LiveRoom(roomId: 'deadline-end', platform: 'huya'),
        );
        first.emitLoading(true);
        await Future<void>.delayed(const Duration(milliseconds: 800));
        first.emitNativeState(PlayerState.paused);
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (outcome == 'user-pause') {
          await manager.pause();
        } else {
          first.emitLoading(false);
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(creations, 1);
        if (outcome == 'new-buffer') {
          first.emitLoading(true);
          await Future<void>.delayed(const Duration(milliseconds: 1900));
          expect(creations, 1, reason: 'a new episode gets its own complete deadline');
          await Future<void>.delayed(const Duration(milliseconds: 200));
          await Future<void>.delayed(const Duration(milliseconds: 100));
          expect(creations, 2);
        } else {
          await Future<void>.delayed(const Duration(seconds: 3));
          expect(creations, 1, reason: 'retired buffering must not reopen the source');
          expect(first.playCalls, 0, reason: 'native buffering and user pause do not request a resume command');
        }
      } finally {
        await manager.dispose();
      }
    });
  }

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
    expect(requests.single.currentUrl, 'https://cdn.example/expired.flv');
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

  for (final outcome in [
    'new frame',
    'buffer recovered',
    'user paused',
    'presentation hidden',
    'pause and resume',
    'still stalled',
    'real EOF',
  ]) {
    test('recovery sharing native Huya prefetch rechecks $outcome', () async {
      final active = _FrameProgressFakePlayer();
      final replacement = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
      final lease = Completer<PlaybackSourceRefreshResult>();
      final prefetchEntered = Completer<void>();
      var requests = 0;
      var creations = 0;
      final manager = _manager(
        {PlayerEngine.mediaKit: active},
        playerCreator: (_) => creations++ == 0 ? active : replacement,
        videoFrameStallTimeout: const Duration(seconds: 2),
        bufferingStallTimeout: const Duration(milliseconds: 500),
        transientLiveRetryDelays: const [],
      );
      final loading = <bool>[];
      final loadingSubscription = manager.onLoading.listen(loading.add);
      manager.configureDefaultEngine(PlayerEngine.mediaKit);
      const url = 'https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100';
      try {
        await manager.play(
          url,
          const [url],
          const {},
          room: LiveRoom(roomId: 'queued-native-recovery', platform: 'huya'),
          sourceRefreshAt: DateTime.now().toUtc(),
          sourceResolver: (_) {
            requests++;
            if (!prefetchEntered.isCompleted) prefetchEntered.complete();
            return lease.future;
          },
        );
        await prefetchEntered.future.timeout(const Duration(seconds: 3));
        expect(requests, 1, reason: 'one credential request is pending');
        if (outcome == 'buffer recovered') active.emitLoading(true);
        if (outcome == 'real EOF' || outcome == 'user paused' || outcome == 'pause and resume') {
          active.emitError(PlayerException(message: 'transport EOF', type: PlayerErrorType.network));
        }
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        expect(manager.currentPlayer, same(active), reason: 'a recovery can await the shared credential');
        if (outcome == 'new frame' || outcome == 'real EOF') active.emitFrame();
        if (outcome == 'buffer recovered') active.emitLoading(false);
        if (outcome == 'user paused') await manager.pause();
        if (outcome == 'presentation hidden') manager.setVideoPresentationVisible(false);
        if (outcome == 'pause and resume') {
          await manager.pause();
          await manager.resume();
        }
        lease.complete(
          PlaybackSourceRefreshResult(
            urls: const ['https://al.flv.huya.com/fresh.flv?ctype=huya_pc_exe&t=100'],
            preferredLineIndex: 0,
            refreshAt: DateTime.now().toUtc().add(const Duration(minutes: 4)),
            invalidAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
        final shouldRecover = outcome == 'still stalled' || outcome == 'real EOF';
        expect(requests, 1, reason: 'reuse the pending credential instead of issuing a duplicate request');
        expect(creations, shouldRecover ? 2 : 1);
        expect(manager.currentPlayer, same(shouldRecover ? replacement : active));
        if (!shouldRecover) {
          expect(active.openedUrls, [url]);
          expect(active.softStopCalls, 0);
          expect(active.isPlayingNow, outcome != 'user paused');
          expect(loading.last, isFalse, reason: 'obsolete recovery must not put a healthy or paused room into loading');
        }
      } finally {
        if (!lease.isCompleted) lease.completeError(StateError('test cleanup'));
        await loadingSubscription.cancel();
        await manager.dispose();
      }
    }, skip: !Platform.isWindows);
  }

  for (final observation in ['buffer', 'frame', 'EOF']) {
    for (final resolverFails in [false, true]) {
      test(
        'in-flight $observation recovery rechecks progress when resolver ${resolverFails ? 'fails' : 'returns'}',
        () async {
          final active = _FrameProgressFakePlayer();
          final replacement = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
          final entered = Completer<void>();
          final lease = Completer<PlaybackSourceRefreshResult>();
          var creations = 0;
          final manager = _manager(
            {PlayerEngine.mediaKit: active},
            playerCreator: (_) => creations++ == 0 ? active : replacement,
            bufferingStallTimeout: const Duration(milliseconds: 30),
            videoFrameStallTimeout: const Duration(seconds: 3),
            transientLiveRetryDelays: const [],
          );
          manager.configureDefaultEngine(PlayerEngine.mediaKit);
          final loading = <bool>[];
          final subscription = manager.onLoading.listen(loading.add);
          const url = 'https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100';
          try {
            await manager.play(
              url,
              const [url],
              const {},
              room: LiveRoom(roomId: 'inflight-recovery', platform: 'huya'),
              sourceResolver: (_) {
                if (!entered.isCompleted) entered.complete();
                return lease.future;
              },
            );
            if (observation == 'buffer') {
              active.emitLoading(true);
            } else {
              active.emitError(
                PlayerException(
                  message: observation == 'EOF' ? 'Live source ended' : 'No presented frame',
                  type: PlayerErrorType.source,
                  code: observation == 'EOF' ? 'live_source_completed' : 'video_frame_stall_timeout',
                ),
              );
            }
            await entered.future.timeout(const Duration(seconds: 2));
            if (observation == 'buffer') {
              active.emitLoading(false);
            } else {
              // A new frame refutes a frame-stall observation. At EOF it can
              // instead be a last buffered frame and is not a renewed socket.
              active.emitFrame();
            }
            if (resolverFails) {
              lease.completeError(StateError('fixture signer unavailable'));
            } else {
              lease.complete(
                const PlaybackSourceRefreshResult(
                  urls: ['https://al.flv.huya.com/fresh.flv?ctype=huya_pc_exe&t=100'],
                  preferredLineIndex: 0,
                ),
              );
            }
            await Future<void>.delayed(const Duration(milliseconds: 90));
            if (observation == 'EOF') {
              expect(creations, 2, reason: 'a cached frame must not cancel real EOF recovery');
            } else {
              expect(creations, 1, reason: 'the original transport recovered while the signer was pending');
              expect(manager.currentPlayer, same(active));
              expect(active.openedUrls, [url]);
              expect(active.softStopCalls, 0);
              expect(active.isPlayingNow, isTrue);
              expect(loading.last, isFalse, reason: 'retired recovery must also dismiss its own loading state');
              // A later independent stall of the same generation still gets a
              // recovery chance, rather than being swallowed by deduplication.
              if (observation == 'buffer' && !resolverFails) {
                active.emitLoading(true);
                await Future<void>.delayed(const Duration(milliseconds: 100));
                expect(creations, 2);
              }
            }
          } finally {
            if (!lease.isCompleted) {
              lease.complete(const PlaybackSourceRefreshResult(urls: [], preferredLineIndex: 0));
            }
            await subscription.cancel();
            await manager.dispose();
          }
        },
      );
    }
  }

  for (final outcome in ['recovered', 'paused', 'paused candidate failed', 'still stalled']) {
    test('in-flight Windows candidate respects $outcome before committing', () async {
      final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
      final candidate = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null, emitPlaying: false);
      var creations = 0;
      final manager = _manager(
        {PlayerEngine.mediaKit: active},
        playerCreator: (_) => creations++ == 0 ? active : candidate,
        bufferingStallTimeout: const Duration(milliseconds: 30),
        sourceReadyTimeout: const Duration(seconds: 2),
        transientLiveRetryDelays: const [],
      );
      manager.configureDefaultEngine(PlayerEngine.mediaKit);
      final loading = <bool>[];
      final subscription = manager.onLoading.listen(loading.add);
      const url = 'https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100';
      try {
        await manager.play(
          url,
          const [url],
          const {},
          room: LiveRoom(roomId: 'inflight-candidate', platform: 'huya'),
          sourceResolver: (_) async => const PlaybackSourceRefreshResult(
            urls: ['https://al.flv.huya.com/fresh.flv?ctype=huya_pc_exe&t=100'],
            preferredLineIndex: 0,
          ),
        );
        active.emitLoading(true);
        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (candidate.openedUrls.isEmpty && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(candidate.openedUrls, hasLength(1));
        if (outcome == 'recovered') active.emitLoading(false);
        if (outcome.startsWith('paused')) await manager.pause();
        if (outcome == 'paused candidate failed') {
          candidate.emitError(PlayerException(message: 'candidate TLS failed', type: PlayerErrorType.network));
        } else {
          candidate.emitUnexpectedPlaying(true);
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (outcome == 'still stalled') {
          expect(manager.currentPlayer, same(candidate));
        } else {
          expect(manager.currentPlayer, same(active));
          expect(active.openedUrls, [url], reason: 'candidate failure must not fall through to destructive reopen');
          expect(active.isPlayingNow, outcome == 'recovered');
          expect(active.softStopCalls, 0);
          expect(candidate.disposeCalls, 1);
          expect(loading.last, isFalse);
        }
      } finally {
        await subscription.cancel();
        await manager.dispose();
      }
    }, skip: !Platform.isWindows);
  }

  test('obsolete recoveries do not exhaust the later real EOF credential budget', () async {
    final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final candidate = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    var entered = Completer<void>();
    var lease = Completer<PlaybackSourceRefreshResult>();
    final requests = <PlaybackSourceRefreshRequest>[];
    var creations = 0;
    final manager = _manager(
      {PlayerEngine.mediaKit: active},
      playerCreator: (_) => creations++ == 0 ? active : candidate,
      bufferingStallTimeout: const Duration(milliseconds: 30),
      transientLiveRetryDelays: const [],
    )..configureDefaultEngine(PlayerEngine.mediaKit);
    try {
      await manager.play(
        'https://cdn.example/live.flv',
        const [],
        const {},
        room: LiveRoom(roomId: 'obsolete-budget', platform: 'huya'),
        sourceResolver: (request) {
          requests.add(request);
          entered.complete();
          return lease.future;
        },
      );
      for (var cycle = 0; cycle < 4; cycle++) {
        if (cycle < 3) {
          active.emitLoading(true);
        } else {
          active.emitCompleted();
        }
        await entered.future.timeout(const Duration(seconds: 2));
        expect(requests.last.advanceLine, isFalse, reason: 'obsolete work must not mark a healthy line failed');
        if (cycle < 3) active.emitLoading(false);
        lease.complete(
          PlaybackSourceRefreshResult(urls: ['https://cdn.example/fresh-$cycle.flv'], preferredLineIndex: 0),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(manager.currentPlayer, same(cycle < 3 ? active : candidate));
        entered = Completer<void>();
        lease = Completer<PlaybackSourceRefreshResult>();
      }
      expect(requests, hasLength(4));
      expect(candidate.openedUrls, ['https://cdn.example/fresh-3.flv']);
    } finally {
      if (!lease.isCompleted) lease.complete(const PlaybackSourceRefreshResult(urls: [], preferredLineIndex: 0));
      await manager.dispose();
    }
  }, skip: !Platform.isWindows);

  for (final outcome in ['recovered', 'paused']) {
    test('IJK recovery checks ownership after allocating a native engine: $outcome', () async {
      final active = _RecoveryFakePlayer(PlayerEngine.fijk, (_) => null);
      final allocation = Completer<void>();
      final candidate = _RecoveryFakePlayer(PlayerEngine.fijk, (_) => null, initBarrier: allocation.future);
      var creations = 0;
      final manager = _manager(
        {PlayerEngine.fijk: active},
        playerCreator: (_) => creations++ == 0 ? active : candidate,
        bufferingStallTimeout: const Duration(milliseconds: 30),
        transientLiveRetryDelays: const [],
      )..configureDefaultEngine(PlayerEngine.fijk);
      try {
        await manager.play(
          'https://cdn.example/live.flv',
          const [],
          const {},
          room: LiveRoom(roomId: 'ijk-recovery', platform: 'test'),
        );
        active.emitLoading(true);
        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (creations < 2 && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(creations, 2);
        if (outcome == 'paused') {
          await manager.pause();
        } else {
          active.emitLoading(false);
        }
        allocation.complete();
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(manager.currentPlayer, same(active));
        expect(candidate.openedUrls, isEmpty);
        expect(candidate.disposeCalls, 1);
        expect(active.disposeCalls, 0);
        expect(active.isPlayingNow, outcome == 'recovered');
      } finally {
        if (!allocation.isCompleted) allocation.complete();
        await manager.dispose();
      }
    });
  }

  for (final commitStep in ['pause active', 'unmute candidate']) {
    test('Windows handoff respects user pause during $commitStep', () async {
      final barrier = Completer<void>();
      final active = _RecoveryFakePlayer(
        PlayerEngine.mediaKit,
        (_) => null,
        pauseBarrier: commitStep == 'pause active' ? barrier.future : null,
      );
      final candidate = _RecoveryFakePlayer(
        PlayerEngine.mediaKit,
        (_) => null,
        unmuteBarrier: commitStep == 'unmute candidate' ? barrier.future : null,
      );
      var creations = 0;
      final manager = _manager(
        {PlayerEngine.mediaKit: active},
        playerCreator: (_) => creations++ == 0 ? active : candidate,
        transientLiveRetryDelays: const [],
      )..configureDefaultEngine(PlayerEngine.mediaKit);
      try {
        await manager.play(
          'https://cdn.example/live.flv',
          const [],
          const {},
          room: LiveRoom(roomId: 'commit-pause', platform: 'huya'),
          sourceResolver: (_) async =>
              const PlaybackSourceRefreshResult(urls: ['https://cdn.example/new.flv'], preferredLineIndex: 0),
        );
        active.emitError(PlayerException(message: 'network EOF', type: PlayerErrorType.network));
        bool commitReached() => commitStep == 'pause active' ? !active.isPlayingNow : candidate.unmuteCalls > 0;
        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (!commitReached() && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(commitReached(), isTrue);
        final userPause = manager.pause();
        barrier.complete();
        await userPause;
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(manager.currentPlayer, same(active));
        expect(active.isPlayingNow, isFalse);
        expect(active.playCalls, 0, reason: 'rollback must not resume against the latest pause intent');
        expect(candidate.disposeCalls, 1);
        expect(active.openedUrls, ['https://cdn.example/live.flv']);
      } finally {
        if (!barrier.isCompleted) barrier.complete();
        await manager.dispose();
      }
    }, skip: !Platform.isWindows);
  }

  test('candidate errors before open completes stay inside the recovery transaction', () async {
    final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final opening = Completer<void>();
    final candidate = _RecoveryFakePlayer(
      PlayerEngine.mediaKit,
      (_) => null,
      emitPlaying: false,
      openBarrier: opening.future,
    );
    var creations = 0;
    final manager = _manager(
      {PlayerEngine.mediaKit: active},
      playerCreator: (_) => creations++ == 0 ? active : candidate,
      bufferingStallTimeout: const Duration(milliseconds: 30),
      transientLiveRetryDelays: const [],
    )..configureDefaultEngine(PlayerEngine.mediaKit);
    try {
      await manager.play(
        'https://cdn.example/live.flv',
        const [],
        const {},
        room: LiveRoom(roomId: 'early-candidate-error', platform: 'huya'),
        sourceResolver: (_) async =>
            const PlaybackSourceRefreshResult(urls: ['https://cdn.example/new.flv'], preferredLineIndex: 0),
      );
      active.emitLoading(true);
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (candidate.openedUrls.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(candidate.openedUrls, hasLength(1));
      active.emitLoading(false);
      candidate.emitError(PlayerException(message: 'early candidate error', type: PlayerErrorType.network));
      // The open operation still owns the await. Any error on the separate
      // readiness Future must be contained rather than escaping to the Zone.
      await Future<void>.delayed(Duration.zero);
      opening.complete();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(manager.currentPlayer, same(active));
      expect(active.isPlayingNow, isTrue);
      expect(active.openedUrls, ['https://cdn.example/live.flv']);
      expect(candidate.disposeCalls, 1);
    } finally {
      if (!opening.isCompleted) opening.complete();
      await manager.dispose();
    }
  }, skip: !Platform.isWindows);

  test('a candidate error after its first frame still prevents installing that candidate', () async {
    final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final opening = Completer<void>();
    final candidate = _RecoveryFakePlayer(
      PlayerEngine.mediaKit,
      (_) => null,
      emitPlaying: false,
      openBarrier: opening.future,
    );
    var creations = 0;
    final manager = _manager({
      PlayerEngine.mediaKit: active,
    }, playerCreator: (_) => creations++ == 0 ? active : candidate)..configureDefaultEngine(PlayerEngine.mediaKit);
    final room = LiveRoom(roomId: 'late-candidate-error', platform: 'test');
    try {
      await manager.play('https://cdn.example/live.flv', const [], const {}, room: room);
      final changeQuality = manager.play('https://cdn.example/new.flv', const [], const {}, room: room);
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (candidate.openedUrls.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(candidate.openedUrls, hasLength(1));
      candidate.emitUnexpectedPlaying(true);
      candidate.emitError(PlayerException(message: 'candidate failed after readiness', type: PlayerErrorType.network));
      opening.complete();
      await changeQuality;
      expect(manager.currentPlayer, same(active));
      expect(candidate.disposeCalls, 1);
      expect(active.openedUrls, ['https://cdn.example/live.flv', 'https://cdn.example/new.flv']);
    } finally {
      if (!opening.isCompleted) opening.complete();
      await manager.dispose();
    }
  }, skip: !Platform.isWindows);

  for (final action in ['change room', 'close', 'change room / late failure', 'close / late failure']) {
    test('slow native Huya credential prefetch does not block $action', () async {
      final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
      final started = Completer<void>();
      final lease = Completer<PlaybackSourceRefreshResult>();
      final manager = _manager({PlayerEngine.mediaKit: active});
      manager.configureDefaultEngine(PlayerEngine.mediaKit);
      const url = 'https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100';
      Future<void>? command;
      try {
        await manager.play(
          url,
          const [url],
          const {},
          room: LiveRoom(roomId: 'slow-prefetch', platform: 'huya'),
          sourceRefreshAt: DateTime.now().toUtc(),
          sourceResolver: (_) {
            if (!started.isCompleted) started.complete();
            return lease.future;
          },
        );
        await started.future.timeout(const Duration(seconds: 3));
        var completed = false;
        command =
            (action.startsWith('close')
                    ? manager.close()
                    : manager.play(
                        'https://cdn.example/next-room.flv',
                        const ['https://cdn.example/next-room.flv'],
                        const {},
                        room: LiveRoom(roomId: 'next-room', platform: 'test'),
                      ))
                .then((_) => completed = true);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(completed, isTrue, reason: 'a credential request must not own the native command queue');
        expect(lease.isCompleted, isFalse);
        if (action.endsWith('late failure')) {
          lease.completeError(StateError('obsolete credential request failed'));
        } else {
          lease.complete(
            const PlaybackSourceRefreshResult(
              urls: ['https://al.flv.huya.com/obsolete.flv?ctype=huya_pc_exe&t=100'],
              preferredLineIndex: 0,
            ),
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(active.openedUrls.any((url) => url.contains('obsolete')), isFalse);
        expect(active.isPlayingNow, !action.startsWith('close'));
      } finally {
        if (!lease.isCompleted) {
          lease.complete(const PlaybackSourceRefreshResult(urls: [], preferredLineIndex: 0));
        }
        await command;
        await manager.dispose();
      }
    });
  }

  test('native playing events do not duplicate an in-flight credential prefetch', () async {
    final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final entered = Completer<void>();
    final lease = Completer<PlaybackSourceRefreshResult>();
    final manager = _manager({PlayerEngine.mediaKit: active});
    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    var requests = 0;
    const url = 'https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100';
    try {
      await manager.play(
        url,
        const [url],
        const {},
        room: LiveRoom(roomId: 'prefetch-single-flight', platform: 'huya'),
        sourceRefreshAt: DateTime.now().toUtc(),
        sourceResolver: (_) {
          requests++;
          if (!entered.isCompleted) entered.complete();
          return lease.future;
        },
      );
      await entered.future.timeout(const Duration(seconds: 3));
      active.emitUnexpectedPlaying(false);
      active.emitUnexpectedPlaying(true);
      await Future<void>.delayed(const Duration(milliseconds: 1150));
      expect(requests, 1);
      expect(active.openedUrls, [url]);
      expect(active.isPlayingNow, isTrue);
    } finally {
      if (!lease.isCompleted) {
        lease.complete(const PlaybackSourceRefreshResult(urls: [], preferredLineIndex: 0));
      }
      await Future<void>.delayed(Duration.zero);
      await manager.dispose();
    }
  });

  test('obsolete prefetch completion cannot clear the new room single-flight owner', () async {
    final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final oldEntered = Completer<void>();
    final newEntered = Completer<void>();
    final oldLease = Completer<PlaybackSourceRefreshResult>();
    final newLease = Completer<PlaybackSourceRefreshResult>();
    final manager = _manager({PlayerEngine.mediaKit: active});
    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    var newRequests = 0;
    const oldUrl = 'https://al.flv.huya.com/old.flv?ctype=huya_pc_exe&t=100';
    const newUrl = 'https://tx.flv.huya.com/new.flv?ctype=huya_pc_exe&t=100';
    try {
      await manager.play(
        oldUrl,
        const [oldUrl],
        const {},
        room: LiveRoom(roomId: 'old-prefetch', platform: 'huya'),
        sourceRefreshAt: DateTime.now().toUtc(),
        sourceResolver: (_) {
          if (!oldEntered.isCompleted) oldEntered.complete();
          return oldLease.future;
        },
      );
      await oldEntered.future.timeout(const Duration(seconds: 3));
      await manager.play(
        newUrl,
        const [newUrl],
        const {},
        room: LiveRoom(roomId: 'new-prefetch', platform: 'huya'),
        sourceRefreshAt: DateTime.now().toUtc(),
        sourceResolver: (_) {
          newRequests++;
          if (!newEntered.isCompleted) newEntered.complete();
          return newLease.future;
        },
      );
      await newEntered.future.timeout(const Duration(seconds: 3));
      oldLease.complete(const PlaybackSourceRefreshResult(urls: [], preferredLineIndex: 0));
      await Future<void>.delayed(Duration.zero);
      active.emitUnexpectedPlaying(false);
      active.emitUnexpectedPlaying(true);
      await Future<void>.delayed(const Duration(milliseconds: 1150));
      expect(newRequests, 1);
      expect(active.openedUrls, [oldUrl, newUrl]);
      expect(active.isPlayingNow, isTrue);
    } finally {
      for (final lease in [oldLease, newLease]) {
        if (!lease.isCompleted) lease.complete(const PlaybackSourceRefreshResult(urls: [], preferredLineIndex: 0));
      }
      await Future<void>.delayed(Duration.zero);
      await manager.dispose();
    }
  });

  test('other signed platforms only prefetch without replacing a healthy Windows transport', () async {
    final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final candidate = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    var creations = 0;
    final refreshed = Completer<void>();
    final requests = <PlaybackSourceRefreshRequest>[];
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: active},
      playerCreator: (_) => creations++ == 0 ? active : candidate,
      windowsHuyaProactiveRefreshInterval: const Duration(milliseconds: 20),
    );
    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    const url = 'https://cdn.example/live.flv?token=first';
    await manager.play(
      url,
      const [url],
      const {},
      room: LiveRoom(roomId: 'native-lease', platform: 'other'),
      sourceRefreshAt: DateTime.now().toUtc(),
      sourceResolver: (request) async {
        requests.add(request);
        if (!refreshed.isCompleted) refreshed.complete();
        return PlaybackSourceRefreshResult(
          urls: const ['https://cdn.example/live.flv?token=second'],
          preferredLineIndex: 0,
          refreshAt: DateTime.now().toUtc().add(const Duration(minutes: 4)),
          invalidAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        );
      },
    );
    await refreshed.future.timeout(const Duration(seconds: 3));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final owner = manager.currentPlayer;
    final playing = active.isPlayingNow;
    await manager.dispose();
    expect(owner, same(active));
    expect(playing, isTrue);
    expect(creations, 1);
    expect(active.openedUrls, [url]);
    expect(requests.single.currentUrl, url);
  }, skip: !Platform.isWindows);

  test('native Huya credential refresh never restarts a healthy Windows transport', () async {
    final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final candidate = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    var creations = 0;
    final refreshed = Completer<void>();
    final requests = <PlaybackSourceRefreshRequest>[];
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: active},
      playerCreator: (_) => creations++ == 0 ? active : candidate,
      windowsHuyaProactiveRefreshInterval: const Duration(milliseconds: 20),
    );
    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    const url = 'https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100';
    await manager.play(
      url,
      const [url],
      const {},
      room: LiveRoom(roomId: 'native-lease', platform: 'huya'),
      sourceRefreshAt: DateTime.now().toUtc(),
      sourceResolver: (request) async {
        requests.add(request);
        if (!refreshed.isCompleted) refreshed.complete();
        return PlaybackSourceRefreshResult(
          urls: const ['https://al.flv.huya.com/fresh.flv?ctype=huya_pc_exe&t=100'],
          preferredLineIndex: 0,
          refreshAt: DateTime.now().toUtc().add(const Duration(minutes: 4)),
          invalidAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        );
      },
    );
    await refreshed.future.timeout(const Duration(seconds: 3));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final owner = manager.currentPlayer;
    final playing = active.isPlayingNow;
    await manager.dispose();
    expect(owner, same(active));
    expect(playing, isTrue);
    expect(creations, 1);
    expect(active.openedUrls, [url]);
    expect(requests.single.currentUrl, url);
  }, skip: !Platform.isWindows);

  test('native Huya has no early timer but can consume a prefetched lease after real EOF', () async {
    final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final candidate = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    var creations = 0;
    var refreshCalls = 0;
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: active},
      playerCreator: (_) => creations++ == 0 ? active : candidate,
      windowsHuyaProactiveRefreshInterval: const Duration(milliseconds: 20),
    );
    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    final initialSelection = PlaybackSourceQualitySelection(
      qualities: <LivePlayQuality>[LivePlayQuality(quality: '蓝光', id: 1)],
      currentQuality: 0,
    );
    final refreshedSelection = PlaybackSourceQualitySelection(
      qualities: <LivePlayQuality>[LivePlayQuality(quality: '蓝光', id: 1, isPlaybackUnconfirmed: false)],
      currentQuality: 0,
    );
    final requests = <PlaybackSourceRefreshRequest>[];
    final commits = <PlaybackSourceCommitSnapshot>[];
    final subscription = manager.onSourceCommitted.listen(commits.add);
    const url = 'https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100';
    await manager.play(
      url,
      const [url],
      const {},
      room: LiveRoom(roomId: 'native-expiry', platform: 'huya'),
      sourceRefreshAt: DateTime.now().toUtc().add(const Duration(milliseconds: 1600)),
      sourceSelection: initialSelection,
      sourceResolver: (request) async {
        requests.add(request);
        refreshCalls++;
        return PlaybackSourceRefreshResult(
          urls: const ['https://al.flv.huya.com/fresh.flv?ctype=huya_pc_exe&t=100'],
          preferredLineIndex: 0,
          refreshAt: DateTime.now().toUtc().add(const Duration(minutes: 4)),
          invalidAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          selection: refreshedSelection,
        );
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 1150));
    expect(refreshCalls, 0, reason: 'the former early Huya timer must not apply');
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (refreshCalls == 0 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(refreshCalls, 1);
    expect(requests.single.currentQuality?.quality, '蓝光');
    expect(manager.currentPlayer, same(active));
    expect(
      manager.currentSourceCommit?.selection,
      same(initialSelection),
      reason: 'prefetch alone must not commit metadata',
    );
    active.emitError(PlayerException(message: 'real EOF', type: PlayerErrorType.network));
    final recoveryDeadline = DateTime.now().add(const Duration(seconds: 2));
    while (!identical(manager.currentPlayer, candidate) && DateTime.now().isBefore(recoveryDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final owner = manager.currentPlayer;
    await Future<void>.delayed(Duration.zero);
    final committed = manager.currentSourceCommit;
    await subscription.cancel();
    await manager.dispose();
    expect(owner, same(candidate));
    expect(refreshCalls, 1, reason: 'a fresh prefetched lease should avoid another network lookup');
    expect(candidate.openedUrls, ['https://al.flv.huya.com/fresh.flv?ctype=huya_pc_exe&t=100']);
    expect(committed?.selection, same(refreshedSelection));
    expect(commits.map((event) => event.selection).toList(), <PlaybackSourceQualitySelection?>[
      initialSelection,
      refreshedSelection,
    ]);
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

  test('pause while a Windows candidate warms keeps the active player paused', () async {
    final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final candidate = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null, emitPlaying: false);
    var creations = 0;
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: active},
      playerCreator: (_) => creations++ == 0 ? active : candidate,
      sourceReadyTimeout: const Duration(seconds: 3),
    );
    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    await manager.play(
      'https://cdn.example/old.flv',
      const [],
      const {},
      room: LiveRoom(roomId: 'warm-pause', platform: 'huya'),
      sourceResolver: (_) async =>
          const PlaybackSourceRefreshResult(urls: ['https://cdn.example/fresh.flv'], preferredLineIndex: 0),
    );
    active.emitError(PlayerException(message: 'expired', type: PlayerErrorType.network));
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (candidate.openedUrls.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(candidate.openedUrls, isNotEmpty);
    await manager.pause();
    candidate.emitUnexpectedPlaying(true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final owner = manager.currentPlayer;
    final playing = manager.isPlayingNow;
    final candidateDisposals = candidate.disposeCalls;
    await manager.dispose();
    expect(owner, same(active));
    expect(playing, isFalse);
    expect(candidateDisposals, 1);
  }, skip: !Platform.isWindows);

  test('close immediately revokes a Windows candidate before queued teardown', () async {
    final opened = Completer<void>();
    final releaseOpen = Completer<void>();
    final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final candidate = _RecoveryFakePlayer(
      PlayerEngine.mediaKit,
      (_) => null,
      openBarrier: releaseOpen.future,
      onOpenSource: () => opened.complete(),
    );
    var creations = 0;
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: active,
    }, playerCreator: (_) => creations++ == 0 ? active : candidate)..configureDefaultEngine(PlayerEngine.mediaKit);
    try {
      await manager.play(
        'https://cdn.example/old.flv',
        const [],
        const {},
        room: LiveRoom(roomId: 'close-warm', platform: 'huya'),
        sourceResolver: (_) async =>
            const PlaybackSourceRefreshResult(urls: ['https://cdn.example/fresh.flv'], preferredLineIndex: 0),
      );
      active.emitError(PlayerException(message: 'transport ended', type: PlayerErrorType.network));
      await opened.future;
      final closing = manager.close();
      releaseOpen.complete();
      await closing;
      expect(candidate.unmuteCalls, 0, reason: 'a retired recovery must never become audible');
      expect(
        manager.currentPlayer,
        same(active),
        reason: 'close must stop the original owner, not install a replacement',
      );
      expect(active.softStopCalls, 1);
      expect(candidate.disposeCalls, 1);
    } finally {
      if (!releaseOpen.isCompleted) releaseOpen.complete();
      await manager.dispose();
    }
  }, skip: !Platform.isWindows);

  test('close followed immediately by play preserves the newer playback intent', () async {
    final player = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: player});
    try {
      await manager.initialize(engine: PlayerEngine.mediaKit);
      final closing = manager.close();
      final opening = manager.play(
        'https://cdn.example/reopen.flv',
        const [],
        const {},
        room: LiveRoom(roomId: 'reopen-intent', platform: 'huya'),
      );
      await Future.wait([closing, opening]);
      expect(player.isPlayingNow, isTrue);
      final token = await manager.pauseForLifecycle();
      expect(token, isNotNull, reason: 'native playing alone must not hide a lost playback intent');
      expect(await manager.resumeFromLifecycle(token!), isTrue);
      expect(player.isPlayingNow, isTrue);
    } finally {
      await manager.dispose();
    }
  });

  test('play superseded by close before dispatch never opens a source', () async {
    final player = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: player});
    try {
      await manager.initialize(engine: PlayerEngine.mediaKit);
      final opening = manager.play(
        'https://cdn.example/cancelled.flv',
        const [],
        const {},
        room: LiveRoom(roomId: 'cancelled-intent', platform: 'huya'),
      );
      final closing = manager.close();
      await Future.wait([opening, closing]);
      expect(player.openedUrls, isEmpty);
      expect(player.unmuteCalls, 0);
    } finally {
      await manager.dispose();
    }
  });

  test('close during native allocation fences the late player before source open', () async {
    final allocationStarted = Completer<void>();
    final releaseAllocation = Completer<void>();
    final player = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: player},
      playerCreator: (_) async {
        allocationStarted.complete();
        await releaseAllocation.future;
        return player;
      },
    )..configureDefaultEngine(PlayerEngine.mediaKit);
    try {
      final opening = manager.play(
        'https://cdn.example/late-allocation.flv',
        const [],
        const {},
        room: LiveRoom(roomId: 'late-allocation', platform: 'huya'),
      );
      await allocationStarted.future;
      final closing = manager.close();
      releaseAllocation.complete();
      await Future.wait([opening, closing]);
      expect(player.openedUrls, isEmpty);
      expect(player.disposeCalls, 1);
      expect(manager.currentPlayer, isNull);
    } finally {
      if (!releaseAllocation.isCompleted) releaseAllocation.complete();
      await manager.dispose();
    }
  });

  for (final command in ['replay', 'retry']) {
    test('close retires an already queued $command without another source open', () async {
      final player = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
      final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: player})
        ..configureDefaultEngine(PlayerEngine.mediaKit);
      try {
        await manager.play(
          'https://cdn.example/live.flv',
          const [],
          const {},
          room: LiveRoom(roomId: 'cancel-$command', platform: 'huya'),
        );
        final reopening = command == 'replay' ? manager.replay() : manager.retry();
        final closing = manager.close();
        await Future.wait([reopening, closing]);
        expect(player.openedUrls, ['https://cdn.example/live.flv']);
        expect(player.softStopCalls, 1);
        expect(player.isPlayingNow, isFalse);
      } finally {
        await manager.dispose();
      }
    });
  }

  test('rapid queued selections open only the latest requested source', () async {
    final player = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: player})
      ..configureDefaultEngine(PlayerEngine.mediaKit);
    final room = LiveRoom(roomId: 'latest-selection', platform: 'huya');
    final commits = <PlaybackSourceCommitSnapshot>[];
    final subscription = manager.onSourceCommitted.listen(commits.add);
    try {
      final previous = manager.play(
        'https://cdn.example/obsolete.flv',
        const [],
        const {},
        room: room,
        sourceSelection: PlaybackSourceQualitySelection(
          qualities: <LivePlayQuality>[LivePlayQuality(quality: 'obsolete', id: 1)],
          currentQuality: 0,
        ),
      );
      final latest = manager.play(
        'https://cdn.example/current.flv',
        const [],
        const {},
        room: room,
        sourceSelection: PlaybackSourceQualitySelection(
          qualities: <LivePlayQuality>[LivePlayQuality(quality: 'current', id: 2)],
          currentQuality: 0,
        ),
      );
      await Future.wait([previous, latest]);
      await Future<void>.delayed(Duration.zero);
      expect(player.openedUrls, ['https://cdn.example/current.flv']);
      expect(player.isPlayingNow, isTrue);
      expect(commits, hasLength(1), reason: 'a superseded playback intent must not publish a source commit');
      expect(commits.single.selection?.quality.quality, 'current');
      expect(await manager.pauseForLifecycle(), isNotNull);
    } finally {
      await subscription.cancel();
      await manager.dispose();
    }
  });

  test('pause during signed lease resolution prevents a stale transport handoff', () async {
    final active = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final replacement = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final resolving = Completer<void>();
    final resolved = Completer<PlaybackSourceRefreshResult>();
    var creations = 0;
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: active},
      playerCreator: (_) => creations++ == 0 ? active : replacement,
      windowsHuyaProactiveRefreshInterval: const Duration(milliseconds: 20),
    );
    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    final initialSelection = PlaybackSourceQualitySelection(
      qualities: <LivePlayQuality>[LivePlayQuality(quality: '蓝光', id: 1)],
      currentQuality: 0,
    );
    final commits = <PlaybackSourceCommitSnapshot>[];
    final subscription = manager.onSourceCommitted.listen(commits.add);
    await manager.play(
      'https://al.flv.huya.com/live.flv',
      const [],
      const {},
      room: LiveRoom(roomId: 'lease-pause', platform: 'huya'),
      sourceRefreshAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      sourceSelection: initialSelection,
      sourceResolver: (_) {
        resolving.complete();
        return resolved.future;
      },
    );
    await resolving.future.timeout(const Duration(seconds: 3));
    await manager.pause();
    resolved.complete(
      const PlaybackSourceRefreshResult(urls: ['https://al.flv.huya.com/fresh.flv'], preferredLineIndex: 0),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final playerAfterResolution = manager.currentPlayer;
    final playingAfterResolution = manager.isPlayingNow;
    await Future<void>.delayed(Duration.zero);
    final committedAfterResolution = manager.currentSourceCommit;
    await subscription.cancel();
    await manager.dispose();
    expect(playerAfterResolution, same(active));
    expect(playingAfterResolution, isFalse);
    expect(replacement.openedUrls, isEmpty);
    expect(commits, hasLength(1), reason: 'a cancelled resolver must not publish its result');
    expect(committedAfterResolution?.selection, same(initialSelection));
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
    final initialSelection = PlaybackSourceQualitySelection(
      qualities: <LivePlayQuality>[LivePlayQuality(quality: '蓝光', id: 1)],
      currentQuality: 0,
    );
    final refreshedSelection = PlaybackSourceQualitySelection(
      qualities: <LivePlayQuality>[LivePlayQuality(quality: '原画', id: 2)],
      currentQuality: 0,
    );
    final commits = <PlaybackSourceCommitSnapshot>[];
    final subscription = manager.onSourceCommitted.listen(commits.add);

    await manager.play(
      'https://al.flv.huya.com/leased.flv',
      const <String>['https://al.flv.huya.com/leased.flv'],
      const <String, String>{},
      room: LiveRoom(roomId: 'huya-proactive-refresh-failure', platform: 'huya'),
      sourceRefreshAt: DateTime.now().toUtc().add(const Duration(milliseconds: 20)),
      sourceSelection: initialSelection,
      sourceResolver: (_) async {
        refreshCalls++;
        return PlaybackSourceRefreshResult(
          urls: const <String>['https://al.flv.huya.com/refreshed.flv'],
          preferredLineIndex: 0,
          refreshAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          selection: refreshedSelection,
        );
      },
    );

    await Future<void>.delayed(const Duration(milliseconds: 1200));

    expect(refreshCalls, 1);
    expect(creations, 2);
    expect(manager.currentPlayer, same(active));
    expect(active.isPlayingNow, isTrue);
    expect(active.openedUrls, <String>['https://al.flv.huya.com/leased.flv']);
    expect(replacement.disposeCalls, 1);
    expect(manager.hasError.value, isFalse);
    expect(commits, hasLength(1), reason: 'a failed warm candidate must not publish resolved metadata');
    expect(manager.currentSourceCommit?.selection, same(initialSelection));
    expect(manager.isSourceCommitCurrent(manager.currentSourceCommit!), isTrue);
    await subscription.cancel();
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

  for (final result in ['fresh-url', 'empty', 'failure']) {
    test('media recovery during a dispatched backoff resolver cancels its $result result', () async {
      final active = _FrameProgressFakePlayer();
      final resolvingRetry = Completer<void>();
      final releaseResolver = Completer<void>();
      var creations = 0;
      var resolverCalls = 0;
      final manager = _manager(
        <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: active},
        videoFrameStallTimeout: Duration.zero,
        bufferingStallTimeout: Duration.zero,
        transientLiveRetryDelays: const [Duration(milliseconds: 12)],
        playerCreator: (_) {
          if (creations++ == 0) return active;
          return _RecoveryFakePlayer(
            PlayerEngine.mediaKit,
            (_) => PlayerException(message: 'replacement TLS failure', type: PlayerErrorType.source),
          );
        },
      );
      manager.configureDefaultEngine(PlayerEngine.mediaKit);
      final loading = <bool>[];
      final subscription = manager.onLoading.listen(loading.add);
      try {
        await manager.play(
          'https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100',
          const ['https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100'],
          const {},
          room: LiveRoom(roomId: 'native-backoff-recovery', platform: 'huya'),
          sourceResolver: (_) async {
            resolverCalls++;
            if (resolverCalls == 1) return const PlaybackSourceRefreshResult(urls: [], preferredLineIndex: 0);
            if (!resolvingRetry.isCompleted) resolvingRetry.complete();
            await releaseResolver.future;
            if (result == 'failure') throw StateError('late resolver failure');
            return PlaybackSourceRefreshResult(
              urls: result == 'empty' ? const [] : const ['https://al.flv.huya.com/fresh.flv?ctype=huya_pc_exe&t=100'],
              preferredLineIndex: 0,
            );
          },
        );
        active.emitError(
          PlayerException(
            message: 'no presented frame',
            type: PlayerErrorType.source,
            code: 'video_frame_stall_timeout',
          ),
        );
        await resolvingRetry.future.timeout(const Duration(seconds: 2));
        final creationsBeforeRecovery = creations;
        final opensBeforeRecovery = active.openedUrls.length;
        // The timer has already fired: only its native operation is waiting.
        active.emitFrame();
        releaseResolver.complete();
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(creations, creationsBeforeRecovery, reason: 'a recovered renderer must retain native ownership');
        expect(active.openedUrls.length, opensBeforeRecovery, reason: 'late retry must not reopen the active stream');
        expect(manager.currentPlayer, same(active));
        expect(manager.isPlayingNow, isTrue);
        expect(loading.last, isFalse);
        expect(manager.hasError.value, isFalse);
        if (result == 'empty') {
          final callsBeforeNewFailure = resolverCalls;
          active.emitError(
            PlayerException(
              message: 'no presented frame',
              type: PlayerErrorType.source,
              code: 'video_frame_stall_timeout',
            ),
          );
          final deadline = DateTime.now().add(const Duration(milliseconds: 300));
          while (resolverCalls == callsBeforeNewFailure && DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          expect(
            resolverCalls,
            greaterThan(callsBeforeNewFailure),
            reason: 'a later real failure keeps its recovery path',
          );
        }
      } finally {
        if (!releaseResolver.isCompleted) releaseResolver.complete();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await subscription.cancel();
        await manager.dispose();
      }
    }, skip: !Platform.isWindows);
  }

  for (final diagnostic in ['buffering_stall_timeout', 'unexpected_pause_timeout']) {
    for (final matchingProgress in [true, false]) {
      test('dispatched $diagnostic requires matching progress: $matchingProgress', () async {
        final active = _FrameProgressFakePlayer();
        final resolvingRetry = Completer<void>();
        final releaseResolver = Completer<void>();
        var creations = 0;
        var resolverCalls = 0;
        final manager = _manager(
          <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: active},
          videoFrameStallTimeout: Duration.zero,
          bufferingStallTimeout: Duration.zero,
          transientLiveRetryDelays: const [Duration(milliseconds: 12)],
          playerCreator: (_) => creations++ == 0
              ? active
              : _RecoveryFakePlayer(
                  PlayerEngine.mediaKit,
                  (_) => PlayerException(message: 'replacement TLS failure', type: PlayerErrorType.source),
                ),
        );
        manager.configureDefaultEngine(PlayerEngine.mediaKit);
        try {
          await manager.play(
            'https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100',
            const ['https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100'],
            const {},
            room: LiveRoom(roomId: 'progress-kind', platform: 'huya'),
            sourceResolver: (_) async {
              if (++resolverCalls == 1) return const PlaybackSourceRefreshResult(urls: [], preferredLineIndex: 0);
              if (!resolvingRetry.isCompleted) resolvingRetry.complete();
              await releaseResolver.future;
              return const PlaybackSourceRefreshResult(
                urls: ['https://al.flv.huya.com/fresh.flv?ctype=huya_pc_exe&t=100'],
                preferredLineIndex: 0,
              );
            },
          );
          if (diagnostic == 'buffering_stall_timeout') {
            active.emitLoading(true);
          } else {
            active.emitUnexpectedPlaying(false);
          }
          active.emitError(PlayerException(message: 'inferred stall', type: PlayerErrorType.source, code: diagnostic));
          await resolvingRetry.future.timeout(const Duration(seconds: 2));
          final creationsBeforeProgress = creations;
          if (!matchingProgress) {
            active.emitFrame();
          } else if (diagnostic == 'buffering_stall_timeout') {
            active.emitLoading(false);
          } else {
            active.emitUnexpectedPlaying(true);
          }
          releaseResolver.complete();
          await Future<void>.delayed(const Duration(milliseconds: 100));
          if (matchingProgress) {
            expect(creations, creationsBeforeProgress, reason: 'the recovered native source must stay installed');
            expect(manager.currentPlayer, same(active));
            expect(manager.isPlayingNow, isTrue);
          } else {
            expect(creations, greaterThan(creationsBeforeProgress), reason: 'a frame does not refute buffering/pause');
          }
        } finally {
          if (!releaseResolver.isCompleted) releaseResolver.complete();
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await manager.dispose();
        }
      }, skip: !Platform.isWindows);
    }
  }

  for (final failure in ['completed', 'native-error']) {
    test('a buffered tail frame cannot cancel dispatched $failure recovery', () async {
      final active = _FrameProgressFakePlayer();
      final resolvingRetry = Completer<void>();
      final releaseResolver = Completer<void>();
      var creations = 0;
      var resolverCalls = 0;
      final manager = _manager(
        <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: active},
        videoFrameStallTimeout: Duration.zero,
        bufferingStallTimeout: Duration.zero,
        transientLiveRetryDelays: const [Duration(milliseconds: 12)],
        playerCreator: (_) => creations++ == 0
            ? active
            : _RecoveryFakePlayer(
                PlayerEngine.mediaKit,
                (_) => PlayerException(message: 'replacement TLS failure', type: PlayerErrorType.source),
              ),
      );
      manager.configureDefaultEngine(PlayerEngine.mediaKit);
      try {
        await manager.play(
          'https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100',
          const ['https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100'],
          const {},
          room: LiveRoom(roomId: 'native-ended-tail-frame', platform: 'huya'),
          sourceResolver: (_) async {
            if (++resolverCalls == 1) return const PlaybackSourceRefreshResult(urls: [], preferredLineIndex: 0);
            if (!resolvingRetry.isCompleted) resolvingRetry.complete();
            await releaseResolver.future;
            return const PlaybackSourceRefreshResult(
              urls: ['https://al.flv.huya.com/fresh.flv?ctype=huya_pc_exe&t=100'],
              preferredLineIndex: 0,
            );
          },
        );
        if (failure == 'completed') {
          active.emitCompleted();
        } else {
          active.emitError(PlayerException(message: 'transport EOF', type: PlayerErrorType.network));
        }
        await resolvingRetry.future.timeout(const Duration(seconds: 2));
        final creationsBeforeTail = creations;
        active.emitFrame();
        releaseResolver.complete();
        final deadline = DateTime.now().add(const Duration(milliseconds: 300));
        while (creations == creationsBeforeTail && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(creations, greaterThan(creationsBeforeTail), reason: 'a tail frame does not reopen an ended socket');
      } finally {
        if (!releaseResolver.isCompleted) releaseResolver.complete();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await manager.dispose();
      }
    }, skip: !Platform.isWindows);
  }

  test('duplicate native failures do not cancel the pending bounded retry', () async {
    final active = _FrameProgressFakePlayer();
    var creations = 0;
    var resolverCalls = 0;
    final retryEntered = Completer<void>();
    final manager = _manager(
      <PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: active},
      videoFrameStallTimeout: Duration.zero,
      bufferingStallTimeout: Duration.zero,
      transientLiveRetryDelays: const [Duration(milliseconds: 40)],
      playerCreator: (_) => creations++ == 0
          ? active
          : _RecoveryFakePlayer(
              PlayerEngine.mediaKit,
              (_) => PlayerException(message: 'replacement TLS failure', type: PlayerErrorType.source),
            ),
    );
    manager.configureDefaultEngine(PlayerEngine.mediaKit);
    try {
      await manager.play(
        'https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100',
        const ['https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100'],
        const {},
        room: LiveRoom(roomId: 'native-duplicate-error', platform: 'huya'),
        sourceResolver: (_) async {
          if (++resolverCalls >= 2 && !retryEntered.isCompleted) retryEntered.complete();
          return const PlaybackSourceRefreshResult(urls: [], preferredLineIndex: 0);
        },
      );
      // Both events belong to the same failed source. The second one waits in
      // the lifecycle queue until the first schedules its backoff timer.
      final error = PlayerException(message: 'repeated native network error', type: PlayerErrorType.network);
      active.emitError(error);
      active.emitError(error);
      await Future.any<void>([retryEntered.future, Future<void>.delayed(const Duration(milliseconds: 500))]);
      expect(retryEntered.isCompleted, isTrue, reason: 'deduplication must have no recovery-cancelling side effects');
    } finally {
      await manager.dispose();
    }
  }, skip: !Platform.isWindows);

  test('frame watchdog does not allocate a fresh timer for every presented frame', () async {
    var timerCreations = 0;
    await runZoned(
      () async {
        final active = _FrameProgressFakePlayer();
        final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{PlayerEngine.mediaKit: active});
        manager.configureDefaultEngine(PlayerEngine.mediaKit);
        try {
          await manager.play(
            'https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100',
            const ['https://al.flv.huya.com/live.flv?ctype=huya_pc_exe&t=100'],
            const {},
            room: LiveRoom(roomId: 'frame-allocation-budget', platform: 'huya'),
          );
          active.emitFrame();
          final before = timerCreations;
          for (var frame = 0; frame < 600; frame++) {
            active.emitFrame();
          }
          expect(timerCreations - before, 0, reason: 'frame progress updates one deadline, not 600 timers');
        } finally {
          await manager.dispose();
        }
      },
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          timerCreations++;
          return parent.createTimer(zone, duration, callback);
        },
      ),
    );
  });

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

  test('a hanging signed-source refresh is bounded before live completion fallback', () async {
    final refreshBarrier = Completer<PlaybackSourceRefreshResult>();
    final mediaKit = _RecoveryFakePlayer(PlayerEngine.mediaKit, (_) => null);
    final fijk = _RecoveryFakePlayer(PlayerEngine.fijk, (_) => null);
    final manager = _manager(<PlayerEngine, _RecoveryFakePlayer>{
      PlayerEngine.mediaKit: mediaKit,
      PlayerEngine.fijk: fijk,
    }, sourceRefreshTimeout: const Duration(milliseconds: 5));
    manager.configureDefaultEngine(PlayerEngine.mediaKit);

    try {
      await manager.play(
        'https://cdn.example/expired-live.flv',
        const <String>['https://cdn.example/expired-live.flv'],
        const <String, String>{},
        room: LiveRoom(roomId: 'hung-refresh', platform: 'test'),
        sourceResolver: (_) => refreshBarrier.future,
      );
      mediaKit.emitCompleted();

      final deadline = DateTime.now().add(const Duration(milliseconds: 300));
      while (manager.currentEngine != PlayerEngine.fijk && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(manager.currentEngine, PlayerEngine.fijk);
      expect(fijk.openedUrls, <String>['https://cdn.example/expired-live.flv']);
    } finally {
      if (!refreshBarrier.isCompleted) {
        refreshBarrier.complete(const PlaybackSourceRefreshResult(urls: <String>[], preferredLineIndex: 0));
      }
      await manager.dispose();
    }
  });
}

PlayerManager _manager(
  Map<PlayerEngine, _RecoveryFakePlayer> players, {
  Duration sourceOpenTimeout = const Duration(seconds: 18),
  Duration sourceRefreshTimeout = const Duration(seconds: 12),
  Duration sourceReadyTimeout = Duration.zero,
  Duration unexpectedPauseGrace = const Duration(milliseconds: 1200),
  Duration? unexpectedPauseFailureGrace,
  Duration bufferingStallTimeout = const Duration(seconds: 12),
  Duration videoFrameStallTimeout = const Duration(seconds: 10),
  Duration recoveryBudgetResetDelay = const Duration(seconds: 30),
  Duration windowsHuyaProactiveRefreshInterval = const Duration(seconds: 40),
  List<Duration> transientLiveRetryDelays = const <Duration>[Duration(milliseconds: 750), Duration(seconds: 2)],
  UnifiedPlayerCreator? playerCreator,
  PlaybackInputFactory? sourceInputFactory,
  bool Function()? suppressAutomaticFallbackAudio,
}) {
  return PlayerManager(
    playerCreator: playerCreator ?? (engine) => players[engine]!,
    sourceInputFactory: sourceInputFactory,
    fallbackManager: EngineFallbackManager(
      defaultEngine: players.containsKey(PlayerEngine.mediaKit) ? PlayerEngine.mediaKit : players.keys.first,
      supportedEngines: players.keys.toList(growable: false),
    ),
    lineManager: LineFallbackManager(),
    sourceOpenTimeout: sourceOpenTimeout,
    sourceRefreshTimeout: sourceRefreshTimeout,
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
    suppressAutomaticFallbackAudio: suppressAutomaticFallbackAudio,
  );
}

class _RecoveryFakePlayer implements UnifiedPlayer, PrivateInputAwarePlayer, AudioOutputSuppressionAwarePlayer {
  bool _privateInput = false;
  final openedPrivateInputs = <bool>[];
  final openedSourceIdentities = <String?>[];
  String? _sourceIdentity;
  final openedHeaders = <Map<String, String>>[];
  final openedChoices = <List<String>>[];
  @override
  void setPrivateInput(bool value, {String? sourceIdentity}) {
    _privateInput = value;
    _sourceIdentity = sourceIdentity;
  }

  _RecoveryFakePlayer(
    this.engine,
    this.failureForUrl, {
    this.initFailure,
    this.emitPlaying = true,
    this.hangWhileOpening = false,
    this.initBarrier,
    this.openBarrier,
    this.playBarrier,
    this.onOpenSource,
    this.pauseBarrier,
    this.unmuteBarrier,
    this.emittedWidth,
    this.emittedHeight,
  });

  @override
  final PlayerEngine engine;
  final PlayerException? Function(String url) failureForUrl;
  final Object? initFailure;
  final bool emitPlaying;
  final bool hangWhileOpening;
  final Future<void>? initBarrier;
  final Future<void>? openBarrier;
  final Future<void>? playBarrier;
  final void Function()? onOpenSource;
  final Future<void>? pauseBarrier;
  final Future<void>? unmuteBarrier;
  int unmuteCalls = 0;
  int? emittedWidth;
  int? emittedHeight;
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
  final List<bool> audioOutputSuppressionWrites = <bool>[];
  bool audioOutputWasSuppressedBeforeInit = false;

  @override
  void setAudioOutputSuppressed(bool suppressed) {
    audioOutputSuppressionWrites.add(suppressed);
  }

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
    audioOutputWasSuppressedBeforeInit = audioOutputSuppressionWrites.isNotEmpty && audioOutputSuppressionWrites.last;
    final error = initFailure;
    if (error != null) throw error;
    if (initBarrier != null) await initBarrier;
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
    openedPrivateInputs.add(_privateInput);
    openedSourceIdentities.add(_sourceIdentity);
    openedHeaders.add(Map.of(headers));
    openedChoices.add(List.of(playUrls));
    onOpenSource?.call();
    if (openBarrier != null) await openBarrier;
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
    if (pauseBarrier != null) await pauseBarrier;
  }

  @override
  Future<void> play() async {
    playCalls++;
    if (playBarrier != null) await playBarrier;
    _isPlaying = true;
    _playing.add(true);
  }

  @override
  Future<void> setAudioOnly(bool audioOnly) async {}

  @override
  Future<void> setVolume(double volume) async {
    if (volume > 0) {
      unmuteCalls++;
      if (unmuteBarrier != null) await unmuteBarrier;
    }
  }

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

class _ReceiptHost implements PlayerSessionHost {
  _ReceiptHost(LiveRoom room, String url)
    : state = LivePlayState(
        room: RoomState(detail: room, success: true, isLiving: true),
        player: ui.PlayerState(
          qualites: [
            LivePlayQuality(quality: '高清'),
            LivePlayQuality(quality: '原画'),
          ],
          currentQuality: 0,
          playUrls: [url],
          sourceQueryPolicies: {url: HlsSourceQueryPolicy.fromSource(Uri.parse(url))},
          currentLineIndex: 0,
        ),
      ).obs;

  @override
  final Rx<LivePlayState> state;

  @override
  bool get isClosed => false;

  @override
  Future<void> setCurrentRoomAudioOnlyFromUser(bool value) async {}

  @override
  void updatePlayer({
    VideoController? videoController,
    bool clearVideoController = false,
    List<LivePlayQuality>? qualites,
    int? currentQuality,
    List<String>? playUrls,
    Map<String, HlsSourceQueryPolicy>? sourceQueryPolicies,
    OwnedPlaybackSource? ownedSource,
    bool clearOwnedSource = false,
    int? currentLineIndex,
    bool? isCurrentRoomAudioOnly,
    bool? hasUseDefaultResolution,
  }) {
    state.value = state.value.copyWith(
      player: state.value.player.copyWith(
        videoController: ui.resolveVideoControllerUpdate(
          current: state.value.player.videoController,
          next: videoController,
          clear: clearVideoController,
        ),
        qualites: qualites,
        currentQuality: currentQuality,
        playUrls: playUrls,
        sourceQueryPolicies: sourceQueryPolicies,
        ownedSource: ownedSource,
        clearOwnedSource: clearOwnedSource,
        currentLineIndex: currentLineIndex,
        isCurrentRoomAudioOnly: isCurrentRoomAudioOnly,
        hasUseDefaultResolution: hasUseDefaultResolution,
      ),
    );
  }

  @override
  void updateRoom({LiveRoom? detail, bool? isLiving, bool? success, bool? isLoading, String? loadError}) {
    state.value = state.value.copyWith(
      room: state.value.room.copyWith(
        detail: detail,
        isLiving: isLiving,
        success: success,
        isLoading: isLoading,
        loadError: loadError,
      ),
    );
  }
}

class _ReceiptSite extends LiveSite implements LivePlayUrlResolver {
  _ReceiptSite(this.url);
  final String url;
  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsRaw({
    required LiveRoom detail,
    required LivePlayQuality quality,
  }) async => LivePlayUrlResolution.withSourcePolicies(
    urls: [url],
    sourceQueryPolicies: {url: HlsSourceQueryPolicy.fromSource(Uri.parse(url))},
    appliedQualityData: quality.selectionId,
  );
}

class _BindingFailureFakePlayer extends _RecoveryFakePlayer {
  _BindingFailureFakePlayer(Future<void> barrier, void Function() started)
    : super(PlayerEngine.mediaKit, (_) => null, openBarrier: barrier, onOpenSource: started);

  @override
  Stream<PlayerState> get onStateChanged => throw StateError('fixture candidate binding failed');
}

class _OwnedReceiptRecipe implements LiveInputRecipe {
  const _OwnedReceiptRecipe();
  @override
  String get identity => 'next';
}

class _OwnedReceiptSite extends LiveSite implements LivePlayUrlResolver {
  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsRaw({
    required LiveRoom detail,
    required LivePlayQuality quality,
  }) async => LivePlayUrlResolution.owned(input: const _OwnedReceiptRecipe(), appliedQualityData: quality.selectionId);
}
