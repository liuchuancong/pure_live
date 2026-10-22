// Test fakes re-create the platform's constructor shapes, whose naming rules
// the public surface's lints govern.
// ignore_for_file: unnecessary_type_name_in_constructor

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
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/looklive/api/looklive_endpoints.dart';
import 'package:live_sites/src/platforms/looklive/api/looklive_http.dart';
import 'package:live_sites/src/platforms/looklive/danmaku/looklive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/looklive/danmaku/looklive_danmaku_session.dart';
import 'package:live_sites/src/platforms/looklive/looklive_site.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_json.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

/// The clock of the tests: 2026-09-30, in the afternoon.
final DateTime _at = DateTime.parse('2026-09-30T14:00:00.000Z').toUtc();

const String _roomNo = '21623631';
const String _otherNo = '520520';
const String _userId = '3017728';
const String _sessionId = '310001';
const String _chatroom = '4506897415';
const String _sessionKey = '6ba7x8';

const String _mediaId = 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6';

String _json(Object? data) => jsonEncode(data);

String _envelope(Object? data, {int code = 200, String message = ''}) =>
    _json({'code': code, if (message.isNotEmpty) 'message': message, 'data': data});

String _hlsUrl({String scheme = 'https'}) =>
    '$scheme://wshls1b.live.126.net/live/$_mediaId/playlist.m3u8?wsSecret=abc&wsTime=17';

String _flvUrl({String scheme = 'http'}) => '$scheme://wsflv1b.live.126.net/live/$_mediaId.flv?wsSecret=abc&wsTime=17';

/// A video or voice list card.
Map<String, Object?> _card({
  String roomNo = _roomNo,
  String userId = _userId,
  String nick = '主播甲',
  String title = '晚间弹唱',
  int liveType = 1,
  String liveId = _sessionId,
  Object? popularity = 88000,
  Object? online = 1200,
  Object? type = 1,
  Object? liveUrl,
  Object? avatarUrl = 'https://img1.126.net/a.png',
}) => {
  'type': '1',
  'liveData': {
    'liveType': liveType,
    'liveId': liveId,
    'liveTitle': title,
    'liveCoverUrl': 'https://img1.126.net/cover.png',
    'popularity': popularity,
    'onlineNumber': online,
    'type': type,
    'liveUrl': liveUrl ?? {'hlsPullUrl': _hlsUrl(), 'httpPullUrl': _flvUrl()},
    'userInfo': {'liveRoomNo': roomNo, 'userId': userId, 'nickname': nick, 'avatarUrl': avatarUrl},
  },
};

String _listFixture({List<Object?>? items, Object? hasMore = true}) => _json({
  'code': 200,
  'data': {'itemList': items, 'hasMore': hasMore},
});

/// A `room/get/v3` answer of [roomId].
Map<String, Object?> _roomData({
  String roomId = _roomNo,
  int liveStatus = 1,
  int liveType = 1,
  Object? liveId,

  Object? chatroomId = _chatroom,
  bool anonymousMode = false,
  Object? startTime = 1727700000000,
  Object? streamType = 1,
  Object? liveUrl,
  Object? feeInfo,
  Object? anchor,
}) => {
  'liveStatus': liveStatus,
  if (anonymousMode) 'anonymousMode': true,
  'anchor':
      anchor ?? {'liveRoomNo': roomId, 'userId': _userId, 'nickName': '主播甲', 'avatarUrl': 'https://img1.126.net/a.png'},
  'roomInfo': {
    'id': liveId ?? _sessionId,
    'liveType': liveType,
    'title': '晚间弹唱',
    'liveCoverUrl': 'https://img1.126.net/cover.png',
    'liveStreamType': streamType,
    'startTime': startTime,
    'roomId': chatroomId,
    'liveUrl': liveUrl ?? {'hlsPullUrl': _hlsUrl(), 'httpPullUrl': _flvUrl()},
  },
  'feeInfo': ?feeInfo,
};

String _roomFixture({int code = 200, Map<String, Object?>? data}) => _json({'code': code, 'data': data ?? _roomData()});

/// The site's answers: the two lists, the room and the chat servers.
LiveResponse _api(_Seen request) {
  final path = request.url.path;
  if (path == LookliveEndpoints.videoListPath) {
    return _resp(200, _listFixture(items: [_card()]));
  }
  if (path == LookliveEndpoints.audioListPath) {
    return _resp(
      200,
      _listFixture(
        items: [_card(roomNo: _otherNo, userId: '8642000', nick: '唱见小乙', title: '晚安电台', liveType: 2, liveId: '310002')],
      ),
    );
  }
  if (path == LookliveEndpoints.roomPath) {
    return _resp(200, _roomFixture());
  }
  if (path == LookliveEndpoints.chatAddressPath) {
    return _resp(
      200,
      _envelope({
        'address': ['chatwl01.yunxinfw.com:443'],
      }),
    );
  }
  if (path == '/socket.io/1/') {
    return _resp(200, '$_sessionKey:25:60:websocket');
  }
  return _resp(404, 'nope');
}

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(body)));

final class _Seen {
  _Seen(LiveRequest request)
    : method = request.method,
      url = request.url,
      body = request.body,
      cancel = request.cancelToken;
  final String method;
  final Uri url;
  final String? body;

  /// The request's cancellation, for fakes that hang until it.
  final CancelToken cancel;
}

final class _FakeHttp implements LiveHttp {
  _FakeHttp(this.onSend);
  final FutureOr<LiveResponse> Function(_Seen request) onSend;
  final List<_Seen> sent = [];

  List<_Seen> get posts => sent.where((seen) => seen.method == 'POST').toList();

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

  LookliveTimers get timers => (after: _after, every: _every);

  Timer _after(Duration delay, void Function() callback) {
    after.add((delay: delay, callback: callback));
    return _IdleTimer();
  }

  Timer _every(Duration period, void Function(Timer timer) callback) {
    every.add((period: period, callback: callback));
    return _IdleTimer();
  }

  void fire({int index = 0}) => after[index].callback();

  void fireLast() => fire(index: after.length - 1);

