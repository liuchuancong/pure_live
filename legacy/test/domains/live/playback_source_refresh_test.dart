import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart' show kMediaKitCustomInputKey;
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/core/player/core/playback_input_lease.dart';
import 'package:pure_live/core/player/core/playback_source.dart';
import 'package:pure_live/core/player/core/playback_source_hints.dart';
import 'package:pure_live/domains/live/domain/live_player_facade.dart';
import 'package:pure_live/domains/live/domain/playback_source_refresh.dart';
import 'package:pure_live/shared/platforms/live_site.dart' show LiveStreamFacts, LiveStreamFormat;

LiveRoom _room({String platform = 'huya', String roomId = '12345'}) => LiveRoom(platform: platform, roomId: roomId);

const Map<String, LiveStreamFacts> _facts = <String, LiveStreamFacts>{
  'https://a.example/live.m3u8': (format: LiveStreamFormat.hls, codec: 'h264', unresolvedChildren: false),
};

FacadeStreamCommit _commit({
  int revision = 3,
  LiveRoom? room,
  List<String> urls = const ['https://a.example/live.m3u8', 'https://b.example/live.flv'],
  String currentUrl = 'https://b.example/live.flv',
  int currentLineIndex = 1,
  List<LivePlayQuality>? qualities,
  int currentQuality = 0,
  Object? ownedSource,
}) => FacadeStreamCommit(
  revision: revision,
  room: room ?? _room(),
  urls: urls,
  currentUrl: currentUrl,
  currentLineIndex: currentLineIndex,
  headers: const {'Referer': 'https://www.huya.com/'},
  qualities: qualities ?? <LivePlayQuality>[LivePlayQuality(quality: '原画')],
  currentQuality: currentQuality,
  streamFacts: _facts,
  source: ownedSource,
);

Future<PlaybackInputLease> _recipe(CancelToken cancel) async =>
    PlaybackInputLease(Uri.parse('owned://input'), () async {});

