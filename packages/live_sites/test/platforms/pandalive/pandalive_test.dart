import 'dart:async';
import 'dart:convert';
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
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_gift_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_endpoints.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_http.dart';
import 'package:live_sites/src/platforms/pandalive/danmaku/pandalive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/pandalive/danmaku/pandalive_danmaku_session.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_site.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_failure.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_json.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_link.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

// The fakes and fixtures mirror the platform files' plain constructor names.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The clock of the tests: 2026-09-30, in the afternoon.
final DateTime _at = DateTime.parse('2026-09-30T14:00:00.000Z').toUtc();

const String _userId = 'daisy00';
const String _otherUserId = 'hong1029';
const String _liveRoomId = 'live0042';
const int _userIndex = 12345;
const String _channel = '$_userIndex';
const String _img = 'https://img.pandalive.co.kr';

/// The chat token room entry brings: a JWT lapsing half an hour after [_at].
final String _token = _jwt(_at.millisecondsSinceEpoch ~/ 1000 + 1800);

final Uri _masterUrl = Uri.parse('https://abcdef.live-video.net/hls/master.m3u8?token=one');

const String _masterPlaylist = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=5500000,RESOLUTION=1920x1080,FRAME-RATE=60.000,CODECS="avc1.64002A,mp4a.40.2",VIDEO="chunked"
https://abcdef.live-video.net/hls/1.m3u8?token=one
#EXT-X-STREAM-INF:BANDWIDTH=2200000,RESOLUTION=1280x720,FRAME-RATE=59.940,CODECS="avc1.64001F,mp4a.40.2",VIDEO="v720"
https://abcdef.live-video.net/hls/2.m3u8?token=one
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360,FRAME-RATE=29.970,CODECS="avc1.42001E,mp4a.40.2",VIDEO="v360"
https://abcdef.live-video.net/hls/3.m3u8?token=one
#EXT-X-STREAM-INF:BANDWIDTH=60000,CODECS="mp4a.40.2"
https://abcdef.live-video.net/hls/audio.m3u8?token=one
''';

String _json(Object? data) => jsonEncode(data);

String _jwt(int expiresAt) {
  String part(Map<String, Object?> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return "${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'exp': expiresAt})}.signature";
}

Map<String, dynamic> _media({
  String id = _userId,
  int index = _userIndex,
  Object? isLive = 'Y',
  String type = 'free',
  Object? onAirType = 'live',
}) => {
  'userId': id,
  'userIdx': index,
  'isLive': isLive,
  'title': '심야 방송',
  'thumbUrl': '$_img/c.png',
  'ivsThumbnail': '$_img/ivs.png',
  'category': 'talk',
  'user': 42,
  'playCnt': 900,
  'fanCnt': 100,
  'startTime': '2026-09-28 02:00:35',
  'type': type,
  'onAirType': onAirType,
};

String _memberFixture({bool withMedia = true, Map<String, dynamic>? media}) => _json({
  'result': true,
  'bjInfo': {
    'id': _userId,
    'idx': _userIndex,
    'nick': '데이지',
    'thumbUrl': '$_img/a.png',
    'channelTitle': '채널 제목',
    'channelDesc': '채널 소개',
    'channelBannerUrl': '$_img/b.png',
    'fanCnt': 100,
  },
  if (withMedia) 'media': media ?? _media(),
});

String _notFoundFixture() => _json({'result': false, 'message': '유저 정보가 없습니다'});

String _playFixture({
  bool? result,
  String? code,
  Object? isLive = 'Y',
  bool withMaster = true,
  Object? token = 'jwt-chat-token',
}) => _json({
  'result': result ?? true,
  if (code != null) 'errorData': {'code': code},
  if (result ?? true) 'media': _media(isLive: isLive),
  if ((result ?? true) && withMaster)
    'PlayList': {
      'hls3': [
        {'url': '$_masterUrl'},
      ],
    },
  if (result ?? true) 'channel': _channel,
  if ((result ?? true) && token != null) 'token': token,
});

Map<String, Object?> _liveRow({String id = _userId, String nick = '데이지', Object? isLive = 'Y'}) => {
  'userId': id,
  'userNick': nick,
  'isLive': isLive,
  'title': '심야 방송',
  'thumbUrl': '$_img/c.png',
  'userImg': '$_img/a.png',
  'category': 'talk',
  'user': 42,
  'playCnt': 900,
  'fanCnt': 100,
  'startTime': '2026-09-28 02:00:35',
  'type': 'free',
  'onAirType': 'live',
};

Map<String, Object?> _broadcasterRow({String id = _otherUserId, Map<String, dynamic>? media, Object? blocked}) => {
  'userId': id,
  'userIdx': 67890,
  'userNick': '홍길동',
  'thumbUrl': '$_img/d.png',
  'blockService': ?blocked,
  'media': media,
};

String _pageFixture({required int page, required int size, List<Map<String, Object?>>? rows}) => _json({
  'result': true,
  'page': {'offset': (page - 1) * size, 'limit': size, 'page': page, 'total': rows?.length ?? 0},
  'list': rows ?? const [],
});

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(body)));

final class _Seen {
  _Seen(LiveRequest request) : url = request.url, body = request.body;
  final Uri url;
  final String? body;
}

Map<String, String> _formOf(_Seen seen) => Uri.splitQueryString(seen.body ?? '');

int _pageOf(_Seen seen) {
  final form = _formOf(seen);
  final offset = int.parse(form['offset'] ?? '0');
  final limit = int.parse(form['limit'] ?? '30');
  return offset ~/ limit + 1;
}

final class _FakeHttp implements LiveHttp {
  _FakeHttp(this.onSend);
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

/// The answers of the site: the member, the play grant, the master, the
/// directory and the two searches. A `member/bj` of another broadcaster is
/// refused as the platform does.
LiveResponse _ordinary(_Seen seen) {
  final path = seen.url.path;
  if (seen.url.host.endsWith('.live-video.net')) return _resp(200, _masterPlaylist);
  switch (path) {
    case '/v1/member/bj':
      return _formOf(seen)['userId'] == _userId ? _resp(200, _memberFixture()) : _resp(400, _notFoundFixture());
    case '/v1/live/play':
      return _resp(200, _playFixture());
    case '/v1/live/index':
      final size = int.parse(_formOf(seen)['limit'] ?? '30');
      final rows = _formOf(seen).containsKey('searchVal') ? [_liveRow(id: _liveRoomId, nick: '라이브방송')] : [_liveRow()];
      return _resp(200, _pageFixture(page: _pageOf(seen), size: size, rows: rows));
    case '/v1/live/bj_list':
      final size = int.parse(_formOf(seen)['limit'] ?? '30');
      return _resp(200, _pageFixture(page: _pageOf(seen), size: size, rows: [_broadcasterRow()]));
  }
  return _resp(404, 'nope');
}

/// A connector that refuses: a test that needs a socket replaces it.
Future<SocketChannel> _refuseSocket(
  Uri endpoint, {
  required Map<String, String> headers,
  required Iterable<String>? protocols,
  required Duration connectTimeout,
  Duration? pingInterval,
}) async => throw StateError('no socket was asked for in this test');

/// A connector whose handshakes always fail.
Future<SocketChannel> _brokenSocket(
  Uri endpoint, {
  required Map<String, String> headers,
  required Iterable<String>? protocols,
  required Duration connectTimeout,
  Duration? pingInterval,
}) async => throw StateError('down');

/// The socket a test drives by hand.
final class _FakeSocket implements SocketChannel {
  final StreamController<Object?> _stream = StreamController<Object?>();
  final List<Object?> sentList = [];
  bool closed = false;

  @override
  Stream<Object?> get stream => _stream.stream;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  void add(Object data) => sentList.add(data);

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
  }

  void push(Object? frame) => _stream.add(frame);
  Future<void> ended() => _stream.close();
  String get sentText => sentList.whereType<String>().join('\n');
}

final class _Connector {
  final List<_FakeSocket> sockets = [];
  final List<Uri> endpoints = [];

  _FakeSocket get latest => sockets.last;

  Future<SocketChannel> call(
    Uri endpoint, {
    required Map<String, String> headers,
    required Iterable<String>? protocols,
    required Duration connectTimeout,
    Duration? pingInterval,
  }) async {
    endpoints.add(endpoint);
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

final class FakeTimers {
  final List<({Duration delay, void Function() callback})> after = [];
  final List<({Duration period, void Function(Timer timer) callback})> every = [];

  PandaliveTimers get timers => (after: _after, every: _every);

  Timer _after(Duration delay, void Function() callback) {
    after.add((delay: delay, callback: callback));
    return _IdleTimer();
  }

  Timer _every(Duration period, void Function(Timer timer) callback) {
    every.add((period: period, callback: callback));
    return _IdleTimer();
  }

  void fire(Duration delay) {
    final watch = after.lastWhere((wait) => wait.delay == delay, orElse: () => throw StateError('no $delay'));
    watch.callback();
  }

  void ringLast() => every.last.callback(_IdleTimer());
}

/// A clock a test can move forward (the variants' lease).
final class _Clock {
  _Clock(this.at);
  DateTime at;
  DateTime call() => at;
}

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

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

Future<void> _settle() => Future<void>.delayed(Duration.zero);

({PandaliveSite site, _FakeHttp http, _Clock clock}) _adapter({
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
  final clock = _Clock(_at);
  return (
    site: PandaliveSite(http: PandaliveHttp(http), connect: connect ?? _refuseSocket, now: clock.call),
    http: http,
    clock: clock,
  );
}

/// A chat session on a fresh socket, with the entry's token.
Future<({PandaliveDanmakuSession session, _FakeSocket socket, FakeTimers timers, _Connector connector, _FakeHttp http})>
_chat({PandaliveDanmakuArgs? args, LiveResponse Function(_Seen request)? onSend}) async {
  final connector = _Connector();
  final timers = FakeTimers();
  final http = _FakeHttp(onSend ?? _ordinary);
  final site = PandaliveSite(http: PandaliveHttp(http), connect: connector.call, now: () => _at);
  final session = PandaliveDanmakuSession(
    args: args ?? PandaliveDanmakuArgs(userId: _userId, channel: _channel, token: _token),
    site: site,
    timers: timers.timers,
    now: () => _at,
  );
  expect(await session.connect(), isNull);
  await _settle();
  return (session: session, socket: connector.latest, timers: timers, connector: connector, http: http);
}

/// A publication push of [message] on the channel.
String _publication(Map<String, Object?> message, {Object? offset = 7, String channel = _channel}) => _json({
  'result': {
    'channel': channel,
    'data': {'data': message, 'offset': offset},
  },
});

void main() {
  group('answers and readers', () {
    test('a status says what kind of answer it is', () {
      void expectKind(int status, PandaliveFailureKind kind) {
        try {
          PandaliveJson.checkStatus(status, 'x');
          fail('no throw for $status');
        } on PandaliveFailure catch (failure) {
          expect(failure.kind, kind);
        }
      }

      expectKind(401, PandaliveFailureKind.riskControl);
      expectKind(403, PandaliveFailureKind.riskControl);
      expectKind(404, PandaliveFailureKind.notFound);
      expectKind(429, PandaliveFailureKind.rateLimited);
      for (final status in [301, 500, 503]) {
        expectKind(status, PandaliveFailureKind.network);
      }
      PandaliveJson.checkStatus(200, 'x');
      PandaliveJson.checkStatus(400, 'x');
    });

    test('an envelope must carry a boolean result, a refusal says why', () {
      expect(
        () => PandaliveRoomParser.answer(_json({'message': 'ok'}), what: 'x'),
        throwsA(predicate((e) => '$e'.contains('no result flag'))),
      );
      expect(() => PandaliveRoomParser.ok(_json({'result': 1}), what: 'x'), throwsA(isA<PandaliveFailure>()));
      expect(
        () => PandaliveRoomParser.ok(_json({'result': false, 'message': '유저 정보가 없습니다'}), what: 'member/bj'),
        throwsA(predicate((e) => e is PandaliveFailure && e.kind == PandaliveFailureKind.notFound)),
      );
      expect(
        () => PandaliveRoomParser.ok(
          _json({
            'result': false,
            'message': '방송종료',
            'errorData': {'code': 'castEnd'},
          }),
          what: 'x',
        ),
        throwsA(predicate((e) => e is PandaliveFailure && e.kind == PandaliveFailureKind.streamUnavailable)),
      );
      expect(
        () => PandaliveRoomParser.ok(_json({'result': false, 'message': 'why'}), what: 'x'),
        throwsA(predicate((e) => e is PandaliveFailure && e.kind == PandaliveFailureKind.apiChanged)),
      );
      expect(
        PandaliveRoomParser.refusalCode({
          'result': false,
          'errorData': {'code': 'needLogin'},
        }),
        'needLogin',
      );
    });

    test('times, flags, ids and images are read strictly', () {
      expect(PandaliveJson.koreanTime('2026-09-28 02:00:35'), DateTime.utc(2026, 9, 27, 17, 0, 35));
      expect(PandaliveJson.koreanTime('0000-00-00 00:00:00'), isNull);
      expect(PandaliveJson.koreanTime('1999-12-31 00:00:00'), isNull);
      expect(PandaliveJson.flag('Y'), isTrue);
      expect(PandaliveJson.flag(0), isFalse);
      expect(PandaliveJson.flag('maybe'), isNull);
      expect(PandaliveEndpoints.normalizeUserId(' $_userId '), _userId);
      expect(PandaliveEndpoints.normalizeUserId('1506087545@ka'), '1506087545@ka');
      expect(PandaliveEndpoints.normalizeUserId('bad id!'), isNull);
      expect(PandaliveJson.image('$_img/a.png'), '$_img/a.png');
      for (final bad in ['http://$_img/a.png', 'https://evil.com/a.png', 'https://pandalive.co.kr/a.png']) {
        expect(PandaliveJson.image(bad), '', reason: bad);
      }
      expect(PandaliveEndpoints.areaNameOf('TALK'), '聊天');
      expect(PandaliveEndpoints.areaNameOf('novel'), 'novel');
    });

    test('only transient failures are worth a retry', () {
      expect(const PandaliveFailure(PandaliveFailureKind.network, 'x').isTransient, isTrue);
      expect(const PandaliveFailure(PandaliveFailureKind.rateLimited, 'x').isTransient, isTrue);
      expect(const PandaliveFailure(PandaliveFailureKind.notFound, 'x').isTransient, isFalse);
      expect(const PandaliveFailure(PandaliveFailureKind.streamUnavailable, 'x').isTransient, isFalse);
      expect(
        const PandaliveFailure(PandaliveFailureKind.riskControl, 'x').toLiveSiteError('pandalive'),
        isA<LiveSiteRateLimitError>(),
        reason: 'a session refusal folds into rate limit at the boundary',
      );
    });
  });

  group('links', () {
    test('the live and channel pages of a broadcaster', () {
      expect(PandaliveLink.roomIdFromUrl('https://www.pandalive.co.kr/play/$_userId'), _userId);
      expect(PandaliveLink.roomIdFromUrl('https://pandalive.co.kr/live/play/$_userId'), _userId);
      expect(PandaliveLink.roomIdFromUrl('https://m.pandalive.co.kr/channel/$_userId'), _userId);
      expect(PandaliveLink.roomIdFromUrl('https://www.pandalive.co.kr/channel/$_userId/home'), _userId);
      expect(PandaliveLink.roomIdFromUrl(PandaliveEndpoints.roomUrl(_userId)), _userId);
    });

    test('anything else is no link', () {
      for (final bad in [
        'https://evil.com/play/$_userId',
        'https://www.pandalive.co.kr:8080/play/$_userId',
        'https://www.pandalive.co.kr/play/$_userId#x',
        'https://u:pandalive.co.kr/www/play/$_userId',
        'https://www.pandalive.co.kr/play/has space',
        ' ${PandaliveEndpoints.roomUrl(_userId)} ',
        'https://www.pandalive.co.kr/play/',
        'https://www.pandalive.co.kr/live',
        'ftp://www.pandalive.co.kr/play/$_userId',
      ]) {
        expect(PandaliveLink.roomIdFromUrl(bad), isNull, reason: bad);
      }
    });
  });

  group('cards and pages', () {
    test('a live card carries the broadcast and its category', () {
      final card = PandaliveRoomParser.liveCard(_liveRow())!;
      expect(card.roomId, _userId);
      expect(card.content.title, '심야 방송');
      expect(card.content.coverUrl, '$_img/c.png');
      expect(card.anchor?.name, '데이지');
      expect(card.anchor?.avatarUrl, '$_img/a.png');
      expect(card.anchor?.followerCount, 100);
      expect(card.area?.areaId, 'talk');
      expect(card.area?.areaName, '聊天');
      expect(card.audience.onlineViewers, 42);
      expect(card.audience.totalViewers, 900);
      expect(card.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(card.broadcast.liveStatus, LiveStatus.live);
      expect(card.broadcast.startedAt, DateTime.utc(2026, 9, 27, 17, 0, 35));
      expect(card.broadcast.restriction, LiveRestriction.none);
      expect(card.content.notice, PandaliveEndpoints.chatNotice);
      expect(card.links.webUrl, PandaliveEndpoints.roomUrl(_userId));
      expect(
        PandaliveRoomParser.liveCard(_liveRow(isLive: 'N')),
        isNull,
        reason: 'a row that is not on air is no card',
      );
    });

    test('a rerun plays like a live broadcast, marked as a replay', () {
      final rerun = PandaliveRoomParser.liveCard(_liveRow()..['onAirType'] = 'rec')!;
      expect(rerun.broadcast.liveStatus, LiveStatus.replay);
    });

    test('a broadcaster row is a room live or not', () {
      final offline = PandaliveRoomParser.profileCard(_broadcasterRow())!;
      expect(offline.roomId, _otherUserId);
      expect(offline.broadcast.liveStatus, LiveStatus.offline);
      expect(offline.content.title, '홍길동', reason: 'an offline broadcaster is titled by the nick');
      final live = PandaliveRoomParser.profileCard(_broadcasterRow(media: _media(id: _otherUserId, index: 67890)))!;
      expect(live.broadcast.liveStatus, LiveStatus.live);
      expect(live.audience.onlineViewers, 42);
      expect(
        PandaliveRoomParser.profileCard(
          _broadcasterRow(
            media: _media(id: _otherUserId, index: 67890, isLive: 'N'),
          ),
        )!.broadcast.liveStatus,
        LiveStatus.offline,
      );
      expect(
        PandaliveRoomParser.profileCard(_broadcasterRow(media: _media(id: _otherUserId, index: 67890, isLive: null)))!
            .broadcast
            .liveStatus,
        LiveStatus.unknown,
      );
      for (final bad in [
        _broadcasterRow(blocked: true),
        _broadcasterRow(media: _media(index: 1)),
        _broadcasterRow(id: 'no such!'),
      ]) {
        expect(PandaliveRoomParser.profileCard(bad), isNull, reason: '$bad');
      }
    });

    test('a page echoes itself and deduplicates its live rows', () {
      final page = PandaliveRoomParser.livePage(
        _pageFixture(
          page: 2,
          size: 30,
          rows: [
            _liveRow(),
            _liveRow(id: _otherUserId),
            _liveRow(isLive: 'N'),
          ],
        ),
        page: 2,
      );
      expect(page.rooms.map((room) => room.roomId), [_userId, _otherUserId], reason: 'a broadcaster once');
      expect(page.hasMore, isFalse, reason: 'two rows against a total of two');
      for (final bad in [
        (_pageFixture(page: 2, size: 30, rows: [_liveRow()]), 1, 30),
        (_pageFixture(page: 1, size: 20, rows: [_liveRow()]), 1, 30),
      ]) {
        expect(
          () => PandaliveRoomParser.livePage(bad.$1, page: bad.$2, size: bad.$3),
          throwsA(predicate((e) => '$e'.contains('page'))),
        );
      }
      expect(
        () => PandaliveRoomParser.livePage(_pageFixture(page: 1, size: 30, rows: List.filled(65, _liveRow())), page: 1),
        throwsA(predicate((e) => '$e'.contains('list'))),
      );
    });

    test('a broadcaster page keeps whole rows and skips broken ones', () {
      final page = PandaliveRoomParser.broadcasterPage(
        _pageFixture(page: 1, size: 30, rows: [_broadcasterRow(), _broadcasterRow(blocked: true)]),
        page: 1,
        size: 30,
      );
      expect(page.rooms, hasLength(1));
      expect(page.rooms.single.roomId, _otherUserId);
    });
  });

  group('member and play', () {
    test('the member answer names its broadcaster and its broadcast', () {
      final member = PandaliveRoomParser.member(_memberFixture(), userId: _userId);
      expect(member.userId, _userId);
      expect(member.userIndex, _userIndex);
      expect(member.profile['nick'], '데이지');
      expect(member.media, isNotNull);
      expect(PandaliveRoomParser.listedLive(member), isTrue);
      expect(
        PandaliveRoomParser.listedLive(PandaliveRoomParser.member(_memberFixture(withMedia: false), userId: _userId)),
        isFalse,
      );
      expect(
        () => PandaliveRoomParser.member(_memberFixture(media: _media(index: 1)), userId: _userId),
        throwsA(predicate((e) => '$e'.contains('media of'))),
      );
      expect(
        () => PandaliveRoomParser.member(_resp(400, _notFoundFixture()).text, userId: _userId, status: 400),
        throwsA(predicate((e) => e is PandaliveFailure && e.kind == PandaliveFailureKind.notFound)),
      );
    });

    test('the play answer carries the master and the chat grant', () {
      final member = PandaliveRoomParser.member(_memberFixture(), userId: _userId);
      final play = PandaliveRoomParser.play(_playFixture(), member: member);
      expect(play.isLive, isTrue);
      expect(play.master, _masterUrl);
      expect(play.chatChannel, _channel);
      expect(play.chatToken, 'jwt-chat-token');
      expect(PandaliveRoomParser.chatGrantOf(member, play), (channel: _channel, token: 'jwt-chat-token'));
      expect(
        () => PandaliveRoomParser.play(_playFixture(), member: member, status: 401),
        throwsA(predicate((e) => e is PandaliveFailure && e.kind == PandaliveFailureKind.riskControl)),
      );
      final refused = PandaliveRoomParser.play(
        _resp(
          400,
          _json({
            'result': false,
            'message': '성인',
            'errorData': {'code': 'needAdult'},
          }),
        ).text,
        member: member,
        status: 400,
      );
      expect(refused.code, 'needAdult');
      expect(refused.isLive, isFalse);
      expect(PandaliveRoomParser.chatGrantOf(member, refused), isNull);
    });

    test('the master comes from hls3, else hls2, else hls, else none', () {
      Map<String, dynamic> playlist(Map<String, Object?> value) => Map<String, dynamic>.from(value);
      Uri? masterOf(Map<String, Object?> value) => PandaliveRoomParser.masterUrl(playlist(value));
      expect(
        masterOf({
          'hls3': [
            {'url': '$_masterUrl'},
          ],
        }),
        _masterUrl,
      );
      expect(
        masterOf({
          'hls2': [
            {'url': '$_masterUrl'},
          ],
          'hls3': [
            {'nope': true},
          ],
        }),
        _masterUrl,
      );
      expect(masterOf({'hls': []}), isNull, reason: 'no master at all stays null');
      expect(
        () => masterOf({
          'hls3': [
            {'url': 'https://evil.com/a.m3u8'},
          ],
        }),
        throwsA(predicate((e) => '$e'.contains('not an IVS playlist'))),
      );
    });

    test('a playlist URL must be an IVS https m3u8', () {
      expect(PandaliveRoomParser.mediaUrl('$_masterUrl'), _masterUrl);
      for (final bad in [
        'http://abcdef.live-video.net/hls/master.m3u8',
        'https://evil.com/hls/master.m3u8',
        'https://abcdef.live-video.net/hls/master.mp4',
        'https://user@abcdef.live-video.net/hls/master.m3u8',
        'https://abcdef.live-video.net/hls/master.m3u8#frag',
      ]) {
        expect(PandaliveRoomParser.mediaUrl(bad), isNull, reason: bad);
      }
    });
  });

  group('room entry rules', () {
    final member = PandaliveRoomParser.member(_memberFixture(), userId: _userId);

    test('an ended broadcast is its profile room, offline', () {
      final (:room, :unavailable) = PandaliveRoomParser.playRoom(member, const PandalivePlay.refused('castEnd'));
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.content.title, '채널 제목', reason: 'an offline room is titled by the channel');
      expect(unavailable, isA<PandaliveFailure>());
      expect('$unavailable', contains('castEnd'));
    });

    test('a refused broadcast is entered with its restriction', () {
      final (:room, :unavailable) = PandaliveRoomParser.playRoom(member, const PandalivePlay.refused('needPassword'));
      expect(room.broadcast.restriction, LiveRestriction.password);
      expect(room.content.notice, PandaliveEndpoints.passwordNotice);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect('$unavailable', contains('needPassword'));
      final adult = PandaliveRoomParser.playRoom(member, const PandalivePlay.refused('needAdult'));
      expect(adult.room.broadcast.restriction, LiveRestriction.adult);
      final anonymous = PandaliveRoomParser.playRoom(member, const PandalivePlay.refused('needLogin'));
      expect(
        anonymous.room.broadcast.restriction,
        LiveRestriction.needsLogin,
        reason: 'a free broadcast refused needLogin wants a login',
      );
      expect(anonymous.room.content.notice, PandaliveEndpoints.restrictedNotice);
    });

    test('an accepted broadcast that is not live is the profile room', () {
      final play = PandalivePlay.accepted(media: Map<String, dynamic>.from(_media(isLive: 'N')));
      final (:room, :unavailable) = PandaliveRoomParser.playRoom(member, play);
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect('$unavailable', contains('not live'));
    });

    test('a live broadcast without a master is unplayable', () {
      final play = PandalivePlay.accepted(media: Map<String, dynamic>.from(_media()));
      final (:room, :unavailable) = PandaliveRoomParser.playRoom(member, play);
      expect(room.broadcast.restriction, LiveRestriction.unplayable);
      expect('$unavailable', contains('no HLS'));
    });

    test('a live broadcast with a master is entered without restriction', () {
      final play = PandalivePlay.accepted(
        media: Map<String, dynamic>.from(_media()),
        master: _masterUrl,
        chatChannel: _channel,
        chatToken: 'jwt-chat-token',
      );
      final (:room, :unavailable) = PandaliveRoomParser.playRoom(member, play);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(unavailable, isNull);
    });
  });

  group('streams', () {
    test('the variants of the master, the source first', () {
      final entries = PandaliveRoomParser.qualities(
        _masterPlaylist,
        master: _masterUrl,
        userId: _userId,
        issuedAt: _at,
      );
      expect(entries.map((entry) => entry.quality.qualityId), ['1080p60', '720p60', '360p']);
      expect(entries.first.quality.label, '原画');
      expect(entries.map((entry) => entry.quality.platformOrder), [3, 2, 1]);
      expect(entries.first.quality.codec, LiveStreamCodec.avc);
      final line = entries.last.line;
      expect(line.url, 'https://abcdef.live-video.net/hls/3.m3u8?token=one');
      expect(line.format, LiveStreamFormat.hls);
      expect(line.lineLabel, PandaliveEndpoints.lineLabel);
      expect(line.headers['origin'], PandaliveEndpoints.origin);
      expect(line.headers['referer'], PandaliveEndpoints.roomUrl(_userId));
      expect(line.lease!.refreshAt, _at.add(PandaliveEndpoints.variantRefresh));
      expect(line.lease!.requiresReconnect, isTrue);
    });

    test('the lease does not count the audio-only variant', () {
      final entries = PandaliveRoomParser.qualities(
        _masterPlaylist,
        master: _masterUrl,
        userId: _userId,
        issuedAt: _at,
      );
      expect(entries, hasLength(3), reason: 'the audio-only variant is left out');
    });

    test('a master with no video variant, or none usable, says why', () {
      const audioOnly = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=60000,CODECS="mp4a.40.2"
audio.m3u8
''';
      expect(
        () => PandaliveRoomParser.qualities(audioOnly, master: _masterUrl, userId: _userId, issuedAt: _at),
        throwsA(predicate((e) => e is PandaliveFailure && e.kind == PandaliveFailureKind.streamUnavailable)),
      );
      const badFps = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360,FRAME-RATE=999.000
