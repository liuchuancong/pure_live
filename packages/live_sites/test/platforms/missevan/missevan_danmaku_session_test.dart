import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/missevan/api/missevan_endpoints.dart';
import 'package:live_sites/src/platforms/missevan/api/missevan_http.dart';
import 'package:live_sites/src/platforms/missevan/danmaku/missevan_danmaku_codec.dart';
import 'package:live_sites/src/platforms/missevan/danmaku/missevan_danmaku_session.dart';
import 'package:live_sites/src/platforms/missevan/missevan_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _room = '777';
final DateTime _at = DateTime.utc(2026, 11, 5, 12);
final Uri _url = Uri.parse('wss://im.missevan.com/ws?room_id=$_room');

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

  /// The text frames sent, in order.
  List<String> get texts => sent.map((frame) => '$frame').toList();

  /// The join command sent first, as its own JSON.
  Map<String, Object?> get join => jsonDecode(texts.first) as Map<String, Object?>;

  /// The `uuid` the session joined with.
  String get uuid => '${join['uuid']}';
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

  MissevanTimers get timers => (
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

  /// Fires the last timer armed for [delay]: the join watch or the silence
  /// watch.
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

  /// Fires the last timer armed, whatever it watches: the next reconnect step.
  void fireLast() {
    if (_after.isEmpty) return;
    final timer = _after.removeLast();
    fired.add(timer.delay);
    timer.fire();
  }

  /// Fires the heartbeat beat.
  void fireBeat() => _every.last.fire();
}

/// One `api/user/info` answer: the cookies it sets and the status it came with.
typedef _Answer = ({List<String> cookies, int status});

/// The transport under the site: the guest session answers from [answers], the
/// last of which repeats; [breaks] is thrown instead of answering.
final class _Http implements LiveHttp {
  _Http([this.answers = const []]);

  final List<_Answer> answers;

  /// When set, every request throws this, as a transport breakdown does.
  Exception? breaks;