  void ring({int index = 0}) => every[index].callback(_IdleTimer());
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

/// The chat of one run: a session, its socket (null when the run never got
/// one, as while a retry is still pending), its watches and its sockets.
Future<({LookliveDanmakuSession session, _FakeSocket? socket, FakeTimers timers, _Connector connector})> _chat({
  LiveResponse Function(_Seen request)? onSend,
}) async {
  final connector = _Connector();
  final timers = FakeTimers();
  final session = LookliveDanmakuSession(
    args: const LookliveDanmakuArgs(roomId: _roomNo, chatroomId: _chatroom),
    site: LookliveSite(http: LookliveHttp(_FakeHttp(onSend ?? _api)), connect: connector.call),
    now: () => _at,
    timers: timers.timers,
    random: Random(7),
  );
  expect(await session.connect(), isNull);
  for (var i = 0; i < 10 && connector.sockets.isEmpty; i++) {
    await _settle();
  }
  return (
    session: session,
    socket: connector.sockets.isEmpty ? null : connector.latest,
    timers: timers,
    connector: connector,
  );
}

/// The chat answers of the socket.io protocol.
String _answer13(int sid, int cid, {int? code, List<Object?>? r}) =>
    '3:::${_json({'sid': sid, 'cid': cid, 'code': ?code, 'r': ?r})}';

String _joined() => _answer13(13, 2, code: 200);

Map<String, Object?> _chatUser({
  Object? nickname = '观众甲',
  Object? userId = '888',
  Object? liveLevel = 3,
  Object? fanClubLevel,
  Object? fanClubName,
  Object? fanClubInfo,
}) => {
  'nickname': nickname,
  'userId': userId,
  'liveLevel': liveLevel,
  'fanClubLevel': ?fanClubLevel,
  'fanClubName': ?fanClubName,
  'fanClubInfo': ?fanClubInfo,
};

/// Marks the `custom` a message map leaves out altogether.
const Object _absentCustom = Object();

Map<String, Object?> _chatMessage({
  Object? id = 'm-1',
  Object? type = 0,
  Object? attach = '大家好',
  Object? custom = _absentCustom,
  Object? from = 'guest-9',
  Object? time = 1727700000000,
  Object? reason,
}) => {
  '1': id,
  '2': type,
  '3': attach,
  '4': identical(custom, _absentCustom)
      ? _json({
          'bizName': 'iplay',
          'content': {'user': _chatUser(fanClubLevel: 2, fanClubName: '灯牌'), 'commonCtrl': <String, Object?>{}},
        })
      : custom,
  '20': time,
  'reason': ?reason,
  '21': from,
};

/// A `chat/address` answer with every kind of address entry.
const String _addressFixture =
    '{"code":200,"data":{"address":["CHATWL01.yunxinfw.com:443","chatwl01.yunxinfw.com:443",'
    '"pircpppfile068.chat.yunxinfw.com:443","not an address","host::443","host:0","host:99999",42]}}';

void main() {
  group('weapi envelope', () {
    test('the params open twice onto the payload, the encSecKey is a constant', () {
      final body = LookliveEndpoints.formBody(LookliveEndpoints.chatAddressPayload(_roomNo));
      final fields = Uri.splitQueryString(body);
      const iv = '0102030405060708';
      final outer = Aes128Cbc.decrypt(
        base64Decode(fields['params']!),
        key: utf8.encode('0123456789abcdef'),
        iv: utf8.encode(iv),
      );
      final inner = Aes128Cbc.decrypt(
        base64Decode(utf8.decode(outer)),
        key: utf8.encode('0CoJUm6Qyw8W8jud'),
        iv: utf8.encode(iv),
      );
      expect(jsonDecode(utf8.decode(inner)), {'liveRoomNo': _roomNo, 'os': 0});
      expect(LookliveEndpoints.encSecKey, fields['encSecKey']);
      expect(LookliveEndpoints.encSecKey.length, 256);
      expect(RegExp(r'^[0-9a-f]{256}$').hasMatch(LookliveEndpoints.encSecKey), isTrue);
      expect(LookliveEndpoints.envelope({'a': 1})['encSecKey'], LookliveEndpoints.encSecKey);
    });
  });

  group('answers and readers', () {
    test('a status says what kind of answer it is', () {
      void expectKind(int status, LookliveFailureKind kind) {
        try {
          LookliveJson.checkStatus(status, 'x');
          fail('no throw for $status');
        } on LookliveFailure catch (failure) {
          expect(failure.kind, kind);
        }
      }

      expectKind(401, LookliveFailureKind.riskControl);
      expectKind(403, LookliveFailureKind.riskControl);
      expectKind(404, LookliveFailureKind.notFound);
      expectKind(429, LookliveFailureKind.rateLimited);
      for (final status in [301, 500, 503]) {
        expectKind(status, LookliveFailureKind.network);
      }
      LookliveJson.checkStatus(200, 'x');
    });

    test('the body is bounded and must be JSON', () {
      expect(() => LookliveJson.json('<html>', 'x', 200), throwsA(predicate((e) => '$e'.contains('not JSON'))));
      expect(
        () => LookliveJson.json('{"a":"${'x' * 2100000}"}', 'x', 200),
        throwsA(predicate((e) => '$e'.contains('answer over'))),
      );
      expect(LookliveJson.json('{"a":1}', 'x', 200), {'a': 1});
    });

    test('the envelope maps its codes, the room ones with their reasons', () {
      void expectKind(String body, LookliveFailureKind kind, {bool room = false, int status = 200, String? reason}) {
        try {
          LookliveJson.data(body, status: status, what: 'x', room: room);
          fail('no throw for $body');
        } on LookliveFailure catch (failure) {
          expect(failure.kind, kind);
        }
      }

      expectKind(_json({'code': 200, 'data': 'no'}), LookliveFailureKind.apiChanged, reason: 'data must be an object');
      expectKind(_json({'code': 404, 'message': '无资源'}), LookliveFailureKind.notFound);
      expectKind(_json({'code': 424, 'message': '请在APP中查看'}), LookliveFailureKind.riskControl);
      expectKind(_json({'code': 424, 'message': '请在APP中查看'}), LookliveFailureKind.streamUnavailable, room: true);
      expectKind(_json({'code': 555}), LookliveFailureKind.streamUnavailable, room: true);
      expectKind(_json({'code': 555}), LookliveFailureKind.riskControl);
      expectKind(_json({'code': 520}), LookliveFailureKind.riskControl, room: true);
      expectKind(_json({'code': 522}), LookliveFailureKind.riskControl, room: true);
      expectKind(_json({'code': 500}), LookliveFailureKind.apiChanged, room: true);
      expectKind(_json({'code': 'no'}), LookliveFailureKind.apiChanged);
      expect(LookliveJson.data(_envelope({'a': 1}), status: 200, what: 'x'), {'a': 1});
    });

    test('ids, counts and times are read strictly', () {
      expect(LookliveJson.id(123, 'x'), '123');
      expect(LookliveJson.id(' 123 ', 'x'), '123');
      expect(() => LookliveJson.id(0, 'x'), throwsA(anything));
      expect(() => LookliveJson.id('0123', 'x'), throwsA(anything));
      expect(LookliveJson.optionalId(4506897415), '4506897415');
      expect(LookliveJson.optionalId('nope'), '');
      expect(LookliveJson.count('42', 'x'), 42);
      expect(LookliveJson.count(null, 'x'), isNull);
      expect(() => LookliveJson.count(-1, 'x'), throwsA(anything));
      expect(LookliveJson.time(1727700000000), DateTime.fromMillisecondsSinceEpoch(1727700000000, isUtc: true));
      expect(LookliveJson.time(0), isNull);
      // Every positive number is read as milliseconds, 10 digits included.
      expect(LookliveJson.time(1727700000), DateTime.fromMillisecondsSinceEpoch(1727700000, isUtc: true));
      expect(LookliveJson.picture('http://img1.126.net/a.png'), 'https://img1.126.net/a.png');
      expect(LookliveJson.picture('ftp://img1.126.net/a.png'), '');
      expect(LookliveJson.picture('https://u:p@img1.126.net/a.png'), '');
    });

    test('a ticket is a fee without a session key', () {
      expect(LookliveJson.paid({'fee': true}), isTrue);
      expect(LookliveJson.paid({'fee': 6}), isTrue);
      expect(LookliveJson.paid({'fee': true, 'sessionKey': 'bought'}), isFalse);
      expect(LookliveJson.paid({'fee': 0}), isFalse);
      expect(LookliveJson.paid(null), isFalse);
      expect(LookliveJson.paid('nope'), isFalse);
    });
  });

  group('lists', () {
    test('the cards of one kind are read, the other kinds skipped', () {
      final page = LookliveRoomParser.directory(
        _listFixture(
          items: [
            _card(),
            _card(roomNo: _otherNo, userId: '8642000', nick: '唱见小乙', title: '晚安电台', liveType: 2, liveId: '310002'),
            {'type': '2', 'liveData': <String, Object?>{}},
            {'type': '1'},
            _card(),
          ],
        ),
        kind: LookliveKind.video,
      );
      expect(page.rooms.map((room) => room.roomId), [_roomNo], reason: 'the other kind and repeats skipped');
      expect(page.rooms.single.state, LookliveState.live);
      expect(page.rooms.single.mediaChecked, isTrue);
      expect(page.hasMore, isTrue);
    });

    test('a voice card is read by the voice list', () {
      final page = LookliveRoomParser.directory(
        _listFixture(
          items: [_card(roomNo: _otherNo, userId: '8642000', nick: '唱见小乙', title: '晚安电台', liveType: 2)],
        ),
        kind: LookliveKind.audio,
      );
      expect(page.rooms.single.kind, LookliveKind.audio);
      expect(page.rooms.single.nick, '唱见小乙');
    });

    test('a broken card costs only itself, unless none is usable', () {
      final page = LookliveRoomParser.directory(
        _listFixture(items: [_card(), _card(popularity: -1)]),
        kind: LookliveKind.video,
      );
      expect(page.rooms, hasLength(1));
      expect(
        () => LookliveRoomParser.directory(_listFixture(items: [_card(popularity: -1)]), kind: LookliveKind.video),
        throwsA(predicate((e) => '$e'.contains('unreadable entries, no room'))),
      );
    });

    test('a list that is not one, or carries too much, is api-changed', () {
      for (final body in [
        _listFixture(items: List.filled(101, _card())),
        _json({
          'code': 200,
          'data': {
            'itemList': [_card()],
            'hasMore': 'yes',
          },
        }),
        _json({
          'code': 200,
          'data': {'itemList': 'no', 'hasMore': true},
        }),
        _json({
          'code': 200,
          'data': {
            'itemList': [_card()],
          },
        }),
      ]) {
        expect(
          () => LookliveRoomParser.directory(body, kind: LookliveKind.video),
          throwsA(isA<LookliveFailure>()),
          reason: body,
        );
      }
    });

    test('a list past its end is an empty last page', () {
      final page = LookliveRoomParser.directory(
        _json({
          'code': 200,
          'data': {'itemList': null, 'hasMore': false},
        }),
        kind: LookliveKind.video,
      );
      expect(page.rooms, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('a room number must be 2 to 18 digits', () {
      // The unreadable card costs the page its last room (api-changed).
      expect(
        () => LookliveRoomParser.directory(
          _listFixture(items: [_card(roomNo: '0123')]),
          kind: LookliveKind.video,
        ),
        throwsA(predicate((e) => '$e'.contains('unreadable entries, no room'))),
      );
    });

    test('a card carries its audience apart', () {
      final room = LookliveRoomParser.directory(_listFixture(items: [_card()]), kind: LookliveKind.video).rooms.single;
      expect(room.currentViewers, 1200);
      expect(room.popularity, 88000);
      final view = LookliveRoomParser.liveRoom(room);
      expect(view.audience.onlineViewers, 1200);
      expect(view.audience.popularity, 88000);
      expect(view.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      // A card without an audience leads with nothing.
      final bare = LookliveRoomParser.directory(
        _listFixture(items: [_card(popularity: null, online: null)]),
        kind: LookliveKind.video,
      ).rooms.single;
      expect(LookliveRoomParser.liveRoom(bare).audience.primaryMetric, LiveAudienceMetricType.unknown);
    });
  });

  group('room answer', () {
    test('a live room is read whole', () {
      final room = LookliveRoomParser.room(_roomFixture(), roomId: _roomNo);
      expect(room.roomId, _roomNo);
      expect(room.userId, _userId);
      expect(room.sessionId, _sessionId);
      expect(room.title, '晚间弹唱');
      expect(room.nick, '主播甲');
      expect(room.kind, LookliveKind.video);
      expect(room.state, LookliveState.live);
      expect(room.startedAt, DateTime.fromMillisecondsSinceEpoch(1727700000000, isUtc: true));
      expect(room.chatroomId, _chatroom);
      expect(room.anonymousMode, isFalse);
      expect(room.paid, isFalse);
      expect(room.mediaChecked, isTrue);
      expect(room.variants.map((variant) => variant.id), [LookliveEndpoints.hlsId, LookliveEndpoints.flvId]);
      expect(room.danmakuArgs, const LookliveDanmakuArgs(roomId: _roomNo, chatroomId: _chatroom));
    });

    test('a refresh reads no streams, an offline room no start', () {
      final refresh = LookliveRoomParser.room(_roomFixture(), roomId: _roomNo, withMedia: false);
      expect(refresh.variants, isEmpty);
      expect(refresh.hasAddress, isTrue);
      expect(refresh.mediaChecked, isFalse);
      final offline = LookliveRoomParser.room(
        _roomFixture(data: _roomData(liveStatus: 0, startTime: null)),
        roomId: _roomNo,
      );
      expect(offline.state, LookliveState.offline);
      expect(offline.startedAt, isNull);
      expect(offline.danmakuArgs, isNull);
    });

    test('the live statuses are told apart', () {
      LookliveState stateOf(int status) => LookliveRoomParser.room(
        _roomFixture(data: _roomData(liveStatus: status)),
        roomId: _roomNo,
      ).state;
      expect(stateOf(1), LookliveState.live);
      expect(stateOf(0), LookliveState.offline);
      expect(stateOf(-1), LookliveState.offline);
      expect(stateOf(-2), LookliveState.offline);
      expect(stateOf(-10), LookliveState.banned);
      expect(stateOf(-4), LookliveState.banned);
      expect(stateOf(7), LookliveState.unknown);
    });

    test('the answer must be about the asked room, of a known kind', () {
      expect(
        () => LookliveRoomParser.room(_roomFixture(), roomId: _otherNo),
        throwsA(predicate((e) => '$e'.contains('asked $_otherNo, got $_roomNo'))),
      );
      expect(
        () => LookliveRoomParser.room(_roomFixture(data: _roomData(liveType: 9)), roomId: _roomNo),
        throwsA(predicate((e) => '$e'.contains('liveType'))),
      );
    });

    test('a voice room is of the voice area', () {
      final room = LookliveRoomParser.room(_roomFixture(data: _roomData(liveType: 2)), roomId: _roomNo);
      expect(room.kind, LookliveKind.audio);
      final view = LookliveRoomParser.liveRoom(room);
      expect(view.area?.areaId, LookliveEndpoints.audioAreaId);
      expect(view.area?.areaName, LookliveEndpoints.audioAreaName);
      expect(view.area?.parentAreaId, 'looklive');
    });

    test('a ticket, an anonymous room and a missing chatroom are carried', () {
      final paid = LookliveRoomParser.room(
        _roomFixture(data: _roomData(feeInfo: {'fee': 6, 'sessionKey': null})),
        roomId: _roomNo,
      );
      expect(paid.paid, isTrue);
      expect(paid.restriction, LiveRestriction.paid);
      final view = LookliveRoomParser.liveRoom(paid);
      expect(view.content.notice, contains(LookliveEndpoints.paidNotice));
      final anonymous = LookliveRoomParser.room(_roomFixture(data: _roomData(anonymousMode: true)), roomId: _roomNo);
      expect(anonymous.anonymousMode, isTrue);
      final noChat = LookliveRoomParser.room(
        _roomFixture(data: _roomData(chatroomId: '')),
        roomId: _roomNo,
      );
      expect(noChat.chatroomId, '');
      expect(noChat.danmakuArgs, isNull);
    });

    test('the v2 room carries what the lists and the room page show', () {
      // Room entry (withData) keeps the room as the stream handle.
      final view = LookliveRoomParser.liveRoom(
        LookliveRoomParser.room(_roomFixture(), roomId: _roomNo),
        withData: true,
      );
      expect(view.platform, 'looklive');
      expect(view.roomId, _roomNo);
      expect(view.content.title, '晚间弹唱');
      expect(view.content.coverUrl, 'https://img1.126.net/cover.png');
      expect(view.content.notice, contains(LookliveEndpoints.chatNotice));
      expect(view.anchor?.anchorId, _userId);
      expect(view.anchor?.name, '主播甲');
      expect(view.anchor?.avatarUrl, 'https://img1.126.net/a.png');
      expect(view.anchor?.liveStatus, LiveStatus.live);
      expect(view.broadcast.liveStatus, LiveStatus.live);
      expect(view.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1727700000000, isUtc: true));
      expect(view.broadcast.restriction, LiveRestriction.none);
      expect(view.links.webUrl, LookliveEndpoints.link(_roomNo));
      expect(view.runtime.streamHandle, isA<LookliveRoom>());
      expect(view.runtime.danmakuHandle, isA<LookliveDanmakuArgs>());
    });

    test('an avatar falls back to the cover, a banned room is marked', () {
      final bare = LookliveRoomParser.room(
        _roomFixture(
          data: _roomData(
            liveStatus: -10,
            anchor: {'liveRoomNo': _roomNo, 'userId': _userId, 'nickName': '主播甲', 'avatarUrl': ''},
          ),
        ),
        roomId: _roomNo,
      );
      final view = LookliveRoomParser.liveRoom(bare);
      expect(view.anchor?.avatarUrl, 'https://img1.126.net/cover.png');
      expect(view.anchor?.liveStatus, LiveStatus.banned);
      expect(view.broadcast.liveStatus, LiveStatus.banned);
      expect(view.content.notice, contains(LookliveEndpoints.bannedNotice));
    });
  });

  group('enrichment', () {
    LookliveRoom cardOf() =>
        LookliveRoomParser.directory(_listFixture(items: [_card()]), kind: LookliveKind.video).rooms.single;

    test('a live answer completes itself from the card of the same broadcast', () {
      final card = cardOf();
      final answer = LookliveRoomParser.room(
        _roomFixture(data: _roomData(liveUrl: {'hlsPullUrl': '', 'httpPullUrl': ''})),
        roomId: _roomNo,
      );
      expect(answer.currentViewers, isNull);
      final merged = answer.enrich(card);
      expect(merged.nick, card.nick, reason: 'the answer already names the anchor');
      expect(merged.currentViewers, card.currentViewers);
      expect(merged.popularity, card.popularity);
      expect(merged.variants, card.variants, reason: "the same broadcast keeps the card's streams");
      expect(merged.state, LookliveState.live);
      expect(merged.chatroomId, _chatroom, reason: "state, ticket and chat stay the answer's");
    });

    test('another broadcast keeps nothing, and a card of another room neither', () {
      final card = cardOf();
      final otherSession = LookliveRoomParser.room(
        _roomFixture(
          data: _roomData(liveId: '999', liveUrl: {'hlsPullUrl': '', 'httpPullUrl': ''}),
        ),
        roomId: _roomNo,
      );
      expect(otherSession.enrich(card).currentViewers, isNull);
      final offline = LookliveRoomParser.room(_roomFixture(data: _roomData(liveStatus: 0)), roomId: _roomNo);
      expect(offline.enrich(card).currentViewers, isNull);
    });

    test('a stream type 50 room without addresses is app-only', () {
      final appOnly = LookliveRoomParser.room(
        _roomFixture(data: _roomData(streamType: 50, liveUrl: {'hlsPullUrl': '', 'httpPullUrl': ''})),
        roomId: _roomNo,
        withMedia: false,
      );
      expect(appOnly.isAppOnly, isTrue);
      expect(appOnly.restriction, LiveRestriction.appOnly);
      expect(LookliveRoomParser.liveRoom(appOnly).content.notice, contains(LookliveEndpoints.appOnlyNotice));
      final view = LookliveRoomParser.liveRoom(appOnly, withData: true);
      expect((view.runtime.streamHandle! as LookliveRoom).streamError?.kind, LookliveFailureKind.streamUnavailable);
    });
  });

  group('streams', () {
    test('a media address must be the netease cdn of a live stream', () {
      expect(LookliveRoomParser.mediaUri(_hlsUrl(), format: LiveStreamFormat.hls), Uri.parse(_hlsUrl()));
      expect(
        LookliveRoomParser.mediaUri(_flvUrl(), format: LiveStreamFormat.flv),
        Uri.parse(_flvUrl(scheme: 'https')),
        reason: 'http is upgraded',
      );
      void bad(String url, LiveStreamFormat format, {String? reason}) {
        expect(
          () => LookliveRoomParser.mediaUri(url, format: format),
          throwsA(isA<LookliveFailure>()),
          reason: reason ?? url,
        );
      }

      bad(_hlsUrl(scheme: 'ftp'), LiveStreamFormat.hls);
      bad('https://evil.com/live/$_mediaId/playlist.m3u8', LiveStreamFormat.hls);
      bad('https://wshls1b.other.126.net/live/$_mediaId/playlist.m3u8', LiveStreamFormat.hls);
      bad('https://wshls1b.live.126.net:8443/live/$_mediaId/playlist.m3u8', LiveStreamFormat.hls);
      bad('https://u:p@wshls1b.live.126.net/live/$_mediaId/playlist.m3u8', LiveStreamFormat.hls);
      bad('https://wshls1b.live.126.net/live/$_mediaId/playlist.m3u8#f', LiveStreamFormat.hls);
      bad('https://wshls1b.live.126.net/live/$_mediaId/playlist.m3u8?${'x' * 2049}', LiveStreamFormat.hls);
      bad('https://wshls1b.live.126.net/live/NOHEX/playlist.m3u8', LiveStreamFormat.hls);
      bad('https://wshls1b.live.126.net/live/$_mediaId/other.m3u8', LiveStreamFormat.hls);
      bad(_hlsUrl(), LiveStreamFormat.flv, reason: 'an hls path is no flv stream');
    });

    test('a bad address costs only its stream', () {
      final room = LookliveRoomParser.directory(
        _listFixture(
          items: [
            _card(liveUrl: {'hlsPullUrl': 'https://evil.com/x.m3u8', 'httpPullUrl': _flvUrl()}),
          ],
        ),
        kind: LookliveKind.video,
      ).rooms.single;
      expect(room.variants, hasLength(1));
      expect(room.variants.single.format, LiveStreamFormat.flv);
      expect(room.hasAddress, isTrue, reason: 'the card did carry an address, valid or not');
      final noMedia = LookliveRoomParser.room(
        _roomFixture(data: _roomData(liveUrl: 'not an object')),
        roomId: _roomNo,
      );
      expect(noMedia.variants, isEmpty);
      expect(noMedia.hasAddress, isFalse);
    });

    test('the qualities are one per stream, hls first, and so are the lines', () {
      final room = LookliveRoomParser.room(_roomFixture(), roomId: _roomNo);
      final qualities = LookliveRoomParser.qualities(room);
      expect(qualities.map((quality) => quality.qualityId), [LookliveEndpoints.hlsId, LookliveEndpoints.flvId]);
      expect(qualities.first.label, LookliveEndpoints.hlsQualityLabel);
      expect(qualities.last.label, LookliveEndpoints.flvQualityLabel);

      final hls = LookliveRoomParser.line(room, LookliveEndpoints.hlsId);
      expect(hls.url, _hlsUrl());
      expect(hls.format, LiveStreamFormat.hls);
      expect(hls.formatSource, LivePlayFormatSource.declared);
      expect(hls.lineLabel, 'wshls1b.live.126.net');
      expect(hls.lease, isNull, reason: 'the addresses carry no signature or expiry');
      expect(hls.headers, LookliveEndpoints.mediaHeaders(_roomNo));
      expect(hls.headers['referer'], LookliveEndpoints.link(_roomNo));
      expect(hls.headers['origin'], LookliveEndpoints.origin);
      final flv = LookliveRoomParser.line(room, LookliveEndpoints.flvId);
      expect(flv.url, _flvUrl(scheme: 'https'));
      expect(flv.format, LiveStreamFormat.flv);

      expect(
        () => LookliveRoomParser.line(room, '720p'),
        throwsA(predicate((e) => '$e'.contains('not a LOOK Live quality'))),
      );
      expect(() => LookliveRoomParser.line(room, LookliveEndpoints.hlsId), returnsNormally);
      final withoutFlv = LookliveRoomParser.room(
        _roomFixture(data: _roomData(liveUrl: {'hlsPullUrl': _hlsUrl()})),
        roomId: _roomNo,
      );
      expect(
        () => LookliveRoomParser.line(withoutFlv, LookliveEndpoints.flvId),
        throwsA(predicate((e) => '$e'.contains('has no ${LookliveEndpoints.flvId}'))),
      );
    });
  });

  group('chat servers', () {
    test('the usable addresses, lower-cased and once each', () {
      final addresses = LookliveRoomParser.chatAddresses(_addressFixture);
      expect(addresses, ['chatwl01.yunxinfw.com:443', 'pircpppfile068.chat.yunxinfw.com:443']);
      expect(
        LookliveDanmakuCodec.endpoints(addresses).first,
        Uri.parse('wss://chatwl01.yunxinfw.com:443/socket.io/1/websocket/'),
      );
    });

    test('no usable address is api-changed, no resource is not-found', () {
      expect(
        () => LookliveRoomParser.chatAddresses(
          _envelope({
            'address': ['nope'],
          }),
        ),
        throwsA(predicate((e) => '$e'.contains('no usable address'))),
      );
      expect(
        () => LookliveRoomParser.chatAddresses(_envelope({'address': 'no'})),
        throwsA(predicate((e) => '$e'.contains('address is'))),
      );
      try {
        LookliveRoomParser.chatAddresses(_envelope(null, code: 404, message: '无资源'));
        fail('no throw');
      } on LookliveFailure catch (failure) {
        expect(failure.kind, LookliveFailureKind.notFound);
      }
    });
  });

  group('links', () {
    test('a room link is read for its number', () {
      expect(LookliveEndpoints.roomIdFromUrl('https://look.163.com/live?id=$_roomNo'), _roomNo);
      expect(LookliveEndpoints.roomIdFromUrl('https://LOOK.163.COM/live?id=$_roomNo'), _roomNo);
      expect(LookliveEndpoints.roomIdFromUrl('http://look.163.com/live?id=$_roomNo'), _roomNo);
      expect(LookliveEndpoints.roomIdFromUrl('https://look.163.com:443/live?id=$_roomNo'), _roomNo);
      expect(LookliveEndpoints.roomIdFromUrl('https://look.163.com/live?id=$_roomNo&position=3'), _roomNo);
      expect(LookliveEndpoints.roomIdFromUrl('https://look.163.com/LIVE?id=$_roomNo'), _roomNo);
      expect(LookliveEndpoints.roomIdOf('  $_roomNo  '), _roomNo);
      expect(LookliveEndpoints.roomIdOf('https://look.163.com/live?id=$_roomNo'), _roomNo);
      expect(LookliveEndpoints.roomIdOf('not a room'), isNull);
    });

    test('anything else is no room link', () {
      for (final bad in [
        'https://look.163.com/live?id=0123',
        'https://look.163.com/live?id=$_roomNo&id=1',
        'https://look.163.com/live?id=1',
        'https://look.163.com/other?id=$_roomNo',
        'https://look.163.com/live/room?id=$_roomNo',
        'https://look.163.com/live',
        'https://evil.com/live?id=$_roomNo',
        'https://u:l@look.163.com/live?id=$_roomNo',
        'https://look.163.com:8080/live?id=$_roomNo',
        'https://look.163.com/live?id=$_roomNo#f',
        'ftp://look.163.com/live?id=$_roomNo',
        'https://look.163.com/live?id=$_roomNo&x=\x00',
      ]) {
        expect(LookliveEndpoints.roomIdFromUrl(bad), isNull, reason: bad);
      }
    });
  });

  group('chat protocol', () {
    test('a guest identity is nimanon and three guids', () {
      final guest = LookliveGuest.random(Random(7));
      expect(guest.account, startsWith('nimanon_'));
      expect(guest.account.substring('nimanon_'.length).length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(guest.deviceId), isTrue);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(guest.session), isTrue);
    });

    test('the arguments must name a room and a chatroom', () {
      expect(
        LookliveDanmakuCodec.checked(const LookliveDanmakuArgs(roomId: _roomNo, chatroomId: _chatroom)),
        const LookliveDanmakuArgs(roomId: _roomNo, chatroomId: _chatroom),
      );
      for (final bad in [
        const LookliveDanmakuArgs(roomId: 'abc', chatroomId: _chatroom),
        const LookliveDanmakuArgs(roomId: _roomNo, chatroomId: '0123'),
        // 16 digits: a chatroom id the login cannot carry as a JSON number.
        const LookliveDanmakuArgs(roomId: _roomNo, chatroomId: '9999999999999999'),
      ]) {
        expect(LookliveDanmakuCodec.checked(bad), isNull, reason: '$bad');
      }
    });

    test('the login names the guest, the chatroom and whether it is again', () {
      const guest = LookliveGuest(account: 'nimanon_a', deviceId: 'd1', session: 's1');
      final first = jsonDecode(
        LookliveDanmakuCodec.login(chatroomId: _chatroom, guest: guest, serial: 1).substring('3:::'.length),
      ) as Map<String, Object?>;
      expect(first, {
        'SID': 13,
        'CID': 2,
        'SER': 1,
        'Q': [
          {'t': 'byte', 'v': 1},
          {
            't': 'Property',
            'v': {
              '1': LookliveDanmakuCodec.appKey,
              '2': 'nimanon_a',
              '3': 'd1',
              '5': int.parse(_chatroom),
              '8': 0,
              '20': LookliveDanmakuCodec.guestNick,
              '21': LookliveDanmakuCodec.guestAvatar,
              '26': 's1',
              '38': 1,
            },
          },
          {
            't': 'Property',
            'v': {
              '4': LookliveDanmakuCodec.os,
              '6': LookliveDanmakuCodec.sdkVersion,
              '8': 1,
              '9': LookliveDanmakuCodec.protocolVersion,
              '13': 'd1',
              '18': LookliveDanmakuCodec.appKey,
              '19': 'nimanon_a',
              '24': LookliveDanmakuCodec.browser,
              '26': 's1',
              '1000': '',
            },
          },
        ],
      });
      final again = jsonDecode(
        LookliveDanmakuCodec.login(
          chatroomId: _chatroom,
          guest: guest,
          serial: 2,
          again: true,
        ).substring('3:::'.length),
      ) as Map<String, Object?>;
      final questions = (again['Q']! as List<Object?>).cast<Map<String, Object?>>();
      expect((questions[1]['v']! as Map<String, Object?>)['8'], 1, reason: 'the chatroom appLogin flips');
      expect((questions[2]['v']! as Map<String, Object?>)['8'], 0);
    });

    test('the handshake names the session, the transports must carry websocket', () {
      expect(LookliveDanmakuCodec.sessionOf('$_sessionKey:25:60:websocket,xhr-polling'), _sessionKey);
      void bad(String text, {int status = 200}) {
        expect(
          () => LookliveDanmakuCodec.sessionOf(text, status: status),
          throwsA(isA<FormatException>()),
          reason: text,
        );
      }

      bad('nope', status: 301);
      bad('short:25:60');
      bad('bad id!:25:60:websocket');
      bad('$_sessionKey:25:60:xhr-polling');
      final endpoint = Uri.parse('wss://chatwl01.yunxinfw.com:443/socket.io/1/websocket/');
      final handshake = LookliveDanmakuCodec.handshakeUrl(endpoint, roomId: _roomNo, now: _at);
      expect(handshake.scheme, 'https');
      expect(handshake.host, 'chatwl01.yunxinfw.com');
      expect(handshake.path, '/socket.io/1/');
      expect(handshake.query, 't=${_at.millisecondsSinceEpoch}');
      expect(
        LookliveDanmakuCodec.socketUrl(endpoint, _sessionKey),
        Uri.parse('wss://chatwl01.yunxinfw.com:443/socket.io/1/websocket/$_sessionKey'),
      );
      final ws = LookliveDanmakuCodec.handshakeUrl(
        Uri.parse('ws://chatwl01.yunxinfw.com:443/socket.io/1/websocket/'),
        roomId: _roomNo,
        now: _at,
      );
      expect(ws.scheme, 'http', reason: 'a ws endpoint hands its handshake over http');
      expect(LookliveDanmakuCodec.socketHeaders, {'origin': LookliveEndpoints.origin, 'user-agent': 'Mozilla/5.0'});
    });

    LookliveDanmakuFrame frame(Object? text, {bool anonymousMode = false}) =>
        LookliveDanmakuCodec.decode(text, anonymousMode: anonymousMode);

    test('the socket.io packets are told apart, echoed and acked', () {
      expect(frame('1::').opened, isTrue);
      expect(frame('2::').replies, ['2::'], reason: 'the heartbeat is echoed');
      expect(frame('0::').dropped, isTrue);
      expect(frame('7:::boom').dropped, isTrue);
      expect(frame(utf8.encode('1::')).opened, isTrue, reason: 'a binary frame is read as utf-8');
      expect(LookliveDanmakuCodec.decode(42), LookliveDanmakuFrame.empty);
      // A message that asked for an ack gets one, with `+` none.
      final acked = frame('3:5::${_json({'sid': 13, 'cid': 2, 'code': 200})}');
      expect(acked.joined, isTrue);
      expect(acked.replies, ['6:::5']);
      expect(
        frame('3:5+::${_json({'sid': 13, 'cid': 2, 'code': 200})}').replies,
        isEmpty,
        reason: 'the + already answered it',
      );
      // A packet for another endpoint is left alone.
      expect(frame('3:::other:{"sid":13,"cid":2,"code":200}').joined, isFalse);
    });

    test('a framed payload carries several packets', () {
      const first = '1::';
      const second = '2::';
      const framed = '\ufffd${first.length}\ufffd$first\ufffd${second.length}\ufffd$second';
      final result = frame(framed);
      expect(result.opened, isTrue);
      expect(result.replies, ['2::']);
      expect(frame('\ufffdnope\ufffd1::').opened, isFalse, reason: 'a broken length ends the framing');
    });

    test('the login is joined by its answer, refused by its code', () {
      expect(frame(_joined()).joined, isTrue);
      final refused = frame(_answer13(13, 2, code: 404));
      expect(refused.joined, isFalse);
      expect(refused.refusal, 404);
      expect(frame(_answer13(13, 2)).refusal, 0, reason: 'no code reads as 0');
    });

    test('a kick names its reason', () {
      expect(frame(_answer13(13, 3, code: 200, r: [2])).kicked, 2);
      expect(frame(_answer13(13, 3, code: 200)).kicked, 0);
      expect(frame(_answer13(13, 3, code: 500, r: [2])).kicked, isNull, reason: 'only an answer of 200 kicks');
    });

    test('a notification wraps the chatroom message', () {
      final wrapped = frame(
        _answer13(
          4,
          10,
          code: 200,
          r: [
            'x',
            {
              'headerPacket': {'sid': 13, 'cid': 7},
              'body': [_chatMessage()],
            },
          ],
        ),
      );
      expect(wrapped.messages.single.text, '大家好');
      expect(frame(_answer13(4, 10, code: 200, r: ['x'])).messages, isEmpty);
    });

    test('a chat line is read with its sender', () {
      final message = frame(_answer13(13, 7, code: 200, r: [_chatMessage()])).messages.single;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, '大家好');
      expect(message.effectiveSender.userName, '观众甲');
      expect(message.effectiveSender.userId, '888');
      expect(message.effectiveSender.userLevel, '3');
      expect(message.effectiveSender.fanBadgeLevel, '2');
      expect(message.effectiveSender.fanBadgeName, '灯牌');
      expect(message.messageId, 'm-1');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1727700000000));
    });

    test('a chat line of the short-keyed custom is expanded', () {
      final shortKeyed = _chatMessage(
        custom: _json({
          'sp': 1,
          'bizName': 'iplay',
          'c': {
            'bizName': 'iplay',
            'u': {'n': '观众乙', 'i': '999', 'l': 4},
          },
        }),
      );
      final message = frame(_answer13(13, 7, code: 200, r: [shortKeyed])).messages.single;
      expect(message.text, '大家好');
      expect(message.effectiveSender.userName, '观众乙');
      expect(message.effectiveSender.userId, '999');
      expect(message.effectiveSender.userLevel, '4');
    });

    test('an anonymous room masks the name, the fan club falls back', () {
      final masked = frame(_answer13(13, 7, code: 200, r: [_chatMessage()]), anonymousMode: true).messages.single;
      expect(masked.effectiveSender.userName, '观***');
      final fallback = _chatMessage(
        custom: _json({
          'bizName': 'iplay',
          'content': {
            'user': _chatUser(nickname: '观众丙', userId: '', fanClubInfo: {'fanClubLevel': 6, 'fanClubName': '后援会'}),
          },
        }),
        from: 'guest-fallback',
      );
      final message = frame(_answer13(13, 7, code: 200, r: [fallback])).messages.single;
      expect(message.effectiveSender.userId, 'guest-fallback', reason: 'the from is the id');
      expect(message.effectiveSender.fanBadgeLevel, '6');
      expect(message.effectiveSender.fanBadgeName, '后援会');
    });

    test('a line the website does not show is left out', () {
      for (final hidden in [
        _chatMessage(attach: ''),
        _chatMessage(
          custom: _json({
            'bizName': 'other',
            'content': {'user': _chatUser()},
          }),
        ),
        _chatMessage(custom: 'not json'),
        _chatMessage(custom: null),
        _chatMessage(type: 5),
        _chatMessage(
          custom: _json({
            'bizName': 'iplay',
            'content': {
              'commonCtrl': {'riskLevelKey': 1},
              'user': _chatUser(),
            },
          }),
          reason: 'held back for a risk level',
        ),
        _chatMessage(custom: _json({'bizName': 'iplay', 'content': 'no user'})),
        _chatMessage(
          type: 100,
          from: 'musiclive_server',
          custom: _json({
            'type': 2601,
            'content': {
              'emoji': _json({'name': ''}),
            },
          }),
        ),
        _chatMessage(
          type: 100,
          from: 'someone-else',
          custom: _json({
            'type': 2601,
            'content': {
              'emoji': _json({'name': '大笑'}),
            },
          }),
        ),
      ]) {
        expect(LookliveDanmakuCodec.chat(hidden), isNull, reason: '$hidden');
      }
    });

    test('an emoji message is the name in brackets', () {
      final emoji = _chatMessage(
        type: 100,
        from: 'musiclive_server',
        custom: _json({
          'type': 2601,
          'content': {
            'emoji': _json({'name': '大笑'}),
            // The sender still comes from the content's user (no id: the
            // message's from).
            'user': {'userId': ''},
          },
        }),
      );
      final message = frame(_answer13(13, 7, code: 200, r: [emoji])).messages.single;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, '[大笑]');
      expect(message.effectiveSender.userId, 'musiclive_server', reason: 'no user id, so the from');
    });

    test('a gift is priced, counted and addressed, field by field', () {
      final giftMessage = _chatMessage(
        id: 'm-9',
        type: 100,
        custom: _json({
          'type': LookliveDanmakuCodec.giftType,
          'content': {
            'giftId': 21,
            'giftName': ' 小星星 ',
            'number': 2,
            'giftWorth': 10,
            'giftIconUrl': 'http://img1.126.net/gift.png',
            'receiver': {'nickName': ' 主播甲 '},
            'user': {'nickname': '观众乙', 'userId': '999', 'liveLevel': 5, 'fanClubLevel': 1, 'fanClubName': '粉'},
          },
        }),
      );
      final message = frame(_answer13(13, 7, code: 200, r: [giftMessage])).messages.single;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, '小星星 ×2');
      expect(message.effectiveSender.userName, '观众乙');
      expect(message.effectiveSender.userId, '999');
      expect(message.effectiveSender.userLevel, '5');
      expect(message.effectiveSender.fanBadgeLevel, '1');
      expect(message.effectiveSender.fanBadgeName, '粉');
      expect(message.messageId, 'm-9');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1727700000000));
      final gift = message.payload! as LiveGift;
      expect(gift.giftId, '21');
      expect(gift.name, '小星星');
      expect(gift.count, 2);
      expect(gift.value.unit, LiveGiftUnit.note, reason: "the platform's paid currency");
      expect(gift.value.unitPrice, 10);
      expect(gift.value.totalValue, 20);
      expect(gift.iconUrl, 'https://img1.126.net/gift.png');
      expect(gift.recipientName, '主播甲');
      expect(gift.combo.comboKey, '');
      expect(gift.combo.comboTotal, isNull);
      expect(message, isA<LiveMessage>());
    });

    test('a gift the answer cannot price still names the gift, or is left out', () {
      LiveGift? giftOf(Map<String, Object?> content) {
        final message = _chatMessage(type: 100, custom: _json({'type': 102, 'content': content}));
        final frame = LookliveDanmakuCodec.decode(_answer13(13, 7, code: 200, r: [message]));
        if (frame.messages.isEmpty) return null;
        return frame.messages.single.payload! as LiveGift;
      }

      // A gift is the answer's gift id and nothing more, unnamed or not.
      final nameless = giftOf({'giftId': 5});
      expect(nameless, isNotNull, reason: 'a gift id alone is still a gift');
      expect(nameless!.name, '');
      final unnamed = giftOf({'giftId': 5, 'giftName': '小星星'});
      expect(unnamed, isNotNull);
      expect(unnamed!.count, 1, reason: 'the count defaults to one');
      expect(unnamed.value.unitPrice, isNull, reason: 'no price is never a fabricated zero');
      expect(unnamed.value.totalValue, isNull);
      expect(unnamed.iconUrl, isNull, reason: 'no icon');
      final refused = giftOf({'giftId': 5, 'giftName': '小星星', 'giftWorth': 8, 'giftIconUrl': 'ftp://x/y.png'});
      expect(refused!.value.unitPrice, 8);
      expect(refused.value.totalValue, 8);
      expect(refused.iconUrl, isNull, reason: 'not a web address');
      for (final bad in [
        <String, Object?>{},
        {'giftId': 0, 'giftName': '小星星'},
        {'giftId': 'no', 'giftName': '小星星'},
      ]) {
        expect(giftOf(bad), isNull, reason: '$bad');
      }
      expect(giftOf({'giftId': 5, 'giftName': '小星星'}).toString(), isNotNull);
    });

    test('a message of another kind is not a gift', () {
      expect(LookliveDanmakuCodec.gift(_chatMessage()), isNull);
      expect(
        LookliveDanmakuCodec.gift(
          _chatMessage(type: 100, custom: _json({'type': 2601, 'content': <String, Object?>{}})),
        ),
        isNull,
      );
    });
  });

  group('comment session', () {
    test('a session asks the servers, hands them a session and logs in', () async {
      final chat = await _chat();
      final address = chat.connector.endpoints.single;
      expect(address.host, 'chatwl01.yunxinfw.com');
      expect(address.path, '/socket.io/1/websocket/$_sessionKey');
      // The login goes out as soon as the session opens.
      chat.socket!.push('1::');
      await _settle();
      expect(chat.socket!.sentText, contains('"SID":13'));
      expect(chat.socket!.sentText, contains('"CID":2'));
      expect(chat.socket!.sentText, contains('"SER":1'));
      expect(chat.socket!.sentText, contains('"5":$_chatroom'));
      expect(chat.socket!.sentText, contains('nimanon_'));
      // The join budget and the watchdog are set.
      expect(
        chat.timers.after.map((wait) => wait.delay),
        containsAll([LookliveDanmakuCodec.joinTimeout, LookliveDanmakuCodec.silenceTimeout]),
      );
      expect(chat.timers.every.single.period, LookliveDanmakuCodec.heartbeatInterval);
      await chat.session.dispose();
    });

    test('the join is confirmed, the chat reported, the heartbeat ticked', () async {
      final chat = await _chat();
      chat.socket!.push('1::');
      chat.socket!.push(_joined());
      final after = _next(chat.session.events, 1);
      chat.socket!.push(_answer13(13, 7, code: 200, r: [_chatMessage()]));
      expect((await after).single.text, '大家好');
      // The link heartbeat goes out on the sixth tick after the join, and the
      // server's heartbeat is echoed as it arrives.
      chat.socket!.push('2::');
      await _settle();
      expect(chat.socket!.sentText, endsWith('2::'));
      for (var tick = 0; tick < LookliveDanmakuCodec.ticksPerHeartbeat - 1; tick++) {
        chat.timers.ring();
        await _settle();
      }
      expect(chat.socket!.sentText, isNot(contains(LookliveDanmakuCodec.heartbeat)));
      chat.timers.ring();
      await _settle();
      expect(chat.socket!.sentText, endsWith(LookliveDanmakuCodec.heartbeat));
      await chat.session.dispose();
    });

    test('the address answer of a not-live room ends the session at once', () async {
      final seen = <LiveMessage>[];
      final done = Completer<void>();
      final connector = _Connector();
      final session = LookliveDanmakuSession(
        args: const LookliveDanmakuArgs(roomId: _roomNo, chatroomId: _chatroom),
        site: LookliveSite(
          http: LookliveHttp(
            _FakeHttp(
              (request) => switch (request.url.path) {
                LookliveEndpoints.chatAddressPath => _resp(200, _envelope(null, code: 404, message: '无资源')),
                _ => _resp(404, 'nope'),
              },
            ),
          ),
          connect: connector.call,
        ),
        now: () => _at,
        timers: FakeTimers().timers,
        random: Random(7),
      );
      // The listener is on before the handshake runs, so it sees the end.
      session.events.listen((message) {
        seen.add(message);
        if (!done.isCompleted) done.complete();
      });
      expect(await session.connect(), isNull);
      await done.future;
      expect(seen.single.type, LiveMessageType.system);
      expect(seen.single.text, contains('no chat'));
      expect(connector.sockets, isEmpty);
      await session.dispose();
    });

    test('the chat servers are asked twice before the run counts a failure', () async {
      var addressCalls = 0;
      final chat = await _chat(
        onSend: (request) {
          if (request.url.path == LookliveEndpoints.chatAddressPath) {
            addressCalls++;
            if (addressCalls == 1) return _resp(500, 'nope');
            return _resp(
              200,
              _envelope({
                'address': ['chatwl01.yunxinfw.com:443'],
              }),
            );
          }
          if (request.url.path == '/socket.io/1/') {
            return _resp(200, '$_sessionKey:25:60:websocket');
          }
          return _resp(404, 'nope');
        },
      );
      expect(chat.connector.sockets, isEmpty, reason: "the second ask waits the website's 2 s");
      expect(addressCalls, 1);
      final wait = chat.timers.after.where((timer) => timer.delay == LookliveDanmakuCodec.addressRetryDelay);
      expect(wait, isNotEmpty);
      chat.timers.fireLast();
      await _settle();
      expect(chat.connector.sockets, hasLength(1), reason: 'the second ask opened the socket');
      expect(addressCalls, 2);
      await chat.session.dispose();
    });

    test('a refused login is retried, and the next refusal ends the session', () async {
      final connector = _Connector();
      final timers = FakeTimers();
      final session = LookliveDanmakuSession(
        args: const LookliveDanmakuArgs(roomId: _roomNo, chatroomId: _chatroom),
        site: LookliveSite(http: LookliveHttp(_FakeHttp(_api)), connect: connector.call),
        now: () => _at,
        timers: timers.timers,
        random: Random(7),
      );
      expect(await session.connect(), isNull);
      await _settle();
      final seen = <LiveMessage>[];
      final done = session.events.listen(seen.add).asFuture<void>();
      final refusal = _answer13(13, 2, code: 408);
      for (var attempt = 0; attempt < LookliveDanmakuCodec.maxRefusals; attempt++) {
        connector.latest.push(refusal);
        await _settle();
        timers.fireLast();
        await _settle();
      }
      expect(connector.sockets, hasLength(LookliveDanmakuCodec.maxRefusals + 1), reason: 'three replacements');
      connector.latest.push(refusal);
      await done;
      expect(seen.where((message) => message.type == LiveMessageType.system), isNotEmpty);
      await session.dispose();
    });

    test('a login the chatroom will not pass ends the session at once', () async {
      final chat = await _chat();
      final seen = <LiveMessage>[];
      final done = chat.session.events.listen(seen.add).asFuture<void>();
      chat.socket!.push('1::');
      chat.socket!.push(_answer13(13, 2, code: 404));
      await done;
      expect(seen.single.text, contains('login refused: 404'));
      await chat.session.dispose();
    });

    test('a kick ends the session unless it is the silent one', () async {
      final chat = await _chat();
      final kicked = _next(chat.session.events, 1);
      chat.socket!.push('1::');
      chat.socket!.push(_joined());
      chat.socket!.push(_answer13(13, 3, code: 200, r: [2]));
      expect((await kicked).single.text, contains('managerKick'));
      await chat.session.dispose();

      final other = await _chat();
      final reported = <LiveMessage>[];
      final subscription = other.session.events.listen(reported.add);
      other.socket!
        ..push('1::')
        ..push(_joined());
      await _settle();
      other.socket!.push(_answer13(13, 3, code: 200, r: [4]));
      await _settle();
      other.timers.fireLast();
      await _settle();
      expect(other.connector.sockets, hasLength(2), reason: 'the silent kick reconnects');
      await _settle();
      expect(reported, isEmpty, reason: 'nothing is reported for a reconnect');
      await subscription.cancel();
      await other.session.dispose();
    });

    test('a dropped or silent socket is replaced, and the budget ends the session', () async {
      final connector = _Connector();
      final timers = FakeTimers();
      final session = LookliveDanmakuSession(
        args: const LookliveDanmakuArgs(roomId: _roomNo, chatroomId: _chatroom),
        site: LookliveSite(http: LookliveHttp(_FakeHttp(_api)), connect: connector.call),
        now: () => _at,
        timers: timers.timers,
        random: Random(7),
      );
      expect(await session.connect(), isNull);
      await _settle();
      final first = connector.latest..push('0::');
      await _settle();
      timers.fireLast();
      await _settle();
      // The dropped socket is closed by its replacement (the reference's
      // runtime closes the old channel when the next connect runs).
      expect(first.closed, isTrue);
      expect(connector.sockets, hasLength(2));
      await session.dispose();

      // A connector that always refuses: eight runs, then the session is over.
      final refusing = _Connector();
      Future<SocketChannel> never(
        Uri endpoint, {
        required Map<String, String> headers,
        required Iterable<String>? protocols,
        required Duration connectTimeout,
        Duration? pingInterval,
      }) async => throw StateError('refused');
      final budget = FakeTimers();
      final failing = LookliveDanmakuSession(
        args: const LookliveDanmakuArgs(roomId: _roomNo, chatroomId: _chatroom),
        site: LookliveSite(http: LookliveHttp(_FakeHttp(_api)), connect: never),
        now: () => _at,
        timers: budget.timers,
        random: Random(7),
      );
      expect(await failing.connect(), isNull);
      final seen = <LiveMessage>[];
      final done = failing.events.listen(seen.add).asFuture<void>();
      for (var attempt = 0; attempt < LookliveDanmakuCodec.maxReconnects * 2; attempt++) {
        await _settle();
        budget.fireLast();
      }
      await done;
      expect(seen.where((message) => message.type == LiveMessageType.system), isNotEmpty);
      expect(refusing.sockets, isEmpty);
      await failing.dispose();
    });

    test('arguments that name no chat are refused before any request', () async {
      final connector = _Connector();
      final http = _FakeHttp(_api);
      final session = LookliveDanmakuSession(
        args: const LookliveDanmakuArgs(roomId: 'abc', chatroomId: _chatroom),
        site: LookliveSite(http: LookliveHttp(http), connect: connector.call),
        timers: FakeTimers().timers,
        random: Random(7),
      );
      expect(await session.connect(), isA<LiveSiteContentUnavailable>());
      expect(connector.sockets, isEmpty);
      expect(http.sent, isEmpty);
    });
  });

  group('adapter wiring', () {
    test('the manifest and the seven capabilities the platform can serve', () async {
      final site = LookliveSite(http: LookliveHttp(_FakeHttp(_api)), connect: _refuseSocket);
      expect(site.manifest.id, 'looklive');
      expect(site.manifest.name['zh-CN'], 'LOOK 直播');
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
    });

    test('a room id that is no number is not-found without a request', () async {
      final http = _FakeHttp(_api);
      final site = LookliveSite(http: LookliveHttp(http));
      expect(_leftOf(await site.capability<LiveRoomProvider>()!.getRoom('not a room')), isA<LiveSiteNotFound>());
      expect(http.sent, isEmpty);
      await site.dispose();
    });

    test('a merged page asks both lists once, then only the living ones', () async {
      var videoCalls = 0;
      var audioCalls = 0;
      final http = _FakeHttp((request) {
        if (request.url.path == LookliveEndpoints.videoListPath) {
          videoCalls++;
          // The third call answers "no more"; a page 1 restart (the fourth)
          // finds the list grown again.
          return _resp(200, _listFixture(hasMore: videoCalls % 3 != 0, items: const []));
        }
        if (request.url.path == LookliveEndpoints.audioListPath) {
          audioCalls++;
          return _resp(200, _listFixture(hasMore: false, items: const []));
        }
        return _resp(404, 'nope');
      });
      final site = LookliveSite(http: LookliveHttp(http));
      final rooms = site.capability<LiveRoomProvider>()!;
      final first = _right(await rooms.getRooms(const LivePageRequest()));
      expect(first.hasMore, isTrue);
      expect(videoCalls, 1);
      expect(audioCalls, 1, reason: 'page 1 asks both lists');
      expect(_right(await rooms.getRooms(const LivePageRequest(page: 2))).hasMore, isTrue);
      expect(audioCalls, 1, reason: 'the ended list is not asked again');
      expect(videoCalls, 2);
      final third = _right(await rooms.getRooms(const LivePageRequest(page: 3)));
      expect(third.hasMore, isFalse);
      expect(videoCalls, 3);
      final before = http.sent.length;
      expect(_right(await rooms.getRooms(const LivePageRequest(page: 4))).hasMore, isFalse);
      expect(http.sent.length, before, reason: 'both lists have ended');
      // Page 1 starts over.
      expect(_right(await rooms.getRooms(const LivePageRequest())).hasMore, isTrue);
      expect(videoCalls, 4);
      expect(audioCalls, 2);
      await site.dispose();
    });

    test('the recommendations are the merged page, cut to the page size', () async {
      final site = LookliveSite(http: LookliveHttp(_FakeHttp(_api)));
      final discovery = site.capability<LiveDiscoveryProvider>()!;
      final page = _right(await discovery.getRecommendedRooms(request: const LivePageRequest(pageSize: 1)));
      expect(page.items, hasLength(1));
      expect(page.hasMore, isTrue, reason: 'the cut does not end the pages');
      expect(_right(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 0))).items, isEmpty);
      await site.dispose();
    });

    test('the areas are the two lists, and another one is refused', () async {
      final http = _FakeHttp((request) {
        if (request.url.path == LookliveEndpoints.audioListPath) {
          return _resp(
            200,
            _listFixture(
              items: [_card(roomNo: _otherNo, userId: '8642000', nick: '唱见小乙', title: '晚安电台', liveType: 2)],
            ),
          );
        }
        return _api(request);
      });
      final site = LookliveSite(http: LookliveHttp(http));
      final area = site.capability<LiveAreaProvider>()!;
      expect(_right(await area.getAreas()).map((entry) => entry.areaId), [
        LookliveEndpoints.videoAreaId,
        LookliveEndpoints.audioAreaId,
      ]);
      final voice = _right(await area.getAreaRooms(areaId: LookliveEndpoints.audioAreaId));
      expect(voice.items.single.roomId, _otherNo);
      expect(voice.items.single.area?.areaId, LookliveEndpoints.audioAreaId);
      expect(http.posts.last.url.path, LookliveEndpoints.audioListPath, reason: 'an area asks its own list');
      expect(_leftOf(await area.getAreaRooms(areaId: 'dance')), isA<LiveSiteInvalidArgument>());
      await site.dispose();
    });

    test('an entry carries the streams and the chat without another request', () async {
      final http = _FakeHttp(_api);
      final site = LookliveSite(http: LookliveHttp(http), connect: _refuseSocket);
      final room = _right(await site.capability<LiveRoomProvider>()!.getRoom(_roomNo));
      expect(http.sent, hasLength(1), reason: 'one room request');
      expect(room.roomId, _roomNo);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.runtime.danmakuHandle, isA<LookliveDanmakuArgs>());
      final playback = site.capability<LivePlaybackProvider>()!;
      final before = http.sent.length;
      final qualities = _right(await playback.getQualities(roomId: _roomNo));
      expect(qualities.map((quality) => quality.qualityId), [LookliveEndpoints.hlsId, LookliveEndpoints.flvId]);
      final lines = _right(await playback.getLines(roomId: _roomNo));
      expect(lines, hasLength(1), reason: 'no quality asks the default, the first stream');
      expect(lines.single.format, LiveStreamFormat.hls);
      expect(http.sent.length, before, reason: 'the entry already holds the streams');
      final flv = _right(await playback.getLines(roomId: _roomNo, quality: qualities.last));
      expect(flv.single.format, LiveStreamFormat.flv);
      expect(
        _leftOf(
          await playback.getLines(
            roomId: _roomNo,
            quality: qualities.first.copyWith(qualityId: '720p'),
          ),
        ),
        isA<LiveSiteInvalidArgument>(),
      );
      await site.dispose();
    });

    test('a room that cannot play says why, and a fresh entry serves a search hit', () async {
      final http = _FakeHttp(_api);
      final site = LookliveSite(http: LookliveHttp(http));
      // A search hit carries no streams and keeps no entry.
      final hit = _right(
        await site.capability<LiveSearchProvider>()!.search(
          const LiveSearchRequest(query: _roomNo, target: LiveSearchTarget.rooms),
        ),
      );
      expect((hit.items.single as RoomSearchResult).room.roomId, _roomNo);
      expect(http.sent, hasLength(1));
      final playback = site.capability<LivePlaybackProvider>()!;
      final lines = _right(await playback.getLines(roomId: _roomNo));
      expect(lines, hasLength(1), reason: 'the entry the playback asked for itself serves the default line');
      expect(http.sent, hasLength(2));
      // An offline room's entry says why it cannot play.
      final offline = LookliveSite(
        http: LookliveHttp(
          _FakeHttp(
            (request) => request.url.path == LookliveEndpoints.roomPath
                ? _resp(200, _roomFixture(data: _roomData(liveStatus: 0)))
                : _api(request),
          ),
        ),
      );
      expect(
        _leftOf(await offline.capability<LivePlaybackProvider>()!.getQualities(roomId: _roomNo)),
        isA<LiveSiteContentUnavailable>(),
      );
      await site.dispose();
      await offline.dispose();
    });

    test('a search finds the number, and no room is no result', () async {
      final http = _FakeHttp(_api);
      final site = LookliveSite(http: LookliveHttp(http));
      final search = site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      final byNumber = _right(
        await search.search(const LiveSearchRequest(query: ' $_roomNo ', target: LiveSearchTarget.rooms)),
      );
      expect((byNumber.items.single as RoomSearchResult).room.roomId, _roomNo);
      expect(byNumber.hasMore, isNull);
      final byLink = _right(
        await search.search(
          const LiveSearchRequest(query: 'https://look.163.com/live?id=$_roomNo', target: LiveSearchTarget.rooms),
        ),
      );
      expect((byLink.items.single as RoomSearchResult).room.roomId, _roomNo);
      final unknown = LookliveSite(
        http: LookliveHttp(
          _FakeHttp(
            (request) => request.url.path == LookliveEndpoints.roomPath
                ? _resp(200, _envelope(null, code: 404, message: '无资源'))
                : _api(request),
          ),
        ),
      );
      expect(
        _right(
          await unknown.capability<LiveSearchProvider>()!.search(
            const LiveSearchRequest(query: '999999', target: LiveSearchTarget.rooms),
          ),
        ).items,
        isEmpty,
      );
      await unknown.dispose();
      await site.dispose();
    });

    test('a keyword filters the first merged page, page 1 only', () async {
      final site = LookliveSite(http: LookliveHttp(_FakeHttp(_api)));
      final search = site.capability<LiveSearchProvider>()!;
      final byName = _right(await search.search(const LiveSearchRequest(query: '主播', target: LiveSearchTarget.rooms)));
      expect(byName.items.map((item) => (item as RoomSearchResult).room.roomId), [_roomNo]);
      expect(byName.hasMore, isNull);
      final byTitle = _right(await search.search(const LiveSearchRequest(query: '晚安', target: LiveSearchTarget.rooms)));
      expect(byTitle.items.map((item) => (item as RoomSearchResult).room.roomId), [_otherNo]);
      // A single digit is no room number, so it filters the merged page by
      // number (a digit run of 2 to 18 would look the room up instead).
      final byNumber = _right(await search.search(const LiveSearchRequest(query: '5', target: LiveSearchTarget.rooms)));
      expect(byNumber.items.map((item) => (item as RoomSearchResult).room.roomId), [_otherNo]);
      expect(
        _right(await search.search(const LiveSearchRequest(query: '主播', page: 2, target: LiveSearchTarget.rooms)))
            .items,
        isEmpty,
        reason: 'the search is page 1 only',
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: '', target: LiveSearchTarget.rooms))).items,
        isEmpty,
      );
      expect(
        _right(
          await search.search(const LiveSearchRequest(query: 'https://example.com/a', target: LiveSearchTarget.rooms)),
        ).items,
        isEmpty,
        reason: 'a link of another site is no keyword',
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: '主播', pageSize: 101, target: LiveSearchTarget.rooms)))
            .items,
        isEmpty,
      );
      await site.dispose();
    });

    test('a link is canonicalized without a request', () async {
      final http = _FakeHttp(_api);
      final site = LookliveSite(http: LookliveHttp(http));
      final link = site.capability<LiveLinkResolver>()!;
      expect(
        _right(await link.resolve(Uri.parse('https://look.163.com/live?id=$_roomNo&position=3'))),
        Uri.parse(LookliveEndpoints.link(_roomNo)),
      );
      expect(http.sent, isEmpty);
      expect(
        _leftOf(await link.resolve(Uri.parse('https://example.com/live?id=$_roomNo'))),
        isA<LiveSiteUnsupported>(),
      );
      expect(_leftOf(await link.resolve(Uri.parse('https://look.163.com/live'))), isA<LiveSiteNotFound>());
      await site.dispose();
    });

    test('the chat provider builds a session only for an entered live room', () async {
      final opened = _Connector();
      final site = LookliveSite(http: LookliveHttp(_FakeHttp(_api)), connect: opened.call);
      final danmaku = site.capability<LiveDanmakuProvider>()!;
      final session = _right(await danmaku.createSession(roomId: _roomNo));
      expect(session, isA<LookliveDanmakuSession>());
      await session.dispose();
      await site.dispose();
      final offline = LookliveSite(
        http: LookliveHttp(
          _FakeHttp(
            (request) => request.url.path == LookliveEndpoints.roomPath
                ? _resp(200, _roomFixture(data: _roomData(liveStatus: 0)))
                : _api(request),
          ),
        ),
        connect: opened.call,
      );
      expect(
        _leftOf(await offline.capability<LiveDanmakuProvider>()!.createSession(roomId: _roomNo)),
        isA<LiveSiteContentUnavailable>(),
      );
      await offline.dispose();
    });

    test('a refused session is mapped at the boundary', () async {
      final site = LookliveSite(
        http: LookliveHttp(
          _FakeHttp((request) => request.url.path == LookliveEndpoints.roomPath ? _resp(401, 'nope') : _api(request)),
        ),
      );
      expect(_leftOf(await site.capability<LiveRoomProvider>()!.getRoom(_roomNo)), isA<LiveSiteRateLimitError>());
      await site.dispose();
      final throttled = LookliveSite(
        http: LookliveHttp(
          _FakeHttp((request) => request.url.path == LookliveEndpoints.roomPath ? _resp(429, 'nope') : _api(request)),
        ),
      );
      expect(_leftOf(await throttled.capability<LiveRoomProvider>()!.getRoom(_roomNo)), isA<LiveSiteRateLimitError>());
      await throttled.dispose();
    });

    test('a transport breakdown is a network failure, the deadline another one', () async {
      final site = LookliveSite(
        // The transport's contract: it throws a TransportFailure.
        http: LookliveHttp(_FakeHttp((_) => throw const ConnectFailure('broken'))),
        deadline: const Duration(milliseconds: 30),
      );
      expect(_leftOf(await site.capability<LiveRoomProvider>()!.getRoom(_roomNo)), isA<LiveSiteNetworkError>());
      final hung = LookliveSite(
        // A transport that never answers but honours its cancellation, as the
        // real one does: the deadline's cancel turns into a CancelledFailure.
        http: LookliveHttp(
          _FakeHttp((request) async {
            await request.cancel.whenCancel;
            throw const CancelledFailure();
          }),
        ),
        deadline: const Duration(milliseconds: 30),
      );
      expect(_leftOf(await hung.capability<LiveRoomProvider>()!.getRoom(_roomNo)), isA<LiveSiteNetworkError>());
      await site.dispose();
      await hung.dispose();
    });

    test('a changed answer is a parse error at the boundary', () async {
      final site = LookliveSite(
        http: LookliveHttp(
          _FakeHttp(
            (request) => request.url.path == LookliveEndpoints.roomPath ? _resp(200, _roomFixture()) : _api(request),
          ),
        ),
      );
      expect(
        _leftOf(await site.capability<LiveRoomProvider>()!.getRoom(_otherNo)),
        isA<LiveSiteParseError>(),
        reason: 'the answer names another room',
      );
      await site.dispose();
    });
  });
}
