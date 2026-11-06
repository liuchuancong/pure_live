import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/looklive/api/looklive_endpoints.dart';
import 'package:live_sites/src/platforms/looklive/api/looklive_http.dart';
import 'package:live_sites/src/platforms/looklive/danmaku/looklive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/looklive/danmaku/looklive_danmaku_session.dart';
import 'package:live_sites/src/platforms/looklive/looklive_manifest.dart';
import 'package:live_sites/src/platforms/looklive/looklive_site.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_room.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

import 'looklive_fixtures.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _room = '447365581';
const String _chatroom = '9902460973';

const LookLiveDanmakuArgs _args = LookLiveDanmakuArgs(roomId: _room, chatroomId: _chatroom);

/// The recording's two requests and the socket it opened, at its start.
final String _handshakeAnswer = liveFrames[1].text;
final String _recordedSession = _handshakeAnswer.split(':').first;

/// The recording's outgoing frames (the login, the echoes, the link
/// heartbeat, the recorder's `0::` when it left).
final List<String> _recordedOutgoing = [
  for (final frame in liveFrames)
    if (!frame.incoming) frame.text,
];

/// The recorded (scrubbed) guest: the login frame's account, device and
/// session.
final LookliveGuest _recordedGuest = () {
  final login = jsonDecode(_recordedOutgoing.first.substring(4)) as Map<String, Object?>;
  final v = ((login['Q']! as List)[1] as Map)['v']! as Map<String, Object?>;
  return LookliveGuest(account: v['2']! as String, deviceId: v['3']! as String, session: v['26']! as String);
}();

/// When the recording was made: the clock of the handshake here.
final DateTime _recordedAt = DateTime.fromMillisecondsSinceEpoch(
  int.parse(Uri.parse(liveFrames[1].url!).queryParameters['t']!),
);

/// A [Random] giving [values] in turn from `nextInt`.
final class _Sequence implements Random {
  _Sequence(this.values);

  final List<int> values;
  int _index = 0;

  @override
  int nextInt(int max) => values[_index++ % values.length];

  @override
  bool nextBool() => throw UnsupportedError('nextBool');

  @override
  double nextDouble() => throw UnsupportedError('nextDouble');
}

/// Gives the recorded guest (`nimanon_0…01`, `0…02`, `0…03`).
Random _recordedRandom() => _Sequence([
  for (final last in [1, 2, 3]) ...[0, 0, 0, 0, 0, 0, 0, last],
]);

/// The chat server answer of [addresses] (the recorded ones by default).
String _addressAnswer([List<String>? addresses]) => addresses == null
    ? liveFrames.first.text
    : jsonEncode({
        'code': 200,
        'msg': null,
        'message': null,
        'data': {'address': addresses},
        'success': true,
      });

const String _notLive = '{"code":404,"msg":"无资源","message":"无资源","data":null,"success":false}';

LiveResponse _answer(LiveRequest request, String body, {int status = 200}) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: utf8.encode(body));

/// The handshake answer the codec's sessionOf reads: the transport's pair.
LookliveResponse _response(String body, {int status = 200}) => (text: body, status: status);

/// Answers the chat server request and the socket.io handshakes: each script
/// entry is a body, a `(status, body)` record or an error to throw; the last
/// entry repeats. Session ids count up (`sid1`, `sid2`, …) unless the
/// handshake script says otherwise.
final class _Http implements LiveHttp {
  _Http({List<Object>? addresses, List<Object>? sessions, List<Object>? rooms})
    : addresses = addresses ?? [_addressAnswer()],
      sessions = sessions ?? const [],
      rooms = rooms ?? const [];

  final List<Object> addresses;
  final List<Object> sessions;

  /// Room answers (`room/get/v3`) for the provider tests; none by default.
  final List<Object> rooms;
  final List<LiveRequest> requests = [];
  int _addressCalls = 0;
  int _sessionCalls = 0;
  int _roomCalls = 0;

  List<LiveRequest> get addressRequests => [
    for (final request in requests)
      if (request.url.path == LookliveEndpoints.chatAddressPath) request,
  ];

  List<LiveRequest> get handshakes => [
    for (final request in requests)
      if (request.url.path == '/socket.io/1/') request,
  ];

  /// The requests of [path], in order.
  List<LiveRequest> asked(String path) => [
    for (final request in requests)
      if (request.url.path == path) request,
  ];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    requests.add(request);
    final Object step;
    if (request.url.path == LookliveEndpoints.chatAddressPath) {
      step = addresses[_addressCalls.clamp(0, addresses.length - 1)];
      _addressCalls++;
    } else if (request.url.path == LookliveEndpoints.roomPath) {
      step = rooms.isEmpty
          ? 'sid$_sessionCalls:90:30:websocket,xhr-polling'
          : rooms[_roomCalls.clamp(0, rooms.length - 1)];
      _roomCalls++;
    } else {
      _sessionCalls++;
      step = sessions.isEmpty
          ? 'sid$_sessionCalls:90:30:websocket,xhr-polling'
          : sessions[(_sessionCalls - 1).clamp(0, sessions.length - 1)];
    }
    return switch (step) {
      final String body => _answer(request, body),
      (final int status, final String body) => _answer(request, body, status: status),
      _ => throw ArgumentError.value(step),
    };
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnsupportedError('open');

  @override
  void close() {}
}

final class _Channel implements SocketChannel {
  final StreamController<Object?> incoming = StreamController<Object?>();
  final List<Object> sent = [];
  bool closed = false;

  @override
  Stream<Object?> get stream => incoming.stream;

  @override
  void add(Object data) {
    if (closed) throw StateError('socket is closed');
    sent.add(data);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
    if (!incoming.isClosed) await incoming.close();
  }

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  /// Delivers [frame] and lets the session handle it.
  Future<void> receive(Object frame) async {
    incoming.add(frame);
    await _settle();
  }

  /// The server opens the session and accepts the login.
  Future<void> join() async {
    await receive('1::');
    await receive(_loginAnswer());
  }

  /// The logins sent, as their JSON.
  List<Map<String, Object?>> get logins => [
    for (final frame in sent)
      if (frame is String && frame.startsWith('3:::{"SID":13,"CID":2'))
        jsonDecode(frame.substring(4)) as Map<String, Object?>,
  ];

  int get heartbeats => sent.where((frame) => frame == LookliveDanmakuCodec.heartbeat).length;
}

/// Hands out fake sockets and records every handshake.
final class _Connector {
  final List<Uri> endpoints = [];
  final List<Map<String, String>> headers = [];
  final List<_Channel> channels = [];

