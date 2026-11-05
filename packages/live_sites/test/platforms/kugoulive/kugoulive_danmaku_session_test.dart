import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/kugoulive/api/kugoulive_http.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_danmaku_session.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_protobuf.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _room = '555';
const String _token = 'soctok';

/// The clock the session is given; a test moves it on to outlive a token.
final class _Now {
  DateTime at = DateTime.utc(2026, 11, 5, 12);

  DateTime read() => at;

  void by(Duration delay) => at = at.add(delay);
}

/// `SocketProtocol.Message`: 1 offset, 2 ack, 3 rpt, 4 msgId, 5 compression,
/// 6 codec (1 reads the content as protobuf), 7 content.
Uint8List _envelope(
  List<int> content, {
  String offset = 'o1',
  int ack = 0,
  int rpt = 0,
  String msgId = 'm1',
  int codec = 1,
}) =>
    (KugouliveProtoWriter()
          ..string(1, offset)
          ..integer(2, ack)
          ..integer(3, rpt)
          ..string(4, msgId)
          ..integer(5, 0)
          ..integer(6, codec)
          ..bytes(7, content))
        .toBytes();

/// A server frame of [command]: the 18-byte header over [envelope].
Uint8List _frame(int command, Uint8List envelope) {
  final header = ByteData(18)
    ..setUint8(0, 100)
    ..setInt16(1, 3)
    ..setUint8(3, 1)
    ..setInt16(4, 12)
    ..setInt32(6, command)
    ..setInt32(10, envelope.length);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...envelope]);
}

/// The answer to the login: [status] 1 joins, anything else refuses with
/// [errorno].
Uint8List _status({int type = 1, int status = 1, int errorno = 0, String msg = '', String? sid}) {
  final body = KugouliveProtoWriter()
    ..integer(2, type)
    ..integer(4, status)
    ..integer(5, errorno)
    ..string(6, msg);
  if (sid != null) body.string(7, sid);
  return _frame(KugouliveDanmakuCodec.statusCommand, _envelope(body.toBytes()));
}

/// A chat packet of this room, as the site writes it in JSON.
Uint8List _chatFrame({String text = '你好', String name = 'Ann'}) => _frame(
  KugouliveDanmakuCodec.chatCommand,
  _envelope(
    utf8.encode(
      jsonEncode({
        'roomid': _room,
        'senderid': 1001,
        'time': 1790733600,
        'content': {'chatmsg': text, 'sendername': name, 'seq': 77},
      }),
    ),
    codec: 0,
  ),
);

/// A gift packet of this room; with [ack] the page acknowledges it.
Uint8List _giftFrame({String msgId = 'g1', int ack = 0}) => _frame(
  KugouliveDanmakuCodec.giftCommand,
  _envelope(
    utf8.encode(
      jsonEncode({
        'roomid': _room,
        'content': {
          'roomid': _room,
          'giftid': '77',
          'giftname': '玫瑰',
          'num': 2,
          'price': 10,
          'comboIdV2': 'c1',
          'comboId': '9',
          'comboGiftSum': 4,
          'image': '/fxstatic/images/giftres/rose.png',
          'sendername': 'Ann',
          'senderid': '1001',
          'receivername': '主播',
          'senderrichlevelV2': 12,
        },
      }),
    ),
    codec: 0,
    ack: ack,
    msgId: msgId,
    offset: 'o9',
    rpt: 2,
  ),
);

/// The site's heartbeat echo: four bytes whose fourth says heartbeat.
const List<int> _heartbeatEcho = [100, 3, 1, 0];

/// The scheduler answer that hands out [hosts] and a token.
String _dispatch({int code = 0, List<String> hosts = const ['1.2.3.4:8001'], String token = _token, int age = 60000}) =>
    jsonEncode({
      'code': code,
      if (code == 0)
        'data': {
          'protocol': 'wss://',
          'addrs': [
            for (final host in hosts) {'host': host},
          ],
          'soctoken': token,
          'age': age,
        }
      else
        'msg': 'room off air',
    });

/// The socket the session drives, by hand.
final class _Socket implements SocketChannel {
  final _incoming = StreamController<Object?>();
  final sent = <Object>[];
  bool closed = false;

  @override
  Stream<Object?> get stream => _incoming.stream;

