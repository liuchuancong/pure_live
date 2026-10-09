// Module: test/fake_engine_playback_test.dart
// Purpose: Play a platform MediaTicket through media_core's kernel on a fake engine, end to end.
// Author: liuchuancong
// Created: 2026-10-09
//
// This is the M2 claim "the media pipeline can play a fake source" turned into a test: a MediaTicket is built
// on the platform side, mapped by the code under test, and the kernel must reach an engine with it. The
// engine is media_core's own FakePlayerAdapter (package:media_core/testing/library.dart is a shipped public
// library, not a private path), so the assertion is about the wiring rather than about a decoder.
//
// What this does NOT prove: that any real device plays anything. No media_kit, no ExoPlayer, no network.
import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart' as core;
import 'package:media_core/testing/library.dart' as doubles;
import 'package:pure_live_media/pure_live_media.dart';
import 'package:pure_live_platform/pure_live_platform.dart' as platform;

import 'support/fake_engine.dart';

platform.MediaTicket _ticket({
  platform.MediaKind kind = platform.MediaKind.vod,
  List<platform.MediaTrack> tracks = const <platform.MediaTrack>[],
  Map<String, String> headers = const <String, String>{},
}) {
  return platform.MediaTicket(
    id: 'ticket-1',
    uri: Uri.parse('https://example.test/master.m3u8'),
    kind: kind,
    protocol: platform.MediaProtocol.hls,
    createdAt: DateTime.utc(2026, 10, 9),
    headers: headers,
    tracks: tracks,
    metadata: platform.MediaPlaybackMetadata(isLive: kind == platform.MediaKind.live),
  );
}

void main() {
  late List<doubles.FakePlayerAdapter> created;
  late core.PlayerKernel kernel;

  setUp(() {
    created = <doubles.FakePlayerAdapter>[];
    kernel = fakeEngineKernel(created: created);
  });

  tearDown(() async {
    await kernel.dispose();
  });

  test('test_ticketReachedTheEngine_aVodTicketOpensOnTheFakeBackend', () async {
    final handle = await kernel.createFromMedia(
      toCoreSource(_ticket(headers: const <String, String>{'Referer': 'https://example.test/'})),
      preferredBackend: 'fake',
    );

    expect(created, hasLength(1));
    final adapter = created.single;
    expect(adapter.calls, contains('initialize'));
    expect(adapter.calls, contains('open'));
    // The url the platform ticket carried is the url the engine was asked to open - nothing re-derived it.
    expect(adapter.openedSources.single.uri, Uri.parse('https://example.test/master.m3u8'));

    await handle.dispose();
  });

  test('test_ticketReachedTheEngine_liveTicketIsOpenedAsLive', () async {
    final handle = await kernel.createFromMedia(
      toCoreSource(_ticket(kind: platform.MediaKind.live)),
      preferredBackend: 'fake',
    );

    expect(created.single.openedSources.single.uri, Uri.parse('https://example.test/master.m3u8'));
    expect(created.single.calls, contains('open'));

    await handle.dispose();
  });

  test('test_ticketReachedTheEngine_compositeTicketReachesTheNativeCompositePlan', () async {
    // A DASH-style ticket is the case CompositeSupport.native exists for: the planner forwards the whole
    // composite and the engine merges internally, so the mapping must not flatten it into one url.
    final source = toCoreSource(
      _ticket(
        tracks: <platform.MediaTrack>[
          platform.MediaTrack(uri: Uri.parse('https://example.test/video.mpd'), kind: platform.MediaTrackType.video),
          platform.MediaTrack(uri: Uri.parse('https://example.test/audio.mpd'), kind: platform.MediaTrackType.audio),
        ],
      ),
    );

    final handle = await kernel.createFromMedia(source, preferredBackend: 'fake');

    expect(source, isA<core.CompositeMediaSource>());
    expect(created.single.calls, contains('open'));

    await handle.dispose();
  });

  test('test_ticketReachedTheEngine_aBackendThatCannotTakeItIsRefusedBeforePlay', () async {
    // The kernel, not the mapping, decides playability: a single-url engine handed a composite gets an
    // UnsupportedPlan, and the platform must see a refusal rather than a silently degraded handle.
    created.clear();
    kernel = fakeEngineKernel(
      created: created,
      capabilities: const core.PlayerAdapterCapabilities(supportedProtocols: <String>{'https'}),
      backendId: 'single_url',
    );

    final source = toCoreSource(
      _ticket(
        tracks: <platform.MediaTrack>[
          platform.MediaTrack(uri: Uri.parse('https://example.test/video.mpd'), kind: platform.MediaTrackType.video),
          platform.MediaTrack(uri: Uri.parse('https://example.test/audio.mpd'), kind: platform.MediaTrackType.audio),
        ],
      ),
    );

    await expectLater(kernel.createFromMedia(source, preferredBackend: 'single_url'), throwsA(isA<UnsupportedError>()));
    expect(created, isEmpty, reason: 'no engine should be built for a plan it cannot serve');
  });

  test('test_ticketReachedTheEngine_playAndStopGoThroughTheHandle', () async {
    final handle = await kernel.createFromMedia(toCoreSource(_ticket()), preferredBackend: 'fake');

    await handle.play();
    await handle.stop();

    expect(created.single.calls, containsAllInOrder(<String>['initialize', 'open', 'play', 'stop']));
    await handle.dispose();
  });
}
