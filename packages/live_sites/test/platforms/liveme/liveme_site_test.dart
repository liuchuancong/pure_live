import 'package:live_net/testing.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/liveme/api/liveme_http.dart';
import 'package:live_sites/src/platforms/liveme/liveme_site.dart';
import 'package:test/test.dart';

// The ids of the S03/S04/S05 samples (a live anchor, 2026-09-27).
const String _shortId = '209683072';
const String _videoId = '17904580585651396476';
const String _nextVideoId = '17904580585651399999';

/// The samples of [_shortId]: `S03-mapping-*` (`uid_vid_by_short_id`: the
/// broadcast [_videoId], [_nextVideoId] or none), `S04-profile-live`
/// (`user/getinfo`) and `S05-query-*` (the signed `queryinfosimple` POST of
/// one broadcast: live, the next one live, or live without a stated state).
const String _samples = 'test/fixtures/liveme';

/// What differs per run: the clock (`_time`), the random `vali` and the
/// signature fields (`lm_s_ts`, `lm_s_str`). The `videoid` field is matched,
/// so the broadcast asked for picks its `S05-query-*` answer.
const Set<String> _perRun = {'_time', 'vali', 'lm_s_ts', 'lm_s_str'};

/// The transport under the site: [samples] answer, every request is
/// recorded.
ReplayHttp _replay(List<String> samples) => ReplayHttp.fixtures(_samples, samples, ignoredQuery: _perRun);

/// The platform answers [sample] from now on, ahead of what it answered.
void _answersNow(ReplayHttp http, String sample) => http.samples.insert(0, ReplaySample.load('$_samples/$sample'));

/// The source FLV of broadcast [videoId], as the CDN names it.
String _flv(String videoId) =>
    'https://game.live11.linkv.fun/yolo/$videoId.flv?wsSecret=a01f1912f57a1e829cc30b93fe7a2f48&wsABStime=6ab98a4a';

LiveRoom _card() => LiveRoom.normalized(platform: 'liveme', roomId: _shortId);

void main() {
  group('the one-bit status', () {
    Future<Object?> statusOf(ReplayHttp http) async {
      final site = LivemeSite(http: LivemeHttp(http));
      final read = await site.capability<LiveStatusCheck>()!.getLiveStatus(room: _card());
      return read.fold<Object?>((error) => error, (live) => live);
    }

    test('a broadcasting anchor is live, one without a broadcast is not', () async {
      expect(await statusOf(_replay(['S03-mapping-live', 'S04-profile-live', 'S05-query-live'])), isTrue);
      expect(await statusOf(_replay(['S03-mapping-offline', 'S04-profile-live'])), isFalse);
    });

    test('a broadcast answer that gives no state is no answer, never an invented offline', () async {
      const unstated = ['S03-mapping-live', 'S04-profile-live', 'S05-query-unstated'];
      final refreshed = await LivemeSite(http: LivemeHttp(_replay(unstated)))
          .capability<LiveRoomRefresh>()!
          .getRoomForRefresh(roomId: _shortId);
      expect(
        refreshed.getOrElse((error) => fail('$error')).broadcast.liveStatus,
        LiveStatus.unknown,
        reason: 'the room reads; only its state is not given',
      );
      expect(await statusOf(_replay(unstated)), isA<LiveSiteParseError>());
    });
  });

  group('recovery', () {
    test('the kept stream data serves the lines; recovery asks for the current broadcast', () async {
      final http = _replay(['S03-mapping-live', 'S04-profile-live', 'S05-query-live', 'S05-query-next']);
      final site = LivemeSite(http: LivemeHttp(http));
      final room = await site.detail(_shortId);
      expect(http.requests, hasLength(3), reason: 'the mapping, then the profile and the broadcast');
      // The per-run fields are not matched, so they are read off the request:
      // the broadcast POST went out signed.
      final signed = http.requests.singleWhere((request) => request.method == 'POST');
      expect(Uri.splitQueryString(signed.body!).keys, containsAll(_perRun));
      expect(signed.headers['lm-s-sign'], matches(RegExp(r'^[0-9a-f]{32}$')));

      final playback = site.capability<LivePlaybackProvider>()!;
      final held = (await playback.getLines(room: room)).getOrElse((error) => fail('$error'));
      expect(held.first.url, _flv(_videoId));
      expect(http.requests, hasLength(3), reason: 'the kept data needs no request');

      // The anchor is on a new broadcast.
      _answersNow(http, 'S03-mapping-next');
      final recovery = site.capability<LivePlayRecovery>();
      expect(recovery, isNotNull);
      final fresh = (await recovery!.refetchLines(room: room)).getOrElse((error) => fail('$error'));
      expect(fresh.first.url, _flv(_nextVideoId));
      expect(http.requests.skip(3).map((request) => request.url.path), [
        '/liveme_ent/v1/user/uid_vid_by_short_id',
        '/live/queryinfosimple',
      ], reason: 'the profile adds nothing to a stream');

      final after = (await playback.getLines(room: room)).getOrElse((error) => fail('$error'));
      expect(after.first.url, _flv(_nextVideoId), reason: "recovery's broadcast is the one kept");
      expect(http.requests, hasLength(5));
    });

    test('a broadcast that ended meanwhile says so, and its lines are not handed back', () async {
      final http = _replay(['S03-mapping-live', 'S04-profile-live', 'S05-query-live']);
      final site = LivemeSite(http: LivemeHttp(http));
      final room = await site.detail(_shortId);

      _answersNow(http, 'S03-mapping-offline');
      final answer = await site.capability<LivePlayRecovery>()!.refetchLines(room: room);
      expect(answer.getLeft().toNullable(), isA<LiveSiteContentUnavailable>());
      expect(http.requests, hasLength(4), reason: 'no broadcast to ask about after the mapping');

      final again = await site.capability<LivePlaybackProvider>()!.getLines(room: room);
      expect(again.getLeft().toNullable(), isA<LiveSiteContentUnavailable>());
      expect(http.requests, hasLength(5), reason: 'the dead data is forgotten, so the mapping is asked again');
    });
  });
}