  @override
  void add(Object data) => sent.add(data);

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
    if (!_incoming.isClosed) await _incoming.close();
  }

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  void deliver(Object? data) => _incoming.add(data);
  void fail(Object error) => _incoming.addError(error);
  void end() => _incoming.close();

  /// The command of the frame sent at [index], read where the header puts it.
  int commandAt(int index) =>
      ByteData.sublistView(Uint8List.fromList(sent[index] as List<int>)).getInt32(6);

  /// The bytes of every frame sent, joined for a search.
  String get text {
    final out = BytesBuilder();
    for (final frame in sent) {
      out.add(Uint8List.fromList(frame as List<int>));
    }
    return utf8.decode(out.takeBytes(), allowMalformed: true);
  }
}

/// The connector the site was built with: every request recorded, and it can be
/// told to refuse or to wait.
final class _Connector {
  final sockets = <_Socket>[];
  final asked = <Uri>[];
  final headers = <Map<String, String>>[];
  final budgets = <Duration>[];

  /// When set, opening the socket throws this instead of answering.
  Exception? failure;

  /// When set, the socket arrives only after its completer is completed.
  Completer<void>? hold;

  Future<SocketChannel> connect(
    Uri endpoint, {
    required Map<String, String> headers,
    required Iterable<String>? protocols,
    required Duration connectTimeout,
    Duration? pingInterval,
  }) async {
    asked.add(endpoint);
    this.headers.add(headers);
    budgets.add(connectTimeout);
    if (failure case final error?) throw error;
    final socket = _Socket();
    sockets.add(socket);
    if (hold case final waiting?) await waiting.future;
    return socket;
  }

  _Socket get last => sockets.last;
}

/// The transport under the site: every scheduler request answers from
/// [answers], the last of which repeats; [breaks] throws instead.
final class _Http implements LiveHttp {
  _Http([List<String> answers = const []]) : answers = answers.isEmpty ? [_dispatch()] : answers;

  final List<String> answers;

  /// When set, every request throws this, as a transport breakdown does.
  Exception? breaks;

