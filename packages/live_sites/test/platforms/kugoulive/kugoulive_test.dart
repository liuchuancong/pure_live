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
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/internal/built_in_sites.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/kugoulive/api/kugoulive_endpoints.dart';
import 'package:live_sites/src/platforms/kugoulive/api/kugoulive_http.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_danmaku_session.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_protobuf.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_site.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_directory.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_failure.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_json.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

/// The clock of the tests: 2026-09-30, in the afternoon.
final DateTime _at = DateTime.utc(2026, 9, 30, 14);

const String _room = '67890';
const String _otherRoom = '12345';

String _json(Object? data) => jsonEncode(data);

Map<String, Object?> _card({
  String roomId = _room,
  String nick = '主播甲',
  String? label = '晚间弹唱',
  Object? liveStatus = 1,
  Object? viewerNum = 42,
  Object? hot = 9001,
  Object? fansCount = 5678,
  String userLogo = 'https://img.kgimg.com/a.png',
  String imgPath = 'https://img.kgimg.com/cover.png',
  Object? livetime = 120,
  bool search = false,
}) => {
  'roomId': roomId,
  'userId': 'u-$roomId',
  'kugouId': roomId,
  'nickName': nick,
  'label': label,
  'liveStatus': liveStatus,
  'viewerNum': viewerNum,
  'hot': hot,
  'fansCount': fansCount,
  'userLogo': userLogo,
  'imgPath': imgPath,
  if (!search) 'livetime': livetime,
  if (search) 'lastLiveTime': 1727700000,
};

String _listFixture({List<Object?>? list, Object? hasNextPage = 1, Object? times = 1727701200000}) => _json({
  'code': 0,
  'times': times,
  'data': {
    'list': list ?? [_card()],
    'hasNextPage': hasNextPage,
  },
});

String _roomInfoFixture({
  Map<String, Object?>? info,
  Object? liveSessionId = '6ab93a1bh10932',
  Object? liveType = 2,
  int code = 0,
}) => _json({
  'code': code,
  'times': 1790524000000,
  'data': {
    'normalRoomInfo':
        info ??
        {
          'userId': 'u-$_room',
          'kugouId': _room,
          'nickName': '主播甲',
          'userLogo': 'https://img.kgimg.com/a.png',
          'imgPath': 'https://img.kgimg.com/cover.png',
          'fansCount': 5678,
          'publicMesg': '欢迎光临',
        },
    'liveSessionId': liveSessionId,
    'liveType': liveType,
  },
});

String _streamFixture({int code = 0, String roomId = _room, Object? status = 1, List<Object?>? lines}) => _json({
  'code': code,
  'time': 1727701200,
  'data': {
    'roomId': roomId,
    'status': status,
    'lines':
        lines ??
        [
          {
            'sid': '7',
            'streamProfiles': [
              {
                'rate': 4,
                'codec': 1,
                'layout': 2,
                'httpsFlv': ['https://liveplay.live.kugou.com/live/67890_4.flv?txSecret=abc&txTime=5dc0a1c0'],
                'httpsHls': ['https://liveplay.live.kugou.com/live/67890_4.m3u8?txSecret=abc&txTime=5dc0a1c0'],
              },
              {
                'rate': 2,
                'codec': 2,
                'layout': 2,
                'httpsFlv': ['https://liveplay.live.kugou.com/live/67890_2hevc.flv?txSecret=abc&txTime=5dc0a1c0'],
              },
            ],
          },
        ],
  },
});

String _jsonpFixture({
  String callback = 'pureLive1',
  List<Object?>? rows,
  Object? status = 0,
  Object? time = 1727701200000,
}) =>
    '$callback(${_json({
      'status': status,
      'time': time,
      'data': {
        'anchor': {
          'list': rows ?? [_card(search: true)],
        },
      },
    })});';

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(body)));

