import 'dart:async';
import 'dart:convert';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/kilakila/api/kilakila_http.dart';
import 'package:live_sites/src/platforms/kilakila/danmaku/kilakila_danmaku_codec.dart';
import 'package:live_sites/src/platforms/kilakila/danmaku/kilakila_danmaku_session.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _room = '555';
const String _ns = KilakilaDanmakuCodec.namespace;
final DateTime _at = DateTime.utc(2026, 11, 5, 12);

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

  KilakilaTimers get timers => (
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

/// The transport under the site: the session never asks it, so any request is a
/// test failure.
final class _Never implements LiveHttp {
  @override
  Future<LiveResponse> send(LiveRequest request) async => throw StateError('the chat asks for no request');

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

/// The server’s confirmation that the namespace was joined.
const String _confirmed = '40$_ns,';

/// The server leaving the namespace, and Engine.IO closing the transport.
const String _left = '41$_ns,';
const String _closing = '1';

/// A Socket.IO error packet of the guest namespace.
String _error(String message) => '44$_ns,${jsonEncode({'message': message})}';

/// The `connect_error` event the live page reads as its own answer.
String _connectError(Map<String, Object?> payload) => _event('connect_error', payload);

/// One socket.io event frame: `42<ns>,["name","payload"]`.
String _event(String name, Object? payload) => '42$_ns,${jsonEncode([name, jsonEncode(payload)])}';

/// A `text_message` frame whose content is [body].
String _message(Map<String, Object?> body) => _event('text_message', {
  'body': {
    'response': {'room_id': _room, 'mid': 'm1', 'created_at': 1790733600000, 'content': jsonEncode(body)},
  },
});

/// A chat content.
Map<String, Object?> _chat(String text) => {'t': KilakilaDanmakuCodec.chatType, 'c': text, 'n': 'Ann', 'u': 12};

/// A combo gift line of [count] hits of the combo [no].
Map<String, Object?> _combo(int count, {String no = 'c1'}) => {
  't': KilakilaDanmakuCodec.giftLineType,
  'c': {'name': '玫瑰', 'price': 30, 'no': no, 'id': 9, 'doubleCount': count, 'isDoubleHit': true, 'u': 12},
  'n': 'Ann',
  'u': 12,
};

/// A session with its connector and clock; [roomId] chooses what it joins.
(_Room, _Connector, _Clock) _session({String roomId = _room}) {
  final connector = _Connector();
  final clock = _Clock();
  final site = KilakilaSite(http: KilakilaHttp(_Never()), connect: connector.connect);
  final session = KilakilaDanmakuSession(
    args: KilakilaDanmakuArgs(roomId: roomId),
    site: site,
    timers: clock.timers,
    now: () => _at,
  );
  return (_Room(session), connector, clock);
}

/// The session, with its event log already collected.
final class _Room {
  _Room(this.session) {
    subscription = session.events.listen(seen.add, onDone: closed.complete);
  }

  final KilakilaDanmakuSession session;
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
  group('joining the guest namespace', () {
    test('the join goes out at once and the confirmation joins without a word', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      expect(await room.connect(), isNull);
      await _settle();
      expect(connector.asked.single, KilakilaDanmakuCodec.endpoint(_room));
      expect(connector.budgets.single, KilakilaDanmakuCodec.silenceTimeout);
      expect(connector.headers.single, KilakilaDanmakuCodec.handshakeHeaders);
      expect(connector.last.texts, [KilakilaDanmakuCodec.join(_room)]);
      expect(room.seen, isEmpty);
      expect(clock.lastEvery, KilakilaDanmakuCodec.heartbeatInterval);
      expect(clock.countArmed(KilakilaDanmakuCodec.joinTimeout), 1);
      expect(clock.countArmed(KilakilaDanmakuCodec.silenceTimeout), 1);

      connector.last.deliver(_confirmed);
      await _settle();
      expect(clock.countArmed(KilakilaDanmakuCodec.joinTimeout), isZero, reason: 'the watch is discharged');
      expect(clock.countArmed(KilakilaDanmakuCodec.silenceTimeout), 1);
      expect(room.seen, isEmpty, reason: 'a join is not a message for the room');
    });

    test('a connect error with the site’s own code 0 is the same confirmation', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_connectError({'code': 0}));
      await _settle();
      expect(clock.countArmed(KilakilaDanmakuCodec.joinTimeout), isZero);

      connector.last.deliver(_connectError({'code': 401, 'message': '房间不存在'}));
      await _settle();
      expect(clock.lastArmed, KilakilaDanmakuCodec.reconnectBaseDelay);
      expect(room.seen, isEmpty, reason: 'the rejoin is not told to the room');
    });

    test('a join that never comes replaces the socket', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      final first = connector.last;
      clock.fire(KilakilaDanmakuCodec.joinTimeout);
      await _settle();
      expect(clock.fired.single, KilakilaDanmakuCodec.joinTimeout);
      expect(clock.armedCount, 1, reason: 'only the next step is armed');
      expect(clock.lastArmed, KilakilaDanmakuCodec.reconnectBaseDelay);

      clock.fireLast();
      await _settle();
      expect(first.closed, isTrue);
      expect(connector.sockets, hasLength(2));
      expect(connector.last.texts, [KilakilaDanmakuCodec.join(_room)], reason: 'the new socket joins again');
    });

    test('a broadcast that is not an id is refused before any socket', () async {
      final (room, connector, _) = _session(roomId: '0');
      expect(await room.connect(), isA<LiveSiteNotFound>());
      expect(connector.sockets, isEmpty);

      final (wide, _, _) = _session(roomId: '55a');
      expect(await wide.connect(), isA<LiveSiteNotFound>());

      await room.session.dispose();
      expect(await room.connect(), isA<LiveSiteUnsupported>());
      await room.dispose();
      await wide.dispose();
    });
  });

  group('what the socket says', () {
    test('chat is reported, the engine’s own frames are not, and each re-arms the watch', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_confirmed);
      connector.last.deliver(_message(_chat('你好')));
      connector.last.deliver('0');
      connector.last.deliver('3');
      connector.last.deliver('6');
      await _settle();
      expect(room.seen.map((message) => message.text), ['你好']);
      expect(room.seen.single.sender?.userName, 'Ann');
      expect(clock.countArmed(KilakilaDanmakuCodec.silenceTimeout), 1, reason: 'one watch, re-armed every frame');

      clock.fireBeat();
      expect(connector.last.texts.last, KilakilaDanmakuCodec.ping);
    });

    test('a combo line that repeats a count already shown is left out', () async {
      final (room, connector, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_confirmed);
      connector.last.deliver(_message(_combo(2)));
      connector.last.deliver(_message(_combo(2)));
      connector.last.deliver(_message(_combo(3)));
      connector.last.deliver(_message(_combo(1, no: 'other')));
      await _settle();
      expect(room.seen.map((message) => message.text), ['玫瑰 ×2', '玫瑰 ×3', '玫瑰 ×1']);
    });

    test('the server leaving the room or closing the transport reconnects', () async {
      for (final frame in [_left, _closing]) {
        final (room, connector, clock) = _session();
        addTearDown(room.dispose);

        await room.connect();
        await _settle();
        connector.last.deliver(_confirmed);
        connector.last.deliver(frame);
        await _settle();
        expect(room.seen, isEmpty, reason: 'the room is not told the socket was dropped');
        expect(clock.lastArmed, KilakilaDanmakuCodec.reconnectBaseDelay);
        clock.fireLast();
        await _settle();
        expect(connector.sockets, hasLength(2), reason: 'and the session asked for a new socket');
      }
    });

    test('the fourth refusal ends the session, and the reason is told once', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      for (var refusal = 1; refusal <= KilakilaDanmakuCodec.maxRefusals; refusal++) {
        connector.last.deliver(_error('房间已结束'));
        await _settle();
        expect(room.closed.isCompleted, isFalse, reason: 'refusal $refusal is still retried');
        expect(clock.lastArmed, KilakilaDanmakuCodec.reconnectBaseDelay * refusal);
        clock.fireLast();
        await _settle();
      }
      expect(connector.sockets, hasLength(KilakilaDanmakuCodec.maxRefusals + 1));

      connector.last.deliver(_error('房间已结束'));
      await _settle();
      await room.closed.future;
      expect(room.ofType(LiveMessageType.system).single.text, 'join refused: 房间已结束');
      expect(clock.armedCount, isZero);
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(KilakilaDanmakuCodec.maxRefusals + 1), reason: 'nothing reconnects');
    });

    test('a confirmed join clears the refusals before it', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      for (var refusal = 0; refusal < KilakilaDanmakuCodec.maxRefusals; refusal++) {
        connector.last.deliver(_error('no'));
        await _settle();
        clock.fireLast();
        await _settle();
      }
      connector.last.deliver(_confirmed);
      await _settle();
      expect(room.closed.isCompleted, isFalse);

      connector.last.deliver(_error('no'));
      await _settle();
      expect(room.closed.isCompleted, isFalse, reason: 'the count starts again');
      expect(clock.lastArmed, KilakilaDanmakuCodec.reconnectBaseDelay);
    });
  });

  group('a socket that stops', () {
    test('silence replaces it, and every frame of it re-arms the watch', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_confirmed);
      await _settle();
      clock.fire(KilakilaDanmakuCodec.silenceTimeout);
      await _settle();
      expect(clock.fired.single, KilakilaDanmakuCodec.silenceTimeout);
      expect(clock.lastArmed, KilakilaDanmakuCodec.reconnectBaseDelay);

      clock.fireLast();
      await _settle();
      expect(connector.sockets.first.closed, isTrue, reason: 'the silent socket is closed, not left to rot');
      expect(connector.sockets, hasLength(2));
      expect(clock.countArmed(KilakilaDanmakuCodec.joinTimeout), 1, reason: 'the new socket waits for its answer');
    });

    test('an error and a close both go to the retry path', () async {
      for (final breakWith in <void Function(_Socket)>[(s) => s.fail(StateError('boom')), (s) => s.end()]) {
        final (room, connector, clock) = _session();
        addTearDown(room.dispose);

        await room.connect();
        await _settle();
        breakWith(connector.last);
        await _settle();
        expect(clock.lastArmed, KilakilaDanmakuCodec.reconnectBaseDelay);
        clock.fireLast();
        await _settle();
        expect(connector.sockets, hasLength(2));
      }
    });

    test('the backoff steps once per failed run and the budget is told once', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      connector.failure = const ConnectFailure('handshake refused');
      await room.connect();
      await _settle();
      expect(room.seen, isEmpty, reason: 'the first failure is already on the ladder');
      expect(clock.lastArmed, KilakilaDanmakuCodec.reconnectBaseDelay);

      for (var step = 1; step <= KilakilaDanmakuCodec.maxReconnects; step++) {
        clock.fireLast();
        await _settle();
        expect(clock.fired.last, KilakilaDanmakuCodec.reconnectBaseDelay * step, reason: 'failure $step');
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

    test('a socket that came to live starts the budget again', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      connector.failure = const ConnectFailure('refused');
      await room.connect();
      await _settle();
      clock.fireLast();
      await _settle();
      expect(clock.lastArmed, KilakilaDanmakuCodec.reconnectBaseDelay * 2, reason: 'two runs, no join between');

      connector.failure = null;
      clock.fireLast();
      await _settle();
      connector.last.deliver(_confirmed);
      await _settle();

      clock.fire(KilakilaDanmakuCodec.silenceTimeout);
      await _settle();
      expect(clock.lastArmed, KilakilaDanmakuCodec.reconnectBaseDelay, reason: 'counted from the live run again');
    });
  });

  group('stopping', () {
    test('disconnect closes the socket and drops a retry that was already armed', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fire(KilakilaDanmakuCodec.joinTimeout);
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
      final (room, connector, _) = _session();
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
      final (room, connector, clock) = _session();
      await room.connect();
      await _settle();
      expect(connector.last.texts, [KilakilaDanmakuCodec.join(_room)]);
      await room.session.dispose();
      await room.closed.future;
      expect(clock.armedCount, isZero);
      expect(connector.last.closed, isTrue);
      await room.session.dispose();
      expect(room.seen, isEmpty);
      await room.dispose();
    });
  });
}
