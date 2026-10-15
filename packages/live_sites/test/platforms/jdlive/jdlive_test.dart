import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/common/crypto/aes_cbc.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/internal/built_in_sites.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/jdlive/api/jdlive_endpoints.dart';
import 'package:live_sites/src/platforms/jdlive/api/jdlive_http.dart';
import 'package:live_sites/src/platforms/jdlive/danmaku/jdlive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/jdlive/danmaku/jdlive_danmaku_session.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_site.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_failure.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_json.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

/// The clock of the tests: 2026-09-29, in the afternoon.
final DateTime _at = DateTime.parse('2026-09-29T14:00:00.000Z');

const String _liveId = '48378944';
const String _otherLiveId = '51002130';
const String _thirdLiveId = '52134567';

String _json(Object? data) => jsonEncode(data);

String _envelope(Object? data, {int code = 0, Object? subCode = 0, String echo = ''}) =>
    _json({'code': code, 'subCode': subCode, 'echo': echo, 'data': data});

/// A featured-list entry of [liveId] with the card's own fields.
Map<String, Object?> _entry({
  required String liveId,
  int templateType = 1,
  String authorId = '6959410',
  String? nick = '京东自营旗舰店',
  String? title = '国庆大促直播',
  Object? userPic = 'https://img.360buyimg.com/avatar.png',
  String indexImage = 'https://img.360buyimg.com/cover.png',
  int pv = 12345,
  Object? status = 1,
  Object? id,
}) => {
  'templateType': templateType,
  'id': id ?? liveId,
  'data': {
    'liveId': liveId,
    'id': id ?? liveId,
    'authorId': authorId,
    'userName': nick,
    'title': title,
    'userPic': userPic,
    'indexImage': indexImage,
    'pv': pv,
    'status': status,
  },
};

String _directoryFixture({List<Object?>? rows, int currentCount = 2}) => _envelope({
  'list': rows ?? [_entry(liveId: _liveId), _entry(liveId: _otherLiveId, title: '厨房小电')],
  'currentCount': currentCount,
});

/// A play answer of [liveId]; the media fields default to a matched pair on
/// JD Cloud's live CDN.
Map<String, Object?> _playData({
  String liveId = _liveId,
  Object? status = 1,
  Object? secret = 0,
  String h5 = 'https://hlive.jdcloud.com/live/48378944.m3u8',
  String video = 'https://hlive.jdcloud.com/live/48378944.flv',
  String? pc,
  String blurred = 'https://img.360buyimg.com/blurred.png',
}) => {
  'liveId': liveId,
  'status': status,
  'secret': secret,
  'h5VideoUrl': h5,
  'videoUrl': video,
  'pcVideoUrl': pc,
  'blurredImg': blurred,
};

String _playFixture({
  String liveId = _liveId,
  Object? status = 1,
  Object? secret = 0,
  String h5 = 'https://hlive.jdcloud.com/live/48378944.m3u8',
  String video = 'https://hlive.jdcloud.com/live/48378944.flv',
  String? pc,
  String blurred = 'https://img.360buyimg.com/blurred.png',
}) => _envelope(
  _playData(liveId: liveId, status: status, secret: secret, h5: h5, video: video, pc: pc, blurred: blurred),
);

/// The playlist of [base], its children named after its stream key.
String _playlist(Uri base) =>
    '#EXTM3U\n'
    '#EXT-X-STREAM-INF:BANDWIDTH=2000000\n'
    "${base.resolve('${_stem(base)}_1.ts')}\n"
    '#EXT-X-KEY:METHOD=AES-128,URI="${base.resolve('${_stem(base)}_0.key')}"\n'
    "${base.resolve('${_stem(base)}_2.ts')}\n";

String _stem(Uri uri) => uri.pathSegments.last.replaceFirst(RegExp(r'\.(?:m3u8|flv)$'), '');

String _liveauthFixture({String host = 'wss://chat.jd.com/mall', String token = 'tok', String? mask, int code = 0}) =>
    _json({
      'code': code,
      'msg': code == 0 ? 'success' : '鉴权失败',
      'data': code == 0 ? {'liveUrl': host, 'token': token, 'msgMaskKey': mask} : {'error': '解密失败!'},
    });

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(body)));

final class _Seen {
  new(LiveRequest request)
    : method = request.method,
      url = request.url,
      headers = request.headers,
      body = request.body ?? '',
      cancelToken = request.cancelToken;

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String body;
  final CancelToken cancelToken;

  /// The request's form fields.
  Map<String, String> get form => Uri(query: body).queryParameters;
}

final class _FakeHttp implements LiveHttp {
  new(this.onSend);

  final FutureOr<LiveResponse> Function(_Seen request) onSend;
  final List<_Seen> sent = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final seen = _Seen(request);
    sent.add(seen);
    return await onSend(seen);
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}

/// The list rows of a page: page 2 introduces a broadcast the earlier pages
/// did not list, later pages repeat the first page's.
List<Object?> _directoryRows(_Seen request) {
  final body = jsonDecode(request.url.queryParameters['body']!) as Map;
  return body['page'] == 2
      ? [_entry(liveId: _thirdLiveId, title: '新上架专场')]
      : [_entry(liveId: _liveId), _entry(liveId: _otherLiveId, title: '厨房小电')];
}

/// The `currentCount` of a page: what the entries before it add up to.
int _directoryCount(_Seen request) {
  final body = jsonDecode(request.url.queryParameters['body']!) as Map;
  return body['page'] == 2 ? 3 : 2;
}

/// The answers of the site: the list, the play answer and the playlist.
LiveResponse _ordinary(_Seen request) => switch (request.url.queryParameters['functionId']) {
  'liveListWithTabToM' => _resp(
    200,
    _directoryFixture(rows: _directoryRows(request), currentCount: _directoryCount(request)),
  ),
  'getImmediatePlayToM' => _resp(200, _envelope(_playData())),
  _ => request.url.path.endsWith('.m3u8') ? _resp(200, _playlist(request.url)) : _resp(404, '{}'),
};

/// A connector that refuses: a test that needs a socket replaces it.
Future<SocketChannel> _refuseSocket(
  Uri endpoint, {
  required Map<String, String> headers,
  required Iterable<String>? protocols,
  required Duration connectTimeout,
  Duration? pingInterval,
}) async => throw StateError('no socket was asked for in this test');

/// The socket a test drives by hand.
final class _FakeSocket implements SocketChannel {
  final StreamController<Object?> _stream = StreamController<Object?>();
  final List<Object?> sentList = [];
  int? _closeCode;
  bool closed = false;

  @override
  Stream<Object?> get stream => _stream.stream;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => null;