  final asked = <Uri>[];
  var _handed = 0;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request.url);
    if (breaks case final error?) throw error;
    final text = answers[_handed.clamp(0, answers.length - 1)];
    _handed += 1;
    return LiveResponse(
      statusCode: 200,
      headers: const <String, String>{},
      bodyBytes: Uint8List.fromList(utf8.encode(text)),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
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
  final _every = <({Duration period, void Function() fire})>[];

  /// Every delay whose timer was fired, in order.
  final fired = <Duration>[];

  Duration? _lastEvery;

  KugouliveTimers get timers => (
    after: (delay, callback) {
      final record = (delay: delay, fire: callback);
      _after.add(record);
      return _Armed(() => _after.remove(record));
    },
    every: (period, callback) {
      _every.add((period: period, fire: () => callback(_Armed(() {}))));
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

  /// Fires the last timer armed for [delay]: the login watch or the silence watch.
  void fire(Duration delay) {
    for (var index = _after.length - 1; index >= 0; --index) {
      if (_after[index].delay != delay) continue;
      final timer = _after.removeAt(index);
      fired.add(timer.delay);
      timer.fire();
      return;
    }
    throw StateError('nothing is armed for $delay');
  }

  /// Fires the last timer armed, whatever it watches: the next step.
  void fireLast() {
    if (_after.isEmpty) return;
    final timer = _after.removeLast();
    fired.add(timer.delay);
    timer.fire();
  }

  /// Fires the heartbeat beat.
  void fireBeat() => _every.last.fire();
}

/// A session with its connector, clock and scheduler answers.
(_Room, _Connector, _Clock, _Http, _Now) _session({List<String> answers = const [], String roomId = _room}) {
  final connector = _Connector();
  final clock = _Clock();
  final now = _Now();
  final http = _Http(answers);
  final site = KugouliveSite(http: KugouliveHttp(http), connect: connector.connect);
  final session = KugouliveDanmakuSession(
    args: KugouliveDanmakuArgs(roomId: roomId),
    site: site,
    timers: clock.timers,
    now: now.read,
    random: Random(5),
  );
  return (_Room(session), connector, clock, http, now);
}

/// The session, with its event log already collected.
final class _Room {
  _Room(this.session) {
    subscription = session.events.listen(seen.add, onDone: closed.complete);
  }

  final KugouliveDanmakuSession session;
  late final StreamSubscription<LiveMessage> subscription;
  final seen = <LiveMessage>[];
  final closed = Completer<void>();

  Future<LiveSiteError?> connect() => session.connect();

  /// The messages of the reported kind.
  List<LiveMessage> ofType(LiveMessageType type) => seen.where((message) => message.type == type).toList();

  Future<void> dispose() async {
    await subscription.cancel();
    await session.dispose();
  }
}

Future<void> _settle() async {
  for (var turn = 0; turn < 20; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('the scheduler in front of the socket', () {
    test('the room is asked for hosts and a token, and the login carries the token', () async {
      final (room, connector, clock, http, _) = _session();
      addTearDown(room.dispose);

      expect(await room.connect(), isNull);
      await _settle();
      expect(http.asked.single.toString(), contains('555'));
      expect(connector.asked.single, Uri.parse('wss://1.2.3.4:8001'));
      expect(connector.budgets.single, KugouliveDanmakuCodec.silenceTimeout);
      expect(connector.headers.single, KugouliveDanmakuCodec.socketHeaders);
      expect(connector.last.commandAt(0), KugouliveDanmakuCodec.loginCommand);
      expect(connector.last.text, contains(_token), reason: 'the login is signed with this grant’s token');
      expect(clock.countArmed(KugouliveDanmakuCodec.joinTimeout), 1);
      expect(clock.countArmed(KugouliveDanmakuCodec.silenceTimeout), 1);
      expect(clock.lastEvery, KugouliveDanmakuCodec.heartbeatInterval);
    });

    test('the three tries are 1.5 s and 4.5 s apart on the session’s own clock', () async {
      final (room, connector, clock, http, _) = _session(answers: [_dispatch(hosts: const [])]);
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      expect(http.asked, hasLength(1), reason: 'the second request waits for its step');
      expect(clock.lastArmed, const Duration(milliseconds: 1500));

      clock.fireLast();
      await _settle();
      expect(clock.lastArmed, const Duration(milliseconds: 4500));
      clock.fireLast();
      await _settle();
      expect(http.asked, hasLength(3), reason: 'the page asks three times');
      expect(connector.sockets, isEmpty);
      expect(room.closed.isCompleted, isFalse, reason: 'a missing grant is one failed run among the budget');
      expect(clock.lastArmed, KugouliveDanmakuCodec.reconnectBaseDelay);
      expect(clock.fired, [
        const Duration(milliseconds: 1500),
        const Duration(milliseconds: 4500),
      ], reason: 'the page’s own backoff, not the reconnect ladder');
    });

    test('a scheduler that refuses ends the session without a socket', () async {
      final (room, connector, clock, _, _) = _session(answers: [_dispatch(code: 404)]);
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      await room.closed.future;
      expect(connector.sockets, isEmpty);
      expect(clock.armedCount, isZero);
      expect(room.ofType(LiveMessageType.system).single.text, 'dispatch: code 404 room off air');
    });

    test('a room number that is not one is refused before any request', () async {
      final (room, connector, _, http, _) = _session(roomId: '12');
      expect(await room.connect(), isA<LiveSiteNotFound>());
      expect(http.asked, isEmpty);
      expect(connector.sockets, isEmpty);

      await room.session.dispose();
      expect(await room.connect(), isA<LiveSiteUnsupported>());
      await room.dispose();
    });
  });

  group('the login answer', () {
    test('status 1 joins, and its session id rides the next login', () async {
      final (room, connector, clock, http, _) = _session(
        answers: [
          _dispatch(token: 'a-1'),
          _dispatch(token: 'a-2'),
        ],
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_status(sid: 'sid-1'));
      await _settle();
      expect(clock.countArmed(KugouliveDanmakuCodec.joinTimeout), isZero);
      expect(room.seen, isEmpty, reason: 'a join is not a message for the room');

      clock.fire(KugouliveDanmakuCodec.silenceTimeout);
      await _settle();
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(2));
      expect(http.asked, hasLength(1), reason: 'a young token is kept for the next socket');
      expect(connector.last.text, contains('sid-1'), reason: 'and the last session is named again');
    });

    test('a socket that is not joined within ten seconds is replaced and its token dropped', () async {
      final (room, connector, clock, http, _) = _session(
        answers: [
          _dispatch(token: 'a-1'),
          _dispatch(token: 'a-2'),
        ],
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fire(KugouliveDanmakuCodec.joinTimeout);
      await _settle();
      expect(clock.lastArmed, KugouliveDanmakuCodec.reconnectBaseDelay);

      clock.fireLast();
      await _settle();
      expect(connector.sockets.first.closed, isTrue);
      expect(connector.sockets, hasLength(2));
      expect(http.asked, hasLength(2), reason: 'a token whose login was never answered is not trusted');
      expect(connector.last.text, contains('a-2'));
    });

    test('a token older than its age is asked for again', () async {
      final (room, connector, clock, http, now) = _session(
        answers: [
          _dispatch(),
          _dispatch(token: 'a-2'),
        ],
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_status(sid: 'sid-1'));
      await _settle();

      now.by(const Duration(seconds: 61));
      clock.fire(KugouliveDanmakuCodec.silenceTimeout);
      await _settle();
      clock.fireLast();
      await _settle();
      expect(http.asked, hasLength(2), reason: 'the scheduler’s age has passed');
      expect(connector.last.text, contains('a-2'));
    });

    test('a refused login reconnects, and a refusal about the token throws it away', () async {
      final (room, connector, clock, http, _) = _session(
        answers: [
          _dispatch(token: 'a-1'),
          _dispatch(token: 'a-2'),
          _dispatch(token: 'a-3'),
        ],
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      for (var refusal = 1; refusal <= KugouliveDanmakuCodec.maxRefusals; refusal++) {
        connector.last.deliver(_status(status: 0, errorno: 622, msg: 'token rejected'));
        await _settle();
        expect(room.closed.isCompleted, isFalse, reason: 'refusal $refusal is still retried');
        expect(clock.lastArmed, KugouliveDanmakuCodec.reconnectBaseDelay * refusal);
        clock.fireLast();
        await _settle();
        expect(http.asked, hasLength(refusal + 1), reason: '622 means the token went with it');
      }
      connector.last.deliver(_status(status: 0, errorno: 622, msg: 'token rejected'));
      await _settle();
      await room.closed.future;
      expect(room.ofType(LiveMessageType.system).single.text, 'chat refused: 901 errorno 622 token rejected');
      expect(clock.armedCount, isZero);
    });

    test('a refusal that is not about the token keeps it and marks the login answered', () async {
      final (room, connector, clock, http, _) = _session(
        answers: [
          _dispatch(token: 'a-1'),
          _dispatch(token: 'a-2'),
        ],
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_status(status: 0, errorno: 621, msg: 'room busy'));
      await _settle();
      expect(clock.lastArmed, KugouliveDanmakuCodec.reconnectBaseDelay);

      clock.fireLast();
      await _settle();
      expect(http.asked, hasLength(1), reason: 'the token was not what the server refused');
      expect(connector.last.text, contains('a-1'), reason: 'the same token went on the new socket');
    });
  });

  group('what the socket says', () {
    test('chat and gifts are reported, a gift is acknowledged, and a repeat is not told twice', () async {
      final (room, connector, _, _, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_status(sid: 'sid-1'));
      connector.last.deliver(_chatFrame());
      connector.last.deliver(_giftFrame(ack: 1));
      await _settle();
      expect(room.seen.map((message) => message.text), ['你好', '玫瑰 ×2']);
      expect(room.seen.last.type, LiveMessageType.gift);
      expect(connector.last.sent, hasLength(2), reason: 'the login and the page’s acknowledgment');
      expect(connector.last.commandAt(1), KugouliveDanmakuCodec.ackCommand);

      final before = room.seen.length;
      connector.last.deliver(_giftFrame(ack: 1));
      await _settle();
      expect(room.seen, hasLength(before), reason: 'the same msgId is the server’s repeat, not a new gift');

      connector.last.deliver(_giftFrame(msgId: 'g2'));
      await _settle();
      expect(room.seen, hasLength(before + 1), reason: 'another gift is another line');
    });

    test('the heartbeat goes out on the beat and its echo re-arms the watch without a word', () async {
      final (room, connector, clock, _, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      final login = connector.last.sent.length;
      clock.fireBeat();
      expect(connector.last.sent.length, login + 1);
      expect(connector.last.sent[login], KugouliveDanmakuCodec.heartbeat(), reason: 'the four-byte keep-alive');

      connector.last.deliver(_heartbeatEcho);
      await _settle();
      expect(room.seen, isEmpty);
      expect(clock.countArmed(KugouliveDanmakuCodec.silenceTimeout), 1);
    });

    test('a text frame reports nothing but still proves the socket is alive', () async {
      final (room, connector, clock, _, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      expect(clock.countArmed(KugouliveDanmakuCodec.joinTimeout), 1);
      connector.last.deliver('{"not":"binary"}');
      await _settle();
      expect(room.seen, isEmpty, reason: 'the scheduler of frames is bytes, and this is not one');
      expect(clock.countArmed(KugouliveDanmakuCodec.silenceTimeout), 1, reason: 'the watch is re-armed all the same');
      expect(clock.countArmed(KugouliveDanmakuCodec.joinTimeout), 1);
    });
  });

  group('the budget', () {
    test('the steps grow and the ninth run without a join ends the session', () async {
      final (room, connector, clock, _, _) = _session();
      addTearDown(room.dispose);

      connector.failure = const ConnectFailure('handshake refused');
      await room.connect();
      await _settle();
      expect(clock.lastArmed, KugouliveDanmakuCodec.reconnectBaseDelay);

      for (var step = 1; step <= KugouliveDanmakuCodec.maxReconnects; step++) {
        clock.fireLast();
        await _settle();
        expect(clock.fired.last, KugouliveDanmakuCodec.reconnectBaseDelay * step, reason: 'failure $step');
      }
      await room.closed.future;
      final terminal = room.ofType(LiveMessageType.system).single;
      expect(terminal.text, contains('handshake refused'), reason: 'the line names what never came');
      expect(terminal.sentAt, DateTime.utc(2026, 11, 5, 12));
      expect(clock.armedCount, isZero);
      expect(connector.sockets, isEmpty, reason: 'nothing reconnects after the budget');
    });

    test('a joined run starts the budget again', () async {
      final (room, connector, clock, _, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_status(sid: 'sid-1'));
      await _settle();

      clock.fire(KugouliveDanmakuCodec.silenceTimeout);
      await _settle();
      expect(clock.lastArmed, KugouliveDanmakuCodec.reconnectBaseDelay);
      clock.fireLast();
      await _settle();
      clock.fire(KugouliveDanmakuCodec.silenceTimeout);
      await _settle();
      expect(
        clock.lastArmed,
        KugouliveDanmakuCodec.reconnectBaseDelay * 2,
        reason: 'the run after the join never joined, so it counts',
      );

      connector.last.deliver(_status(sid: 'sid-2'));
      await _settle();
      clock.fire(KugouliveDanmakuCodec.silenceTimeout);
      await _settle();
      expect(clock.lastArmed, KugouliveDanmakuCodec.reconnectBaseDelay, reason: 'and a joined run clears it');
    });

    test('an error and a close both go to the retry path', () async {
      for (final breakWith in <void Function(_Socket)>[(s) => s.fail(StateError('boom')), (s) => s.end()]) {
        final (room, connector, clock, _, _) = _session();
        addTearDown(room.dispose);

        await room.connect();
        await _settle();
        breakWith(connector.last);
        await _settle();
        expect(clock.lastArmed, KugouliveDanmakuCodec.reconnectBaseDelay);
        clock.fireLast();
        await _settle();
        expect(connector.sockets, hasLength(2));
      }
    });
  });

  group('stopping', () {
    test('disconnect closes the socket and drops a retry that was already armed', () async {
      final (room, connector, clock, _, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fire(KugouliveDanmakuCodec.joinTimeout);
      await _settle();
      await room.session.disconnect();
      expect(connector.last.closed, isTrue);
      expect(clock.armedCount, isZero);
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(1), reason: 'the queued retry found the session gone');

      await room.connect();
      await _settle();
      expect(connector.sockets, hasLength(2), reason: 'and it can be joined again');
    });

    test('a socket that opens after the session stopped is closed and unused', () async {
      final (room, connector, _, _, _) = _session();
      addTearDown(room.dispose);

      connector.hold = Completer<void>();
      await room.connect();
      await _settle();
      await room.session.disconnect();
      connector.hold!.complete();
      await _settle();
      expect(connector.sockets, hasLength(1));
      expect(connector.last.closed, isTrue);
      expect(connector.last.sent, isEmpty, reason: 'and nothing was logged in with it');
    });

    test('dispose ends the stream and leaves no timer armed', () async {
      final (room, connector, clock, _, _) = _session();
      await room.connect();
      await _settle();
      await room.session.dispose();
      await room.closed.future;
      expect(clock.armedCount, isZero);
      expect(connector.last.closed, isTrue);
      await room.session.dispose();
      await room.dispose();
    });
  });
}
