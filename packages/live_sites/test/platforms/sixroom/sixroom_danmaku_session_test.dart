import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/sixroom/api/sixroom_endpoints.dart';
import 'package:live_sites/src/platforms/sixroom/api/sixroom_http.dart';
import 'package:live_sites/src/platforms/sixroom/danmaku/sixroom_danmaku_codec.dart';
import 'package:live_sites/src/platforms/sixroom/danmaku/sixroom_danmaku_session.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_room_parser.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _room = '8888';
const String _user = '1234';
final DateTime _at = DateTime.utc(2026, 11, 5, 12);

/// The `getChat.php` answer naming these chat servers.
String _chatServers(List<String> servers) => jsonEncode({'websock': servers});

/// A frame of the chat socket, in the page's `key=value` lines.
String _frame(Map<String, String> fields) {
  final text = [for (final MapEntry(:key, :value) in fields.entries) '$key=$value'].join('\r\n');
  return '$text\r\n';
}

/// The answer to the login.
String get _loginOk => _frame({'command': 'result', 'content': 'login.success'});
String get _loginFailed => _frame({'command': 'result', 'content': 'login.failed'});

/// The `content` of a `receivemessage` frame: the site writes it base64 with
/// `(`, `)` and `@` standing for `+`, `/` and `=`.
String _payload(Map<String, Object?> root) =>
    base64.encode(utf8.encode(jsonEncode(root))).replaceAll('+', '(').replaceAll('/', ')').replaceAll('=', '@');

/// A `001` message frame carrying one public chat line.
String get _chatFrame => _frame({
  'command': 'receivemessage',
  'content': _payload({
    'flag': '001',
    'content': {'typeID': SixroomDanmakuCodec.publicChat, 'from': 'Ann', 'content': '你好'},
  }),
});

