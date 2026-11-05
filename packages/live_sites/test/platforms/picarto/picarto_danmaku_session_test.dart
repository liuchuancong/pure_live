import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/picarto/api/picarto_endpoints.dart';
import 'package:live_sites/src/platforms/picarto/api/picarto_http.dart';
import 'package:live_sites/src/platforms/picarto/danmaku/picarto_danmaku_codec.dart';
import 'package:live_sites/src/platforms/picarto/danmaku/picarto_danmaku_session.dart';
import 'package:live_sites/src/platforms/picarto/picarto_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const int _channel = 42;
const String _name = 'ann';
const String _token = 'a.b.c';

/// The GraphQL answer that hands out a chat token.
({Object? json, int status}) _granted({Object? key = _token, int status = 200}) => (
  json: {
    'data': {
      'generateJwtToken': {'key': ?key},
    },
  },
  status: status,
);

/// The GraphQL answer that gives none (an unknown channel, or a broken API).
({Object? json, int status}) _nothing({int status = 200}) => (json: {'data': <String, Object?>{}}, status: status);

/// The chat server refusing the token it was handed.
const String _refused = '{"success":false,"code":"JWT_TOKEN"}';

/// The chat server answering a keep-alive: proof the token was good.
const String _pong = '{"success":true,"code":"PONG"}';

/// One frame of the chat socket, as the site writes it.
String _lines(List<Map<String, Object?>> messages) => jsonEncode({'type': 'c', 'messages': messages});

/// A chat line of this channel.
Map<String, Object?> _chatLine([String text = 'hello']) => {'t': 'c', 'm': text, 'n': 'Ann', 'u': 7, 'id': 'l1'};

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

/// The transport under the site: every token request answers from [answers],
/// the last of which repeats; [breaks] is thrown instead of answering.
final class _Http implements LiveHttp {
  _Http([List<({Object? json, int status})> answers = const []]) : answers = answers.isEmpty ? [_granted()] : answers;

  final List<({Object? json, int status})> answers;

  /// When set, every request throws this, as a transport breakdown does.
  Exception? breaks;

  /// When set, an answer comes only after its completer is completed.
  Completer<void>? hold;