void main() {
  group('refreshedLineOrder', () {
    test('the preferred line leads and the platform order follows', () {
      // The kernel starts a refreshed list at index 0, so the line the viewer
      // was watching has to be moved to the front — an index into the old plan
      // would point at whatever the platform happened to return this time.
      expect(
        refreshedLineOrder(
          urls: const ['https://one.example/a.flv', 'https://two.example/b.flv', 'https://three.example/c.flv'],
          preferredLineIndex: 1,
        ),
        ['https://two.example/b.flv', 'https://one.example/a.flv', 'https://three.example/c.flv'],
      );
    });

    test('an out-of-range preference clamps instead of throwing', () {
      // A quality change can return fewer lines than the plan being replaced;
      // recovery runs on a stream that is already broken, so it must not fail
      // on an index the platform no longer has.
      expect(
        refreshedLineOrder(
          urls: const ['https://one.example/a.flv', 'https://two.example/b.flv'],
          preferredLineIndex: 7,
        ),
        ['https://two.example/b.flv', 'https://one.example/a.flv'],
      );
      expect(refreshedLineOrder(urls: const ['https://one.example/a.flv'], preferredLineIndex: -1), [
        'https://one.example/a.flv',
      ]);
    });

    test('a line the platform listed twice is swept once', () {
      expect(
        refreshedLineOrder(
          urls: const ['https://one.example/a.flv', 'https://two.example/b.flv', 'https://one.example/a.flv'],
          preferredLineIndex: 2,
        ),
        ['https://one.example/a.flv', 'https://two.example/b.flv'],
      );
    });

    test('an empty plan stays empty', () {
      expect(refreshedLineOrder(urls: const [], preferredLineIndex: 0), isEmpty);
    });
  });

  group('sourceRefreshRequestFor', () {
    test('recovery asks for the line it is on, never the next one', () {
      // The sweep walks the refreshed plan itself. A resolver that pre-advanced
      // would skip the viewer's line and land on a CDN nobody chose.
      final request = sourceRefreshRequestFor(_commit());

      expect(request.advanceLine, isFalse);
      expect(request.currentLineIndex, 1);
      expect(request.currentUrl, 'https://b.example/live.flv');
      expect(request.currentQuality?.quality, '原画');
      expect(request.currentSource, isNull);
    });

    test('an owned playback hands the source over and has no URL', () {
      final owned = OwnedPlaybackSource(identity: 'fc2:123', createInput: _recipe);
      final request = sourceRefreshRequestFor(
        _commit(urls: const [], currentUrl: '', currentLineIndex: 0, ownedSource: owned),
      );

      expect(request.currentUrl, isNull);
      expect(identical(request.currentSource, owned), isTrue);
    });

    test('a quality index outside the list clamps, and no list means no quality', () {
      expect(sourceRefreshRequestFor(_commit(currentQuality: 4)).currentQuality?.quality, '原画');
      expect(sourceRefreshRequestFor(_commit(qualities: const [], currentQuality: 0)).currentQuality, isNull);
    });
  });

  group('canAdoptSourceRefresh', () {
    final result = PlaybackSourceRefreshResult(urls: const ['https://fresh.example/a.flv'], preferredLineIndex: 0);

    test('a fresh answer for the same playback is adopted', () {
      expect(canAdoptSourceRefresh(disposed: false, sameRoom: true, revisionMoved: false, result: result), isTrue);
    });

    test('an answer with nothing in it is refused', () {
      expect(
        canAdoptSourceRefresh(
          disposed: false,
          sameRoom: true,
          revisionMoved: false,
          result: const PlaybackSourceRefreshResult(urls: [], preferredLineIndex: 0),
        ),
        isFalse,
      );
    });

    test('a disposed player, a changed room or a newer commit each refuse it', () {
      // The refresh is a round-trip to the platform: everything that can end a
      // playback can happen while it is in flight, and a stale answer would
      // publish a commit describing sources the kernel was never given.
      expect(canAdoptSourceRefresh(disposed: true, sameRoom: true, revisionMoved: false, result: result), isFalse);
      expect(canAdoptSourceRefresh(disposed: false, sameRoom: false, revisionMoved: false, result: result), isFalse);
      expect(canAdoptSourceRefresh(disposed: false, sameRoom: true, revisionMoved: true, result: result), isFalse);
    });

    test('an owned answer counts as sources even with no URLs', () {
      expect(
        canAdoptSourceRefresh(
          disposed: false,
          sameRoom: true,
          revisionMoved: false,
          result: PlaybackSourceRefreshResult.owned(
            source: OwnedPlaybackSource(identity: 'fc2:123', createInput: _recipe),
          ),
        ),
        isTrue,
      );
    });
  });

  group('livePlanSources', () {
    test('every line carries the headers and the container the platform declared', () {
      // A source built without the declared container makes the engine probe
      // for it, and probing is the cost a slow line cannot pay.
      final sources = livePlanSources(
        const ['https://a.example/live.m3u8', 'https://b.example/live.flv'],
        headers: const {'Referer': 'https://www.huya.com/'},
        streamFacts: _facts,
      );

      expect(sources.map((source) => source.uri.toString()), [
        'https://a.example/live.m3u8',
        'https://b.example/live.flv',
      ]);
      expect(declaredStreamFormatOf(sources[0]), 'hls');
      expect(declaredStreamFormatOf(sources[1]), isNull);
      expect(sources.every((source) => source.headers?['Referer'] == 'https://www.huya.com/'), isTrue);
      expect(sources.every((source) => source.type == SourceType.live), isTrue);
    });
  });

  group('ownedPlanSource', () {
    test('the engine is handed the input factory, not the source', () {
      // The regression this pins: a whole OwnedPlaybackSource in the metadata
      // is refused by the custom-input opener ("Not an owned-input recipe")
      // and the room never opens.
      final owned = OwnedPlaybackSource(identity: 'fc2:123', createInput: _recipe);
      final source = ownedPlanSource(owned, _room(platform: 'fc2live', roomId: '123'));

      expect(source.metadata[kMediaKitCustomInputKey], isA<PlaybackOwnedInputFactory>());
      expect(identical(source.metadata[kMediaKitCustomInputKey], owned.createInput), isTrue);
      expect(source.uri.scheme, 'owned');
      expect(source.uri.path, 'fc2live:123');
      expect(source.protocol, SourceProtocol.custom);
    });
  });

  group('refreshedPlaybackCommit', () {
    test('a URL plan goes through the wiring and keeps the platform order in the commit', () async {
      final committed = _commit();
      final relay = PlayerSource(
        id: SourceId('relay'),
        uri: Uri.parse('http://127.0.0.1:8321/live.m3u8'),
        type: SourceType.live,
      );
      final seen = <List<PlayerSource>>[];

      final refreshed = await refreshedPlaybackCommit(
        PlaybackSourceRefreshResult(
          urls: ['https://fresh-one.example/a.m3u8', 'https://fresh-two.example/b.flv'],
          preferredLineIndex: 1,
          selection: PlaybackSourceQualitySelection(
            qualities: [
              LivePlayQuality(quality: '蓝光'),
              LivePlayQuality(quality: '超清'),
            ],
            currentQuality: 1,
            streamFacts: _facts,
          ),
        ),
        committed: committed,
        room: committed.room,
        intercept: (sources) async {
          seen.add(sources);
          return [relay];
        },
      );

      // The kernel sweeps what the wiring returned, not the pre-wiring plan:
      // a refreshed source that skipped the relay would downgrade exactly the
      // streams that need one.
      expect(refreshed.sources, [relay]);
      expect(seen.single.map((source) => source.uri.toString()), [
        'https://fresh-two.example/b.flv',
        'https://fresh-one.example/a.m3u8',
      ]);
      // The commit reports the platform order, so the selector keeps
      // highlighting the line the viewer is on.
      expect(refreshed.urls, ['https://fresh-one.example/a.m3u8', 'https://fresh-two.example/b.flv']);
      expect(refreshed.currentUrl, 'https://fresh-two.example/b.flv');
      expect(refreshed.lines, ['https://fresh-two.example/b.flv', 'https://fresh-one.example/a.m3u8']);
      expect(refreshed.qualities.map((quality) => quality.quality), ['蓝光', '超清']);
      expect(refreshed.currentQuality, 1);
      expect(refreshed.streamFacts, _facts);
      expect(refreshed.ownedSource, isNull);
      // The refreshed lines are opened with the headers the commit already
      // carried: a signed URL is replaced, the room's auth is not re-derived.
      expect(seen.single.first.headers?['Referer'], 'https://www.huya.com/');
    });

    test('an owned answer keeps the source the floating window rebuilds from', () async {
      final committed = _commit(urls: const [], currentUrl: 'owned:fc2live:123', currentLineIndex: 0);
      final owned = OwnedPlaybackSource(identity: 'fc2:123', createInput: _recipe);

      final refreshed = await refreshedPlaybackCommit(
        PlaybackSourceRefreshResult.owned(source: owned),
        committed: committed,
        room: _room(platform: 'fc2live', roomId: '123'),
        intercept: (sources) async => sources,
      );

      expect(refreshed.sources, hasLength(1));
      expect(refreshed.sources.single.uri.scheme, 'owned');
      expect(refreshed.urls, isEmpty);
      expect(refreshed.lines, isEmpty);
      expect(refreshed.currentUrl, 'owned:fc2live:123');
      expect(identical(refreshed.ownedSource, owned), isTrue);
      // No selection came back with the answer, so the committed quality stays.
      expect(refreshed.qualities.map((quality) => quality.quality), ['原画']);
      expect(refreshed.currentQuality, 0);
    });

    test('a selection whose quality index is out of range clamps to the list', () async {
      final committed = _commit();

      final refreshed = await refreshedPlaybackCommit(
        PlaybackSourceRefreshResult(
          urls: ['https://fresh.example/a.m3u8'],
          preferredLineIndex: 0,
          selection: PlaybackSourceQualitySelection(qualities: [LivePlayQuality(quality: '蓝光')], currentQuality: 9),
        ),
        committed: committed,
        room: committed.room,
        intercept: (sources) async => sources,
      );

      expect(refreshed.currentQuality, 0);
      expect(refreshed.streamFacts, isEmpty);
    });
  });
}
