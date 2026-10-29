import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
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

/// The room's lasting id and the broadcast it was in when these fixtures were
/// written.
const String _webRid = '127453393722';
const String _broadcast = '7700781210271812361';

/// The moment the fixtures were answered, so a play URL's `expire` reads as an
/// expiry rather than as a stray number.
final DateTime _issued = DateTime.utc(2026, 10, 29, 4);

/// One hour past the issue time, as the `expire` query counts it.
final String _expire = '${_issued.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000}';

/// `room.stream_url` with two video qualities (the play parser reads the old
/// pull maps and `stream_data` alike).
Map<String, dynamic> get _streamUrl => {
  'flv_pull_url': {
    'FULL_HD1': 'https://pull.example.com/a.flv?expire=$_expire',
    'HD1': 'https://pull.example.com/b.flv?expire=$_expire',
  },
};

/// `room/web/enter/` for [_webRid]: live, with a stream, and no start time —
/// enter never carries one, only reflow does.
String get _enter => jsonEncode({
  'status_code': 0,
  'data': {
    'data': [
      {
        'id_str': _broadcast,
        'status': 2,
        'title': '直播中',
        'owner': {'web_rid': _webRid, 'id_str': '555', 'nickname': '主播'},
        'stats': {'user_count': 12},
        'stream_url': _streamUrl,
      },
    ],
  },
});

/// `room/reflow/info/` for [_broadcast], with a start time only when the
/// broadcast's start is being reported.
String _reflow({int? startTime}) => jsonEncode({
  'status_code': 0,
  'data': {
    'room': {
      'id_str': _broadcast,
      'status': 2,
      'start_time': ?startTime,
      'owner': {'web_rid': _webRid},
      'stream_url': _streamUrl,
    },
  },
});

/// A transport that answers by endpoint, records every request, and can hold
/// one endpoint open the way a host the network cannot reach does.
final class _FakeHttp implements LiveHttp {
  /// The body of `room/web/enter/`.
  String enterBody = _enter;

  /// The body of `room/reflow/info/`, rewritable mid-test.
  String reflowBody = _reflow();

  /// When set, reflow never answers.
  bool reflowHangs = false;

  final List<LiveRequest> requests = [];

  /// How many times the signed enter request was made for the room.
  int get enterCalls => _count('/webcast/room/web/enter/');

  /// How many times the start-time request was made.
  int get reflowCalls => _count('/webcast/room/reflow/info/');

  int _count(String path) => requests.where((request) => request.url.path.contains(path)).length;

  @override
  Future<LiveResponse> send(LiveRequest request) {
    requests.add(request);
    if (request.url.path.contains('/webcast/room/reflow/info/')) {
      if (reflowHangs) return Completer<LiveResponse>().future;
      return Future.value(_response(reflowBody));
    }
    if (request.url.path.contains('/webcast/room/web/enter/')) {
      return Future.value(_response(enterBody));
    }
    throw StateError('unexpected request ${request.url}');
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}

LiveResponse _response(String body) =>
    LiveResponse(statusCode: 200, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(body)));

/// The site over [http], on a clock the test turns.
DouyinSite _site(_FakeHttp http, DateTime Function() now) =>
    DouyinSite(http: DouyinHttp(http), loginCookie: () => 'ttwid=test', now: now, random: Random(7));

/// The right of a capability answer, failing the test when it was a left.
T _right<T>(Either<LiveSiteError, T> answer) => answer.match((error) => fail(error.message), (value) => value);

void main() {
  late _FakeHttp http;
  late DateTime now;

  setUp(() {
    http = _FakeHttp();
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

      expect(http.enterCalls, 1, reason: 'one open used to sign four enters for one room');
      expect(http.reflowCalls, 1);
    });

    test('the plan is read off the room too', () async {
      final site = _site(http, () => now);
      final room = await DouyinRoomProvider(site: site).detail(_webRid);

      final plan = _right<LivePlaybackPlan>(
        await DouyinPlaybackProvider(site: site).resolvePlan(room: room),
      );
      expect(plan.lines, isNotEmpty);
      expect(http.enterCalls, 1);
    });

    test('an answer older than the open window is read again', () async {
      // Recovery and lease renewal arrive long after the open, and must never
      // be handed the address they are recovering from.
      final site = _site(http, () => now);
      final room = await DouyinRoomProvider(site: site).detail(_webRid);
      final playback = DouyinPlaybackProvider(site: site);
      _right<List<LivePlayLine>>(await playback.getLines(room: room));
      expect(http.enterCalls, 1);

      now = now.add(DouyinPlaybackProvider.playbackHandleWindow + const Duration(seconds: 1));
      _right<List<LivePlayLine>>(await playback.getLines(room: room));
      expect(http.enterCalls, 2);
    });

    test('a refresh read carries no handles, so playback asks the room itself', () async {
      final site = _site(http, () => now);
      final room = _right<LiveRoom>(await DouyinRoomRefresh(site: site).getRoomForRefresh(roomId: _webRid));
      expect(room.runtime.streamHandle, isNull);

      final asked = http.enterCalls;
      _right<List<LivePlayLine>>(await DouyinPlaybackProvider(site: site).getLines(room: room));
      expect(http.enterCalls, asked + 1);
    });
  });

  group('the start time is a label, not a gate', () {
    test('reflow answers it and the room carries it', () async {
      final start = _issued.subtract(const Duration(minutes: 30));
      http.reflowBody = _reflow(startTime: start.millisecondsSinceEpoch ~/ 1000);

      final room = await DouyinRoomProvider(site: _site(http, () => now)).detail(_webRid);

      expect(room.broadcast.startedAt, start);
      expect(http.enterCalls, 1);
    });

    test('a host that never answers holds the detail for its wait only', () async {
      http.reflowHangs = true;
      final clock = Stopwatch()..start();

      final room = await DouyinRoomProvider(site: _site(http, () => now)).detail(_webRid);
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
      expect(http.reflowCalls, 1);

      await DouyinRoomProvider(site: site).detail(_webRid);
      expect(http.reflowCalls, 1, reason: 'the miss is remembered for its cooldown');
      expect(http.enterCalls, 2, reason: 'the room itself is still read fresh');
    });

    test('a broadcast that later gives its start is believed', () async {
      final site = _site(http, () => now);
      await DouyinRoomProvider(site: site).detail(_webRid);

      final start = _issued.subtract(const Duration(minutes: 5));
      http.reflowBody = _reflow(startTime: start.millisecondsSinceEpoch ~/ 1000);
      now = now.add(DouyinSite.startLookupCooldown + const Duration(seconds: 1));

      final room = await DouyinRoomProvider(site: site).detail(_webRid);
      expect(room.broadcast.startedAt, start);
    });
  });
}