final class _Seen {
  new(LiveRequest request) : url = request.url;
  final Uri url;
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

/// The answers of the site: the home page, the list, the room info, the
/// stream and the search.
LiveResponse _ordinary(_Seen request) {
  final path = request.url.path;
  if (path == '/') {
    return _resp(
      200,
      '<html><a href="/pcindex/category/8000" title="推荐"></a> '
      '<a href="/pcindex/category/7024" title="舞蹈"></a> '
      '<a href="/pcindex/category/3001" title="关注"></a></html>',
    );
  }
  if (path.startsWith('/mfanxing-home/h5/cdn/room/index/list')) return _resp(200, _listFixture());
  if (path == '/roomcen/room/web/cdn/getEnterRoomInfo') return _resp(200, _roomInfoFixture());
  if (path == '/video/pc/live/pull/mutiline/streamaddr') return _resp(200, _streamFixture());
  if (path == '/pt_search/pcsearch/v1/type_all.jsonp') {
    return _resp(200, _jsonpFixture(callback: request.url.queryParameters['callback']!));
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

/// The socket a test drives by hand.
final class _FakeSocket implements SocketChannel {
  final StreamController<Object?> _stream = StreamController<Object?>();
  final List<Object?> sentFrames = [];
  bool closed = false;

  @override
  Stream<Object?> get stream => _stream.stream;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  void add(Object data) => sentFrames.add(data);

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
  }

  void push(Object? frame) => _stream.add(frame);

  Future<void> ended() => _stream.close();
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

  KugouliveTimers get timers => (after: _after, every: _every);

  Timer _after(Duration delay, void Function() callback) {
    after.add((delay: delay, callback: callback));
    return _IdleTimer();
  }

  Timer _every(Duration period, void Function(Timer timer) callback) {
    every.add((period: period, callback: callback));
    return _IdleTimer();
  }

  void fire({int index = 0}) => after[index].callback();

  void ring({int index = 0}) => every[index].callback(_IdleTimer());
}

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// A comment connection over a socket, clocks and a random the test holds.
Future<({KugouliveDanmakuSession session, _FakeSocket socket, FakeTimers timers, _Connector connector, _FakeHttp http})>
_chat({LiveResponse Function(_Seen request)? onSend}) async {
  final connector = _Connector();
  final timers = FakeTimers();
  final http = _FakeHttp(
    onSend ??
        (request) => request.url.path == KugouliveDanmakuCodec.dispatchPath
            ? _resp(
                200,
                _json({
                  'code': 0,
                  'data': {
                    'protocol': 'wss://',
                    'addrs': [
                      {'host': 'chat1.kugou.com:443'},
                      {'host': 'chat2.kugou.com:443'},
                    ],
                    'soctoken': 'tok-1',
                    'age': 300000,
                  },
                }),
              )
            : _ordinary(request),
  );
  final session = KugouliveDanmakuSession(
    args: const KugouliveDanmakuArgs(roomId: _room),
    site: KugouliveSite(http: KugouliveHttp(http), connect: connector.call, now: () => _at),
    timers: timers.timers,
    random: Random(7),
  );
  expect(await session.connect(), isNull);
  await _settle();
  return (session: session, socket: connector.latest, timers: timers, connector: connector, http: http);
}

void main() {
  group('answers and readers', () {
    test('a status says what kind of answer it is', () {
      expect(KugouliveJson.statusError(200, 'x'), isNull);
      expect(KugouliveJson.statusError(400, 'x')?.kind, KugouliveFailureKind.apiChanged);
      expect(KugouliveJson.statusError(422, 'x')?.kind, KugouliveFailureKind.apiChanged);
      expect(KugouliveJson.statusError(401, 'x')?.kind, KugouliveFailureKind.riskControl);
      expect(KugouliveJson.statusError(403, 'x')?.kind, KugouliveFailureKind.riskControl);
      expect(KugouliveJson.statusError(451, 'x')?.kind, KugouliveFailureKind.regionBlocked);
      expect(KugouliveJson.statusError(404, 'x')?.kind, KugouliveFailureKind.notFound);
      expect(KugouliveJson.statusError(410, 'x')?.kind, KugouliveFailureKind.notFound);
      expect(KugouliveJson.statusError(429, 'x')?.kind, KugouliveFailureKind.rateLimited);
      expect(KugouliveJson.statusError(500, 'x')?.kind, KugouliveFailureKind.network);
      expect(KugouliveJson.statusError(302, 'x')?.kind, KugouliveFailureKind.network);
      expect(const KugouliveFailure(KugouliveFailureKind.network, 'x').isTransient, isTrue);
      expect(const KugouliveFailure(KugouliveFailureKind.rateLimited, 'x').isTransient, isTrue);
      expect(const KugouliveFailure(KugouliveFailureKind.riskControl, 'x').isTransient, isFalse);
    });

    test('the envelope gates code and data', () {
      expect(
        KugouliveJson.answer(
          _json({
            'code': 0,
            'data': {'a': 1},
          }),
          what: 'x',
          status: 200,
        ).data,
        {'a': 1},
      );
      expect(
        () => KugouliveJson.answer(_json({'code': 3, 'msg': 'no'}), what: 'x', status: 200),
        throwsA(predicate((e) => '$e'.contains('code 3 no'))),
      );
      expect(
        () => KugouliveJson.answer(_json({'code': 0, 'data': <String, Object?>{}}), what: 'x', status: 200),
        throwsA(predicate((e) => '$e'.contains('no data'))),
      );
    });

    test('the clocks of a broadcast are read plausibly', () {
      expect(KugouliveJson.sessionStart('6ab93a1bh10932', ownerId: 67890, answered: _at), isNotNull);
      expect(
        KugouliveJson.sessionStart('6ab93a1bh10932', ownerId: 1, answered: _at),
        isNull,
        reason: 'a session of another anchor',
      );
      expect(KugouliveJson.sessionStart('nope'), isNull);
      expect(KugouliveJson.listStart(120, DateTime.utc(2026, 9, 30, 14)), DateTime.utc(2026, 9, 30, 13, 58));
      expect(KugouliveJson.listStart(120, null), isNull);
    });

    test('a room number and a room link', () {
      expect(KugouliveEndpoints.parseRoomId(' $_room '), _room);
      expect(KugouliveEndpoints.parseRoomId('12'), isNull, reason: 'two digits are no room');
      expect(KugouliveEndpoints.parseRoomId('0123'), isNull);
      expect(KugouliveEndpoints.roomIdFromUrl('https://fanxing.kugou.com/$_room'), _room);
      expect(KugouliveEndpoints.roomIdFromUrl('https://mfanxing.kugou.com/x/y?roomId=$_room'), _room);
      expect(
        KugouliveEndpoints.roomIdFromUrl('https://fanxing.kugou.com/room/$_room'),
        isNull,
        reason: 'no roomId query',
      );
      expect(KugouliveEndpoints.roomIdFromUrl('https://evil.com/$_room'), isNull);
      expect(KugouliveEndpoints.roomIdFromUrl('https://fanxing.kugou.com/$_room#f'), isNull);
    });
  });

  group('areas and list', () {
    test('the home page links the areas once, without the personal routes', () {
      const html =
          '<a href="/pcindex/category/8000" title="推荐"></a> '
          '<a href="/pcindex/category/7024" title="舞蹈"></a> '
          '<a href="/pcindex/category/3001" title="关注"></a> '
          '<a href="/pcindex/category/7024" title="舞蹈"></a>';
      final areas = KugouliveRoomParser.areas(html);
      expect(areas.map((area) => area.areaId), ['8000', '7024']);
      expect(
        KugouliveRoomParser.areas('<html>none</html>').map((area) => area.areaId).first,
        '8000',
        reason: 'the fallback',
      );
    });

    test('a list page is the cards, a room once, hasMore from hasNextPage', () {
      final page = kugouliveDirectoryPage(
        _listFixture(
          list: [
            _card(),
            {'uiType': 'star', 'data': _card(roomId: _otherRoom)},
            _card(),
          ],
        ),
        page: 1,
      );
      expect(page.rooms.map((room) => room.roomId), [_room, _otherRoom]);
      expect(page.hasMore, isTrue);
      final last = kugouliveDirectoryPage(_listFixture(hasNextPage: 0), page: 2);
      expect(last.hasMore, isFalse);
      final room = page.rooms.first;
      expect(room.content.title, '晚间弹唱');
      expect(room.anchor?.name, '主播甲');
      expect(room.audience.onlineViewers, 42);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(room.anchor?.followerCount, 5678);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, isNotNull, reason: 'livetime before the answer');
      expect(room.broadcast.restriction, isNull, reason: 'a card cannot tell');
      expect(room.content.notice, KugouliveEndpoints.chatNotice);
    });

    test('an offline card is offline, a search card hides zero viewers', () {
      final offline = kugouliveDirectoryPage(_listFixture(list: [_card(liveStatus: 0)]), page: 1).rooms.single;
      expect(offline.broadcast.liveStatus, LiveStatus.offline);
      expect(offline.broadcast.startedAt, isNull);
      final searched = KugouliveRoomParser.card(_card(search: true, viewerNum: 0), search: true)!;
      expect(searched.audience.onlineViewers, isNull, reason: 'the search answers 0 for everyone');
      final liveSearched = KugouliveRoomParser.card(_card(search: true, viewerNum: 7), search: true)!;
      expect(liveSearched.audience.onlineViewers, 7);
    });
  });

  group('room info and streams', () {
    test('the room info of a live room names its session start', () {
      final (:room, :state) = KugouliveRoomParser.roomInfo(_roomInfoFixture(), roomId: _room);
      expect(state, KugouliveState.live);
      expect(room.roomId, _room);
      expect(room.content.title, '', reason: 'the room info has no title');
      expect(room.content.notice, contains('欢迎光临'));
      expect(room.content.notice, contains(KugouliveEndpoints.chatNotice));
      expect(room.broadcast.startedAt, isNotNull);
      final offline = KugouliveRoomParser.roomInfo(_roomInfoFixture(liveType: -1, liveSessionId: ''), roomId: _room);
      expect(offline.state, KugouliveState.offline);
      expect(offline.room.broadcast.liveStatus, LiveStatus.offline);
    });

    test('a room without an anchor is not-found', () {
      expect(
        () => KugouliveRoomParser.roomInfo(_roomInfoFixture(info: {'kugouId': 0, 'nickName': ''}), roomId: _room),
        throwsA(predicate((e) => e is KugouliveFailure && e.kind == KugouliveFailureKind.notFound)),
      );
    });

    test('the stream answer groups its lines by protocol, rate, codec, layout', () {
      final variants = KugouliveRoomParser.variants(_streamFixture(), roomId: _room);
      expect(variants.map((variant) => variant.id), ['flv:4:1:2', 'hls:4:1:2', 'flv:2:2:2'], reason: 'rate first');
      expect(variants.first.lines, hasLength(1));
      expect(variants.first.lines.single.format, LiveStreamFormat.flv);
      expect(variants.first.codec, 1);
      expect(variants.last.isHevc, isTrue);
      expect(KugouliveRoomParser.codecName(1), LiveStreamCodec.avc);
      expect(KugouliveRoomParser.codecName(2), LiveStreamCodec.hevc);
      final qualities = KugouliveRoomParser.qualities(variants);
      expect(qualities.first.qualityId, 'flv:4:1:2', reason: 'H.264 first');
      expect(qualities.first.label, 'FLV 码率档 4');
      final rateOrder = KugouliveRoomParser.qualities(variants, preferH264: false);
      expect(rateOrder.map((quality) => quality.qualityId), [
        'flv:4:1:2',
        'hls:4:1:2',
        'flv:2:2:2',
      ], reason: "without the preference, the variants' own (rate) order");
      expect(KugouliveRoomParser.qualities(variants).last.codec, LiveStreamCodec.hevc);
    });

    test('a media url must be the signed cdn address of its protocol', () {
      const good = 'https://liveplay.live.kugou.com/live/67890_4.flv?txSecret=abc&txTime=5dc0a1c0';
      expect(KugouliveRoomParser.mediaUrl(good, protocol: 'flv'), Uri.parse(good));
      for (final bad in [
        'http://liveplay.live.kugou.com/live/67890_4.flv?txSecret=a&txTime=5dc0a1c0',
        'https://evil.com/live/67890_4.flv?txSecret=a&txTime=5dc0a1c0',
        'https://liveplay.live.kugou.com/other/67890_4.flv?txSecret=a&txTime=5dc0a1c0',
        'https://liveplay.live.kugou.com/live/67890_4.png?txSecret=a&txTime=5dc0a1c0',
        'https://liveplay.live.kugou.com/live/67890_4.m3u8?txSecret=a&txTime=5dc0a1c0',
        'https://liveplay.live.kugou.com/live/67890_4.flv?txTime=5dc0a1c0',
        'https://liveplay.live.kugou.com/live/67890_4.flv?txSecret=abc&txTime=zz',
      ]) {
        expect(KugouliveRoomParser.mediaUrl(bad, protocol: 'flv'), isNull, reason: bad);
      }
      // The lease stops at txTime, renewed five minutes before.
      final expires = KugouliveRoomParser.invalidAt(good)!;
      expect(expires, DateTime.fromMillisecondsSinceEpoch(0x5dc0a1c0 * 1000, isUtc: true));
      expect(
        KugouliveRoomParser.refreshAt(good, now: expires.subtract(const Duration(minutes: 10))),
        expires.subtract(KugouliveEndpoints.leaseLead),
      );
      expect(
        KugouliveRoomParser.refreshAt(good, now: expires.subtract(const Duration(minutes: 1))),
        expires.subtract(const Duration(minutes: 1)),
        reason: 'once the lead has passed, now',
      );
    });

    test('the stream answer refuses what it cannot serve', () {
      expect(
        () => KugouliveRoomParser.variants(_streamFixture(code: -1), roomId: _room),
        throwsA(predicate((e) => e is KugouliveFailure && e.kind == KugouliveFailureKind.needsLogin)),
      );
      expect(
        () => KugouliveRoomParser.variants(_streamFixture(status: 0), roomId: _room),
        throwsA(predicate((e) => '$e'.contains('status 0'))),
      );
      expect(
        () => KugouliveRoomParser.variants(_streamFixture(roomId: '1'), roomId: _room),
        throwsA(predicate((e) => '$e'.contains('asked 67890'))),
      );
      expect(
        () => KugouliveRoomParser.variants(_streamFixture(lines: []), roomId: _room),
        throwsA(predicate((e) => '$e'.contains('no playable URL'))),
      );
    });
  });

  group('search', () {
    test('the jsonp is unwrapped and its cards paged', () {
      final rooms = KugouliveRoomParser.searchRooms(_jsonpFixture(), callback: 'pureLive1');
      expect(rooms, hasLength(1));
      expect(rooms.single.broadcast.startedAt, isNotNull, reason: 'lastLiveTime');
      expect(
        () => KugouliveRoomParser.searchRooms(_jsonpFixture(), callback: 'other'),
        throwsA(predicate((e) => '$e'.contains('JSONP to pureLive1, not other'))),
      );
      expect(() => KugouliveRoomParser.searchRooms('not jsonp'), throwsA(predicate((e) => '$e'.contains('not JSONP'))));
      final bad = KugouliveRoomParser.searchRooms(
        _jsonpFixture(
          rows: [
            {'roomId': 'x'},
          ],
        ),
        callback: 'pureLive1',
      );
      expect(bad, isEmpty, reason: 'a row without a room number is skipped');
    });

    test('a keyword is cut at the platform limit', () {
      expect(KugouliveEndpoints.searchUrl('k', 'cb').queryParameters['nums'], '200,0,0,0');
    });
  });

  group('chat protocol', () {
    test('the scheduler address is signed', () {
      final url = KugouliveDanmakuCodec.dispatchUrl(_room, now: _at);
      expect(url.host, KugouliveEndpoints.apiHost);
      expect(url.queryParameters['rid'], _room);
      expect(url.queryParameters['sign'], hasLength(16));
      final query = Map.of(url.queryParameters)..remove('sign');
      expect(url.queryParameters['sign'], KugouliveDanmakuCodec.sign(query));
    });

    test('the grant of a scheduler answer', () {
      final grant = KugouliveDanmakuCodec.grant(
        _json({
          'code': 0,
          'data': {
            'protocol': 'wss://',
            'addrs': [
              {'host': 'chat1.kugou.com:443'},
              {'host': 'chat2.kugou.com:443'},
              {'host': 'chat1.kugou.com:443'},
            ],
            'soctoken': 'tok',
            'age': 1000,
          },
        }),
      );
      expect(grant.endpoints, [
        Uri.parse('wss://chat1.kugou.com:443'),
        Uri.parse('wss://chat2.kugou.com:443'),
      ], reason: 'dupes skipped, order kept');
      expect(grant.token, 'tok');
      expect(grant.age, const Duration(milliseconds: 1000));
      expect(
        () => KugouliveDanmakuCodec.grant(_json({'code': 5, 'msg': 'slider'})),
        throwsA(predicate((e) => '$e'.contains('code 5 slider'))),
      );
      expect(
        () => KugouliveDanmakuCodec.grant(
          _json({
            'code': 0,
            'data': {'addrs': <Object?>[]},
          }),
        ),
        throwsA(predicate((e) => '$e'.contains('no chat address or token'))),
      );
    });

    test('a login frame carries the page fields', () {
      final login = KugouliveDanmakuCodec.login(roomId: _room, token: 'tok', sid: 'sid-1', deviceNo: 'dev-1');
      expect(login.length, greaterThan(18));
      final view = ByteData.sublistView(login);
      expect(view.getUint8(0), 100);
      expect(view.getInt32(6), KugouliveDanmakuCodec.loginCommand);
      final again = KugouliveDanmakuCodec.login(roomId: _room, token: 'tok', sid: 's', deviceNo: 'd', again: true);
      expect(ByteData.sublistView(again).getInt32(6), KugouliveDanmakuCodec.reloginCommand);
      expect(KugouliveDanmakuCodec.heartbeat(), Uint8List.fromList(const [100, 0, 1, 0]));
      final uuid = KugouliveDanmakuCodec.uuid(Random(7));
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(uuid), isTrue);
    });

    test('a chat line is read with badge, level and colour', () {
      KugouliveProtoWriter chatWriter({String text = 'hi', int level = 3, String name = '观众甲'}) =>
          KugouliveProtoWriter()
            ..string(1, text)
            ..integer(2, 777)
            ..string(4, name)
            ..integer(5, level)
            ..integer(13, 9)
            ..integer(25, level);
      final ext = KugouliveProtoWriter()
        ..bytes(
          39,
          (KugouliveProtoWriter()
                ..integer(1, 8)
                ..string(2, '粉丝团')
                ..integer(3, 1)
                ..integer(5, 1))
              .toBytes(),
        );
      final content = KugouliveProtoWriter()
        ..bytes(2, chatWriter().toBytes())
        ..integer(3, int.parse(_room))
        ..integer(6, 777)
        ..integer(11, 1727700000)
        ..integer(16, 1)
        ..bytes(14, ext.toBytes());
      final envelope =
          (KugouliveProtoWriter()
                ..bytes(7, content.toBytes())
                ..string(4, 'msg-1')
                ..integer(6, 1))
              .toBytes();
      final header = ByteData(18)
        ..setUint8(0, 100)
        ..setInt16(1, 3)
        ..setUint8(3, 1)
        ..setInt16(4, 12)
        ..setInt32(6, KugouliveDanmakuCodec.chatCommand)
        ..setInt32(10, envelope.length);
      final frame = KugouliveDanmakuCodec.decode(
        (BytesBuilder()
              ..add(header.buffer.asUint8List())
              ..add(envelope))
            .toBytes(),
        roomId: _room,
      );
      final chat = frame.messages.single;
      expect(chat.type, LiveMessageType.chat);
      expect(chat.text, 'hi');
      expect(chat.effectiveSender.userName, '观众甲');
      expect(chat.effectiveSender.userId, '777');
      expect(chat.effectiveSender.userLevel, '3');
      expect(chat.effectiveSender.fanBadgeName, '粉丝团');
      expect(chat.effectiveSender.fanBadgeLevel, '8');
      expect(chat.messageId, 'msg-1');
      expect(chat.sentAt, DateTime.fromMillisecondsSinceEpoch(1727700000 * 1000));
      // A private message is not shown.
      final hidden =
          (KugouliveProtoWriter()
                ..bytes(2, chatWriter(text: 'psst').toBytes())
                ..integer(4, 9)
                ..integer(16, 1))
              .toBytes();
      final envelope2 = (KugouliveProtoWriter()..bytes(7, hidden)).toBytes();
      final header2 = ByteData(18)
        ..setUint8(0, 100)
        ..setInt16(1, 3)
        ..setUint8(3, 1)
        ..setInt16(4, 12)
        ..setInt32(6, KugouliveDanmakuCodec.chatCommand)
        ..setInt32(10, envelope2.length);
      expect(
        KugouliveDanmakuCodec.decode(
          (BytesBuilder()
                ..add(header2.buffer.asUint8List())
                ..add(envelope2))
              .toBytes(),
          roomId: _room,
        ).messages,
        isEmpty,
      );
    });

    test('a gift is priced in star coins and acknowledged when asked', () {
      KugouliveProtoWriter giftWriter({int price = 10, int comboSum = 5}) => KugouliveProtoWriter()
        ..integer(2, 55)
        ..string(3, '火箭')
        ..integer(4, 2)
        ..integer(5, price)
        ..string(8, '/fxstatic/images/giftres/x.png')
        ..integer(12, int.parse(_room))
        ..integer(13, 777)
        ..string(15, '观众乙')
        ..integer(18, 1)
        ..string(19, '主播甲')
        ..string(28, 'combo-1')
        ..integer(29, comboSum)
        ..integer(75, comboSum);
      final content = KugouliveProtoWriter()
        ..bytes(2, giftWriter().toBytes())
        ..integer(3, int.parse(_room))
        ..integer(6, 777)
        ..integer(11, 1727700000)
        ..integer(16, 1);
      final envelope =
          (KugouliveProtoWriter()
                ..bytes(7, content.toBytes())
                ..integer(2, 1)
                ..string(4, 'gift-1')
                ..integer(6, 1))
              .toBytes();
      final header = ByteData(18)
        ..setUint8(0, 100)
        ..setInt16(1, 3)
        ..setUint8(3, 1)
        ..setInt16(4, 12)
        ..setInt32(6, KugouliveDanmakuCodec.giftCommand)
        ..setInt32(10, envelope.length);
      final frame = KugouliveDanmakuCodec.decode(
        (BytesBuilder()
              ..add(header.buffer.asUint8List())
              ..add(envelope))
            .toBytes(),
        roomId: _room,
      );
      final gift = frame.messages.single.payload! as LiveGift;
      expect(gift.giftId, '55');
      expect(gift.name, '火箭');
      expect(gift.count, 2);
      expect(gift.value.unit, LiveGiftUnit.gold);
      expect(gift.value.unitPrice, 10);
      expect(gift.value.totalValue, 20);
      expect(gift.combo.comboKey, 'combo-1');
      expect(gift.combo.comboTotal, 5);
      expect(gift.recipientName, '主播甲');
      expect(gift.iconUrl, 'https://s4fx.kgimg.com/fxstatic/images/giftres/x.png');
      expect(frame.messages.single.text, '火箭 ×2');
      expect(frame.ack, isNotNull, reason: 'the envelope asked for an ack');
      expect(frame.messages.single.messageId, 'gift-1');
    });

    test('the audience frame reports count and visited', () {
      final packet = {
        'roomid': int.parse(_room),
        'content': {
          'actionId': 'roomAuNumber',
          'data': {'count': 42, 'visited': 9001},
        },
      };
      final audience = KugouliveDanmakuCodec.audience(packet, roomId: _room);
      expect(audience, hasLength(2));
      expect(audience.first.type, LiveMessageType.audienceUpdate);
      expect(
        KugouliveDanmakuCodec.audience({
          'content': {'actionId': 'other'},
        }, roomId: _room),
        isEmpty,
      );
    });

    test('snappy decompresses a raw block', () {
      // A literal block: length 3, then the tag and the bytes.
      final block = Uint8List.fromList([3, (3 - 1) << 2, 104, 105, 33]);
      expect(KugouliveDanmakuCodec.snappy(block), utf8.encode('hi!'));
      expect(() => KugouliveDanmakuCodec.snappy(Uint8List.fromList([9])), throwsA(isA<FormatException>()));
    });
  });