  Future<SocketChannel> call(
    Uri endpoint, {
    required Map<String, String> headers,
    required Iterable<String>? protocols,
    required Duration connectTimeout,
    Duration? pingInterval,
  }) async {
    endpoints.add(endpoint);
    this.headers.add(headers);
    final channel = _Channel();
    channels.add(channel);
    return channel;
  }
}

/// A timer the session can arm and cancel while the test keeps its callback.
final class _Armed implements Timer {
  _Armed(this._gone);

  final void Function() _gone;
  var _cancelled = false;

  @override
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _gone();
  }

  @override
  bool get isActive => !_cancelled;

  @override
  int get tick => 0;
}

/// The timers the session arms, kept so the slow paths can be fired by hand.
final class _Clock {
  final _after = <({Duration delay, void Function() fire})>[];
  final _every = <void Function()>[];

  Duration? _lastEvery;

  LookliveTimers get timers => (
    after: (delay, callback) {
      final record = (delay: delay, fire: callback);
      _after.add(record);
      return _Armed(() => _after.remove(record));
    },
    every: (period, callback) {
      _every.add(() => callback(_Armed(() {})));
      _lastEvery = period;
      return _Armed(() {});
    },
  );

  Duration? get lastEvery => _lastEvery;

  /// The one-shot timers currently armed.
  int get armedCount => _after.length;

  /// How many one-shot timers armed for [delay] are still waiting.
  int countArmed(Duration delay) => _after.where((timer) => timer.delay == delay).length;

  /// The delay of the last timer armed.
  Duration? get lastArmed => _after.isEmpty ? null : _after.last.delay;

  /// Fires the last timer armed for [delay].
  void fire(Duration delay) {
    for (var index = _after.length - 1; index >= 0; --index) {
      if (_after[index].delay != delay) continue;
      final timer = _after.removeAt(index);
      timer.fire();
      return;
    }
    throw StateError('nothing is armed for $delay');
  }

  /// Fires the last timer armed, whatever it watches: the next reconnect
  /// step.
  void fireLast() {
    if (_after.isEmpty) return;
    final timer = _after.removeLast();
    timer.fire();
  }

  /// Fires the heartbeat beat.
  void fireBeat() => _every.last();
}

/// The login's answer (13-2) with [code], in the recorded shape.
String _loginAnswer({int code = 200}) =>
    '3:::${jsonEncode({
      'key': 0,
      'ser': 1,
      'code': code,
      'sid': 13,
      'cid': 2,
      'r': code == 200 ? [
              {'1': _chatroom, '3': 'online_liveChatRoom_110013407_564597113', '100': '564597113', '101': '26'},
              {'2': 'nimanon_00000000000000000000000000000001', '3': '4', '5': '匿名用户'},
              <String, Object?>{},
            ] : <Object?>[],
    })}';

/// A chatroom message in a notification (4-10), as the server sends them.
String _notify(Object? message, {int sid = 13, int cid = 7, int code = 200}) =>
    '3:::${jsonEncode({
      'key': 0,
      'ser': 0,
      'code': code,
      'sid': 4,
      'cid': 10,
      'r': [
        0,
        {
          'body': [message],
          'headerPacket': {'key': 0, 'sid': sid, 'cid': cid},
        },
      ],
    })}';

/// A text message in the recorded shape (synthetic values).
Map<String, Object?> _text({
  Object? text = '大家好',
  Object? type = '0',
  Object? custom,
  Object? from = '1000000002',
  Object? time = '1790770791719',
  Object? id = '8878bc5ff6cc45dead8734cd26b0f3b8',
}) => {
  '1': ?id,
  '2': ?type,
  '3': ?text,
  '4': custom ?? jsonEncode(_custom()),
  '6': '1790770468408',
  '20': ?time,
  '21': ?from,
  '22': _chatroom,
};

/// A `custom` of a text message: LOOK's `iplay` wrapper with [user].
Map<String, Object?> _custom({Object? bizName = 'iplay', Object? user, Map<String, Object?>? content}) => {
  'sourceType': 2,
  'bizName': ?bizName,
  'type': 0,
  'liveId': 134608594,
  'content': content ?? {'text': '大家好', 'user': user ?? _user()},
  'roomId': 447365581,
};

Map<String, Object?> _user({
  Object? nickname = '观众2',
  Object? userId = 1000000002,
  Object? liveLevel = 21,
  Object? fanClubLevel = 11,
  Object? fanClubName = '偏爱离',
}) => {
  'liveRoomNo': 900000002,
  'fanClubLevel': ?fanClubLevel,
  'liveLevel': ?liveLevel,
  'userId': ?userId,
  'fanClubName': ?fanClubName,
  'nickname': ?nickname,
};

/// LOOK's emoji message (a custom from the server, type 2601).
Map<String, Object?> _emoji({Object? name = '比心', Object? from = 'musiclive_server', Object? user}) => {
  '1': 'e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0',
  '2': '100',
  '3': '',
  '4': jsonEncode({
    'id': 0,
    'type': 2601,
    'content': {
      'emoji': jsonEncode({'name': ?name}),
      'user': user ?? _user(),
    },
  }),
  '20': '1790770800000',
  '21': ?from,
  '22': _chatroom,
};

List<LiveMessage> _messages(List<LiveMessage> events) => events;

/// Records one request and fails it: the transport under a site whose asks
/// the test wants to see.
final class _Capturing implements LiveHttp {
  final List<LiveRequest> requests = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    requests.add(request);
    throw const ConnectFailure('looklive');
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnsupportedError('open');

  @override
  void close() {}
}