  @override
  void add(Object data) => sentList.add(data);

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
  }

  /// One frame from the site.
  void push(Object? frame) => _stream.add(frame);

  /// The site closed the socket.
  Future<void> ended() => _stream.close();
}

/// Sockets handed out in order, oldest first.
final class _Connector {
  final List<_FakeSocket> sockets = [];
  final List<Uri> endpoints = [];
  final List<Map<String, String>> headers = [];

  _FakeSocket get latest => sockets.last;

  Future<SocketChannel> call(
    Uri endpoint, {
    required Map<String, String> headers,
    required Iterable<String>? protocols,
    required Duration connectTimeout,
    Duration? pingInterval,
  }) async {
    endpoints.add(endpoint);
    this.headers.add(headers);
    final socket = _FakeSocket();
    sockets.add(socket);
    return socket;
  }
}

/// A timer that never goes off: the watches are kept by [FakeTimers] instead.
final class _IdleTimer implements Timer {
  @override
  bool get isActive => false;

  @override
  int get tick => 0;

  @override
  void cancel() {}
}

/// The watches a session sets, so a test can ring them by hand.
final class FakeTimers {
  final List<({Duration delay, void Function() callback})> after = [];

  JdliveTimers get timers => (after: _after, every: _every);

  Timer _after(Duration delay, void Function() callback) {
    after.add((delay: delay, callback: callback));
    return _IdleTimer();
  }

  Timer _every(Duration period, void Function(Timer timer) callback) => _IdleTimer();

  /// Rings the [index]th wait.
  void fire({int index = 0}) => after[index].callback();
}

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

/// The next [count] messages a session reports.
Future<List<LiveMessage>> _next(Stream<LiveMessage> events, int count) {
  final seen = <LiveMessage>[];
  final done = Completer<void>();
  late StreamSubscription<LiveMessage> subscription;
  subscription = events.listen((message) {
    seen.add(message);
    if (seen.length == count && !done.isCompleted) {
      done.complete();
      unawaited(subscription.cancel());
    }
  });
  return done.future.then((_) => seen);
}

/// A comment connection over a socket, clocks and a random the test holds.
Future<({JdliveDanmakuSession session, _FakeSocket socket, FakeTimers timers, _Connector connector, _FakeHttp http})>
_chat({LiveResponse Function(_Seen request)? onSend, Random? random}) async {
  final connector = _Connector();
  final timers = FakeTimers();
  final http = _FakeHttp(onSend ?? (request) => _resp(200, _liveauthFixture()));
  final session = JdliveDanmakuSession(
    args: const JdliveDanmakuArgs(liveId: _liveId),
    site: JdliveSite(http: JdliveHttp(http), connect: connector.call, now: () => _at),
    timers: timers.timers,
    random: random ?? Random(7),
  );
  expect(await session.connect(), isNull);
  await _settle();
  return (session: session, socket: connector.latest, timers: timers, connector: connector, http: http);
}

/// Lets the microtasks of a handshake run.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// One `chat_group_message` of [type].
String _chatFrame({
  String type = 'viewer_send_message',
  String content = '大家好',
  String group = _liveId,
  Object? datetime = 1727611200000,
}) => _json({
  'type': 'chat_group_message',
  'id': 'msg-1',
  'from': {'pinmd5': 'abcd1234'},
  'datetime': datetime,
  'body': {'type': type, 'groupid': group, 'nickName': '观众甲', 'content': content},
});

/// One `get_statistics_result`.
String _statsFrame({Object? current = 42, Object? total = 9001, String group = _liveId}) => _json({
  'type': 'get_statistics_result',
  'body': {'groupid': group, 'current_viewer': current, 'total_viwer': total},
});

