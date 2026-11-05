import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_endpoints.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_http.dart';
import 'package:live_sites/src/platforms/pandalive/danmaku/pandalive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/pandalive/danmaku/pandalive_danmaku_session.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _user = 'daisy00';
const String _channel = '123456';

/// The clock every token of these tests is measured against.
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

  /// The commands sent, as the protocol's own JSON.
  List<Map<String, Object?>> get commands => sent.map(_command).toList();

  /// The `params` of the command at [index].
  Map<String, Object?> params(int index) => commands[index]['params']! as Map<String, Object?>;

  static Map<String, Object?> _command(Object? frame) => jsonDecode('$frame') as Map<String, Object?>;
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

  Duration? _lastAfter;
  Duration? _lastEvery;

  PandaliveTimers get timers => (
    after: (delay, callback) {
      final record = (delay: delay, fire: callback);
      _after.add(record);
      _lastAfter = delay;
      return _Armed(() => _after.remove(record));
    },
    every: (period, callback) {
      _every.add((period: period, fire: () => callback(_Armed(() {}))));
      _lastEvery = period;
      return _Armed(() {});
    },
  );

  Duration? get lastAfter => _lastAfter;
  Duration? get lastEvery => _lastEvery;

  /// The one-shot timers currently armed.
  int get armedCount => _after.length;

  /// How many one-shot timers armed for [delay] are still waiting.
  int countArmed(Duration delay) => _after.where((timer) => timer.delay == delay).length;

  /// The delay of the last timer armed.
  Duration? get lastArmed => _after.isEmpty ? null : _after.last.delay;

  /// Fires the last timer armed for [delay]: the join watch, the silence
  /// watch, or a renewal.
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

/// The transport under the site: every `live/play` POST answers from
/// [answers], the last of which repeats.
final class _Http implements LiveHttp {
  _Http(this.answers);