3.m3u8
''';
      expect(
        () => PandaliveRoomParser.qualities(badFps, master: _masterUrl, userId: _userId, issuedAt: _at),
        throwsA(predicate((e) => e is PandaliveFailure && e.kind == PandaliveFailureKind.apiChanged)),
      );
      expect(
        () => PandaliveRoomParser.qualities('not a playlist', master: _masterUrl, userId: _userId, issuedAt: _at),
        throwsA(predicate((e) => '$e'.contains('not a playlist'))),
      );
    });

    test('a stored quality id from the older adapter names the same stream', () {
      expect(PandaliveRoomParser.qualityIdFromLegacy('720p30'), '720p');
      expect(PandaliveRoomParser.qualityIdFromLegacy('720p30_2'), '720p_2');
      expect(PandaliveRoomParser.qualityIdFromLegacy('720p60'), '720p60');
      final data = PandaliveStreamData(
        userId: _userId,
        userIndex: _userIndex,
        entries: PandaliveRoomParser.qualities(_masterPlaylist, master: _masterUrl, userId: _userId, issuedAt: _at),
      );
      expect(PandaliveRoomParser.line(data, _quality('360p30')).url, contains('/hls/3.m3u8'));
      expect(
        () => PandaliveRoomParser.line(data, _quality('480p')),
        throwsA(predicate((e) => '$e'.contains('not offered'))),
      );
      expect(
        () => PandaliveRoomParser.line(
          PandaliveStreamData(
            userId: _userId,
            userIndex: _userIndex,
            unavailable: const PandaliveFailure(PandaliveFailureKind.streamUnavailable, 'member/bj: not live'),
          ),
          _quality('720p'),
        ),
        throwsA(predicate((e) => '$e'.contains('not live'))),
      );
    });
  });

  group('chat protocol', () {
    test('the frames of the Centrifugo handshake', () {
      expect(PandaliveDanmakuCodec.endpoint.host, 'chat-ws.neolive.kr');
      expect(
        PandaliveDanmakuCodec.connect('tok'),
        _json({
          'params': {'token': 'tok', 'name': 'js'},
          'id': 1,
        }),
      );
      expect(
        PandaliveDanmakuCodec.subscribe('$_userIndex'),
        _json({
          'method': 1,
          'params': {'channel': _channel},
          'id': 2,
        }),
      );
      expect(PandaliveDanmakuCodec.ping(7), _json({'method': 7, 'id': 7}));
    });

    test('the arguments are checked before any socket', () {
      final checked = PandaliveDanmakuCodec.checked(
        const PandaliveDanmakuArgs(userId: ' $_userId ', channel: ' $_channel ', token: ' tok '),
      );
      expect(checked?.userId, _userId);
      expect(checked?.channel, _channel);
      expect(checked?.token, 'tok');
      expect(PandaliveDanmakuCodec.checked(const PandaliveDanmakuArgs(userId: _userId, channel: 'chat')), isNull);
      expect(PandaliveDanmakuCodec.checked(const PandaliveDanmakuArgs(userId: 'bad id!', channel: _channel)), isNull);
      expect(
        PandaliveDanmakuCodec.checked(
          const PandaliveDanmakuArgs(userId: _userId, channel: _channel, token: 'has space'),
        )?.token,
        isNull,
        reason: 'an unusable token is dropped, a fresh one is asked for',
      );
    });

    test('the token expiry and the renewal lead', () {
      expect(
        PandaliveDanmakuCodec.tokenExpiry(_token),
        DateTime.fromMillisecondsSinceEpoch((_at.millisecondsSinceEpoch ~/ 1000 + 1800) * 1000, isUtc: true),
      );
      expect(PandaliveDanmakuCodec.tokenExpiry('not-a-jwt'), isNull);
      expect(PandaliveDanmakuCodec.renewalDelay(const Duration(seconds: 1800)), const Duration(seconds: 1740));
      expect(PandaliveDanmakuCodec.renewalDelay(const Duration(seconds: 90)), const Duration(seconds: 45));
    });

    test('a live/play answer grants the chat, or refuses it', () {
      final grant = PandaliveDanmakuCodec.grant((text: _playFixture(), status: 200));
      expect(grant.channel, _channel);
      expect(grant.token, 'jwt-chat-token');
      expect(
        () => PandaliveDanmakuCodec.grant((
          text: _resp(
            400,
            _json({
              'result': false,
              'errorData': {'code': 'castEnd'},
            }),
          ).text,
          status: 400,
        )),
        throwsA(predicate((e) => '$e'.contains('castEnd'))),
      );
      expect(
        () => PandaliveDanmakuCodec.grant((text: _playFixture(isLive: 'N'), status: 200)),
        throwsA(predicate((e) => '$e'.contains('not live'))),
      );
      expect(
        () => PandaliveDanmakuCodec.grant((text: _playFixture(token: ''), status: 200)),
        throwsA(predicate((e) => '$e'.contains('no chat channel or token'))),
      );
    });

    PandaliveDanmakuFrame frame(Object? data) => PandaliveDanmakuCodec.decode(data, channel: _channel);

    test('the replies of the connect and the subscribe', () {
      expect(frame(_json({'id': 2})).joined, isTrue);
      expect(frame(_json({'id': 7})).joined, isFalse, reason: 'a ping reply');
      expect(frame(_json({'id': 1, 'result': <String, Object?>{}})).joined, isFalse);
      final ttl = frame(
        _json({
          'id': 1,
          'result': {'expires': true, 'ttl': 1800},
        }),
      );
      expect(ttl.expiresIn, const Duration(seconds: 1800));
      expect(
        frame(
          _json({
            'id': 1,
            'result': {'expires': true, 'ttl': 0},
          }),
        ).expiresIn,
        isNull,
      );
      expect(
        frame(
          _json({
            'id': 2,
            'error': {'code': 109, 'message': 'token expired'},
          }),
        ).refusal,
        'subscribe: 109 token expired',
      );
      expect(
        frame(
          _json({
            'id': 1,
            'error': {'code': 3002, 'message': 'invalid token'},
          }),
        ).refusal,
        'connect: 3002 invalid token',
      );
      expect(frame(_json({'id': 2, 'error': 'boom'})).refusal, 'subscribe: boom');
    });

    test('a chat publication is read, others are left', () {
      final chat = frame(
        _publication({
          'type': 'chatter',
          'message': ' 안녕하세요 ',
          'nk': '시청자',
          'id': 'viewer01',
          'created_at': 1759200000,
        }),
      ).messages.single;
      expect(chat.type, LiveMessageType.chat);
      expect(chat.text, '안녕하세요');
      expect(chat.effectiveSender.userName, '시청자');
      expect(chat.effectiveSender.userId, 'viewer01');
      expect(chat.messageId, '$_channel:7');
      expect(chat.sentAt, DateTime.fromMillisecondsSinceEpoch(1759200000000));
      final emoticon = frame(
        _publication({
          'type': 'bj',
          'message': '',
          'nk': '시청자',
          'id': 'viewer01',
          'emoticon': {
            'block': {'name': '하트', 'img': 'x.png'},
            'inline': <Object?>[],
          },
        }),
      ).messages.single;
      expect(emoticon.text, '[하트]');
      for (final silent in [
        _publication({'type': 'join'}, offset: 1),
        _publication({'type': 'SponCoin', 'message': 'not json'}, offset: 2),
        _publication({'type': 'chatter', 'message': '   '}, offset: 3),
        _publication({'type': 'chatter', 'message': 'x'}, offset: 4, channel: '999'),
        _json({
          'result': {'type': 'join', 'channel': _channel},
        }),
      ]) {
        expect(frame(silent).messages, isEmpty, reason: silent);
      }
    });

    test('hearts are a gift, the words sent with them a chat line', () {
      final messages = frame(
        _publication({
          'type': 'SponCoin',
          'message': _json({
            'coin': 100,
            'nick': '후원자',
            'id': 'viewer02',
            'excelNick': '데이지',
            'heartMessage': {'message': '항상 응원해요'},
          }),
          'created_at': 1759200001,
        }),
      ).messages;
      expect(messages, hasLength(2));
      final gift = messages.first;
      expect(gift.type, LiveMessageType.gift);
      expect(gift.text, '하트 ×100');
      expect(gift.effectiveSender.userName, '후원자');
      final payload = gift.payload! as LiveGift;
      expect(payload.name, '하트');
      expect(payload.count, 100);
      expect(payload.kind, LiveGiftKind.tip);
      expect(payload.value.unitPrice, 1.0);
      expect(payload.value.totalValue, 100.0);
      expect(payload.recipientName, '데이지');
      expect(messages.last.type, LiveMessageType.chat);
      expect(messages.last.text, '항상 응원해요');
      expect(messages.last.messageId, '$_channel:7:words');
      for (final silent in [
        _publication({
          'type': 'SponCoin',
          'message': _json({'coin': 0, 'nick': '후원자'}),
        }),
        _publication({
          'type': 'SponCoin',
          'message': _json({'coin': 5, 'nick': ''}),
        }),
      ]) {
        expect(frame(silent).messages, isEmpty, reason: silent);
      }
    });

    test('a frame is read line by line, in bytes too', () {
      final both =
          '${_json({'id': 2})}\nnot json\n${_publication({'type': 'chatter', 'message': 'hi', 'nk': 'n', 'id': 'u'})}';
      final parsed = frame(both);
      expect(parsed.joined, isTrue);
      expect(parsed.messages.single.text, 'hi');
      expect(frame(utf8.encode(both)).messages.single.text, 'hi');
      expect(frame(42).joined, isFalse);
      expect(PandaliveDanmakuFrame.empty.joined, isFalse);
    });
  });

  group('comment session', () {
    test('the first handshake uses the entry token and pings', () async {
      final chat = await _chat();
      expect(chat.connector.endpoints.single, PandaliveDanmakuCodec.endpoint);
      expect(
        chat.socket.sentText,
        '${PandaliveDanmakuCodec.connect(_token)}\n${PandaliveDanmakuCodec.subscribe(_channel)}',
        reason: 'connect and subscribe go out as soon as the socket opens',
      );
      expect(chat.connector.sockets, hasLength(1));
      expect(chat.http.sent.where((seen) => seen.url.path == '/v1/live/play'), isEmpty, reason: 'the token is young');
      expect(chat.timers.every.single.period, PandaliveDanmakuCodec.heartbeatInterval);
      expect(
        chat.timers.after.map((watch) => watch.delay),
        containsAll([PandaliveDanmakuCodec.joinTimeout, PandaliveDanmakuCodec.silenceTimeout]),
      );
      chat.timers.ringLast();
      expect(chat.socket.sentText, endsWith(PandaliveDanmakuCodec.ping(3)));
      await chat.session.dispose();
      expect(chat.socket.closed, isTrue);
    });

    test('the subscription joins, and the connect reply renews the token', () async {
      final chat = await _chat();
      final after = _next(chat.session.events, 1);
      chat.socket.push(_json({'id': 2}));
      chat.socket.push(_publication({'type': 'chatter', 'message': 'hi', 'nk': 'n', 'id': 'u'}));
      expect((await after).single.text, 'hi');
      chat.socket.push(
        _json({
          'id': 1,
          'result': {'expires': true, 'ttl': 1800},
        }),
      );
      await _settle();
      chat.timers.fire(const Duration(seconds: 1740));
      await _settle();
      expect(chat.connector.sockets, hasLength(2), reason: 'the renewal opens a new socket');
      expect(chat.http.sent.where((seen) => seen.url.path == '/v1/live/play'), hasLength(1), reason: 'a fresh token');
      expect(chat.connector.latest.sentText, startsWith(PandaliveDanmakuCodec.connect('jwt-chat-token')));
      await chat.session.dispose();
    });

    test('a refused join is retried, the next refusal ends the session', () async {
      final chat = await _chat();
      final refusal = _json({
        'id': 2,
        'error': {'code': 109, 'message': 'token expired'},
      });
      final done = chat.session.events.listen((_) {}).asFuture<void>();
      for (var attempt = 0; attempt < PandaliveDanmakuCodec.maxRefusals; attempt++) {
        chat.connector.latest.push(refusal);
        await _settle();
        chat.timers.fire(PandaliveDanmakuCodec.reconnectBaseDelay * (attempt + 1));
        await _settle();
      }
      expect(chat.connector.sockets, hasLength(PandaliveDanmakuCodec.maxRefusals + 1), reason: 'three replacements');
      expect(chat.connector.latest.sentText, startsWith(PandaliveDanmakuCodec.connect('jwt-chat-token')));
      chat.connector.latest.push(refusal);
      await done;
      await chat.session.dispose();
    });

    test('a joined socket resets the refusal and failure counts', () async {
      final chat = await _chat();
      chat.connector.latest.push(
        _json({
          'id': 2,
          'error': {'code': 1, 'message': 'x'},
        }),
      );
      await _settle();
      chat.timers.fire(PandaliveDanmakuCodec.reconnectBaseDelay);
      await _settle();
      chat.connector.latest.push(_json({'id': 2}));
      await _settle();
      chat.connector.latest.push(
        _json({
          'id': 2,
          'error': {'code': 1, 'message': 'x'},
        }),
      );
      await _settle();
      chat.timers.fire(PandaliveDanmakuCodec.reconnectBaseDelay);
      await _settle();
      expect(chat.connector.sockets, hasLength(3));
      expect(chat.session.events, isNotNull, reason: 'a confirmed join clears the counts, so the session lives on');
      await chat.session.dispose();
    });

    test('a socket that never joins or goes silent is replaced', () async {
      final chat = await _chat();
      final first = chat.socket;
      chat.timers.fire(PandaliveDanmakuCodec.joinTimeout);
      await _settle();
      chat.timers.fire(PandaliveDanmakuCodec.reconnectBaseDelay);
      await _settle();
      expect(chat.connector.sockets, hasLength(2));
      expect(first.closed, isTrue);
      chat.connector.latest.push(_json({'id': 2}));
      await _settle();
      chat.timers.fire(PandaliveDanmakuCodec.silenceTimeout);
      await _settle();
      chat.timers.fire(PandaliveDanmakuCodec.reconnectBaseDelay);
      await _settle();
      expect(chat.connector.sockets, hasLength(3), reason: 'the watchdog keeps its word even on a joined socket');
      await chat.session.dispose();
    });

    test('the reconnect budget ends the session', () async {
      final timers = FakeTimers();
      final http = _FakeHttp(_ordinary);
      final session = PandaliveDanmakuSession(
        args: PandaliveDanmakuArgs(userId: _userId, channel: _channel, token: _token),
        site: PandaliveSite(http: PandaliveHttp(http), connect: _brokenSocket, now: () => _at),
        timers: timers.timers,
        now: () => _at,
      );
      expect(await session.connect(), isNull);
      await _settle();
      final seen = <LiveMessage>[];
      final done = session.events.listen(seen.add).asFuture<void>();
      for (var attempt = 0; attempt < PandaliveDanmakuCodec.maxReconnects; attempt++) {
        timers.fire(PandaliveDanmakuCodec.reconnectBaseDelay * (attempt + 1));
        await _settle();
      }
      await done;
      expect(seen.where((message) => message.type == LiveMessageType.system), isNotEmpty);
      await session.dispose();
    });

    test('a refused live/play ends the session at once', () async {
      final connector = _Connector();
      final timers = FakeTimers();
      final http = _FakeHttp(
        (seen) => switch (seen.url.path) {
          '/v1/live/play' => _resp(
            400,
            _json({
              'result': false,
              'message': '방송종료',
              'errorData': {'code': 'castEnd'},
            }),
          ),
          _ => _ordinary(seen),
        },
      );
      final session = PandaliveDanmakuSession(
        args: const PandaliveDanmakuArgs(userId: _userId, channel: _channel),
        site: PandaliveSite(http: PandaliveHttp(http), connect: connector.call, now: () => _at),
        timers: timers.timers,
        now: () => _at,
      );
      expect(await session.connect(), isNull);
      final seen = <LiveMessage>[];
      await session.events.listen(seen.add).asFuture<void>();
      expect(seen.where((message) => message.type == LiveMessageType.system), isNotEmpty);
      expect(
        seen.where((message) => message.type == LiveMessageType.system).map((message) => message.text).first,
        contains('castEnd'),
      );
      expect(connector.sockets, isEmpty, reason: 'no socket without a token');
      await session.dispose();
    });

    test('arguments that name no chat are refused before any socket', () async {
      final connector = _Connector();
      final session = PandaliveDanmakuSession(
        args: const PandaliveDanmakuArgs(userId: 'bad id!', channel: _channel),
        site: PandaliveSite(http: PandaliveHttp(_FakeHttp(_ordinary)), connect: connector.call, now: () => _at),
        timers: FakeTimers().timers,
        now: () => _at,
      );
      expect(await session.connect(), isA<LiveSiteNotFound>());
      expect(connector.sockets, isEmpty);
      await session.dispose();
    });
  });

  group('adapter wiring', () {
    test('the manifest and the seven capabilities the platform can serve', () async {
      final adapter = _adapter();
      final site = adapter.site;
      expect(site.manifest.id, 'pandalive');
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
      expect(site.capability<LiveSiteCapability>(), isNull, reason: 'an unknown capability is null');
      await site.dispose();
    });

    test('a directory page is one live/index POST', () async {
      final adapter = _adapter();
      final rooms = _right(await adapter.site.capability<LiveRoomProvider>()!.getRooms(const LivePageRequest()));
      expect(adapter.http.sent.single.url.path, '/v1/live/index');
      expect(adapter.http.sent.single.body, contains('orderBy=hot'));
      expect(rooms.items.single.roomId, _userId);
      expect(rooms.hasMore, isFalse);
      expect(
        _leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRooms(const LivePageRequest(page: 1001))),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(
        _leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRooms(const LivePageRequest(pageSize: 65))),
        isA<LiveSiteInvalidArgument>(),
      );
    });

    test('the two directories are the areas, and another one is refused', () async {
      final adapter = _adapter();
      final area = adapter.site.capability<LiveAreaProvider>()!;
      expect(_right(await area.getAreas()).map((entry) => entry.areaId), ['public', 'newbj']);
      expect(_right(await area.getAreas()).first.areaName, '公开直播');
      final newbj = await area.getAreaRooms(areaId: 'newbj', request: const LivePageRequest(pageSize: 5));
      expect(_right(newbj).items.single.roomId, _userId);
      expect(adapter.http.sent.last.body, contains('onlyNewBj=Y'));
      expect(adapter.http.sent.last.body, contains('limit=5'));
      expect(_leftOf(await area.getAreaRooms(areaId: 'game')), isA<LiveSiteInvalidArgument>());
      final discovery = adapter.site.capability<LiveDiscoveryProvider>()!;
      expect(_right(await discovery.getRecommendedRooms()).items.single.roomId, _userId);
      expect(
        adapter.http.sent.last.body,
        isNot(contains('onlyNewBj')),
        reason: 'the recommendations are the public one',
      );
    });

    test('an entry is member, play and master, with its handles', () async {
      final adapter = _adapter();
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_userId));
      expect(
        adapter.http.sent.where((seen) => seen.url.host == PandaliveEndpoints.apiHost).map((seen) => seen.url.path),
        ['/v1/member/bj', '/v1/live/play'],
      );
      expect(adapter.http.sent.last.url.host, endsWith('.live-video.net'), reason: 'the master is read once');
      expect(room.roomId, _userId);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.runtime.danmakuHandle, isA<PandaliveDanmakuArgs>());
      expect((room.runtime.danmakuHandle! as PandaliveDanmakuArgs).channel, _channel);
      // The qualities and lines come from the entry, without a request.
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final before = adapter.http.sent.length;
      final qualities = _right(await playback.getQualities(roomId: _userId));
      expect(qualities.map((quality) => quality.qualityId), ['1080p60', '720p60', '360p']);
      final lines = _right(await playback.getLines(roomId: _userId));
      expect(lines, hasLength(1));
      expect(lines.single.url, 'https://abcdef.live-video.net/hls/1.m3u8?token=one');
      expect(lines.single.headers['referer'], PandaliveEndpoints.roomUrl(_userId));
      expect(lines.single.format, LiveStreamFormat.hls);
      expect(lines.single.lineLabel, 'ivs');
      expect(lines.single.lease!.refreshAt, _at.add(PandaliveEndpoints.variantRefresh));
      expect(adapter.http.sent.length, before, reason: 'the entry already holds the variants');
    });

    test('a line the lease has run out re-enters the room', () async {
      final adapter = _adapter();
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      expect(_right(await playback.getQualities(roomId: _userId)), hasLength(3));
      final before = adapter.http.sent.length;
      adapter.clock.at = _at.add(PandaliveEndpoints.variantRefresh).add(const Duration(seconds: 1));
      final lines = _right(await playback.getLines(roomId: _userId));
      expect(lines.single.url, contains('/hls/1.m3u8'));
      expect(adapter.http.sent.length, before + 3, reason: 'member, play and master again');
    });

    test('an offline broadcaster is entered, and says it has no stream', () async {
      final adapter = _adapter(
        onSend: (seen) => switch (seen.url.path) {
          '/v1/member/bj' => _resp(200, _memberFixture(withMedia: false)),
          _ => _ordinary(seen),
        },
      );
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_userId));
      expect(adapter.http.sent, hasLength(1), reason: 'the member answer alone');
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.runtime.danmakuHandle, isNull);
      final left = _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _userId));
      expect(left, isA<LiveSiteContentUnavailable>());
      expect(adapter.http.sent, hasLength(1), reason: 'the kept answer says why, without a request');
    });

    test('a refused broadcast is entered, and its stream names the reason', () async {
      final adapter = _adapter(
        onSend: (seen) => switch (seen.url.path) {
          '/v1/live/play' => _resp(200, _playFixture(result: false, code: 'needPassword')),
          _ => _ordinary(seen),
        },
      );
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_userId));
      expect(room.broadcast.restriction, LiveRestriction.password);
      expect(room.content.notice, PandaliveEndpoints.passwordNotice);
      expect(
        _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _userId)),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test('a master the edge refuses ends the entry with its own error', () async {
      final adapter = _adapter(
        onSend: (seen) => seen.url.host.endsWith('.live-video.net') ? _resp(404, 'gone') : _ordinary(seen),
      );
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_userId));
      expect(room.broadcast.restriction, LiveRestriction.unplayable, reason: 'the master is part of the broadcast');
      expect(
        _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _userId)),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test('a search runs the BJ search and the LIVE search, live first', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      final page = await search.search(
        const LiveSearchRequest(query: '방송', target: LiveSearchTarget.rooms, pageSize: 2),
      );
      expect(_right(page).items.map((item) => (item as RoomSearchResult).room.roomId), [
        _liveRoomId,
        _otherUserId,
      ], reason: 'the live cards come first');
      final paths = adapter.http.sent.map((seen) => seen.url.path).toList();
      expect(paths, ['/v1/live/bj_list', '/v1/live/index']);
      expect(_formOf(adapter.http.sent.first)['limit'], '1', reason: 'each source takes half the page');
      expect(_formOf(adapter.http.sent.last)['searchVal'], '방송');
      expect(_right(page).hasMore, isNull, reason: 'the platform says nothing about search pages');
    });

    test('a broadcaster id is searched exactly, and put first', () async {
      final adapter = _adapter(
        onSend: (seen) => switch (seen.url.path) {
          '/v1/live/bj_list' => _resp(200, _pageFixture(page: 1, size: 1, rows: [_broadcasterRow(id: _userId)])),
          _ => _ordinary(seen),
        },
      );
      final search = adapter.site.capability<LiveSearchProvider>()!;
      final page = await search.search(
        const LiveSearchRequest(query: _userId, target: LiveSearchTarget.rooms, pageSize: 2),
      );
      expect(_right(page).items.map((item) => (item as RoomSearchResult).room.roomId), [
        _userId,
        _liveRoomId,
      ], reason: 'the exact broadcaster is moved to the front, without a member request');
      expect(adapter.http.sent, hasLength(2));
    });

    test('an id the searches missed is asked for, an unknown one adds nothing', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      final page = await search.search(
        const LiveSearchRequest(query: _userId, target: LiveSearchTarget.rooms, pageSize: 2),
      );
      expect(_right(page).items.first, isA<RoomSearchResult>());
      expect((_right(page).items.first as RoomSearchResult).room.roomId, _userId);
      expect(adapter.http.sent, hasLength(3), reason: 'the two searches, then member/bj');
      expect(_formOf(adapter.http.sent.last)['userId'], _userId);
      final unknown = _adapter(
        onSend: (seen) => switch (seen.url.path) {
          '/v1/member/bj' => _resp(400, _notFoundFixture()),
          _ => _ordinary(seen),
        },
      );
      final missed = await unknown.site.capability<LiveSearchProvider>()!.search(
        const LiveSearchRequest(query: _userId, target: LiveSearchTarget.rooms, pageSize: 2),
      );
      expect(_right(missed).items.map((item) => (item as RoomSearchResult).room.roomId), [
        _liveRoomId,
        _otherUserId,
      ], reason: 'no such broadcaster: the searches stand');
    });

    test('a room link finds its broadcaster, another URL finds nothing', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      final page = await search.search(
        LiveSearchRequest(query: PandaliveEndpoints.roomUrl(_userId), target: LiveSearchTarget.rooms),
      );
      expect((_right(page).items.single as RoomSearchResult).room.roomId, _userId);
      expect(adapter.http.sent, hasLength(1), reason: 'one member request');
      expect(
        _right(
          await search.search(
            LiveSearchRequest(query: PandaliveEndpoints.roomUrl(_userId), target: LiveSearchTarget.rooms, page: 2),
          ),
        ).items,
        isEmpty,
      );
      expect(
        _right(
          await search.search(const LiveSearchRequest(query: 'https://evil.com/x', target: LiveSearchTarget.rooms)),
        ).items,
        isEmpty,
      );
      expect(adapter.http.sent, hasLength(1), reason: 'neither asked a request');
    });

    test('a keyword the platform could not read is refused, a short one empty', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(
        _right(await search.search(const LiveSearchRequest(query: 'd', target: LiveSearchTarget.rooms))).items,
        isEmpty,
      );
      expect(adapter.http.sent, isEmpty, reason: 'too short to search');
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: '방송\x00', target: LiveSearchTarget.rooms))),
        isA<LiveSiteInvalidArgument>(),
      );
    });

    test('a link is canonicalized without a request', () async {
      final adapter = _adapter();
      final link = adapter.site.capability<LiveLinkResolver>()!;
      expect(
        _right(await link.resolve(Uri.parse('https://www.pandalive.co.kr/live/play/$_userId'))),
        Uri.parse(PandaliveEndpoints.roomUrl(_userId)),
      );
      expect(adapter.http.sent, isEmpty);
      expect(_leftOf(await link.resolve(Uri.parse('https://example.com/x'))), isA<LiveSiteUnsupported>());
      expect(_leftOf(await link.resolve(Uri.parse('https://www.pandalive.co.kr/live'))), isA<LiveSiteNotFound>());
    });

    test('a status the gate refuses is mapped', () async {
      final refused = _adapter(onSend: (_) => _resp(401, 'nope'));
      expect(
        _leftOf(await refused.site.capability<LiveRoomProvider>()!.getRoom(_userId)),
        isA<LiveSiteRateLimitError>(),
      );
      final gone = _adapter(onSend: (_) => _resp(400, _notFoundFixture()));
      expect(_leftOf(await gone.site.capability<LiveRoomProvider>()!.getRoom(_userId)), isA<LiveSiteNotFound>());
      final broken = _adapter(onSend: (_) => _resp(200, 'not json'));
      expect(
        _leftOf(await broken.site.capability<LiveRoomProvider>()!.getRooms(const LivePageRequest())),
        isA<LiveSiteParseError>(),
      );
    });

    test('the chat provider builds a session only for a live broadcast', () async {
      final opened = _Connector();
      final adapter = _adapter(connect: opened.call);
      final danmaku = adapter.site.capability<LiveDanmakuProvider>()!;
      final session = _right(await danmaku.createSession(roomId: _userId)) as PandaliveDanmakuSession;
      await _settle();
      expect(opened.sockets, hasLength(1));
      await session.dispose();
      final idle = _adapter(
        connect: opened.call,
        onSend: (seen) => switch (seen.url.path) {
          '/v1/member/bj' => _resp(200, _memberFixture(withMedia: false)),
          _ => _ordinary(seen),
        },
      );
      expect(
        _leftOf(await idle.site.capability<LiveDanmakuProvider>()!.createSession(roomId: _userId)),
        isA<LiveSiteContentUnavailable>(),
      );
      final wrong = _adapter(
        connect: opened.call,
        onSend: (seen) => switch (seen.url.path) {
          '/v1/member/bj' => _resp(400, _notFoundFixture()),
          _ => _ordinary(seen),
        },
      );
      expect(
        _leftOf(await wrong.site.capability<LiveDanmakuProvider>()!.createSession(roomId: 'nope!')),
        isA<LiveSiteNotFound>(),
      );
    });
  });
}

/// A quality that names only its stored id.
LivePlayQuality _quality(String id) => LivePlayQuality(label: id, qualityId: id);