Future<void> _settle() async {
  for (var turn = 0; turn < 12; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// The session with its socket log, transport and clock, already wired.
(_Room, _Connector, _Http, _Clock) _roomSession({
  List<Object>? addresses,
  List<Object>? sessions,
  Random? random,
  Duration addressRetryDelay = const Duration(milliseconds: 5),
}) {
  final http = _Http(addresses: addresses, sessions: sessions);
  final connector = _Connector();
  final clock = _Clock();
  final site = LookliveSite(http: LookliveHttp(http), connect: connector.call);
  final session = LookliveDanmakuSession(
    args: _args,
    site: site,
    timers: clock.timers,
    now: () => _recordedAt,
    random: random ?? _recordedRandom(),
    addressRetryDelay: addressRetryDelay,
  );
  return (_Room(session), connector, http, clock);
}

/// The session, with its event log already collected.
final class _Room {
  _Room(this.session) {
    subscription = session.events.listen(seen.add, onDone: closed.complete);
  }

  final LookliveDanmakuSession session;
  late final StreamSubscription<LiveMessage> subscription;
  final List<LiveMessage> seen = [];
  final Completer<void> closed = Completer<void>();

  List<LiveMessage> get system => seen.where((message) => message.type == LiveMessageType.system).toList();

  Future<void> dispose() async {
    await subscription.cancel();
    await session.dispose();
  }
}

void main() {
  group('protocol', () {
    test('the app key, timing and fixed frames', () {
      expect(LookliveDanmakuCodec.appKey, '3a6a3e48f6854dfa4e4464f3bdaec3b4');
      expect((LookliveDanmakuCodec.sdkVersion, LookliveDanmakuCodec.protocolVersion), ('47', 1));
      expect(LookliveDanmakuCodec.heartbeatInterval, const Duration(seconds: 30));
      expect(LookliveDanmakuCodec.silenceTimeout, const Duration(seconds: 90));
      expect(
        LookliveDanmakuCodec.heartbeatInterval * LookliveDanmakuCodec.ticksPerHeartbeat,
        const Duration(minutes: 3),
      );
      expect(LookliveDanmakuCodec.joinTimeout, const Duration(seconds: 10));
      expect(
        (LookliveDanmakuCodec.addressAttempts, LookliveDanmakuCodec.addressRetryDelay),
        (2, const Duration(seconds: 2)),
      );
      expect(LookliveDanmakuCodec.socketHeaders, {'origin': 'https://look.163.com', 'user-agent': 'Mozilla/5.0'});
      expect(LookliveDanmakuCodec.heartbeat, '3:::{"SID":1,"CID":2,"SER":0}');
      expect(LookliveDanmakuCodec.socketHeartbeat, '2::');
      expect(LookliveDanmakuCodec.retriedRefusals, {408, 415, 500, 503});
      expect(LookliveDanmakuCodec.kickReasons[LookliveDanmakuCodec.silentKick], 'silentlyKick');
      expect(LookliveDanmakuCodec.giftType, 102);
    });

    test("the chat server request is the adapter's weapi POST, with the website's payload", () async {
      final request = LookliveDanmakuCodec.addressRequest(_room);
      expect('${request.method} ${request.url}', 'POST https://api.look.163.com/weapi/livestream/chat/address');
      expect(request.body, LookliveEndpoints.formBody(LookliveEndpoints.chatAddressPayload(_room)));
      expect(request.headers, LookliveEndpoints.requestHeaders);
      // What the site's transport sends for the same ask.
      final http = _Capturing();
      final transport = LookliveHttp(http);
      await expectLater(
        transport.post(LookliveEndpoints.chatAddressPath, LookliveEndpoints.chatAddressPayload(_room)),
        throwsA(isA<LookliveFailure>()),
      );
      final sent = http.requests.single;
      expect(
        (request.site, request.method, request.headers, request.timeout),
        (sent.site, sent.method, sent.headers, sent.timeout),
      );
    });

    test('endpoints, the socket.io handshake and the socket of a session (the recording)', () {
      final endpoints = LookliveDanmakuCodec.endpoints([
        'chatwl01.yunxinfw.com:443',
        'chatwl01-bgp.yunxinfw.com:443',
        'chatwl02-bgp.yunxinfw.com:443',
        'chatwl02.yunxinfw.com:443',
      ]);
      expect(endpoints.map((endpoint) => '$endpoint'), [
        'wss://chatwl01.yunxinfw.com:443/socket.io/1/websocket/',
        'wss://chatwl01-bgp.yunxinfw.com:443/socket.io/1/websocket/',
        'wss://chatwl02-bgp.yunxinfw.com:443/socket.io/1/websocket/',
        'wss://chatwl02.yunxinfw.com:443/socket.io/1/websocket/',
      ]);
      final handshake = LookliveDanmakuCodec.handshakeRequest(endpoints.first, roomId: _room, now: _recordedAt);
      // Uri normalizes https's default port away; the request is the recorded
      // one (the website wrote `:443`, Uri's `toString` leaves it out).
      expect('$handshake', 'GET ${Uri.parse(liveFrames[1].url!)}');
      expect(handshake.url, Uri.parse(liveFrames[1].url!));
      expect((handshake.site, handshake.method), ('looklive', 'GET'));
      expect(handshake.headers, {
        'origin': 'https://look.163.com',
        'referer': 'https://look.163.com/live?id=$_room',
        'user-agent': 'Mozilla/5.0',
      });
      final plain = LookliveDanmakuCodec.handshakeRequest(
        Uri.parse('ws://127.0.0.1:9000/socket.io/1/websocket/'),
        roomId: _room,
        now: _recordedAt,
      );
      expect('${plain.url}', 'http://127.0.0.1:9000/socket.io/1/?t=${_recordedAt.millisecondsSinceEpoch}');
      final session = LookliveDanmakuCodec.sessionOf(_response(_handshakeAnswer));
      expect(session, _recordedSession);
      final socket = LookliveDanmakuCodec.socketUrl(endpoints.first, session);
      expect('$socket', 'wss://chatwl01.yunxinfw.com:443/socket.io/1/websocket/$_recordedSession');
      for (final (status, body) in [
        (500, 'sid:90:30:websocket'),
        (403, 'handshake unauthorized'),
        (200, ''),
        (200, 'sid:90:30'),
        (200, 'sid:90:30:xhr-polling'),
        (200, 'a/b:90:30:websocket'),
        (200, ':90:30:websocket'),
        (200, '<html>'),
      ]) {
        expect(
          () => LookliveDanmakuCodec.sessionOf(_response(body, status: status)),
          throwsFormatException,
          reason: '$status $body',
        );
      }
      expect(LookliveDanmakuCodec.sessionOf(_response(' s-1_A:25:60:websocket \n')), 's-1_A');
    });

    test('arguments: a room number and a chatroom id the login can carry as a number', () {
      expect(LookliveDanmakuCodec.checked(_args), _args);
      expect(
        LookliveDanmakuCodec.checked(
          const LookLiveDanmakuArgs(roomId: ' $_room ', chatroomId: ' $_chatroom ', anonymousMode: true),
        ),
        const LookLiveDanmakuArgs(roomId: _room, chatroomId: _chatroom, anonymousMode: true),
      );
      expect(
        LookliveDanmakuCodec.checked(const LookLiveDanmakuArgs(roomId: _room, chatroomId: '9007199254740991')),
        isNotNull,
      );
      for (final (roomId, chatroomId) in [
        ('', _chatroom),
        ('1', _chatroom),
        ('0447365581', _chatroom),
        ('room', _chatroom),
        (_room, ''),
        (_room, '0'),
        (_room, '09902460973'),
        (_room, '9007199254740992'),
        (_room, '12345678901234567'),
        (_room, '99-1'),
      ]) {
        expect(
          LookliveDanmakuCodec.checked(LookLiveDanmakuArgs(roomId: roomId, chatroomId: chatroomId)),
          isNull,
          reason: '$roomId $chatroomId',
        );
      }
    });

    test("the login is the recording's frame, byte for byte; again after a reconnect", () {
      final ours = LookliveDanmakuCodec.login(chatroomId: _chatroom, guest: _recordedGuest, serial: 1);
      expect(ours, _recordedOutgoing.first);
      final again = jsonDecode(
        LookliveDanmakuCodec.login(chatroomId: _chatroom, guest: _recordedGuest, serial: 2, again: true).substring(4),
      ) as Map<String, Object?>;
      final q = again['Q']! as List;
      expect(again['SER'], 2);
      expect((((q[1] as Map)['v'] as Map)['8'], ((q[2] as Map)['v'] as Map)['8']), (1, 0));
      expect(((q[1] as Map)['v'] as Map)['5'], 9902460973, reason: 'the chatroom as a number');
    });

    test('the guest: nimanon_ and 32 hex digits, a device and a session of 32 hex digits', () {
      final guest = LookliveGuest.random(Random(7));
      expect(guest.account, matches(RegExp(r'^nimanon_[0-9a-f]{32}$')));
      expect(guest.deviceId, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(guest.session, matches(RegExp(r'^[0-9a-f]{32}$')));
      final recorded = LookliveGuest.random(_recordedRandom());
      expect(
        (recorded.account, recorded.deviceId, recorded.session),
        (_recordedGuest.account, _recordedGuest.deviceId, _recordedGuest.session),
      );
    });

    test('socket.io packets: connect, heartbeat, disconnect, error, acks, other endpoints, framed, bytes', () {
      expect(LookliveDanmakuCodec.decode('1::').opened, isTrue);
      expect(LookliveDanmakuCodec.decode('2::').replies, ['2::']);
      expect(LookliveDanmakuCodec.decode('0::').dropped, isTrue);
      expect(LookliveDanmakuCodec.decode('7:::1+0').dropped, isTrue);
      for (final quiet in ['8::', '5:::{"name":"x"}', '4:::{}', '6:::1', '', 'nonsense', '3:::', '3:::not json']) {
        final frame = LookliveDanmakuCodec.decode(quiet);
        expect(
          (frame.opened, frame.dropped, frame.joined, frame.replies.length, frame.messages.length),
          (false, false, false, 0, 0),
          reason: quiet,
        );
      }
      expect(LookliveDanmakuCodec.decode('3:7::{"sid":1,"cid":2,"code":200,"r":[]}').replies, ['6:::7']);
      expect(LookliveDanmakuCodec.decode('3:7+::{"sid":1,"cid":2,"code":200,"r":[]}').replies, isEmpty);
      expect(LookliveDanmakuCodec.decode('1::/other').opened, isFalse);
      expect(LookliveDanmakuCodec.decode(_notify(_text()).replaceFirst('3:::', '3::/other:')).messages, isEmpty);
      final chat = _notify(_text(text: '表情😀'));
      final framed = LookliveDanmakuCodec.decode('\ufffd3\ufffd1::\ufffd${chat.length}\ufffd$chat\ufffd3\ufffd2::');
      expect((framed.opened, framed.messages.single.text), (true, '表情😀'));
      expect(framed.replies, ['2::']);
      expect(LookliveDanmakuCodec.decode('\ufffd99\ufffd1::').opened, isFalse, reason: 'a length past the end');
      expect(LookliveDanmakuCodec.decode(utf8.encode(_notify(_text()))).messages.single.text, '大家好');
      expect(LookliveDanmakuCodec.decode([0xff, 0xfe]).messages, isEmpty);
      expect(LookliveDanmakuCodec.decode(null).messages, isEmpty);
      expect(LookliveDanmakuCodec.decode(42).opened, isFalse);
    });

    test('answers: the login and its refusal, kicks, messages direct or in a notification', () {
      expect(LookliveDanmakuCodec.decode(_loginAnswer()).joined, isTrue);
      final refused = LookliveDanmakuCodec.decode(_loginAnswer(code: 404));
      expect((refused.joined, refused.refusal), (false, 404));
      expect(LookliveDanmakuCodec.decode('3:::{"sid":13,"cid":2,"r":[]}').refusal, 0, reason: 'no code');
      expect(LookliveDanmakuCodec.decode('3:::{"sid":"13","cid":"2","code":"200","r":[]}').joined, isTrue);
      expect(LookliveDanmakuCodec.decode('3:::{"sid":13,"cid":3,"code":200,"r":[1,""]}').kicked, 1);
      expect(
        LookliveDanmakuCodec.decode(
          '3:::{"sid":4,"cid":10,"code":200,"r":[0,{"body":[5,""],"headerPacket":{"sid":13,"cid":3}}]}',
        ).kicked,
        5,
        reason: 'a kick in a notification',
      );
      expect(LookliveDanmakuCodec.decode('3:::{"sid":13,"cid":3,"code":200,"r":[]}').kicked, 0);
      final direct =
          '3:::${jsonEncode({
            'sid': 13,
            'cid': 7,
            'code': 200,
            'r': [_text()],
          })}';
      expect(LookliveDanmakuCodec.decode(direct).messages.single.text, '大家好');
      expect(LookliveDanmakuCodec.decode(_notify(_text())).messages.single.text, '大家好');
      expect(
        LookliveDanmakuCodec.decode(_notify(_text()).replaceFirst('"cid":10', '"cid":11')).messages,
        hasLength(1),
        reason: '4-11 wraps too',
      );
      expect(LookliveDanmakuCodec.decode(_notify(_text(), code: 500)).messages, isEmpty);
      expect(LookliveDanmakuCodec.decode(_notify(_text(), cid: 6)).messages, isEmpty, reason: 'not 13-7');
      for (final bad in [
        '3:::[]',
        '3:::{"cid":7}',
        '3:::{"sid":4,"cid":10,"code":200,"r":[0]}',
        '3:::{"sid":4,"cid":10,"code":200,"r":[0,{"body":[]}]}',
        '3:::{"sid":4,"cid":10,"code":200,"r":[0,{"headerPacket":{"sid":13,"cid":7},"body":{}}]}',
        '3:::{"sid":4,"cid":10,"code":200,"r":"x"}',
        '3:::{"sid":13,"cid":7,"code":200,"r":{}}',
        '3:::{"sid":1,"cid":2,"code":200,"r":[]}',
      ]) {
        final frame = LookliveDanmakuCodec.decode(bad);
        expect((frame.messages.length, frame.joined, frame.kicked, frame.refusal), (0, false, null, null), reason: bad);
      }
    });

    test('a chat line: text, sender, levels, fan club, message id and time', () {
      final message = LookliveDanmakuCodec.chat(_text())!;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, '大家好');
      expect(message.messageId, '8878bc5ff6cc45dead8734cd26b0f3b8');
      expect(message.sender?.userId, '1000000002');
      expect(message.sender?.userName, '观众2');
      expect(message.sender?.userLevel, '21');
      expect(message.sender?.fanBadgeLevel, '11');
      expect(message.sender?.fanBadgeName, '偏爱离');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1790770791719));
      expect(message.sentAt!.isUtc, isFalse);
    });

    test('chat boundaries: types, text, the iplay wrapper, risk levels, senders, levels and times', () {
      LiveMessage? chat(Map<String, Object?> message, {bool anonymousMode = false}) =>
          LookliveDanmakuCodec.chat(message, anonymousMode: anonymousMode);
      String custom(Map<String, Object?> value) => jsonEncode(value);
      for (final (reason, message) in [
        ('no text', _text(text: null)),
        ('empty text', _text(text: '')),
        ('text not a string', _text(text: true)),
        ('no custom', {..._text()}..remove('4')),
        ('custom not JSON', _text(custom: '{bad')),
        ('custom not an object', _text(custom: '[1]')),
        ('another bizName', _text(custom: custom(_custom(bizName: 'other')))),
        ('no content', _text(custom: custom({'bizName': 'iplay'}))),
        ('no user', _text(custom: custom(_custom(content: {'text': '大家好'})))),
        (
          'a risk level the guest lacks',
          _text(
            custom: custom(
              _custom(
                content: {
                  'user': _user(),
                  'commonCtrl': {'riskLevelKey': 'level2'},
                },
              ),
            ),
          ),
        ),
        ('another message type', _text(type: '1')),
        ('no type', _text(type: null)),
        (
          'a custom message that is not an emoji',
          {
            ..._emoji(),
            '4': jsonEncode({
              'id': 0,
              'type': 114,
              'content': {'user': _user()},
            }),
          },
        ),
        ('an emoji not from the server', _emoji(from: '1000000002')),
        ('an emoji without a name', _emoji(name: '')),
      ]) {
        expect(chat(message), isNull, reason: reason);
      }
      expect(LookliveDanmakuCodec.chat('x'), isNull);
      for (final key in [null, '', false, 0]) {
        final message = _text(
          custom: custom(
            _custom(
              content: {
                'user': _user(),
                'commonCtrl': {'riskLevelKey': key},
              },
            ),
          ),
        );
        expect(chat(message)?.text, '大家好', reason: '$key');
      }
      expect(chat(_text(text: '  你好 \n'))!.text, '你好');
      expect(chat(_text(text: 7))!.text, '7', reason: 'the page shows a number too');
      expect(chat(_text(type: 0))!.text, '大家好');
      LiveMessage sent(Map<String, Object?> user, {Object? from = '1000000002'}) => chat(
        _text(
          from: from,
          custom: custom(_custom(user: user)),
        ),
      )!;
      expect(sent(_user(nickname: null)..['nickName'] = '别名').sender?.userName, '别名');
      expect(sent(_user(nickname: ' 名字 ')).sender?.userName, '名字');
      expect(sent(_user(userId: '123')).sender?.userId, '123');
      expect(sent(_user(userId: null)).sender?.userId, '1000000002');
      expect(sent(_user(userId: null), from: null).sender?.userId, '');
      for (final (value, expected) in [(0, ''), (-1, ''), ('12', '12'), (1.5, ''), (null, '')]) {
        final message = chat(
          _text(
            custom: custom(
              _custom(
                user: _user(liveLevel: value, fanClubLevel: value, fanClubName: null),
              ),
            ),
          ),
        )!;
        expect(
          (message.sender?.userLevel, message.sender?.fanBadgeLevel),
          (expected.isEmpty ? null : expected, expected),
        );
      }
      final info = chat(
        _text(
          custom: custom(
            _custom(
              user: _user(fanClubLevel: null, fanClubName: null)
                ..['fanClubInfo'] = {'fanClubLevel': 3, 'fanClubName': '粉团'},
            ),
          ),
        ),
      )!;
      expect((info.sender?.fanBadgeLevel, info.sender?.fanBadgeName), ('3', '粉团'));
      expect(chat(_text(id: null))!.messageId, '');
      for (final (value, expected) in [
        ('1790770791719', 1790770791719),
        (1790770791719, 1790770791719),
        ('0', null),
        ('-5', null),
        ('x', null),
        (null, null),
        ('8640000000000000', 8640000000000000),
        ('8640000000000001', null),
      ]) {
        expect(chat(_text(time: value))!.sentAt?.millisecondsSinceEpoch, expected, reason: '$value');
      }
    });

    test('emoji messages (2601) are chat in brackets; short-keyed customs (sp 1) are expanded', () {
      final emoji = LookliveDanmakuCodec.chat(_emoji())!;
      expect(
        (emoji.text, emoji.sender?.userName, emoji.sender?.userId, emoji.messageId),
        ('[比心]', '观众2', '1000000002', 'e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0'),
      );
      final short = {
        'sp': 1,
        'bizName': 'iplay',
        'sourceType': 2,
        'c': {
          'ir': false,
          'u': {'n': '短名', 'i': 42, 'l': 7, 'fcl': 2, 'fcn': '团', 'extra': 1},
          'commonCtrl': {'riskLevelKey': null},
        },
      };
      final expanded = LookliveDanmakuCodec.chat(_text(custom: jsonEncode(short)))!;
      expect(
        (
          expanded.sender?.userName,
          expanded.sender?.userId,
          expanded.sender?.userLevel,
          expanded.sender?.fanBadgeLevel,
          expanded.sender?.fanBadgeName,
        ),
        ('短名', '42', '7', '2', '团'),
      );
      expect(LookliveDanmakuCodec.chat(_text(custom: jsonEncode({...short, 'sp': 0}))), isNull);
    });

    test("anonymous rooms show a name's first character and ***", () {
      String? name(Object? nickname) => LookliveDanmakuCodec.chat(
        _text(
          custom: jsonEncode(_custom(user: _user(nickname: nickname))),
        ),
        anonymousMode: true,
      )?.sender?.userName;
      expect(name('观众2'), '观***');
      expect(name('😀笑脸'), '😀***', reason: 'a whole code point, not half a surrogate pair');
      expect(name('a'), 'a***');
      expect(name(''), '');
      expect(name(null), '');
      expect(LookliveDanmakuCodec.chat(_emoji(), anonymousMode: true)!.sender?.userName, '观***');
    });

    test('gifts: count, worth in notes, picture, receiver, sender', () {
      Map<String, Object?> message(Map<String, Object?> custom, {String type = '100'}) => {
        '1': 'id',
        '2': type,
        '4': jsonEncode(custom),
        '20': '1791531626046',
      };
      const content = {
        'giftId': 7,
        'giftName': '花',
        'number': 3,
        'giftWorth': 10,
        'user': {'userId': 5, 'nickName': 'a'},
      };
      expect(LookliveDanmakuCodec.gift(message({'type': 102, 'content': content}, type: '0')), isNull);
      expect(LookliveDanmakuCodec.gift(message({'type': 114, 'content': content})), isNull);
      expect(
        LookliveDanmakuCodec.gift(
          message({
            'type': 102,
            'content': {...content, 'giftId': 0},
          }),
        ),
        isNull,
      );
      expect(LookliveDanmakuCodec.gift(message({'type': 102})), isNull);
      final gift = LookliveDanmakuCodec.gift(
        message({
          'type': 102,
          'content': {
            ...content,
            'receiver': {'nickName': '嘉宾'},
            'giftIconUrl': 'http://p1.music.126.net/x.jpg',
          },
        }),
      )!;
      expect(gift.type, LiveMessageType.gift);
      expect(gift.text, '花 ×3');
      expect(gift.sender?.userId, '5');
      expect(gift.sender?.userName, 'a');
      expect(gift.sentAt, DateTime.fromMillisecondsSinceEpoch(1791531626046));
      final data = gift.giftOrNull! as LiveGift;
      expect(data.giftId, '7');
      expect(data.name, '花');
      expect(data.count, 3);
      expect(data.value.unit, LiveGiftUnit.note);
      expect(data.value.unitPrice, 10);
      expect(data.value.totalValue, 30);
      expect(data.iconUrl, 'https://p1.music.126.net/x.jpg');
      expect(data.recipientName, '嘉宾');
    });

    test('the recording S05: every incoming frame decodes; 47 chat lines; the join on the recorded answer', () {
      final incoming = [
        for (final (index, frame) in liveFrames.indexed)
          if (frame.incoming && frame.url == null) (index: index, text: frame.text),
      ];
      var chats = 0;
      var joined = 0;
      for (final frame in incoming) {
        final decoded = LookliveDanmakuCodec.decode(frame.text);
        expect(decoded.refusal, isNull, reason: 'frame ${frame.index}');
        expect((decoded.kicked, decoded.dropped), (null, false), reason: 'frame ${frame.index}');
        if (decoded.joined) joined += 1;
        chats += decoded.messages.length;
      }
      expect(chats, 47, reason: '35 of the room assistant, 12 of two viewers');
      expect(joined, 1, reason: 'the login was accepted once');
      // The echoes the recording sent back are the ones the frames asked for.
      final echoes = [
        for (final frame in liveFrames)
          if (frame.incoming && frame.text == '2::') frame.text,
      ];
      expect(_recordedOutgoing.where((text) => text == '2::'), echoes);
    });
  });

  group('gifts recording (S06)', () {
    test('every recorded custom message 102 is a gift: name, count, worth, picture, sender', () {
      final messages = [for (final frame in giftFrames) ...LookliveDanmakuCodec.decode(frame.text).messages];
      expect(
        [for (final m in messages) (m.sender?.userName, m.text, (m.giftOrNull! as LiveGift).value.totalValue)],
        [('观众1', '小麦穗 ×1', 1.0), ('观众2', '时光相册 ×1', 1.0), ('观众3', '时光相册 ×1', 1.0), ('观众4', '旋转木马 ×1', 100.0)],
      );
      final first = messages.first;
      expect(
        (
          first.sender?.userId,
          first.sender?.userLevel,
          first.sender?.fanBadgeLevel,
          first.sender?.fanBadgeName,
          first.messageId,
          first.sentAt,
        ),
        (
          '7000000001',
          '38',
          '18',
          '口果汁',
          '5ec5af7d94fc432bbe36dcb7eb6d43b7',
          DateTime.fromMillisecondsSinceEpoch(1791531626046),
        ),
      );
      expect(
        first.giftOrNull,
        LiveGift.of(
          giftId: '14193526',
          name: '小麦穗',
          value: LiveGiftValue.of(unit: LiveGiftUnit.note, unitPrice: 1, totalValue: 1),
          iconUrl: 'https://p1.music.126.net/rS6UvA8RznaFOobx26Uj8g==/109951173868759962.jpg',
        ),
      );
      final masked = LookliveDanmakuCodec.decode(giftFrames.last.text, anonymousMode: true).messages.single;
      expect(masked.sender?.userName, '观***');
    });
  });

  group('session', () {
    test('the handshake: chat servers, a socket.io session, the socket; login on 1::, chat after the join', () async {
      final (room, connector, http, _) = _roomSession(sessions: [_handshakeAnswer]);
      await room.session.connect();
      await _settle();
      final address = http.addressRequests.single;
      expect(address.body, LookliveEndpoints.formBody(LookliveEndpoints.chatAddressPayload(_room)));
      expect('${http.handshakes.single.url}', startsWith('https://chatwl01.yunxinfw.com/socket.io/1/?t='));
      expect(connector.endpoints.map((endpoint) => '$endpoint'), [
        'wss://chatwl01.yunxinfw.com:443/socket.io/1/websocket/$_recordedSession',
      ]);
      expect(connector.headers.single, LookliveDanmakuCodec.socketHeaders);
      final socket = connector.channels.single;
      expect(socket.sent, isEmpty, reason: 'nothing before the session opens');
      expect(room.seen, isEmpty);
      await socket.receive('1::');
      expect(socket.logins, hasLength(1));
      expect(socket.logins.single['SER'], 1);
      expect(socket.sent, [LookliveDanmakuCodec.login(chatroomId: _chatroom, guest: _recordedGuest, serial: 1)]);
      await socket.receive('1::');
      expect(socket.logins, hasLength(1), reason: 'one login per socket');
      await socket.receive(_loginAnswer());
      expect(room.system, isEmpty, reason: 'the join is quiet');
      await socket.receive(_notify(_text()));
      await socket.receive(
        _notify({
          ..._emoji(),
          '4': jsonEncode({'id': 0, 'type': 114, 'content': <String, Object?>{}}),
        }),
      );
      expect(_messages(room.seen).map((message) => message.text), ['大家好'], reason: 'a non-chat custom is skipped');
      await room.dispose();
    });

    test('a room that is not live ends at once; one retry after a failure; then the end', () async {
      final (room, connector, http, _) = _roomSession(addresses: [_notLive]);
      await room.session.connect();
      await _settle();
      expect(room.system, hasLength(1));
      expect(room.system.single.text, startsWith('No chat: '));
      expect(http.addressRequests, hasLength(1));
      expect(connector.endpoints, isEmpty);
      expect(room.closed.future, completion(null), reason: 'the stream is closed');
      // One failure: asked again after the delay, then joined.
      final (room2, connector2, http2, clock2) = _roomSession(
        addresses: [const ConnectFailure('looklive'), _addressAnswer()],
      );
      await room2.session.connect();
      await _settle();
      clock2.fire(const Duration(milliseconds: 5));
      await _settle();
      expect(http2.addressRequests, hasLength(2));
      await connector2.channels.single.join();
      expect(room2.system, isEmpty);
      await room2.dispose();
      // Two failures: the end.
      final (room3, connector3, http3, clock3) = _roomSession(
        addresses: [
          (503, ''),
          _addressAnswer(['bad']),
        ],
      );
      await room3.session.connect();
      await _settle();
      clock3.fire(const Duration(milliseconds: 5));
      await _settle();
      expect(http3.addressRequests, hasLength(2));
      expect(connector3.endpoints, isEmpty);
      expect(room3.system.single.text, startsWith('Chat servers: '));
      await room3.dispose();
    });

    test('a failed socket.io session counts as a failed handshake: the next server, then the budget', () async {
      final (room, connector, http, clock) = _roomSession(
        addresses: [
          _addressAnswer(['a.example.com:443', 'b.example.com:443']),
        ],
        sessions: [(500, 'error'), 'sid:90:30:xhr-polling', 'ok:90:30:websocket'],
      );
      await room.session.connect();
      await _settle();
      clock.fireLast();
      await _settle();
      expect(http.handshakes.map((request) => request.url.host), ['a.example.com', 'b.example.com', 'a.example.com']);
      expect('${connector.endpoints.single}', 'wss://a.example.com:443/socket.io/1/websocket/ok');
      await connector.channels.single.join();
      await room.dispose();
    });

    test('sessions that never come: eight attempts, then the end', () async {
      final (room, connector, http, clock) = _roomSession(
        addresses: [
          _addressAnswer(['a.example.com:443']),
        ],
        sessions: [const ConnectFailure('looklive')],
      );
      await room.session.connect();
      for (var step = 0; step < 8; step++) {
        await _settle();
        clock.fireLast();
      }
      await _settle();
      expect(http.handshakes, hasLength(9), reason: 'the first ask and its eight retries');
      expect(connector.endpoints, isEmpty);
      expect(room.system, hasLength(1));
      await room.dispose();
    });

    test('a dropped socket: a new session and login (serial 2, again), the same guest', () async {
      final (room, connector, http, clock) = _roomSession();
      await room.session.connect();
      await _settle();
      final first = connector.channels.single;
      await first.join();
      await first.incoming.close();
      await _settle();
      clock.fireLast();
      await _settle();
      expect(connector.channels, hasLength(2));
      final second = connector.channels.last;
      await second.join();
      expect('${connector.endpoints.last}', endsWith('/sid2'));
      final login = second.logins.single;
      final q = login['Q']! as List;
      expect(login['SER'], 2);
      expect((((q[1] as Map)['v'] as Map)['8'], ((q[2] as Map)['v'] as Map)['8']), (1, 0));
      expect(((q[1] as Map)['v'] as Map)['2'], _recordedGuest.account, reason: 'the same guest for the run');
      expect(http.addressRequests, hasLength(1), reason: 'the chat servers are asked once per connect');
      await room.dispose();
    });

    test('0:: and 7::: from the server replace the socket', () async {
      for (final packet in ['0::', '7:::1+0']) {
        final (room, connector, _, clock) = _roomSession();
        await room.session.connect();
        await _settle();
        await connector.channels.single.join();
        await connector.channels.single.receive(packet);
        await _settle();
        clock.fireLast();
        await _settle();
        expect(connector.channels.first.closed, isTrue, reason: packet);
        await connector.channels.last.join();
        expect(connector.channels, hasLength(2), reason: packet);
        await room.dispose();
      }
    });

    test('refused logins: codes that may pass reconnect, three in a row; others end at once', () async {
      final (room, connector, _, clock) = _roomSession();
      await room.session.connect();
      await _settle();
      for (var socket = 0; socket < 3; socket++) {
        await _until(() => connector.channels.length == socket + 1);
        await connector.channels.last.receive('1::');
        await connector.channels.last.receive(_loginAnswer(code: 503));
        clock.fireLast();
      }
      await _until(() => connector.channels.length == 4);
      // A join in between starts the count again.
      await connector.channels.last.join();
      await connector.channels.last.receive('0::');
      clock.fireLast();
      for (var socket = 4; socket < 8; socket++) {
        await _until(() => connector.channels.length == socket + 1);
        await connector.channels.last.receive('1::');
        await connector.channels.last.receive(_loginAnswer(code: 415));
        clock.fireLast();
      }
      await _until(() => room.closed.isCompleted);
      expect(connector.channels, hasLength(8));
      expect(room.system.last.text, 'Login refused: 415');
      // A chatroom that is gone ends the run at once.
      final (ended, gone, _, _) = _roomSession();
      await ended.session.connect();
      await _settle();
      await gone.channels.single.receive('1::');
      await gone.channels.single.receive(_loginAnswer(code: 13002));
      await _settle();
      expect(ended.system.single.text, 'Login refused: 13002');
      expect(gone.channels, hasLength(1));
      expect(gone.channels.single.closed, isTrue);
      await ended.dispose();
    });

    test('kicks: a silent one reconnects; any other ends the run', () async {
      final (room, connector, _, clock) = _roomSession();
      await room.session.connect();
      await _settle();
      await connector.channels.single.join();
      await connector.channels.single.receive('3:::{"sid":13,"cid":3,"code":200,"r":[4,""]}');
      await _settle();
      clock.fireLast();
      await _settle();
      await connector.channels.last.join();
      await connector.channels.last.receive('3:::{"sid":13,"cid":3,"code":200,"r":[1,""]}');
      await _settle();
      expect(room.system.last.text, 'Kicked: chatroomClosed');
      for (final (reason, name) in [(2, 'managerKick'), (5, 'blacked'), (9, '9'), (0, '0')]) {
        final (kicked, other, _, _) = _roomSession();
        await kicked.session.connect();
        await _settle();
        await other.channels.single.join();
        await other.channels.single.receive('3:::{"sid":13,"cid":3,"code":200,"r":[$reason]}');
        await _settle();
        expect(kicked.system.single.text, 'Kicked: $name');
        await kicked.dispose();
      }
      await room.dispose();
    });

    test('an unanswered login times out and reconnects', () async {
      final (room, connector, _, clock) = _roomSession();
      await room.session.connect();
      await _settle();
      await connector.channels.single.receive('1::');
      expect(clock.countArmed(const Duration(seconds: 10)), 1, reason: 'the join watch');
      clock.fire(const Duration(seconds: 10));
      await _settle();
      clock.fireLast();
      await _settle();
      await connector.channels.last.join();
      expect(connector.channels, hasLength(2));
      await room.dispose();
    });

    test('heartbeats: 2:: is echoed; the link heartbeat on demand and every sixth tick after the join', () async {
      final (room, connector, _, clock) = _roomSession();
      await room.session.connect();
      await _settle();
      expect(clock.lastEvery, const Duration(seconds: 30), reason: 'the watchdog tick');
      final socket = connector.channels.single;
      await socket.receive('2::');
      expect(socket.sent, ['2::']);
      room.session.heartbeat();
      await _settle();
      expect(socket.heartbeats, 0, reason: 'nothing before the login');
      await socket.join();
      clock.fireBeat();
      await _settle();
      expect(socket.heartbeats, 0, reason: 'the first tick after the join');
      for (var i = 0; i < 5; i++) {
        clock.fireBeat();
      }
      await _settle();
      expect(socket.heartbeats, 1, reason: 'the sixth tick sends the link heartbeat');
      room.session.heartbeat();
      await _settle();
      expect(socket.heartbeats, 2, reason: 'at once on demand');
      await room.dispose();
      LookliveDanmakuSession(
        args: _args,
        site: LookliveSite(http: LookliveHttp(_Http())),
      ).heartbeat();
    });

    test('the watchdog replaces a socket silent for 90 s', () async {
      final (room, connector, _, clock) = _roomSession();
      await room.session.connect();
      await _settle();
      await connector.channels.single.join();
      clock.fire(const Duration(seconds: 90));
      await _settle();
      clock.fireLast();
      await _settle();
      await connector.channels.last.join();
      expect(connector.channels, hasLength(2));
      await room.dispose();
    });

    test('unusable arguments end at once, without a request', () async {
      final (_, connector, http, _) = _roomSession();
      final bad = LookliveDanmakuSession(
        args: const LookLiveDanmakuArgs(roomId: _room, chatroomId: '0'),
        site: LookliveSite(http: LookliveHttp(_Http())),
      );
      final failure = await bad.connect();
      expect(failure, isA<LiveSiteContentUnavailable>());
      expect(failure?.message, 'No usable room or chatroom');
      expect(http.requests, isEmpty);
      expect(connector.endpoints, isEmpty);
      await bad.dispose();
    });

    test('the recording replayed: one handshake, the login, 47 chats, the echoes', () async {
      final (room, connector, http, _) = _roomSession(sessions: [_handshakeAnswer]);
      await room.session.connect();
      await _settle();
      expect(
        _recordedOutgoing.first,
        LookliveDanmakuCodec.login(chatroomId: _chatroom, guest: _recordedGuest, serial: 1),
      );
      expect('${http.handshakes.single.url}', startsWith('https://chatwl01.yunxinfw.com/socket.io/1/?t='));
      final socket = connector.channels.single;
      for (final frame in liveFrames.skip(2)) {
        if (frame.incoming) {
          await socket.receive(frame.text);
        } else if (frame.text == LookliveDanmakuCodec.heartbeat) {
          room.session.heartbeat();
        }
      }
      await _settle();
      expect(socket.sent, [
        for (final frame in _recordedOutgoing)
          if (frame != '0::') frame,
      ], reason: 'the login, then the echoes and the link heartbeat; the recorder 0:: is not repeated');
      expect(_messages(room.seen).where((message) => message.type == LiveMessageType.system), isEmpty);
      expect(_messages(room.seen), hasLength(47));
      await room.dispose();
    });

    test('after close nothing is reported', () async {
      final (room, connector, _, _) = _roomSession();
      await room.session.connect();
      await _settle();
      await connector.channels.single.join();
      await connector.channels.single.receive(_notify(_text()));
      final seen = room.seen.length;
      await room.dispose();
      // The disposed session closed its socket, so no late frame can arrive.
      expect(connector.channels.single.closed, isTrue);
      expect(room.seen, hasLength(seen), reason: 'the disposed session is silent');
    });

    test('the provider builds a session from the room handle, and refuses a room without a chatroom', () async {
      final http = _Http(
        addresses: [_addressAnswer()],
        sessions: [_handshakeAnswer],
        rooms: [
          // A live room answer whose chatroom id is missing.
          jsonEncode({
            'code': 200,
            'data': {
              'liveStatus': 1,
              'anchor': {
                'liveRoomNo': _room,
                'userId': 351218439,
                'nickName': 'n',
                'avatarUrl': 'http://p1.music.126.net/a.jpg',
              },
              'roomInfo': {'id': 1, 'liveType': 1, 'title': 't', 'roomId': 0},
            },
          }),
        ],
      );
      final site = LookliveSite(http: LookliveHttp(http), connect: _Connector().call);
      final provider = site.capability<LiveDanmakuProvider>()!;
      final withHandle = LiveRoom.normalized(
        platform: lookliveSiteId,
        roomId: _room,
        runtime: RoomRuntime.of(danmakuHandle: _args),
      );
      final session = await provider.createSession(room: withHandle);
      expect(session.isRight(), isTrue, reason: 'the handle spared the detail request');
      await _settle();
      expect(http.asked(LookliveEndpoints.roomPath), isEmpty);
      expect(http.handshakes, hasLength(1));
      final live = session.fold((error) => fail('$error'), (live) => live);
      await live.dispose();
      final bare = LiveRoom.normalized(platform: lookliveSiteId, roomId: _room);
      final refused = await provider.createSession(room: bare);
      expect(refused.isLeft(), isTrue, reason: 'the fresh answer names no chatroom');
      expect(http.asked(LookliveEndpoints.roomPath), hasLength(1));
      expect(http.handshakes, hasLength(1), reason: 'no second socket is opened');
      await site.dispose();
    });
  });
}

/// Waits until [condition] holds, at most five seconds.
Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('condition not reached');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}