void main() {
  group('answers, ids and links', () {
    test('a status says what kind of answer it is', () {
      void expectKind(int status, JdliveFailureKind kind) {
        expect(
          () => JdliveJson.data('{}', status: status, what: 'x'),
          throwsA(predicate((e) => e is JdliveFailure && e.kind == kind)),
        );
      }

      expectKind(200, JdliveFailureKind.apiChanged); // 200 but no envelope code
      expectKind(400, JdliveFailureKind.apiChanged);
      expectKind(422, JdliveFailureKind.apiChanged);
      expectKind(401, JdliveFailureKind.riskControl);
      expectKind(403, JdliveFailureKind.riskControl);
      expectKind(404, JdliveFailureKind.notFound);
      expectKind(429, JdliveFailureKind.rateLimited);
      for (final status in [301, 500, 503]) {
        expectKind(status, JdliveFailureKind.network);
      }
    });

    test('the envelope gates code, subCode and the body size', () {
      expect(JdliveJson.data(_envelope({'a': 1}), status: 200, what: 'x'), {'a': 1});
      expect(
        () => JdliveJson.data(_envelope({}, code: 2, echo: 'api not exist'), status: 200, what: 'x'),
        throwsA(predicate((e) => '$e'.contains('code 2 api not exist'))),
      );
      expect(
        () => JdliveJson.data(_envelope({}, subCode: 3), status: 200, what: 'x'),
        throwsA(predicate((e) => e is JdliveFailure && e.kind == JdliveFailureKind.notFound)),
      );
      expect(
        () => JdliveJson.data('<html>', status: 200, what: 'x'),
        throwsA(predicate((e) => '$e'.contains('not JSON'))),
      );
      expect(
        () => JdliveJson.data('{"a":"${'x' * (JdliveEndpoints.responseLimit + 1)}"}', status: 200, what: 'x'),
        throwsA(predicate((e) => '$e'.contains('answer over'))),
      );
    });

    test('only a breakdown or a throttle is worth asking again', () {
      expect(const JdliveFailure(JdliveFailureKind.network, 'x').isTransient, isTrue);
      expect(const JdliveFailure(JdliveFailureKind.rateLimited, 'x').isTransient, isTrue);
      expect(
        const JdliveFailure(JdliveFailureKind.riskControl, 'x').isTransient,
        isFalse,
        reason: 'an edge that refuses this client does not lift on retry',
      );
      expect(const JdliveFailure(JdliveFailureKind.notFound, 'x').isTransient, isFalse);
    });

    test('a broadcast id is 5 to 18 digits without a leading zero', () {
      expect(JdliveEndpoints.isLiveId('48378944'), isTrue);
      expect(JdliveEndpoints.isLiveId('10000'), isTrue);
      expect(JdliveEndpoints.isLiveId('09999'), isFalse);
      expect(JdliveEndpoints.isLiveId('1234'), isFalse);
      expect(JdliveEndpoints.isLiveId('9' * 19), isFalse);
      expect(JdliveEndpoints.liveIdOf(' 48378944 '), _liveId);
      expect(JdliveEndpoints.liveIdOf('shop'), isNull);
    });

    test('a room link is the page routing by fragment', () {
      String? id(String url) => JdliveEndpoints.liveIdFromUrl(url);
      expect(id('https://lives.jd.com/#/$_liveId'), _liveId);
      expect(id('https://lives.jd.com/#/$_liveId/live'), _liveId);
      expect(id('https://lives.jd.com/#/$_liveId/notice'), _liveId);
      expect(id('https://lives.jd.com/#/$_liveId/closed'), _liveId);
      expect(id('https://lives.jd.com/#/$_liveId/replay?origin=0'), _liveId);
      expect(id('https://LIVES.JD.com/#/$_liveId'), _liveId);
      expect(id('http://lives.jd.com:80/#/$_liveId'), _liveId);
      expect(id('https://lives.jd.com:443/#/$_liveId'), _liveId);
      expect(id('https://lives.jd.com/some/path?x=1#/$_liveId'), _liveId);
      expect(id('https://lives.jd.com:8080/#/$_liveId'), isNull);
      expect(id('https://jd.com/#/$_liveId'), isNull);
      expect(id('https://u:lives.jd.com/#/$_liveId'), isNull);
      expect(id('https://lives.jd.com/#/shop'), isNull);
      expect(JdliveEndpoints.link(_liveId), 'https://lives.jd.com/#/$_liveId');
    });
  });

  group('featured list', () {
    test('the broadcasts of a page are read, the other entries skipped', () {
      final page = JdliveRoomParser.directory(
        _directoryFixture(
          rows: [
            _entry(liveId: _liveId),
            _entry(liveId: '1', templateType: -100),
            _entry(liveId: _otherLiveId),
            _entry(liveId: _liveId, title: 'repeat'),
          ],
        ),
        after: 0,
      );
      expect(page.rooms.map((room) => room.liveId), [_liveId, _otherLiveId], reason: 'promotions and repeats skipped');
      expect(page.nextCount, 2);
      expect(page.hasMore, isTrue);
      final room = page.rooms.first;
      expect(room.authorId, '6959410');
      expect(room.nick, '京东自营旗舰店');
      expect(room.title, '国庆大促直播');
      expect(room.avatar, 'https://img.360buyimg.com/avatar.png');
      expect(room.cover, 'https://img.360buyimg.com/cover.png');
      expect(room.totalViews, 12345);
      expect(room.state, JdliveState.live);
      expect(room.hasPlayAnswer, isFalse, reason: 'a card says no restriction');
    });

    test('an entry that cannot be read is skipped, unless none can', () {
      final page = JdliveRoomParser.directory(
        _directoryFixture(
          rows: [
            _entry(liveId: _liveId),
            {'templateType': 1},
            _entry(liveId: 'x'),
          ],
        ),
        after: 0,
      );
      expect(page.rooms, hasLength(1), reason: 'the unreadable entries cost only themselves');
      expect(
        () => JdliveRoomParser.directory(
          _directoryFixture(
            rows: [
              {'templateType': 1},
              'junk',
            ],
          ),
          after: 0,
        ),
        throwsA(predicate((e) => '$e'.contains('unreadable entries, no broadcast'))),
      );
    });

    test('a list that is not one, too long, or without currentCount is api-changed', () {
      expect(
        () => JdliveRoomParser.directory(_envelope({'list': 'nope', 'currentCount': 1}), after: 0),
        throwsA(predicate((e) => '$e'.contains('not a list'))),
      );
      expect(
        () => JdliveRoomParser.directory(_envelope({'list': <Object?>[], 'currentCount': 'x'}), after: 0),
        throwsA(predicate((e) => '$e'.contains('currentCount'))),
      );
      final over = List.generate(1001, (index) => _entry(liveId: '${10000 + index}'));
      expect(
        () => JdliveRoomParser.directory(_envelope({'list': over, 'currentCount': 1}), after: 0),
        throwsA(predicate((e) => '$e'.contains('1001 entries'))),
      );
    });

    test('a page has more while it has broadcasts and currentCount moves on', () {
      final over = JdliveRoomParser.directory(_directoryFixture(), after: 5);
      expect(over.hasMore, isFalse, reason: 'currentCount did not move past what was served');
      final empty = JdliveRoomParser.directory(_envelope({'list': <Object?>[], 'currentCount': 2}), after: 2);
      expect(empty.hasMore, isFalse);
      expect(empty.rooms, isEmpty);
    });
  });

  group('play answer', () {
    test('the state of a status', () {
      expect(JdliveRoomParser.state(1), JdliveState.live);
      expect(JdliveRoomParser.state(0), JdliveState.preview);
      expect(JdliveRoomParser.state(2), JdliveState.offline);
      expect(JdliveRoomParser.state(3), JdliveState.replay);
      expect(JdliveRoomParser.state(10), JdliveState.paused);
      expect(JdliveRoomParser.state(11), JdliveState.paused);
      expect(JdliveRoomParser.state(null), JdliveState.unknown);
      expect(JdliveRoomParser.state(9), JdliveState.unknown);
    });

    test('a live answer carries its media, matched by stream key', () {
      final room = JdliveRoomParser.play(_playFixture(), liveId: _liveId);
      expect(room.state, JdliveState.live);
      expect(room.restriction, LiveRestriction.none);
      expect(room.hasPlayAnswer, isTrue);
      expect(room.hls.toString(), 'https://hlive.jdcloud.com/live/48378944.m3u8');
      expect(room.flv.toString(), 'https://hlive.jdcloud.com/live/48378944.flv');
      expect(room.background, 'https://img.360buyimg.com/blurred.png');
      expect(room.streamError, isNull);
    });

    test('the flv falls back to pcVideoUrl, and a foreign stream key is dropped', () {
      final fromPc = JdliveRoomParser.play(
        _playFixture(video: '', pc: 'https://hlive.jdcloud.com/live/48378944.flv'),
        liveId: _liveId,
      );
      expect(fromPc.flv.toString(), 'https://hlive.jdcloud.com/live/48378944.flv');
      final foreign = JdliveRoomParser.play(
        _playFixture(video: 'https://hlive.jdcloud.com/live/other.flv'),
        liveId: _liveId,
      );
      expect(foreign.flv, isNull, reason: 'the flv stream key must match the playlist');
      expect(foreign.hls, isNotNull);
    });

    test('an address that is not JD Cloud live media is no address', () {
      for (final bad in [
        'http://hlive.jdcloud.com/live/x.m3u8',
        'https://evil.example.com/live/x.m3u8',
        'https://hlive.jdcloud.com/other/x.m3u8',
        'https://hlive.jdcloud.com/live/x.png',
        'https://u@hlive.jdcloud.com/live/x.m3u8',
        'https://hlive.jdcloud.com/live/x.m3u8#f',
        'https://hlive.jdcloud.com/live/x.m3u8 x',
        'https://hlive.jdcloud.com/live/${'x' * 8200}.m3u8',
      ]) {
        final room = JdliveRoomParser.play(
          _playFixture(h5: bad, video: ''),
          liveId: _liveId,
        );
        expect(room.hls, isNull, reason: bad);
        expect(room.restriction, LiveRestriction.unplayable, reason: 'live without media');
      }
    });

    test('a replay names its recording on the video service, or is unplayable', () {
      final replay = JdliveRoomParser.play(
        _envelope(_playData(status: 3, h5: '', video: '', pc: 'https://videocloud.300hu.com/live/48378944.m3u8')),
        liveId: _liveId,
      );
      expect(replay.state, JdliveState.replay);
      expect(replay.recording.toString(), 'https://videocloud.300hu.com/live/48378944.m3u8');
      expect(replay.hls, isNull, reason: 'a recording is not a live playlist');
      expect(replay.streamError, isNull);
      final bare = JdliveRoomParser.play(
        _envelope(_playData(status: 3, h5: '', video: '', pc: '')),
        liveId: _liveId,
      );
      expect(bare.recording, isNull);
      expect(bare.restriction, LiveRestriction.unplayable);
    });

    test('secret marks the app-only broadcast, whatever the state', () {
      final room = JdliveRoomParser.play(_playFixture(secret: 1), liveId: _liveId);
      expect(room.appOnly, isTrue);
      expect(room.restriction, LiveRestriction.appOnly);
      expect('$room'.contains('appOnly'), isFalse);
      expect('${room.streamError}'.contains('app only'), isTrue);
    });

    test('an answer about another broadcast is api-changed', () {
      expect(
        () => JdliveRoomParser.play(_playFixture(), liveId: _otherLiveId),
        throwsA(predicate((e) => '$e'.contains('asked $_otherLiveId'))),
      );
    });

    test('a JD image is https on 360buyimg.com, anything else is none', () {
      expect(
        JdliveRoomParser.play(_playFixture(blurred: 'https://img.360buyimg.com/x.png'), liveId: _liveId).background,
        'https://img.360buyimg.com/x.png',
      );
      for (final bad in [
        'http://img.360buyimg.com/x.png',
        'https://evil.com/x.png',
        'https://img.360buyimg.com/x.png#f',
        '123',
      ]) {
        expect(
          JdliveRoomParser.play(_playFixture(blurred: bad), liveId: _liveId).background,
          '',
          reason: bad,
        );
      }
      expect(
        () => JdliveRoomParser.directory(_directoryFixture(rows: [_entry(liveId: _liveId, userPic: 123)]), after: 0),
        throwsA(predicate((e) => '$e'.contains('unreadable'))),
        reason: 'a card image that is not text cannot be read',
      );
    });
  });

  group('playlist check', () {
    test('the media references of the playlist must be its own children', () {
      final base = Uri.parse('https://hlive.jdcloud.com/live/48378944.m3u8');
      JdliveRoomParser.checkPlaylist(_playlist(base), expected: base);
      expect(
        () => JdliveRoomParser.checkPlaylist('#EXTM3U\nhttps://evil.example.com/live/48378944_1.ts\n', expected: base),
        throwsA(predicate((e) => '$e'.contains('foreign'))),
      );
      expect(
        () => JdliveRoomParser.checkPlaylist('#EXTM3U\nhttps://hlive.jdcloud.com/live/other_1.ts\n', expected: base),
        throwsA(predicate((e) => '$e'.contains('foreign'))),
      );
      expect(
        () => JdliveRoomParser.checkPlaylist('#EXTM3U\n', expected: base),
        throwsA(predicate((e) => '$e'.contains('no media reference'))),
      );
      expect(
        () => JdliveRoomParser.checkPlaylist('<html>', expected: base),
        throwsA(predicate((e) => '$e'.contains('not an HLS playlist'))),
      );
      expect(
        () => JdliveRoomParser.checkPlaylist('x', expected: base, status: 404),
        throwsA(predicate((e) => e is JdliveFailure && e.kind == JdliveFailureKind.streamUnavailable)),
      );
      final thousand = '#EXTM3U\n${List.filled(1001, '${base.resolve('${_stem(base)}.ts')}').join('\n')}';
      expect(
        () => JdliveRoomParser.checkPlaylist(thousand, expected: base),
        throwsA(predicate((e) => '$e'.contains('over 1000'))),
      );
    });
  });

  group('rooms and streams', () {
    test('the room of a live broadcast', () {
      final room = JdliveRoomParser.room(JdliveRoomParser.play(_playFixture(), liveId: _liveId), withData: true);
      expect(room.roomId, _liveId);
      expect(room.platform, 'jdlive');
      expect(room.links.webUrl, 'https://lives.jd.com/#/$_liveId');
      expect(room.content.notice, JdliveEndpoints.chatNotice);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.audience.totalViewers, isNull, reason: 'the play answer has no views');
      expect(room.audience.primaryMetric, LiveAudienceMetricType.unknown);
      expect(room.runtime.danmakuHandle, isA<JdliveDanmakuArgs>(), reason: 'live and not app-only');
    });

    test('the room of a card keeps the card and no chat arguments', () {
      final card = JdliveRoomParser.directory(_directoryFixture(), after: 0).rooms.first;
      final room = JdliveRoomParser.room(card);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.restriction, isNull);
      expect(room.audience.totalViewers, 12345);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.totalViewers);
      expect(room.runtime.danmakuHandle, isNull, reason: 'only a play answer hands the chat over');
    });

    test('a preview or ended broadcast is offline, a replay is a replay', () {
      LiveRoom roomOf(JdliveState state) {
        final status = switch (state) {
          JdliveState.preview => 0,
          JdliveState.offline => 2,
          JdliveState.replay => 3,
          JdliveState.paused => 10,
          _ => 1,
        };
        final play = JdliveRoomParser.play(
          _envelope(_playData(status: status, h5: '', video: '')),
          liveId: _liveId,
        );
        return JdliveRoomParser.room(play);
      }

      expect(roomOf(JdliveState.preview).broadcast.liveStatus, LiveStatus.offline);
      expect(roomOf(JdliveState.offline).broadcast.liveStatus, LiveStatus.offline);
      expect(roomOf(JdliveState.paused).broadcast.liveStatus, LiveStatus.unknown);
      expect(roomOf(JdliveState.replay).broadcast.liveStatus, LiveStatus.replay);
    });

    test('the qualities and lines of a live broadcast', () {
      final room = JdliveRoomParser.play(_playFixture(), liveId: _liveId);
      final qualities = JdliveRoomParser.qualities(room);
      expect(qualities.map((quality) => quality.qualityId), ['hls', 'flv']);
      expect(qualities.first.label, 'HLS（推荐）');
      final hls = JdliveRoomParser.line(room, 'hls');
      expect(hls.url, 'https://hlive.jdcloud.com/live/48378944.m3u8');
      expect(hls.format, LiveStreamFormat.hls);
      expect(hls.formatSource, LivePlayFormatSource.declared);
      expect(hls.lineLabel, 'hlive.jdcloud.com');
      expect(hls.headers['referer'], 'https://lives.jd.com/#/$_liveId');
      expect(hls.lease, isNull, reason: 'the addresses carry no expiry');
      expect(JdliveRoomParser.line(room, 'flv').format, LiveStreamFormat.flv);
      expect(
        () => JdliveRoomParser.line(room, '1080p'),
        throwsA(predicate((e) => e is JdliveFailure && e.kind == JdliveFailureKind.invalidArgument)),
      );
      final bare = JdliveRoomParser.play(
        _envelope(_playData(h5: '', video: '')),
        liveId: _liveId,
      );
      expect(() => JdliveRoomParser.line(bare, 'hls'), throwsA(predicate((e) => '$e'.contains('no hls'))));
    });

    test('the one quality of a replay is its recording', () {
      final room = JdliveRoomParser.play(
        _envelope(_playData(status: 3, h5: '', video: '', pc: 'https://videocloud.300hu.com/live/48378944.m3u8')),
        liveId: _liveId,
      );
      expect(JdliveRoomParser.qualities(room).single.qualityId, 'replay');
      expect(JdliveRoomParser.line(room, 'replay').url, 'https://videocloud.300hu.com/live/48378944.m3u8');
    });

    test('an app-only broadcast cannot play, and its notice says so', () {
      final room = JdliveRoomParser.room(
        JdliveRoomParser.play(_playFixture(secret: 1), liveId: _liveId),
        withData: true,
      );
      expect(room.content.notice, JdliveEndpoints.restrictedNotice);
      expect(room.runtime.danmakuHandle, isNull);
    });
  });

  group('chat protocol', () {
    test('the content is the page JSON in its key order, encrypted', () {
      final nonce = JdliveDanmakuCodec.nonce(Random(7));
      expect(nonce, hasLength(6));
      expect(RegExp(r'^\d{6}$').hasMatch(nonce), isTrue);
      final content = JdliveDanmakuCodec.content(_liveId, now: _at, nonce: '123456');
      expect(
        content,
        _json({
          'appId': 'jd.mall',
          'secretKey': 'RYm2dMPMWD9AxYFk',
          'groupId': _liveId,
          'clientType': 'm',
          'timestamp': _at.millisecondsSinceEpoch,
          'origin': -100,
          'encryptPin': true,
          'random': '123456',
        }),
      );
      // The page's key order, checked byte for byte.
      expect(
        content.indexOf('"appId"') < content.indexOf('"secretKey"') &&
            content.indexOf('"secretKey"') < content.indexOf('"groupId"'),
        isTrue,
      );
      final encrypted = JdliveDanmakuCodec.encrypt(content);
      final plain = utf8.decode(
        Aes128Cbc.decrypt(
          base64.decode(encrypted),
          key: utf8.encode(JdliveDanmakuCodec.secretKey),
          iv: utf8.encode(JdliveDanmakuCodec.iv),
        ),
      );
      expect(plain, content, reason: 'the page decrypts what it encrypted');
    });

    test('the liveauth form names the app and the group', () {
      final fields = JdliveDanmakuCodec.authFields(_liveId, now: _at, nonce: '654321');
      expect(fields['loginType'], '2');
      expect(fields['appid'], 'h5-live');
      expect(fields['functionId'], 'liveauth');
      expect(fields['t'], '${_at.millisecondsSinceEpoch}');
      final body = jsonDecode(fields['body']!) as Map;
      expect(body['appId'], 'jd.mall');
      expect(JdliveDanmakuCodec.endpoint(_liveId).queryParameters['groupId'], _liveId);
      expect(JdliveDanmakuCodec.liveIdOf(JdliveDanmakuCodec.endpoint(_liveId)), _liveId);
      expect(JdliveDanmakuCodec.liveIdOf(Uri.parse('https://api.m.jd.com/api?functionId=other')), isNull);
    });

    test('the credentials of a liveauth answer', () {
      final auth = JdliveDanmakuCodec.auth(_liveauthFixture(mask: 'mask'));
      expect(auth.socketUrl.toString(), 'wss://chat.jd.com/mall?token=tok');
      expect(auth.maskKey, 'mask');
      expect(JdliveDanmakuCodec.auth(_liveauthFixture()).maskKey, isNull);
      expect(
        () => JdliveDanmakuCodec.auth(_liveauthFixture(code: 1)),
        throwsA(predicate((e) => '$e'.contains('refused') && '$e'.contains('解密失败'))),
      );
      for (final bad in [
        _liveauthFixture(host: 'ws://chat.jd.com/mall'),
        _liveauthFixture(host: 'wss://evil.com/mall'),
        _liveauthFixture(host: 'wss://chat.jd.com/mall?a=1'),
        _liveauthFixture(token: 'a b'),
        _liveauthFixture(token: ''),
      ]) {
        expect(() => JdliveDanmakuCodec.auth(bad), throwsA(predicate((e) => '$e'.contains('no socket'))), reason: bad);
      }
      expect(
        () => JdliveDanmakuCodec.auth('nope', status: 500),
        throwsA(predicate((e) => e is JdliveFailure && e.kind == JdliveFailureKind.network)),
      );
    });

    test('a frame is read by its type and group', () {
      JdliveDanmakuFrame frame(String text) => JdliveDanmakuCodec.decode(text, liveId: _liveId);
      final stats = frame(_statsFrame());
      expect(stats.messages, hasLength(2));
      expect(stats.messages.first.type, LiveMessageType.audienceUpdate);
      expect(
        stats.messages.first.payload,
        const LiveAudienceUpdate(kind: LiveAudienceSignalKind.onlineViewers, value: 42),
      );
      expect(
        stats.messages.last.payload,
        const LiveAudienceUpdate(kind: LiveAudienceSignalKind.totalViewers, value: 9001),
      );
      expect(
        frame(_statsFrame(current: -1, total: 'junk')).messages,
        isEmpty,
        reason: 'a number that is not a whole count is left out',
      );
      final chat = frame(_chatFrame()).messages.single;
      expect(chat.type, LiveMessageType.chat);
      expect(chat.effectiveSender.userName, '观众甲');
      expect(chat.effectiveSender.userId, 'abcd1234');
      expect(chat.text, '大家好');
      expect(chat.messageId, 'msg-1');
      expect(chat.sentAt, DateTime.fromMillisecondsSinceEpoch(1727611200000));
      final anchor = frame(_chatFrame(type: 'anchor_send_message')).messages.single;
      expect(anchor.effectiveSender.userName, '主播');
      expect(frame(_chatFrame(type: 'like')).messages, isEmpty, reason: 'only chat is shown');
      expect(frame(_chatFrame(content: '  ')).messages, isEmpty);
      expect(frame(_chatFrame(group: '999')).messages, isEmpty, reason: 'another group');
      expect(
        frame(
          _json({
            'type': 'chat_group_message',
            'body': {'type': 'viewer_send_message', 'nickName': '观众甲', 'content': '大家好'},
          }),
        ).messages,
        hasLength(1),
        reason: 'an event without a group is this group',
      );
      expect(frame('not json').messages, isEmpty);
      expect(
        frame(
          _json({
            'type': 'chat_group_message',
            'body': {'type': 'stop_live_broadcast', 'groupid': _liveId},
          }),
        ).ended,
        isTrue,
      );
      expect(JdliveDanmakuCodec.decode(null, liveId: _liveId).messages, isEmpty);
    });

    test('a binary frame is unmasked with the mask key', () {
      const text = '{"type":"chat_group_message","body":{"type":"stop_live_broadcast","groupid":"$_liveId"}}';
      const mask = 'k3y';
      final masked = [
        for (var i = 0; i < text.codeUnits.length; i++) (text.codeUnits[i] ^ mask.codeUnits[i % mask.length]) & 0xFF,
      ];
      expect(
        JdliveDanmakuCodec.decode(masked, liveId: _liveId).ended,
        isFalse,
        reason: 'without the mask the bytes are noise',
      );
      expect(JdliveDanmakuCodec.decode(masked, liveId: _liveId, maskKey: mask).ended, isTrue);
      expect(
        JdliveDanmakuCodec.decode(<int>[0xff, 0xfe, 0xfd], liveId: _liveId).messages,
        isEmpty,
        reason: 'bytes that are no text are dropped',
      );
    });

    test('a failure never names the token', () {
      expect(
        JdliveDanmakuCodec.redact('handshake to wss://chat.jd.com/mall?token=sekret&x=1 failed'),
        'handshake to wss://chat.jd.com/mall?token=…&x=1 failed',
      );
    });
  });

  group('comment session', () {
    test('a session asks liveauth and opens the token socket', () async {
      final chat = await _chat();
      expect(chat.http.sent, hasLength(1));
      final auth = chat.http.sent.single;
      expect(auth.method, 'POST');
      expect(auth.url.host, 'api.m.jd.com');
      expect(auth.form['functionId'], 'liveauth');
      expect(auth.form['appid'], 'h5-live');
      final body = jsonDecode(auth.form['body']!) as Map;
      expect(body['appId'], 'jd.mall');
      expect(chat.connector.endpoints.single.host, 'chat.jd.com');
      expect(chat.connector.endpoints.single.queryParameters['token'], isNotEmpty);
      expect(chat.connector.headers.single['origin'], JdliveEndpoints.webOrigin);
      expect(chat.timers.after.single.delay, JdliveDanmakuCodec.silenceTimeout, reason: 'the silence watchdog');
      await chat.session.dispose();
    });

    test('the frames the socket pushes are reported', () async {
      final chat = await _chat();
      final after = _next(chat.session.events, 3);
      chat.socket.push(_statsFrame());
      chat.socket.push(_chatFrame());
      final seen = await after;
      expect(seen[0].type, LiveMessageType.audienceUpdate);
      expect(seen[1].type, LiveMessageType.audienceUpdate);
      expect(seen[2].type, LiveMessageType.chat);
      expect(seen[2].effectiveSender.userName, '观众甲');
      await chat.session.dispose();
      expect(chat.socket.closed, isTrue);
    });

    test('the end of the broadcast ends the session', () async {
      final chat = await _chat();
      final ended = chat.session.events.listen(null).asFuture<void>();
      chat.socket.push(
        _json({
          'type': 'chat_group_message',
          'body': {'type': 'stop_live_broadcast', 'groupid': _liveId},
        }),
      );
      await ended;
      await _settle();
      expect(chat.socket.closed, isTrue);
      await chat.session.dispose();
    });

    test('a refused or unanswered handshake is retried, until the budget ends', () async {
      final timers = FakeTimers();
      final http = _FakeHttp((request) => _resp(200, _liveauthFixture(code: 1)));
      final session = JdliveDanmakuSession(
        args: const JdliveDanmakuArgs(liveId: _liveId),
        site: JdliveSite(http: JdliveHttp(http), connect: _refuseSocket, now: () => _at),
        timers: timers.timers,
      );
      expect(await session.connect(), isNull, reason: 'the runtime retries a failed first handshake');
      await _settle();
      final seen = <LiveMessage>[];
      final done = session.events.listen(seen.add).asFuture<void>();
      for (var attempt = 0; attempt < JdliveDanmakuCodec.maxReconnects; attempt++) {
        expect(http.sent, hasLength(attempt + 1));
        timers.fire(index: timers.after.length - 1);
        await _settle();
      }
      await done;
      expect(seen.where((message) => message.type == LiveMessageType.system), isNotEmpty);
      await session.dispose();
    });

    test('a socket that closes or goes silent is replaced', () async {
      final chat = await _chat();
      final first = chat.socket;
      await first.ended();
      await _settle();
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      expect(chat.http.sent, hasLength(2), reason: 'a fresh token per handshake');
      expect(identical(chat.connector.latest, first), isFalse);
      expect(chat.connector.latest.closed, isFalse);
      // A silence is answered by the backoff step, and the fresh socket's
      // answered frames reset the budget of replacements.
      for (var attempt = 0; attempt < 3; attempt++) {
        chat.timers.fire(index: chat.timers.after.length - 1);
        await _settle();
        chat.timers.fire(index: chat.timers.after.length - 1);
        await _settle();
        chat.connector.latest.push(_statsFrame());
        await _settle();
      }
      expect(chat.connector.sockets, hasLength(5), reason: 'three replacements on top of the first two');
      expect(chat.connector.latest.closed, isFalse, reason: 'still alive');
      await chat.session.dispose();
      expect(chat.connector.latest.closed, isTrue);
    });

    test('a session closed mid-handshake cancels the request in flight', () async {
      final stopped = <Uri>[];
      Future<LiveResponse> hanging(_Seen request) async {
        await request.cancelToken.whenCancel;
        stopped.add(request.url);
        throw const CancelledFailure();
      }

      final connector = _Connector();
      final timers = FakeTimers();
      final http = _FakeHttp(hanging);
      final session = JdliveDanmakuSession(
        args: const JdliveDanmakuArgs(liveId: _liveId),
        site: JdliveSite(http: JdliveHttp(http), connect: connector.call, now: () => _at),
        timers: timers.timers,
      );
      expect(await session.connect(), isNull);
      await _settle();
      expect(http.sent, hasLength(1));
      await session.dispose();
      expect(stopped, [http.sent.first.url], reason: 'the liveauth in flight was told to stop');
      expect(timers.after, isEmpty, reason: 'nothing is left to retry');
    });

    test('an id that is no broadcast is refused before any request', () async {
      final connector = _Connector();
      final http = _FakeHttp(_ordinary);
      final session = JdliveDanmakuSession(
        args: const JdliveDanmakuArgs(liveId: 'shop'),
        site: JdliveSite(http: JdliveHttp(http), connect: connector.call, now: () => _at),
        timers: FakeTimers().timers,
      );
      final refused = await session.connect();
      expect(refused, isA<LiveSiteNotFound>());
      expect(http.sent, isEmpty);
      expect(connector.endpoints, isEmpty);
    });
  });

  group('adapter wiring', () {
    test('the manifest and the seven capabilities the platform can serve', () async {
      final adapter = _adapter();
      final site = adapter.site;
      expect(site.manifest.id, 'jdlive');
      expect(site.runtimeInfo.status, LiveSiteStatus.ready);
      await site.initialize(
        const LiveSiteContext(platform: LiveTargetPlatform.windows, locale: 'zh-CN', defaultLocale: 'en-US'),
      );
      expect(site.capability<LiveRoomProvider>(), isNotNull);
      expect(site.capability<LiveAreaProvider>(), isNotNull);
      expect(site.capability<LiveDiscoveryProvider>(), isNotNull);
      expect(site.capability<LiveSearchProvider>(), isNotNull);
      expect(site.capability<LivePlaybackProvider>(), isNotNull);
      expect(site.capability<LiveDanmakuProvider>(), isNotNull);
      expect(site.capability<LiveLinkResolver>(), isNotNull);
      await site.dispose();
      final built = createBuiltInLiveSites(http: _FakeHttp((_) => _resp(200, '{}')));
      expect(built.map((entry) => entry.manifest.id), contains('jdlive'));
    });

    test('a room read is the play answer and the playlist check', () async {
      final adapter = _adapter();
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_liveId));
      expect(adapter.http.sent.map((seen) => seen.url.queryParameters['functionId']), [
        'getImmediatePlayToM',
        null,
      ], reason: 'the play answer, then the playlist');
      expect(adapter.http.sent.last.url.host, 'hlive.jdcloud.com');
      expect(adapter.http.sent.last.headers['referer'], 'https://lives.jd.com/#/$_liveId');
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.runtime.danmakuHandle, isA<JdliveDanmakuArgs>());
      expect(_leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRoom('shop')), isA<LiveSiteNotFound>());
      expect(adapter.http.sent, hasLength(2), reason: 'an id that is no broadcast is refused without a request');
    });

    test('a directory page starts the sequence, the next one continues it', () async {
      final adapter = _adapter();
      final rooms = adapter.site.capability<LiveRoomProvider>()!;
      final first = _right(await rooms.getRooms(const LivePageRequest()));
      expect(first.items.map((room) => room.roomId), [_liveId, _otherLiveId]);
      expect(first.hasMore, isTrue);
      final request = adapter.http.sent.single;
      final body = jsonDecode(request.url.queryParameters['body']!) as Map;
      expect(body, {'tabId': 1, 'currentCount': '0', 'page': 1, 'timestamp': _at.millisecondsSinceEpoch});
      final second = _right(await rooms.getRooms(const LivePageRequest(page: 2)));
      final nextQuery = jsonDecode(adapter.http.sent.last.url.queryParameters['body']!) as Map;
      expect(nextQuery['currentCount'], '2');
      expect(nextQuery['timestamp'], _at.millisecondsSinceEpoch, reason: 'the sequence keeps its first page time');
      expect(nextQuery['page'], 2);
      expect(second.items.map((room) => room.roomId), [_thirdLiveId], reason: 'the page the sequence asked for');
      // The sequence moved on, so the broadcasts already listed are left out.
      final continued = _right(await rooms.getRooms(const LivePageRequest(page: 3)));
      expect(continued.items.where((room) => room.roomId == _liveId), isEmpty);
    });

    test('a page that cannot follow is empty without a request', () async {
      final adapter = _adapter();
      final rooms = adapter.site.capability<LiveRoomProvider>()!;
      expect(_right(await rooms.getRooms(const LivePageRequest(page: 2))).items, isEmpty);
      expect(adapter.http.sent, isEmpty, reason: 'no sequence asked for page 2 yet');
      expect(_right(await rooms.getRooms(const LivePageRequest(page: 0))).items, isEmpty);
      expect(adapter.http.sent, isEmpty);
    });

    test('the recommendations and the one area come from their own sequence', () async {
      final adapter = _adapter();
      final discovery = await adapter.site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms(
        request: const LivePageRequest(pageSize: 1),
      );
      expect(_right(discovery).items, hasLength(1), reason: 'cut to the page size asked for');
      final area = await adapter.site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: 'featured');
      expect(_right(area).items.map((room) => room.area?.areaName), everyElement('精选直播购物'));
      expect(
        _leftOf(await adapter.site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: 'dance')),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(adapter.http.sent, hasLength(2), reason: 'the discovery and the area keep separate sequences');
      expect(
        (await adapter.site.capability<LiveAreaProvider>()!.getAreas()).match(
          (left) => throw StateError('$left'),
          (areas) => areas.map((area) => area.areaId).toList(),
        ),
        ['featured'],
      );
    });

    test('a search finds the exact broadcast, or filters the list', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      final exact = await search.search(
        const LiveSearchRequest(query: 'https://lives.jd.com/#/$_liveId', target: LiveSearchTarget.rooms),
      );
      expect(_right(exact).items.single.runtimeType, RoomSearchResult);
      expect((_right(exact).items.single as RoomSearchResult).room.roomId, _liveId);
      expect(_right(exact).hasMore, isNull, reason: 'an exact hit says nothing about pages');
      expect(adapter.http.sent, hasLength(1), reason: 'an exact hit takes the play answer alone');
      final byName = await search.search(const LiveSearchRequest(query: '厨房小电', target: LiveSearchTarget.rooms));
      expect(_right(byName).items.single.runtimeType, RoomSearchResult);
      expect((_right(byName).items.single as RoomSearchResult).room.content.title, '厨房小电');
      expect(_right(byName).items, hasLength(1));
      final filtered = _right(byName);
      expect(filtered.hasMore, isNotNull);
      expect(
        _right(await search.search(const LiveSearchRequest(query: 'no such shop', target: LiveSearchTarget.rooms)))
            .items,
        isEmpty,
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: '', target: LiveSearchTarget.rooms))).items,
        isEmpty,
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.rooms, pageSize: 101)))
            .items,
        isEmpty,
      );
      expect(
        _right(
          await search.search(const LiveSearchRequest(query: 'https://bigo.tv/abc', target: LiveSearchTarget.rooms)),
        ).items,
        isEmpty,
        reason: 'a link of another site is no result',
      );
      final firstPage = await search.search(const LiveSearchRequest(query: '专场', target: LiveSearchTarget.rooms));
      expect(_right(firstPage).items, isEmpty, reason: 'page 1 of the sequence has no such title');
      final again = await search.search(const LiveSearchRequest(query: '专场', target: LiveSearchTarget.rooms, page: 2));
      expect(adapter.http.sent.last.url.queryParameters['functionId'], 'liveListWithTabToM');
      final query = jsonDecode(adapter.http.sent.last.url.queryParameters['body']!) as Map;
      expect(query['page'], 2, reason: 'the keyword keeps its own sequence');
      expect(_right(again).items, hasLength(1));
      expect((_right(again).items.single as RoomSearchResult).room.content.title, '新上架专场');
    });

    test('a play answer is completed from the card the list showed', () async {
      final adapter = _adapter();
      await adapter.site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms();
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_liveId));
      expect(room.content.title, '国庆大促直播', reason: 'the play answer has no title; the card had one');
      expect(room.anchor?.name, '京东自营旗舰店');
      expect(room.content.coverUrl, 'https://img.360buyimg.com/cover.png');
      expect(room.audience.totalViewers, 12345);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.totalViewers);
      expect(room.content.notice, JdliveEndpoints.chatNotice);
    });

    test('the qualities and lines come from the room read, without a request', () async {
      final adapter = _adapter();
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      await adapter.site.capability<LiveRoomProvider>()!.getRoom(_liveId);
      final before = adapter.http.sent.length;
      final qualities = _right(await playback.getQualities(roomId: _liveId));
      expect(qualities.map((quality) => quality.qualityId), ['hls', 'flv']);
      expect(adapter.http.sent.length, before, reason: 'the play answer is already kept');
      final lines = _right(await playback.getLines(roomId: _liveId));
      expect(lines.single.url, 'https://hlive.jdcloud.com/live/48378944.m3u8');
      expect(
        _right(await playback.getLines(roomId: _liveId, quality: qualities.last)).single.format,
        LiveStreamFormat.flv,
      );
      expect(
        _leftOf(
          await playback.getLines(
            roomId: _liveId,
            quality: const LivePlayQuality(label: 'x', qualityId: 'x'),
          ),
        ),
        isA<LiveSiteInvalidArgument>(),
      );
    });

    test('playback without a room read takes the play answer itself', () async {
      final adapter = _adapter();
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final qualities = _right(await playback.getQualities(roomId: _liveId));
      expect(qualities, hasLength(2));
      expect(adapter.http.sent.map((seen) => seen.url.queryParameters['functionId'] ?? seen.url.path), [
        'getImmediatePlayToM',
        '/live/48378944.m3u8',
      ]);
    });

    test('a broadcast that cannot be played says why', () async {
      final adapter = _adapter(
        onSend: (request) => request.url.queryParameters['functionId'] == 'getImmediatePlayToM'
            ? _resp(200, _envelope(_playData(status: 0, h5: '', video: '')))
            : _resp(200, _playlist(request.url)),
      );
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      expect(_leftOf(await playback.getQualities(roomId: _liveId)), isA<LiveSiteContentUnavailable>());
      final secret = _adapter(onSend: (request) => _resp(200, _envelope(_playData(secret: 1))));
      expect(
        _leftOf(await secret.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _liveId)),
        isA<LiveSiteContentUnavailable>(),
      );
      expect(
        '${_leftOf(await secret.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _liveId))}',
        contains('app only'),
      );
    });

    test('a link is canonicalized, an alien host is unsupported', () async {
      final adapter = _adapter();
      final link = adapter.site.capability<LiveLinkResolver>()!;
      expect(
        _right(await link.resolve(Uri.parse('https://lives.jd.com/#/$_liveId/replay?origin=0'))),
        Uri.parse('https://lives.jd.com/#/$_liveId'),
      );
      expect(_leftOf(await link.resolve(Uri.parse('https://example.com/#/$_liveId'))), isA<LiveSiteUnsupported>());
      expect(_leftOf(await link.resolve(Uri.parse('https://lives.jd.com/shop'))), isA<LiveSiteNotFound>());
      expect(adapter.http.sent, isEmpty, reason: 'the routing is in the fragment');
    });

    test('a status the gate refuses is mapped', () async {
      final adapter = _adapter(onSend: (_) => _resp(401, 'nope'));
      expect(
        _leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_liveId)),
        isA<LiveSiteRateLimitError>(),
      );
      final gone = _adapter(onSend: (request) => _resp(200, _envelope({}, subCode: 5)));
      expect(_leftOf(await gone.site.capability<LiveRoomProvider>()!.getRoom(_liveId)), isA<LiveSiteNotFound>());
    });

    test('the chat provider builds a session only for a chat that opens', () async {
      final opened = _Connector();
      final adapter = _adapter(
        connect: opened.call,
        onSend: (request) => request.url.queryParameters['functionId'] == 'liveauth'
            ? _resp(200, _liveauthFixture())
            : _ordinary(request),
      );
      final danmaku = adapter.site.capability<LiveDanmakuProvider>()!;
      final session = _right(await danmaku.createSession(roomId: _liveId));
      expect(session, isA<JdliveDanmakuSession>());
      await session.dispose();
      final offline = _adapter(
        connect: opened.call,
        onSend: (request) => _resp(200, _envelope(_playData(status: 2, h5: '', video: ''))),
      );
      expect(
        _leftOf(await offline.site.capability<LiveDanmakuProvider>()!.createSession(roomId: _liveId)),
        isA<LiveSiteContentUnavailable>(),
      );
    });
  });
}

/// The site over a fake transport, with a fixed clock and no socket.
({JdliveSite site, _FakeHttp http}) _adapter({
  LiveResponse Function(_Seen request)? onSend,
  Future<SocketChannel> Function(
    Uri, {
    required Map<String, String> headers,
    required Iterable<String>? protocols,
    required Duration connectTimeout,
    Duration? pingInterval,
  })?
  connect,
}) {
  final http = _FakeHttp(onSend ?? _ordinary);
  return (site: JdliveSite(http: JdliveHttp(http), connect: connect ?? _refuseSocket, now: () => _at), http: http);
}