  final List<({String text, int status})> answers;
  final asked = <String>[];
  var _handed = 0;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request.url.path);
    final answer = answers[_handed.clamp(0, answers.length - 1)];
    _handed += 1;
    return LiveResponse(
      statusCode: answer.status,
      headers: const <String, String>{},
      bodyBytes: Uint8List.fromList(utf8.encode(answer.text)),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

/// The `live/play` answer that grants a chat of [channel] and [token].
({String text, int status}) _granted({String channel = _channel, String token = 'g.1.2'}) =>
    (text: jsonEncode({'result': true, 'channel': channel, 'token': token}), status: 200);

/// The `live/play` answer that refuses the broadcast.
({String text, int status}) _refused(String code) => (
  text: jsonEncode({
    'result': false,
    'errorData': {'code': code},
  }),
  status: 200,
);

/// One JWT of [exp].
String _jwt(int? exp) => [
  base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256'}))),
  base64Url.encode(utf8.encode(jsonEncode({'exp': ?exp, 'sub': _channel}))),
  'signature',
].map((part) => part.replaceAll('=', '')).join('.');

/// A token of the clock's own minute that lapses in [seconds].
String _lapsingIn(int seconds) => _jwt(_at.millisecondsSinceEpoch ~/ 1000 + seconds);

/// The reply of [id], with its result or error.
String _reply(Object? id, {Object? result, Object? error}) =>
    jsonEncode({'id': ?id, 'result': ?result, 'error': ?error});

/// The connect reply that says how long the token lives.
String _ttl(int seconds) => _reply(PandaliveDanmakuCodec.connectId, result: {'expires': true, 'ttl': seconds});

/// The subscription's reply: the join.
String get _joined => _reply(PandaliveDanmakuCodec.subscribeId);

/// A publication of [channel] carrying [message].
String _push(Map<String, Object?> message, {Object? offset = 42, String channel = _channel}) => jsonEncode({
  'result': {
    'channel': channel,
    'data': {'data': message, 'offset': ?offset},
  },
});

/// A chat publication of [text].
String _chat(String text, {int offset = 42}) =>
    _push({'type': 'chatter', 'message': text, 'nk': 'Ann', 'id': 'user1', 'created_at': 1790733600}, offset: offset);

/// A heart publication of [coin].
String _hearts(int coin, {int offset = 43}) => _push({
  'type': 'SponCoin',
  'created_at': 1790733600,
  'message': jsonEncode({'nick': '보내는이', 'id': 'user1', 'coin': coin}),
}, offset: offset);

/// A session with its connector, clock and `live/play` answers; [args] chooses
/// what the room hands the socket.
(_Session, _Connector, _Clock, _Http) _session({
  PandaliveDanmakuArgs? args,
  List<({String text, int status})> play = const [],
}) {
  final connector = _Connector();
  final clock = _Clock();
  final http = _Http(play.isEmpty ? [_granted()] : play);
  final site = PandaliveSite(http: PandaliveHttp(http), connect: connector.connect);
  final session = PandaliveDanmakuSession(
    args: args ?? const PandaliveDanmakuArgs(userId: _user, channel: _channel, token: 'a.b.c'),
    site: site,
    timers: clock.timers,
    now: () => _at,
  );
  return (_Session(session), connector, clock, http);
}

/// The session, with its event log already collected.
final class _Session {
  _Session(this.session) {
    subscription = session.events.listen(seen.add, onDone: closed.complete);
  }

  final PandaliveDanmakuSession session;
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
  group('the first handshake', () {
    test('a token that outlives the lead is sent as the room brought it', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      expect(await room.connect(), isNull);
      await _settle();
      expect(http.asked, isEmpty, reason: 'the broadcast’s own token still has most of its half hour');
      expect(connector.asked.single.toString(), PandaliveEndpoints.chatUrl);
      expect(connector.budgets.single, PandaliveDanmakuCodec.silenceTimeout);
      expect(connector.headers.single, PandaliveDanmakuCodec.socketHeaders);
      expect(room.seen, isEmpty);

      final sent = connector.last;
      expect(sent.commands, hasLength(2), reason: 'connect, then subscribe');
      expect(sent.commands.first['id'], PandaliveDanmakuCodec.connectId);
      expect(sent.params(0)['token'], 'a.b.c');
      expect(sent.commands.last['method'], 1);
      expect(sent.params(1)['channel'], _channel);

      expect(clock.lastEvery, PandaliveDanmakuCodec.heartbeatInterval);
      expect(clock.countArmed(PandaliveDanmakuCodec.silenceTimeout), 1, reason: 'the silence watch');
      expect(clock.countArmed(PandaliveDanmakuCodec.joinTimeout), 1, reason: 'and the join watch');
    });

    test('a token that lapses within the lead is left for a fresh one', () async {
      final (room, connector, _, http) = _session(
        args: PandaliveDanmakuArgs(userId: _user, channel: _channel, token: _lapsingIn(30)),
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      expect(http.asked, [PandaliveEndpoints.playPath], reason: 'a minute is less than the renewal lead');
      expect(connector.last.params(0)['token'], 'g.1.2', reason: 'the socket got the new token');
      expect(connector.last.params(1)['channel'], _channel);

      final (kept, _, _, keptHttp) = _session(
        args: PandaliveDanmakuArgs(userId: _user, channel: _channel, token: _lapsingIn(61)),
      );
      addTearDown(kept.dispose);
      await kept.connect();
      await _settle();
      expect(keptHttp.asked, isEmpty, reason: '61 s is past the lead, so the token is still good');
    });

    test('a room without a token asks live/play before it opens', () async {
      final (room, connector, _, http) = _session(
        args: const PandaliveDanmakuArgs(userId: _user, channel: '000777'),
        play: [_granted(channel: '000777')],
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      expect(http.asked.single, PandaliveEndpoints.playPath);
      expect(connector.asked.single.toString(), PandaliveEndpoints.chatUrl);
      expect(connector.last.params(0)['token'], 'g.1.2');
      expect(connector.last.params(1)['channel'], '000777', reason: 'the channel of the grant, not of the room');
    });

    test('arguments that name no chat are refused before any request', () async {
      final (room, connector, _, http) = _session(
        args: const PandaliveDanmakuArgs(userId: _user, channel: 'abc'),
      );
      expect(await room.connect(), isA<LiveSiteNotFound>());
      expect(connector.sockets, isEmpty);
      expect(http.asked, isEmpty);

      final (wide, _, _, _) = _session(
        args: const PandaliveDanmakuArgs(userId: 'a nn', channel: _channel),
      );
      expect(await wide.connect(), isA<LiveSiteNotFound>());

      await room.session.dispose();
      expect(await room.connect(), isA<LiveSiteUnsupported>(), reason: 'the session was released');
      await room.dispose();
      await wide.dispose();
    });
  });

  group('joining', () {
    test('the subscription’s reply joins: only the silence watch is left', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_joined);
      await _settle();
      expect(clock.countArmed(PandaliveDanmakuCodec.joinTimeout), isZero, reason: 'the watch is discharged');
      expect(clock.countArmed(PandaliveDanmakuCodec.silenceTimeout), 1);
      expect(room.seen, isEmpty, reason: 'a join is not a message for the room');

      connector.last.deliver(_joined);
      await _settle();
      expect(clock.armedCount, 1, reason: 'and a second reply changes nothing');
    });

    test('a join that never comes replaces the socket', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      final first = connector.last;
      clock.fire(PandaliveDanmakuCodec.joinTimeout);
      await _settle();
      expect(clock.fired.single, PandaliveDanmakuCodec.joinTimeout);
      expect(clock.armedCount, 1, reason: 'the failure armed only its step');
      expect(clock.lastArmed, PandaliveDanmakuCodec.reconnectBaseDelay);
      expect(clock.countArmed(PandaliveDanmakuCodec.silenceTimeout), isZero, reason: 'the dead socket watches nothing');

      clock.fireLast();
      await _settle();
      expect(first.closed, isTrue);
      expect(connector.sockets, hasLength(2));
      expect(http.asked.single, PandaliveEndpoints.playPath, reason: 'a token whose socket opened is spent');
      expect(connector.last.params(0)['token'], 'g.1.2');
      expect(connector.last.commands.map((command) => command['id']), [1, 2]);
    });

    test('the token’s life arms one renewal, and a longer answer replaces it', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_ttl(600));
      await _settle();
      final renewal = PandaliveDanmakuCodec.renewalDelay(const Duration(seconds: 600));
      expect(renewal, const Duration(seconds: 540));
      expect(clock.countArmed(renewal), 1);

      connector.last.deliver(_ttl(120));
      await _settle();
      final next = PandaliveDanmakuCodec.renewalDelay(const Duration(seconds: 120));
      expect(clock.countArmed(renewal), isZero, reason: 'the earlier promise is forgotten');
      expect(clock.countArmed(next), 1);
      expect(room.seen, isEmpty);
    });

    test('a renewal joins again without telling the room', () async {
      final (room, connector, clock, http) = _session(play: [_granted()]);
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last
        ..deliver(_joined)
        ..deliver(_ttl(600));
      await _settle();
      expect(http.asked, isEmpty);

      clock.fire(PandaliveDanmakuCodec.renewalDelay(const Duration(seconds: 600)));
      await _settle();
      expect(http.asked.single, PandaliveEndpoints.playPath, reason: 'a re-handshake always asks for a new token');
      expect(connector.sockets.first.closed, isTrue);
      expect(connector.sockets, hasLength(2));
      expect(connector.last.params(0)['token'], 'g.1.2');
      expect(room.seen, isEmpty, reason: 'the room is not told about the socket it never lost');

      clock.fire(PandaliveDanmakuCodec.joinTimeout);
      await _settle();
      expect(clock.lastArmed, PandaliveDanmakuCodec.reconnectBaseDelay, reason: 'the new socket is not joined yet');
    });
  });

  group('what the socket says', () {
    test('chat and hearts are reported in the order the frame holds them', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_chat('안녕'));
      connector.last.deliver(utf8.encode(_hearts(5)));
      connector.last.deliver(_push({'type': 'notice', 'message': 'not chat'}, channel: '999'));
      await _settle();
      expect(room.seen.map((message) => message.text), ['안녕', '하트 ×5']);
      expect(room.seen.first.messageId, '$_channel:42');
      expect(room.seen.last.type, LiveMessageType.gift);
      expect(clock.countArmed(PandaliveDanmakuCodec.silenceTimeout), 1, reason: 'each frame re-arms the watch');

      clock.fireBeat();
      expect(connector.last.commands.last, {'method': 7, 'id': 3}, reason: 'pings count on from the subscription');
      clock.fireBeat();
      expect(connector.last.commands.last, {'method': 7, 'id': 4});
    });

    test('a refused join reconnects, and the fourth ends the session', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      final error = _reply(PandaliveDanmakuCodec.connectId, error: {'code': 109, 'message': 'token expired'});
      for (var refusal = 1; refusal <= PandaliveDanmakuCodec.maxRefusals; refusal++) {
        connector.last.deliver(error);
        await _settle();
        expect(room.closed.isCompleted, isFalse, reason: 'refusal $refusal is still retried');
        expect(clock.lastArmed, PandaliveDanmakuCodec.reconnectBaseDelay * refusal);
        clock.fireLast();
        await _settle();
      }
      expect(connector.sockets, hasLength(PandaliveDanmakuCodec.maxRefusals + 1));

      connector.last.deliver(error);
      await _settle();
      await room.closed.future;
      expect(room.ofType(LiveMessageType.system).single.text, 'chat refused: connect: 109 token expired');
      expect(clock.armedCount, isZero);
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(PandaliveDanmakuCodec.maxRefusals + 1), reason: 'nothing reconnects');
    });

    test('a joined socket forgives the refusals before it', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      final error = _reply(PandaliveDanmakuCodec.subscribeId, error: 'nope');
      for (var refusal = 0; refusal < PandaliveDanmakuCodec.maxRefusals; refusal++) {
        connector.last.deliver(error);
        await _settle();
        clock.fireLast();
        await _settle();
      }
      connector.last.deliver(_joined);
      await _settle();
      expect(room.closed.isCompleted, isFalse, reason: 'the join itself is not the refusal budget');

      connector.last.deliver(error);
      await _settle();
      expect(room.closed.isCompleted, isFalse, reason: 'the count starts again');
      expect(clock.lastArmed, PandaliveDanmakuCodec.reconnectBaseDelay);
    });

    test('live/play refusing the broadcast ends the session without a socket', () async {
      Future<String> terminal(({String text, int status}) answer) async {
        final (room, connector, clock, http) = _session(
          args: const PandaliveDanmakuArgs(userId: _user, channel: _channel),
          play: [answer],
        );
        await room.connect();
        await _settle();
        await room.closed.future;
        expect(connector.sockets, isEmpty, reason: 'a broadcast that is over has no chat to join');
        expect(http.asked.single, PandaliveEndpoints.playPath);
        expect(clock.armedCount, isZero);
        final reason = room.ofType(LiveMessageType.system).single.text;
        await room.dispose();
        return reason;
      }

      expect(await terminal(_refused('castEnd')), 'live/play refused the chat: castEnd');
      expect(await terminal(_refused('needAdult')), 'live/play refused the chat: needAdult');
      expect(
        await terminal((text: jsonEncode({'result': false}), status: 200)),
        'live/play refused the chat: no reason',
      );
    });

    test('a live/play that only fails is one failed run among the budget', () async {
      final (room, connector, clock, http) = _session(
        args: const PandaliveDanmakuArgs(userId: _user, channel: _channel),
        play: [(text: '{}', status: 503), _granted()],
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      expect(connector.sockets, isEmpty, reason: 'the grant failed, so no socket was asked for');
      expect(room.closed.isCompleted, isFalse);
      expect(clock.lastArmed, PandaliveDanmakuCodec.reconnectBaseDelay);

      clock.fireLast();
      await _settle();
      expect(http.asked, hasLength(2));
      expect(connector.sockets.single.commands.map((command) => command['id']), [1, 2]);
    });
  });

  group('a socket that stops', () {
    test('silence replaces it and the new one subscribes again', () async {
      final (room, connector, clock, http) = _session(
        play: [
          _granted(),
          _granted(token: 'g.3.4'),
        ],
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_joined);
      await _settle();
      clock.fire(PandaliveDanmakuCodec.silenceTimeout);
      await _settle();
      expect(clock.fired.single, PandaliveDanmakuCodec.silenceTimeout);
      expect(connector.sockets, hasLength(1), reason: 'the silence only arms the next step');
      expect(clock.lastArmed, PandaliveDanmakuCodec.reconnectBaseDelay);

      clock.fireLast();
      await _settle();
      expect(connector.sockets.first.closed, isTrue);
      expect(connector.sockets, hasLength(2));
      expect(http.asked.single, PandaliveEndpoints.playPath, reason: 'a spent token is never reused');
      expect(connector.last.params(0)['token'], 'g.1.2');
      expect(clock.countArmed(PandaliveDanmakuCodec.joinTimeout), 1);
      expect(clock.countArmed(PandaliveDanmakuCodec.silenceTimeout), 1);

      clock.fire(PandaliveDanmakuCodec.joinTimeout);
      await _settle();
      clock.fireLast();
      await _settle();
      expect(http.asked, hasLength(2), reason: 'and the run after it asks again');
      expect(connector.last.params(0)['token'], 'g.3.4');
    });

    test('an error and a close both go to the retry path', () async {
      for (final breakWith in <void Function(_Socket)>[(s) => s.fail(StateError('boom')), (s) => s.end()]) {
        final (room, connector, clock, _) = _session();
        addTearDown(room.dispose);

        await room.connect();
        await _settle();
        breakWith(connector.last);
        await _settle();
        expect(clock.lastArmed, PandaliveDanmakuCodec.reconnectBaseDelay);
        clock.fireLast();
        await _settle();
        expect(connector.sockets, hasLength(2));
      }
    });

    test('the backoff steps once per failed run and the budget is told once', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      connector.failure = const ConnectFailure('handshake refused');
      await room.connect();
      await _settle();
      expect(room.seen, isEmpty, reason: 'the first failure is already on the ladder');
      expect(clock.lastArmed, PandaliveDanmakuCodec.reconnectBaseDelay);

      for (var step = 1; step <= PandaliveDanmakuCodec.maxReconnects; step++) {
        clock.fireLast();
        await _settle();
        expect(clock.fired.last, PandaliveDanmakuCodec.reconnectBaseDelay * step, reason: 'failure $step');
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
      expect(clock.fired, [PandaliveDanmakuCodec.reconnectBaseDelay]);
      expect(clock.lastArmed, PandaliveDanmakuCodec.reconnectBaseDelay * 2, reason: 'two runs, no join between');

      connector.failure = null;
      clock.fireLast();
      await _settle();
      connector.last.deliver(_joined);
      await _settle();

      clock.fire(PandaliveDanmakuCodec.silenceTimeout);
      await _settle();
      expect(clock.lastArmed, PandaliveDanmakuCodec.reconnectBaseDelay, reason: 'counted from the live run again');
    });
  });

  group('stopping', () {
    test('disconnect closes the socket and drops a retry that was already armed', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fire(PandaliveDanmakuCodec.silenceTimeout);
      await _settle();
      expect(connector.sockets, hasLength(1));
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
      final (room, connector, _, _) = _session(
        args: const PandaliveDanmakuArgs(userId: _user, channel: _channel),
      );
      addTearDown(room.dispose);

      connector.hold = Completer<void>();
      await room.connect();
      await _settle();
      await room.session.disconnect();
      connector.hold!.complete();
      await _settle();
      expect(connector.sockets, hasLength(1));
      expect(connector.last.closed, isTrue, reason: 'the late socket is not handed to the room');
      expect(connector.last.sent, isEmpty, reason: 'and nothing was subscribed with it');
    });

    test('dispose ends the stream and leaves no timer armed', () async {
      final (room, connector, clock, _) = _session();
      await room.connect();
      await _settle();
      expect(connector.last.commands, hasLength(2));
      await room.session.dispose();
      await room.closed.future;
      expect(clock.armedCount, isZero);
      expect(connector.last.closed, isTrue);
      await room.session.dispose();
      expect(room.seen, isEmpty, reason: 'a join is not a message for the room');
      await room.dispose();
    });
  });
}