/// A frame carrying a flag the room page stops its socket on.
String _stopped(String flag, [String said = '房间人多']) => _frame({
  'command': 'receivemessage',
  'content': _payload({'flag': flag, 'content': said}),
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

  /// The text frames sent, in order.
  List<String> get texts => sent.map((frame) => '$frame').toList();

  /// The guest id the login went out with.
  int get guestId => int.parse(RegExp(r'uid=(\d+)').firstMatch(texts.first)![1]!);
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

/// The transport under the site: every `getChat.php` answers from [answers],
/// the last of which repeats; [breaks] is thrown instead of answering.
final class _Http implements LiveHttp {
  _Http([List<String> answers = const []])
    : answers = answers.isEmpty
          ? [
              _chatServers(['ws1.6rooms.com:8080']),
            ]
          : answers;

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

  SixroomTimers get timers => (
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

  /// How many repeating watches are armed: none before the login is answered.
  int get everyCount => _every.length;

  /// The one-shot timers currently armed.
  int get armedCount => _after.length;

  /// How many one-shot timers armed for [delay] are still waiting.
  int countArmed(Duration delay) => _after.where((timer) => timer.delay == delay).length;

  /// The delay of the last timer armed.
  Duration? get lastArmed => _after.isEmpty ? null : _after.last.delay;

  /// Fires the last timer armed for [delay]: the login watch or the silence
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

  /// Fires the keep-alive beat.
  void fireBeat() => _every.last.fire();
}

/// A session with its connector, clock and server answers.
(_Room, _Connector, _Clock, _Http) _session({
  List<String> answers = const [],
  String room = _room,
  String user = _user,
}) {
  final connector = _Connector();
  final clock = _Clock();
  final http = _Http(answers);
  final site = SixroomSite(http: SixroomHttp(http), connect: connector.connect);
  final session = SixroomDanmakuSession(
    args: SixroomDanmakuArgs(roomId: room, userId: user),
    site: site,
    timers: clock.timers,
    now: () => _at,
    random: Random(11),
  );
  return (_Room(session), connector, clock, http);
}

/// The session, with its event log already collected.
final class _Room {
  _Room(this.session) {
    subscription = session.events.listen(seen.add, onDone: closed.complete);
  }

  final SixroomDanmakuSession session;
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
  group('the server list and the login', () {
    test('the room’s servers are asked for, and the guest login goes out at once', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      expect(await room.connect(), isNull);
      await _settle();
      expect(http.asked.single, SixroomEndpoints.chatServersUrl(_user));
      expect(connector.asked.single, Uri(scheme: 'wss', host: 'ws1.6rooms.com', port: 8080));
      expect(connector.budgets.single, SixroomDanmakuCodec.connectTimeout);
      expect(connector.headers.single, SixroomDanmakuCodec.socketHeaders);
      expect(connector.last.texts.single, SixroomDanmakuCodec.login(connector.last.guestId, _user));
      expect(connector.last.guestId, inInclusiveRange(1800000000, 1999999999), reason: 'the page’s guest id range');
      expect(room.seen, isEmpty);
      expect(clock.countArmed(SixroomDanmakuCodec.joinTimeout), 1);
      expect(clock.countArmed(SixroomDanmakuCodec.silenceTimeout), 1);
      expect(clock.everyCount, isZero, reason: 'the keep-alive starts with the login’s answer');
    });

    test('login.success joins: a heartbeat goes out at once, then on the beat', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_loginOk);
      await _settle();
      expect(connector.last.texts, [contains('command=login'), SixroomDanmakuCodec.heartbeat]);
      expect(clock.countArmed(SixroomDanmakuCodec.joinTimeout), isZero);
      expect(clock.lastEvery, SixroomDanmakuCodec.heartbeatInterval);
      expect(room.seen, isEmpty, reason: 'a join is not a message for the room');

      clock.fireBeat();
      expect(connector.last.texts, hasLength(3), reason: 'the beat sends the same noop keep-alive again');
      expect(connector.last.texts.last, SixroomDanmakuCodec.heartbeat);
    });

    test('a list of several servers is walked before it is asked for again', () async {
      final (room, connector, clock, http) = _session(
        answers: [
          _chatServers(['ws1.6rooms.com:8080', 'ws2.6rooms.com:8080']),
          _chatServers(['ws3.6rooms.com:9000']),
        ],
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fire(SixroomDanmakuCodec.silenceTimeout);
      await _settle();
      clock.fireLast();
      await _settle();
      expect(http.asked, hasLength(1), reason: 'the second server was still in the list');
      expect(connector.asked, hasLength(2));
      expect(connector.asked.last.host, 'ws2.6rooms.com');

      clock.fire(SixroomDanmakuCodec.silenceTimeout);
      await _settle();
      clock.fireLast();
      await _settle();
      expect(http.asked, hasLength(2), reason: 'and once they are used, the page asks again');
      expect(connector.asked.last.host, 'ws3.6rooms.com');
    });

    test('an answer that names no server is one failed run among the budget', () async {
      final (room, connector, clock, _) = _session(answers: [_chatServers([])]);
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      expect(connector.asked, isEmpty);
      expect(room.closed.isCompleted, isFalse);
      expect(clock.lastArmed, SixroomDanmakuCodec.reconnectBaseDelay);

      clock.fireLast();
      await _settle();
      expect(connector.asked, isEmpty, reason: 'the same empty answer is the next run’s too');
      expect(clock.lastArmed, SixroomDanmakuCodec.reconnectBaseDelay * 2);
    });
  });

  group('what the socket says', () {
    test('chat is reported, and a frame of no command is nothing', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_loginOk);
      connector.last.deliver(_chatFrame);
      connector.last.deliver(_frame({'command': 'sendmessage', 'content': 'ok'}));
      await _settle();
      expect(room.seen.map((message) => message.text), ['你好']);
      expect(room.seen.single.sender?.userName, 'Ann');
      expect(clock.countArmed(SixroomDanmakuCodec.silenceTimeout), 1, reason: 'every frame re-arms the watch');
    });

    test('a refused login reconnects quietly, and the fourth ends the session', () async {
      final (room, connector, clock, _) = _session(
        answers: [
          _chatServers(['ws1.6rooms.com:8080', 'ws2.6rooms.com:8080']),
        ],
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      for (var refusal = 1; refusal <= SixroomDanmakuCodec.maxRefusals; refusal++) {
        connector.last.deliver(_loginFailed);
        await _settle();
        expect(room.closed.isCompleted, isFalse, reason: 'refusal $refusal is still retried');
        expect(room.seen, isEmpty, reason: 'and the room is told nothing');
        expect(clock.lastArmed, SixroomDanmakuCodec.reconnectBaseDelay * refusal);
        clock.fireLast();
        await _settle();
      }
      expect(connector.sockets, hasLength(SixroomDanmakuCodec.maxRefusals + 1));

      connector.last.deliver(_loginFailed);
      await _settle();
      await room.closed.future;
      expect(room.ofType(LiveMessageType.system).single.text, 'chat refused: login.failed');
      expect(room.ofType(LiveMessageType.system).single.sentAt, _at);
      expect(clock.armedCount, isZero);
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(SixroomDanmakuCodec.maxRefusals + 1), reason: 'nothing reconnects');
    });

    test('a joined run clears the refusals before it', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      for (var refusal = 0; refusal < SixroomDanmakuCodec.maxRefusals; refusal++) {
        connector.last.deliver(_loginFailed);
        await _settle();
        clock.fireLast();
        await _settle();
      }
      connector.last.deliver(_loginOk);
      await _settle();
      expect(room.closed.isCompleted, isFalse);

      connector.last.deliver(_loginFailed);
      await _settle();
      expect(room.closed.isCompleted, isFalse, reason: 'the count starts again');
      expect(clock.lastArmed, SixroomDanmakuCodec.reconnectBaseDelay);
    });

    test('a flag the page stops on ends the session at once', () async {
      for (final flag in ['101', '102', '204', '306']) {
        final (room, connector, clock, _) = _session();
        addTearDown(room.dispose);

        await room.connect();
        await _settle();
        connector.last.deliver(_loginOk);
        connector.last.deliver(_stopped(flag));
        await _settle();
        await room.closed.future;
        expect(room.ofType(LiveMessageType.system).single.text, 'chat refused: flag $flag: 房间人多');
        expect(clock.armedCount, isZero);
        expect(connector.last.closed, isTrue);
      }

      final (ignored, connector, clock, _) = _session();
      addTearDown(ignored.dispose);
      await ignored.connect();
      await _settle();
      connector.last.deliver(_stopped('205'));
      await _settle();
      expect(ignored.seen, isEmpty, reason: 'a flag the page only speaks on is not the end');
      expect(clock.lastArmed, isNot(SixroomDanmakuCodec.reconnectBaseDelay), reason: 'and it reconnects nothing');
    });
  });

  group('a socket that stops', () {
    test('the login’s six seconds bound a run that never gets an answer', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      final first = connector.last;
      clock.fire(SixroomDanmakuCodec.joinTimeout);
      await _settle();
      expect(clock.fired.single, SixroomDanmakuCodec.joinTimeout);
      expect(clock.lastArmed, SixroomDanmakuCodec.reconnectBaseDelay);

      clock.fireLast();
      await _settle();
      expect(first.closed, isTrue);
      expect(connector.sockets, hasLength(2));
      expect(http.asked, hasLength(2), reason: 'the one server it had was used up');
      expect(connector.last.texts.single, contains('command=login'));
    });

    test('an error and a close both go to the retry path', () async {
      for (final breakWith in <void Function(_Socket)>[(s) => s.fail(StateError('boom')), (s) => s.end()]) {
        final (room, connector, clock, _) = _session();
        addTearDown(room.dispose);

        await room.connect();
        await _settle();
        breakWith(connector.last);
        await _settle();
        expect(clock.lastArmed, SixroomDanmakuCodec.reconnectBaseDelay);
        clock.fireLast();
        await _settle();
        expect(connector.sockets, hasLength(2));
      }
    });

    test('the backoff steps once per failed run and the budget is told once', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      connector.failure = const ConnectFailure('handshake refused');
      await room.connect();
      await _settle();
      expect(room.seen, isEmpty, reason: 'the first failure is already on the ladder');
      expect(clock.lastArmed, SixroomDanmakuCodec.reconnectBaseDelay);

      for (var step = 1; step <= SixroomDanmakuCodec.maxReconnects; step++) {
        clock.fireLast();
        await _settle();
        expect(clock.fired.last, SixroomDanmakuCodec.reconnectBaseDelay * step, reason: 'failure $step');
      }
      await room.closed.future;
      final terminal = room.ofType(LiveMessageType.system).single;
      expect(terminal.text, contains('handshake refused'), reason: 'the line names what never came');
      expect(terminal.sentAt, _at, reason: 'the clock the session was given');
      expect(clock.armedCount, isZero);
      expect(http.asked, hasLength(SixroomDanmakuCodec.maxReconnects + 1), reason: 'every run asked its servers');

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
      expect(clock.lastArmed, SixroomDanmakuCodec.reconnectBaseDelay * 2, reason: 'two runs, no join between');

      connector.failure = null;
      clock.fireLast();
      await _settle();
      connector.last.deliver(_loginOk);
      await _settle();

      clock.fire(SixroomDanmakuCodec.silenceTimeout);
      await _settle();
      expect(clock.lastArmed, SixroomDanmakuCodec.reconnectBaseDelay, reason: 'counted from the live run again');
    });
  });

  group('stopping', () {
    test('disconnect closes the socket and drops a retry that was already armed', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fire(SixroomDanmakuCodec.joinTimeout);
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
      expect(connector.last.sent, isEmpty, reason: 'and nothing was logged in with it');
    });

    test('dispose ends the stream and leaves no timer armed', () async {
      final (room, connector, clock, _) = _session();
      await room.connect();
      await _settle();
      connector.last.deliver(_loginOk);
      await _settle();
      await room.session.dispose();
      await room.closed.future;
      expect(clock.armedCount, isZero);
      expect(connector.last.closed, isTrue);
      await room.session.dispose();
      await room.dispose();
    });

    test('a room that names no chat is refused before any request', () async {
      final (room, connector, _, http) = _session(room: 'abc');
      expect(await room.connect(), isA<LiveSiteNotFound>());
      expect(http.asked, isEmpty);
      expect(connector.sockets, isEmpty);

      await room.session.dispose();
      expect(await room.connect(), isA<LiveSiteUnsupported>());
      await room.dispose();
    });
  });
}