  final asked = <Uri>[];
  final bodies = <Object?>[];
  var _handed = 0;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request.url);
    bodies.add(request.body);
    if (breaks case final error?) throw error;
    if (hold case final waiting?) await waiting.future;
    final answer = answers[_handed.clamp(0, answers.length - 1)];
    _handed += 1;
    return LiveResponse(
      statusCode: answer.status,
      headers: const <String, String>{},
      bodyBytes: Uint8List.fromList(utf8.encode(jsonEncode(answer.json))),
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

  PicartoTimers get timers => (
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

  /// Fires the last timer armed for [delay]: the join budget, the token step or
  /// the silence watch.
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

/// A session with its connector, clock and token answers.
(_Room, _Connector, _Clock, _Http) _session({
  List<({Object? json, int status})> answers = const [],
  String channelName = _name,
  int channelId = _channel,
}) {
  final connector = _Connector();
  final clock = _Clock();
  final http = _Http(answers);
  final site = PicartoSite(http: PicartoHttp(http), connect: connector.connect);
  final session = PicartoDanmakuSession(
    args: PicartoDanmakuArgs(channelName: channelName, channelId: channelId),
    site: site,
    timers: clock.timers,
    now: () => DateTime.utc(2026, 11, 5, 12),
  );
  return (_Room(session), connector, clock, http);
}

/// The session, with its event log already collected.
final class _Room {
  _Room(this.session) {
    subscription = session.events.listen(seen.add, onDone: closed.complete);
  }

  final PicartoDanmakuSession session;
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
  group('the chat token', () {
    test('a token is asked for, and the socket’s path carries it', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      expect(await room.connect(), isNull);
      await _settle();
      expect(http.asked.single, PicartoEndpoints.tokenUrl());
      expect(http.bodies.single, allOf(contains('generateJwtToken'), contains('"name":"ann"')));
      expect(connector.asked.single, PicartoDanmakuCodec.endpoint(_token));
      expect(connector.budgets.single, PicartoDanmakuCodec.silenceTimeout);
      expect(connector.headers.single, PicartoDanmakuCodec.handshakeHeaders);
      expect(room.seen, isEmpty);
      expect(connector.last.sent, isEmpty, reason: 'the server sends no welcome and the client joins with nothing');
      expect(clock.lastEvery, PicartoDanmakuCodec.heartbeatInterval);
      expect(clock.countArmed(PicartoDanmakuCodec.joinTimeout), isZero, reason: 'an open socket is the join');
      expect(clock.countArmed(PicartoDanmakuCodec.silenceTimeout), 1);
    });

    test('three answers without a token are one failed run, stepped by the token’s own delay', () async {
      final (room, connector, clock, http) = _session(
        answers: [_nothing(status: 503), _nothing(status: 503), _nothing(status: 503), _granted()],
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      expect(http.asked, hasLength(1), reason: 'the second request waits for its step');
      expect(clock.lastArmed, PicartoDanmakuCodec.tokenRetryDelay);

      clock.fireLast();
      await _settle();
      clock.fireLast();
      await _settle();
      expect(http.asked, hasLength(PicartoDanmakuCodec.tokenAttempts));
      expect(clock.fired.last, PicartoDanmakuCodec.tokenRetryDelay * 2, reason: 'the step grows once per attempt');
      expect(connector.sockets, isEmpty);
      expect(room.closed.isCompleted, isFalse);
      expect(clock.lastArmed, PicartoDanmakuCodec.reconnectBaseDelay);

      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(1), reason: 'the answers now hand out a token');
    });

    test('a token request that cannot be made still steps its attempts', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);
      http.breaks = const ConnectFailure('no route to the api');

      await room.connect();
      await _settle();
      expect(http.asked, hasLength(1));
      expect(clock.lastArmed, PicartoDanmakuCodec.tokenRetryDelay, reason: 'the breakdown is kept as the reason');

      clock.fireLast();
      await _settle();
      clock.fireLast();
      await _settle();
      expect(http.asked, hasLength(PicartoDanmakuCodec.tokenAttempts));
      expect(connector.sockets, isEmpty);
      expect(room.closed.isCompleted, isFalse, reason: 'a missing token is retried like any other failure');
      expect(clock.lastArmed, PicartoDanmakuCodec.reconnectBaseDelay);
    });

    test('a socket that never opens runs the ladder to the end', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      connector.failure = const ConnectFailure('handshake refused');
      await room.connect();
      await _settle();
      for (var step = 1; step <= PicartoDanmakuCodec.maxReconnects; step++) {
        expect(clock.lastArmed, PicartoDanmakuCodec.reconnectBaseDelay * step, reason: 'failure $step');
        clock.fireLast();
        await _settle();
      }
      await room.closed.future;
      expect(connector.asked, hasLength(PicartoDanmakuCodec.maxReconnects + 1), reason: 'every run asked for a socket');
      expect(http.asked, hasLength(PicartoDanmakuCodec.maxReconnects + 1), reason: 'one token per run');
      final terminal = room.ofType(LiveMessageType.system).single;
      expect(terminal.text, contains('handshake refused'), reason: 'the line names what never came');
      expect(terminal.sentAt, DateTime.utc(2026, 11, 5, 12));
      expect(clock.armedCount, isZero);

      clock.fireLast();
      await _settle();
      expect(connector.sockets, isEmpty, reason: 'nothing reconnects after the budget');
    });
  });

  group('the join budget', () {
    test('it bounds the handshake: a socket that never opens is a failed run', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      connector.hold = Completer<void>();
      await room.connect();
      await _settle();
      expect(http.asked, hasLength(1));
      expect(clock.countArmed(PicartoDanmakuCodec.joinTimeout), 1);
      expect(connector.sockets, hasLength(1), reason: 'the socket was asked for and is still on its way');
      expect(clock.armedCount, 1, reason: 'nothing else is armed while the connect waits');

      clock.fire(PicartoDanmakuCodec.joinTimeout);
      await _settle();
      expect(clock.lastArmed, PicartoDanmakuCodec.reconnectBaseDelay);
      clock.fireLast();
      await _settle();
      expect(http.asked, hasLength(2), reason: 'the next run asks for a token of its own');
      connector.hold!.complete();
      await _settle();
      expect(connector.sockets.first.closed, isTrue, reason: 'the late socket is closed, not handed to the room');
      expect(connector.sockets.last.closed, isFalse);
    });

    test('an opened socket clears the count', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fire(PicartoDanmakuCodec.silenceTimeout);
      await _settle();
      expect(clock.lastArmed, PicartoDanmakuCodec.reconnectBaseDelay);
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(2));

      clock.fire(PicartoDanmakuCodec.silenceTimeout);
      await _settle();
      expect(clock.lastArmed, PicartoDanmakuCodec.reconnectBaseDelay, reason: 'counted from the live socket again');
    });
  });

  group('a refused token', () {
    test('the socket is reopened without a notice, and the budget’s end is told once', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      for (var refresh = 1; refresh <= PicartoDanmakuCodec.maxTokenRefreshes; refresh++) {
        connector.last.deliver(_refused);
        await _settle();
        expect(room.closed.isCompleted, isFalse, reason: 'refresh $refresh is still tried');
        expect(room.seen, isEmpty, reason: 'and the room is told nothing about it');
        expect(http.asked, hasLength(refresh + 1), reason: 'a fresh token for every reopened socket');
        expect(connector.sockets, hasLength(refresh + 1));
        expect(clock.armedCount, 1, reason: 'no backoff step: the reopen is immediate');
      }

      connector.last.deliver(_refused);
      await _settle();
      await room.closed.future;
      expect(room.ofType(LiveMessageType.system).single.text, 'chat token refused');
      expect(room.ofType(LiveMessageType.system).single.sentAt, DateTime.utc(2026, 11, 5, 12));
      expect(clock.armedCount, isZero);
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(PicartoDanmakuCodec.maxTokenRefreshes + 1), reason: 'nothing reconnects');
    });

    test('any other answer from the server starts the budget again', () async {
      final (room, connector, _, http) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_refused);
      await _settle();
      connector.last.deliver(_refused);
      await _settle();
      expect(http.asked, hasLength(3));

      connector.last.deliver(_pong);
      await _settle();
      for (var refresh = 0; refresh < PicartoDanmakuCodec.maxTokenRefreshes; refresh++) {
        connector.last.deliver(_refused);
        await _settle();
        expect(room.closed.isCompleted, isFalse, reason: 'the count restarted at the PONG');
      }
      connector.last.deliver(_refused);
      await _settle();
      await room.closed.future;
      expect(room.ofType(LiveMessageType.system).single.text, 'chat token refused');
    });
  });

  group('what the socket says', () {
    test('chat is reported, the keep-alive goes out on the beat, and frames re-arm the watch', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_lines([_chatLine()]));
      connector.last.deliver(_lines([_chatLine('第二条')]));
      await _settle();
      expect(room.seen.map((message) => message.text), ['hello', '第二条']);
      expect(room.seen.first.sender?.userName, 'Ann');
      expect(clock.countArmed(PicartoDanmakuCodec.silenceTimeout), 1);

      clock.fireBeat();
      expect(connector.last.texts.single, PicartoDanmakuCodec.heartbeat);
    });

    test('an error and a close both go to the retry path', () async {
      for (final breakWith in <void Function(_Socket)>[(s) => s.fail(StateError('boom')), (s) => s.end()]) {
        final (room, connector, clock, _) = _session();
        addTearDown(room.dispose);

        await room.connect();
        await _settle();
        breakWith(connector.last);
        await _settle();
        expect(clock.lastArmed, PicartoDanmakuCodec.reconnectBaseDelay);
        clock.fireLast();
        await _settle();
        expect(connector.sockets, hasLength(2), reason: 'and the run asks for a token again');
      }
    });
  });

  group('stopping', () {
    test('a session closed while its token is on its way opens nothing', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      http.hold = Completer<void>();
      await room.connect();
      await _settle();
      await room.session.disconnect();
      http.hold!.complete();
      await _settle();
      expect(connector.asked, isEmpty, reason: 'the late answer does not start a socket');
      expect(clock.armedCount, isZero, reason: 'and it counts as no failure');

      await room.connect();
      await _settle();
      expect(connector.sockets, hasLength(1), reason: 'the session can be joined again');
    });

    test('disconnect drops an armed retry', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fire(PicartoDanmakuCodec.silenceTimeout);
      await _settle();
      await room.session.disconnect();
      expect(connector.last.closed, isTrue);
      expect(clock.armedCount, isZero);
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(1), reason: 'the queued retry found the session gone');
    });

    test('a channel that is not a name is refused before any request', () async {
      final (room, connector, _, http) = _session(channelName: 'has space');
      expect(await room.connect(), isA<LiveSiteNotFound>());
      expect(http.asked, isEmpty);
      expect(connector.sockets, isEmpty);

      await room.session.dispose();
      expect(await room.connect(), isA<LiveSiteUnsupported>());
      await room.dispose();
    });

    test('dispose ends the stream and leaves no timer armed', () async {
      final (room, connector, clock, _) = _session();
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