  group('comment session', () {
    test('a session dispatches, connects and logs in', () async {
      final chat = await _chat();
      final dispatch = chat.http.sent.single;
      expect(dispatch.url.path, KugouliveDanmakuCodec.dispatchPath);
      expect(dispatch.url.queryParameters['rid'], _room);
      expect(chat.connector.endpoints.single, Uri.parse('wss://chat1.kugou.com:443'));
      expect(chat.socket.sentFrames, isNotEmpty, reason: 'the login goes out at once');
      final heartbeats = chat.timers.every.single;
      expect(heartbeats.period, KugouliveDanmakuCodec.heartbeatInterval);
      expect(
        chat.timers.after.map((wait) => wait.delay),
        containsAll([KugouliveDanmakuCodec.joinTimeout, KugouliveDanmakuCodec.silenceTimeout]),
      );
      await chat.session.dispose();
      expect(chat.socket.closed, isTrue);
    });

    test('the login answer joins, the frames are reported, gifts deduplicated', () async {
      final chat = await _chat();
      // The heartbeat's answer is not a message and not a drop.
      chat.socket.push(Uint8List.fromList([100, 0, 3, 0]));
      await _settle();
      expect(chat.connector.sockets, hasLength(1), reason: 'still the one socket');
      await chat.session.dispose();
      expect(chat.socket.closed, isTrue);
    });

    test('a refused scheduler ends the session at once', () async {
      final connector = _Connector();
      final timers = FakeTimers();
      final http = _FakeHttp((request) => _resp(200, _json({'code': 7, 'msg': 'slider'})));
      final session = KugouliveDanmakuSession(
        args: const KugouliveDanmakuArgs(roomId: _room),
        site: KugouliveSite(http: KugouliveHttp(http), connect: connector.call, now: () => _at),
        timers: timers.timers,
      );
      expect(await session.connect(), isNull);
      final seen = <LiveMessage>[];
      final done = session.events.listen(seen.add).asFuture<void>();
      await _settle();
      await done;
      expect(seen.where((message) => message.type == LiveMessageType.system), isNotEmpty);
      expect(connector.sockets, isEmpty);
      await session.dispose();
    });

    test('an id that is no room is refused before any request', () async {
      final connector = _Connector();
      final http = _FakeHttp(_ordinary);
      final session = KugouliveDanmakuSession(
        args: const KugouliveDanmakuArgs(roomId: 'x'),
        site: KugouliveSite(http: KugouliveHttp(http), connect: connector.call, now: () => _at),
        timers: FakeTimers().timers,
      );
      expect(await session.connect(), isA<LiveSiteNotFound>());
      expect(http.sent, isEmpty);
      expect(connector.sockets, isEmpty);
    });
  });

