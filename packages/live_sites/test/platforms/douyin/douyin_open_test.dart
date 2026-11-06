import 'dart:async';
import 'dart:math';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_net/testing.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/play/live_playback_plan/live_playback_plan.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_http.dart';
import 'package:live_sites/src/platforms/douyin/capabilities/douyin_playback_provider.dart';
import 'package:live_sites/src/platforms/douyin/capabilities/douyin_room_provider.dart';
import 'package:live_sites/src/platforms/douyin/capabilities/douyin_room_refresh.dart';
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_danmaku_session.dart';
import 'package:live_sites/src/platforms/douyin/douyin_site.dart';
import 'package:test/test.dart';

/// The room's lasting id, as the fixtures name it (`S01-enter-live` was
/// answered in the broadcast whose id the samples carry).
const String _webRid = '127453393722';

/// The moment the fixtures were answered, so a start time reads against the
/// open the samples were written for.
final DateTime _issued = DateTime.utc(2026, 10, 29, 4);

/// The samples of [_webRid]: `S01-enter-live` the signed room answer with its
/// stream, `S02-reflow-nostart` the broadcast's reflow answer without a start
/// time, `S03/S04` the reflow answers that carry one (30 and 5 minutes before
/// the open).
const String _samples = 'test/fixtures/douyin';

/// What differs per run: the random `msToken` and the `a_bogus` it feeds; the
/// samples carry stand-ins for both.
const Set<String> _perRun = {'msToken', 'a_bogus'};

/// The transport under the site: [samples] answer, every request is recorded.
ReplayHttp _replay(List<String> samples) =>
    ReplayHttp.fixtures(_samples, samples, ignoredQuery: _perRun);

/// The platform answers [sample] from now on, ahead of what it answered.
void _answersNow(ReplayHttp http, String sample) =>
    http.samples.insert(0, ReplaySample.load('$_samples/$sample'));

/// How many times a request whose path contains [needle] was made.
int _calls(ReplayHttp http, String needle) =>
    http.requests.where((request) => request.url.path.contains(needle)).length;

/// The replay with one hold added: `room/reflow/info/` never answers, the way
/// a host the network cannot reach does (it accepts and stalls). The replay
/// transport itself always answers, so the hold cannot be a sample.
final class _HangsReflow implements LiveHttp {
  new(this.replay);

  final ReplayHttp replay;

  @override
  Future<LiveResponse> send(LiveRequest request) {
    if (request.url.path.contains('/webcast/room/reflow/info/')) {
      return Completer<LiveResponse>().future;
    }
    return replay.send(request);
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => replay.open(request);

  @override
  void close() => replay.close();
}

/// The site over [http], on a clock the test turns.
DouyinSite _site(LiveHttp http, DateTime Function() now) =>
    DouyinSite(http: DouyinHttp(http), loginCookie: () => 'ttwid=test', now: now, random: Random(7));

/// The right of a capability answer, failing the test when it was a left.
T _right<T>(Either<LiveSiteError, T> answer) => answer.match((error) => fail(error.message), (value) => value);

void main() {
  late ReplayHttp http;
  late DateTime now;

  setUp(() {
    http = _replay(['S01-enter-live', 'S02-reflow-nostart']);
    now = _issued;
  });

  group('one room open reads the room once', () {
    test('detail, chat, qualities and lines share the enter the detail made', () async {
      final site = _site(http, () => now);
      final room = await DouyinRoomProvider(site: site).detail(_webRid);
      final playback = DouyinPlaybackProvider(site: site);

      _right<List<LivePlayQuality>>(await playback.getQualities(room: room));
      _right<List<LivePlayLine>>(await playback.getLines(room: room));
      expect(await DouyinDanmakuProvider(site: site).joinArgs(room), isNotNull);

      expect(_calls(http, '/webcast/room/web/enter/'), 1, reason: 'one open used to sign four enters for one room');
      expect(_calls(http, '/webcast/room/reflow/info/'), 1);
    });

    test('the plan is read off the room too', () async {
      final site = _site(http, () => now);
      final room = await DouyinRoomProvider(site: site).detail(_webRid);

      final plan = _right<LivePlaybackPlan>(await DouyinPlaybackProvider(site: site).resolvePlan(room: room));
      expect(plan.lines, isNotEmpty);
      expect(_calls(http, '/webcast/room/web/enter/'), 1);
    });

    test('an answer older than the open window is read again', () async {
      // Recovery and lease renewal arrive long after the open, and must never
      // be handed the address they are recovering from.
      final site = _site(http, () => now);
      final room = await DouyinRoomProvider(site: site).detail(_webRid);
      final playback = DouyinPlaybackProvider(site: site);
      _right<List<LivePlayLine>>(await playback.getLines(room: room));
      expect(_calls(http, '/webcast/room/web/enter/'), 1);

      now = now.add(DouyinPlaybackProvider.playbackHandleWindow + const Duration(seconds: 1));
      _right<List<LivePlayLine>>(await playback.getLines(room: room));
      expect(_calls(http, '/webcast/room/web/enter/'), 2);
    });

    test('a refresh read carries no handles, so playback asks the room itself', () async {
      final site = _site(http, () => now);
      final room = _right<LiveRoom>(await DouyinRoomRefresh(site: site).getRoomForRefresh(roomId: _webRid));
      expect(room.runtime.streamHandle, isNull);

      final asked = _calls(http, '/webcast/room/web/enter/');
      _right<List<LivePlayLine>>(await DouyinPlaybackProvider(site: site).getLines(room: room));
      expect(_calls(http, '/webcast/room/web/enter/'), asked + 1);
    });
  });

  group('the start time is a label, not a gate', () {
    test('reflow answers it and the room carries it', () async {
      final start = _issued.subtract(const Duration(minutes: 30));
      _answersNow(http, 'S03-reflow-start-30m');

      final room = await DouyinRoomProvider(site: _site(http, () => now)).detail(_webRid);

      expect(room.broadcast.startedAt, start);
      expect(_calls(http, '/webcast/room/web/enter/'), 1);
    });

    test('a host that never answers holds the detail for its wait only', () async {
      final site = _site(_HangsReflow(http), () => now);
      final clock = Stopwatch()..start();

      final room = await DouyinRoomProvider(site: site).detail(_webRid);
      clock.stop();

      expect(room.broadcast.startedAt, isNull);
      expect(room.content.title, '直播中', reason: 'the room itself arrived regardless');
      expect(
        clock.elapsed,
        lessThan(const Duration(seconds: 2)),
        reason: 'the first frame is worth more than the label',
      );
    });

    test('a broadcast that answered nothing is not asked again', () async {
      final site = _site(http, () => now);
      await DouyinRoomProvider(site: site).detail(_webRid);
      expect(_calls(http, '/webcast/room/reflow/info/'), 1);

      await DouyinRoomProvider(site: site).detail(_webRid);
      expect(_calls(http, '/webcast/room/reflow/info/'), 1, reason: 'the miss is remembered for its cooldown');
      expect(_calls(http, '/webcast/room/web/enter/'), 2, reason: 'the room itself is still read fresh');
    });

    test('a broadcast that later gives its start is believed', () async {
      final site = _site(http, () => now);
      await DouyinRoomProvider(site: site).detail(_webRid);

      final start = _issued.subtract(const Duration(minutes: 5));
      _answersNow(http, 'S04-reflow-start-5m');
      now = now.add(DouyinSite.startLookupCooldown + const Duration(seconds: 1));

      final room = await DouyinRoomProvider(site: site).detail(_webRid);
      expect(room.broadcast.startedAt, start);
    });
  });
}
