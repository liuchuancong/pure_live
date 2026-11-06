import 'package:live_net/testing.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kugoulive/api/kugoulive_endpoints.dart';
import 'package:live_sites/src/platforms/kugoulive/api/kugoulive_http.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_site.dart';
import 'package:test/test.dart';

const String _room = '1234567';

/// The samples of [_room]: `S04-room-*` the room info (live, offline, or
/// neither), `S05-stream-*` the stream answer of one FLV variant (signed
/// `first`, renewed `second`).
const String _samples = 'test/fixtures/kugoulive';

/// The transport under the site: [samples] answer, every request is
/// recorded. The stream answer's clock (`_`) differs per run.
ReplayHttp _replay(List<String> samples) => ReplayHttp.fixtures(_samples, samples, ignoredQuery: const {'_'});

/// The platform answers [sample] from now on, ahead of what it answered.
void _answersNow(ReplayHttp http, String sample) => http.samples.insert(0, ReplaySample.load('$_samples/$sample'));

void main() {
  group('recovery', () {
    test('the kept variants serve the lines; recovery enters the room again', () async {
      final http = _replay(['S04-room-live', 'S05-stream-live']);
      final site = KugouliveSite(http: KugouliveHttp(http));
      final room = await site.detail(_room);
      expect(http.requests, hasLength(2), reason: 'the room info, then the stream answer');

      final playback = site.capability<LivePlaybackProvider>()!;
      final held = (await playback.getLines(room: room)).getOrElse((error) => fail('$error'));
      expect(held.single.url, contains('txSecret=first'));
      expect(held.single.lineLabel, 'sid5');
      expect(http.requests, hasLength(2), reason: 'the kept variants need no request');

      _answersNow(http, 'S05-stream-renewed');
      final recovery = site.capability<LivePlayRecovery>();
      expect(recovery, isNotNull);
      final fresh = (await recovery!.refetchLines(room: room)).getOrElse((error) => fail('$error'));
      expect(fresh.single.url, contains('txSecret=second'));
      expect(http.requests.skip(2).map((request) => request.url.host), [
        KugouliveEndpoints.roomHost,
        KugouliveEndpoints.apiHost,
      ]);
    });

    test('a room no longer live is not recovered', () async {
      final http = _replay(['S04-room-live', 'S05-stream-live']);
      final site = KugouliveSite(http: KugouliveHttp(http));
      final room = await site.detail(_room);
      _answersNow(http, 'S04-room-offline');
      final answer = await site.capability<LivePlayRecovery>()!.refetchLines(room: room);
      expect(answer.getLeft().toNullable(), isA<LiveSiteContentUnavailable>());
      expect(http.requests, hasLength(3), reason: 'the offline room info ends it before a stream request');
    });
  });

  group('the one-bit status', () {
    LiveRoom card() => LiveRoom.normalized(platform: 'kugoulive', roomId: _room);

    test('a live session is live, liveType -1 is offline', () async {
      final live = KugouliveSite(http: KugouliveHttp(_replay(['S04-room-live'])));
      expect((await live.capability<LiveStatusCheck>()!.getLiveStatus(room: card())).toNullable(), isTrue);
      final offline = KugouliveSite(http: KugouliveHttp(_replay(['S04-room-offline'])));
      expect((await offline.capability<LiveStatusCheck>()!.getLiveStatus(room: card())).toNullable(), isFalse);
    });

    test('a room with neither has no answer, never an invented offline', () async {
      final site = KugouliveSite(http: KugouliveHttp(_replay(['S04-room-unstated'])));
      final answer = await site.capability<LiveStatusCheck>()!.getLiveStatus(room: card());
      expect(answer.getLeft().toNullable(), isA<LiveSiteParseError>());
    });
  });
}