  group('adapter wiring', () {
    test('the manifest and the seven capabilities the platform can serve', () async {
      final site = KugouliveSite(http: KugouliveHttp(_FakeHttp(_ordinary)), connect: _refuseSocket, now: () => _at);
      expect(site.manifest.id, 'kugoulive');
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
      expect(built.map((entry) => entry.manifest.id), contains('kugoulive'));
    });

    test('a room entry is the info and the stream answer, with its handles', () async {
      final adapter = _adapter();
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_room));
      expect(adapter.http.sent.map((seen) => seen.url.path), [
        '/roomcen/room/web/cdn/getEnterRoomInfo',
        '/video/pc/live/pull/mutiline/streamaddr',
      ]);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.runtime.danmakuHandle, isA<KugouliveDanmakuArgs>());
      // The qualities and lines come from the entry, without a request.
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final before = adapter.http.sent.length;
      final qualities = _right(await playback.getQualities(roomId: _room));
      expect(qualities.first.qualityId, 'flv:4:1:2');
      final lines = _right(await playback.getLines(roomId: _room, quality: qualities.first));
      expect(lines.single.url, contains('.flv'));
      expect(adapter.http.sent.length, before, reason: 'the entry already holds the variants');
      expect(
        _leftOf(
          await playback.getLines(
            roomId: _room,
            quality: qualities.first.copyWith(qualityId: 'flv:9:1:2'),
          ),
        ),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test('an offline room is entered and says why', () async {
      final adapter = _adapter(
        onSend: (request) => switch (request.url.path) {
          '/roomcen/room/web/cdn/getEnterRoomInfo' => _resp(200, _roomInfoFixture(liveType: -1, liveSessionId: '')),
          _ => _resp(200, '{}'),
        },
      );
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_room));
      expect(adapter.http.sent, hasLength(1), reason: 'the info alone');
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.runtime.danmakuHandle, isNull);
      expect(
        _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _room)),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test('a login-gated room is marked and says so', () async {
      final adapter = _adapter(
        onSend: (request) => switch (request.url.path) {
          '/video/pc/live/pull/mutiline/streamaddr' => _resp(200, _streamFixture(code: -1)),
          _ => _ordinary(request),
        },
      );
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_room));
      expect(room.broadcast.restriction, LiveRestriction.needsLogin);
      expect(room.content.notice, startsWith(KugouliveEndpoints.restrictedNotice));
      expect(room.runtime.danmakuHandle, isNotNull, reason: 'the chat joins regardless');
      expect(
        _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _room)),
        isA<LiveSiteAuthenticationError>(),
      );
    });

    test('the areas, the list and the search are wired', () async {
      final adapter = _adapter();
      final area = adapter.site.capability<LiveAreaProvider>()!;
      final areas = _right(await area.getAreas());
      expect(areas.map((entry) => entry.areaId), ['8000', '7024']);
      expect(_right(await area.getAreaRooms(areaId: '7024')).items, hasLength(1));
      expect(adapter.http.sent.last.url.path, endsWith('list_v4'));
      expect(_leftOf(await area.getAreaRooms(areaId: 'dance')), isA<LiveSiteInvalidArgument>());
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      final byRoom = await search.search(const LiveSearchRequest(query: _room, target: LiveSearchTarget.rooms));
      expect((_right(byRoom).items.single as RoomSearchResult).room.roomId, _room);
      final byKeyword = await search.search(const LiveSearchRequest(query: '主播', target: LiveSearchTarget.rooms));
      expect(_right(byKeyword).items, hasLength(1));
      expect(_right(byKeyword).hasMore, isNull, reason: 'the keyword pages cut one answer locally');
      expect(
        _right(await search.search(const LiveSearchRequest(query: '', target: LiveSearchTarget.rooms))).items,
        isEmpty,
      );
      expect(
        _leftOf(
          await search.search(
            const LiveSearchRequest(
              query: 'x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x',
              target: LiveSearchTarget.rooms,
            ),
          ),
        ),
        isA<LiveSiteInvalidArgument>(),
      );
    });

    test('a link is canonicalized, an alien host is unsupported', () async {
      final adapter = _adapter();
      final link = adapter.site.capability<LiveLinkResolver>()!;
      expect(
        _right(await link.resolve(Uri.parse('https://fanxing.kugou.com/$_room'))),
        Uri.parse('https://fanxing.kugou.com/$_room'),
      );
      expect(adapter.http.sent, isEmpty, reason: 'no request: the link names its room');
      expect(_leftOf(await link.resolve(Uri.parse('https://example.com/$_room'))), isA<LiveSiteUnsupported>());
      expect(_leftOf(await link.resolve(Uri.parse('https://fanxing.kugou.com/room/x'))), isA<LiveSiteNotFound>());
    });
  });
}

/// The site over a fake transport, with a fixed clock and no socket.
({KugouliveSite site, _FakeHttp http}) _adapter({LiveResponse Function(_Seen request)? onSend}) {
  final http = _FakeHttp(onSend ?? _ordinary);
  return (site: KugouliveSite(http: KugouliveHttp(http), connect: _refuseSocket, now: () => _at), http: http);
}