  final asked = <Uri>[];
  var _handed = 0;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request.url);
    if (breaks case final error?) throw error;
    final list = answers.isEmpty ? [_cookie('s-1')] : answers;
    final answer = list[_handed.clamp(0, list.length - 1)];
    _handed += 1;
    return LiveResponse(
      statusCode: answer.status,
      headers: const <String, String>{},
      setCookies: answer.cookies,
      bodyBytes: Uint8List.fromList(utf8.encode('{"code":0}')),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

_Answer _cookie(String value, {int status = 200}) => (cookies: ['FM_SESS=$value; Path=/; HttpOnly'], status: status);

_Answer _noCookie({int status = 200}) => (cookies: const ['OTHER=1'], status: status);

/// The join’s answer for [uuid]: accepted with code 0, refused with anything
/// else.
String _answer(String uuid, {int code = 0, String info = ''}) =>
    jsonEncode({'type': 'room', 'event': 'join', 'uuid': uuid, 'code': code, if (info.isNotEmpty) 'info': info});

/// A chat frame of this room.
String _chat(String text, {String id = 'm1'}) => jsonEncode({
  'type': 'message',
  'event': 'new',
  'room_id': int.parse(_room),
  'message': text,
  'msg_id': id,
  'time': 1790733600000,
  'user': {'username': 'Ann', 'user_id': 21, 'titles': null},
});

/// The join's uuid, as version 4.
final RegExp _uuidPattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

/// A session with its connector, clock and transport; [delay] is the wait
/// between the guest session’s attempts, and [answers] what it sets.
(_Room, _Connector, _Clock, _Http) _session({
  List<_Answer> answers = const [],
  Uri? url,
  String roomId = _room,
  Duration delay = Duration.zero,
}) {
  final connector = _Connector();
  final clock = _Clock();
  final http = _Http(answers);
  final site = MissevanSite(http: MissevanHttp(http), connect: connector.connect);
  final session = MissevanDanmakuSession(
    args: MissevanDanmakuArgs(roomId: roomId, url: url ?? _url),
    site: site,
    timers: clock.timers,
    now: () => _at,
    random: Random(7),
    sessionRetryDelay: delay,
  );
  return (_Room(session), connector, clock, http);
}

/// The session, with its event log already collected.
final class _Room {
  _Room(this.session) {
    subscription = session.events.listen(seen.add, onDone: closed.complete);
  }

  final MissevanDanmakuSession session;
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
  for (var turn = 0; turn < 12; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('the guest session', () {
    test('no socket is opened before the cookie arrives, and the cookie rides with it', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      expect(await room.connect(), isNull);
      await _settle();
      expect(http.asked.single, MissevanEndpoints.guestSession);
      expect(connector.asked.single, _url);
      expect(connector.budgets.single, MissevanDanmakuCodec.silenceTimeout);
      expect(connector.headers.single['cookie'], 'FM_SESS=s-1');
      expect(connector.headers.single['origin'], MissevanEndpoints.origin);
      expect(room.seen, isEmpty);
      expect(clock.countArmed(MissevanDanmakuCodec.joinTimeout), 1);
      expect(clock.countArmed(MissevanDanmakuCodec.silenceTimeout), 1);
      expect(clock.lastEvery, MissevanDanmakuCodec.heartbeatInterval);
    });

    test('the join carries the room’s number and the uuid the answer must echo', () async {
      final (room, connector, _, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      final join = connector.last.join;
      expect(join['action'], 'join');
      expect(join['type'], 'room');
      expect(join['room_id'], 777, reason: 'the site sends the room as a number');
      expect(join['uuid'], matches(_uuidPattern));
      expect(join.containsKey('reconnect'), isFalse);
    });

    test('three answers without a cookie are one failed run, not a socket', () async {
      final (room, connector, clock, http) = _session(answers: [_noCookie(), _noCookie(), _noCookie(), _cookie('s-2')]);
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      expect(http.asked, hasLength(MissevanDanmakuCodec.sessionAttempts));
      expect(connector.sockets, isEmpty);
      expect(room.closed.isCompleted, isFalse, reason: 'a missing cookie is retried like any breakdown');
      expect(clock.lastArmed, MissevanDanmakuCodec.reconnectBaseDelay);

      clock.fireLast();
      await _settle();
      expect(http.asked, hasLength(MissevanDanmakuCodec.sessionAttempts + 1));
      expect(connector.sockets, hasLength(1), reason: 'the next run gets the cookie the answers now set');
      expect(connector.headers.single['cookie'], 'FM_SESS=s-2');
    });

    test('the attempts wait the session’s own delay apart', () async {
      final (room, _, _, http) = _session(answers: [_noCookie()], delay: const Duration(milliseconds: 30));
      addTearDown(room.dispose);

      final started = Stopwatch()..start();
      await room.connect();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      started.stop();
      expect(http.asked, hasLength(MissevanDanmakuCodec.sessionAttempts));
      expect(
        started.elapsed,
        greaterThanOrEqualTo(const Duration(milliseconds: 80)),
        reason: 'the delay before attempt 2, and twice before attempt 3',
      );
    });

    test('a broken transport is a failed run, told in the transport’s words', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);
      http.breaks = const ConnectFailure('connection refused');

      await room.connect();
      await _settle();
      expect(
        http.asked,
        hasLength(MissevanDanmakuCodec.sessionAttempts),
        reason: 'the attempt loop is exhausted before the run is called failed',
      );
      expect(connector.sockets, isEmpty);
      expect(clock.lastArmed, MissevanDanmakuCodec.reconnectBaseDelay);

      for (var step = 2; step <= MissevanDanmakuCodec.maxReconnects; step++) {
        clock.fireLast();
        await _settle();
        expect(clock.lastArmed, MissevanDanmakuCodec.reconnectBaseDelay * step);
      }
      clock.fireLast();
      await _settle();
      await room.closed.future;
      expect(
        room.ofType(LiveMessageType.system).single.text,
        contains('connection refused'),
        reason: 'the terminal line keeps the transport’s own words',
      );
    });
  });

  group('joining', () {
    test('the answer of another join is not an answer to this one', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_answer('00000000-0000-4000-8000-000000000000'));
      await _settle();
      expect(clock.countArmed(MissevanDanmakuCodec.joinTimeout), 1, reason: 'the watch is still armed');
      expect(room.seen, isEmpty);

      connector.last.deliver(_answer(connector.last.uuid));
      await _settle();
      expect(clock.countArmed(MissevanDanmakuCodec.joinTimeout), isZero, reason: 'its own uuid discharged it');
      expect(clock.countArmed(MissevanDanmakuCodec.silenceTimeout), 1);
      expect(room.seen, isEmpty, reason: 'a join is not a message for the room');
    });

    test('a join that never comes replaces the socket', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      final first = connector.last;
      clock.fire(MissevanDanmakuCodec.joinTimeout);
      await _settle();
      expect(clock.fired.single, MissevanDanmakuCodec.joinTimeout);
      expect(clock.armedCount, 1, reason: 'only the next step is armed');
      expect(clock.lastArmed, MissevanDanmakuCodec.reconnectBaseDelay);

      clock.fireLast();
      await _settle();
      expect(first.closed, isTrue);
      expect(connector.sockets, hasLength(2));
      expect(http.asked, hasLength(1), reason: 'the cookie it already has is reused');
      expect(connector.last.join.containsKey('reconnect'), isFalse, reason: 'the room was never joined');
    });

    test('the rejoin after a joined run says reconnect', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_answer(connector.last.uuid));
      await _settle();
      clock.fire(MissevanDanmakuCodec.silenceTimeout);
      await _settle();
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(2));
      expect(connector.last.join['reconnect'], 1);
      expect(http.asked, hasLength(1), reason: 'and the guest session of three days is asked for once');
    });

    test('a refused join is answered with a fresh session and socket, quietly', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_answer(connector.last.uuid, code: 500, info: '无法找到该聊天室'));
      await _settle();
      expect(room.seen, isEmpty, reason: 'the rejoin is not told to the room');
      expect(clock.lastArmed, MissevanDanmakuCodec.reconnectBaseDelay);

      clock.fireLast();
      await _settle();
      expect(http.asked, hasLength(2), reason: 'the cookie that was refused is thrown away');
      expect(connector.sockets, hasLength(2));
      expect(connector.headers.last['cookie'], 'FM_SESS=s-1');
    });
  });

  group('what the socket says', () {
    test('chat is reported, the heartbeat echo is not, and both re-arm the watch', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_answer(connector.last.uuid));
      connector.last.deliver(_chat('你好'));
      await _settle();
      expect(room.seen.map((message) => message.text), ['你好']);
      expect(room.seen.single.sender?.userName, 'Ann');
      expect(clock.countArmed(MissevanDanmakuCodec.silenceTimeout), 1);

      connector.last.deliver(MissevanDanmakuCodec.heartbeat);
      await _settle();
      expect(room.seen, hasLength(1), reason: 'the server’s echo of the heartbeat is not a message');
      expect(clock.countArmed(MissevanDanmakuCodec.silenceTimeout), 1, reason: 'but it does prove the socket lives');

      clock.fireBeat();
      expect(connector.last.texts.last, MissevanDanmakuCodec.heartbeat);
    });

    test('the fourth refusal ends the session, and the reason is told once', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      for (var refusal = 1; refusal <= MissevanDanmakuCodec.maxRejoins; refusal++) {
        connector.last.deliver(_answer(connector.last.uuid, code: 500, info: 'no such room'));
        await _settle();
        expect(room.closed.isCompleted, isFalse, reason: 'refusal $refusal is still rejoined');
        expect(clock.lastArmed, MissevanDanmakuCodec.reconnectBaseDelay * refusal);
        clock.fireLast();
        await _settle();
      }
      expect(connector.sockets, hasLength(MissevanDanmakuCodec.maxRejoins + 1));

      connector.last.deliver(_answer(connector.last.uuid, code: 500, info: 'no such room'));
      await _settle();
      await room.closed.future;
      expect(room.ofType(LiveMessageType.system).single.text, 'join refused: 500 no such room');
      expect(clock.armedCount, isZero);
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(MissevanDanmakuCodec.maxRejoins + 1), reason: 'nothing reconnects');
    });

    test('a joined run forgives the refusals before it', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      for (var refusal = 0; refusal < MissevanDanmakuCodec.maxRejoins; refusal++) {
        connector.last.deliver(_answer(connector.last.uuid, code: 500));
        await _settle();
        clock.fireLast();
        await _settle();
      }
      connector.last.deliver(_answer(connector.last.uuid));
      await _settle();
      expect(room.closed.isCompleted, isFalse);

      connector.last.deliver(_answer(connector.last.uuid, code: 500));
      await _settle();
      expect(room.closed.isCompleted, isFalse, reason: 'the count starts again');
      expect(clock.lastArmed, MissevanDanmakuCodec.reconnectBaseDelay);
    });
  });

  group('a socket that stops', () {
    test('the backoff steps once per failed run and the budget is told once', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      connector.failure = const ConnectFailure('handshake refused');
      await room.connect();
      await _settle();
      expect(room.seen, isEmpty, reason: 'the first failure is already on the ladder');
      expect(clock.lastArmed, MissevanDanmakuCodec.reconnectBaseDelay);

      for (var step = 1; step <= MissevanDanmakuCodec.maxReconnects; step++) {
        clock.fireLast();
        await _settle();
        expect(clock.fired.last, MissevanDanmakuCodec.reconnectBaseDelay * step, reason: 'failure $step');
      }
      await room.closed.future;
      final terminal = room.ofType(LiveMessageType.system).single;
      expect(terminal.text, contains('handshake refused'), reason: 'the line names what never came');
      expect(terminal.sentAt, _at, reason: 'the clock the session was given');
      expect(clock.armedCount, isZero);

      clock.fireLast();
      await _settle();
      expect(connector.sockets, isEmpty, reason: 'nothing reconnects after the budget');
    });

    test('a socket that joined starts the budget again', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      connector.failure = const ConnectFailure('refused');
      await room.connect();
      await _settle();
      clock.fireLast();
      await _settle();
      expect(clock.lastArmed, MissevanDanmakuCodec.reconnectBaseDelay * 2, reason: 'two runs, no join between');

      connector.failure = null;
      clock.fireLast();
      await _settle();
      connector.last.deliver(_answer(connector.last.uuid));
      await _settle();

      clock.fire(MissevanDanmakuCodec.silenceTimeout);
      await _settle();
      expect(clock.lastArmed, MissevanDanmakuCodec.reconnectBaseDelay, reason: 'counted from the live run again');
    });

    test('an error and a close both go to the retry path', () async {
      for (final breakWith in <void Function(_Socket)>[(s) => s.fail(StateError('boom')), (s) => s.end()]) {
        final (room, connector, clock, _) = _session();
        addTearDown(room.dispose);

        await room.connect();
        await _settle();
        breakWith(connector.last);
        await _settle();
        expect(clock.lastArmed, MissevanDanmakuCodec.reconnectBaseDelay);
        clock.fireLast();
        await _settle();
        expect(connector.sockets, hasLength(2));
      }
    });
  });

  group('stopping', () {
    test('disconnect closes the socket and drops a retry that was already armed', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fire(MissevanDanmakuCodec.joinTimeout);
      await _settle();
      await room.session.disconnect();
      expect(connector.last.closed, isTrue);
      expect(clock.armedCount, isZero, reason: 'the retry that was already armed is dropped');
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(1), reason: 'the queued retry found the session gone');

      await room.connect();
      await _settle();
      expect(connector.sockets, hasLength(2), reason: 'and it can be joined again');
    });

    test('a socket that opens after the session stopped is closed and unused', () async {
      final (room, connector, _, _) = _session();
      addTearDown(room.dispose);

      connector.hold = Completer<void>();
      await room.connect();
      await _settle();
      await room.session.disconnect();
      connector.hold!.complete();
      await _settle();
      expect(connector.sockets, hasLength(1));
      expect(connector.last.closed, isTrue, reason: 'the late socket is not handed to the room');
      expect(connector.last.sent, isEmpty, reason: 'and nothing was joined with it');
    });

    test('dispose ends the stream and leaves no timer armed', () async {
      final (room, connector, clock, _) = _session();
      await room.connect();
      await _settle();
      expect(connector.last.texts.single, contains('"action":"join"'));
      await room.session.dispose();
      await room.closed.future;
      expect(clock.armedCount, isZero);
      expect(connector.last.closed, isTrue);
      await room.session.dispose();
      expect(room.seen, isEmpty);
      await room.dispose();
    });

    test('a room that is not a number never asks for a session', () async {
      final (room, connector, _, http) = _session(roomId: 'not a room');
      expect(await room.connect(), isA<LiveSiteError>());
      expect(http.asked, isEmpty);
      expect(connector.sockets, isEmpty);

      await room.session.dispose();
      expect(await room.connect(), isA<LiveSiteUnsupported>());
      await room.dispose();
    });
  });
}
