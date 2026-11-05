import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/fc2live/api/fc2live_endpoints.dart';
import 'package:live_sites/src/platforms/fc2live/api/fc2live_http.dart';
import 'package:live_sites/src/platforms/fc2live/danmaku/fc2live_danmaku_codec.dart';
import 'package:live_sites/src/platforms/fc2live/danmaku/fc2live_danmaku_session.dart';
import 'package:live_sites/src/platforms/fc2live/fc2live_site.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _channel = '12345678';
final DateTime _at = DateTime.utc(2026, 11, 5, 12);

/// The `memberApi` answer of a channel that is on air.
String _member({int status = 1, int publish = 1, Object? version = '3', int limited = 0}) => jsonEncode({
  'status': status,
  'data': {
    'channel_data': {
      'channelid': _channel,
      'is_publish': publish,
      'is_limited': limited,
      'fee': 0,
      'ticketid': 0,
      'ticket_only': 0,
      'login_only': 0,
      'adult': 0,
      'version': ?version,
      'category': 1,
      'count': '10',
      'total': '20',
      'start': '1790733600',
      'tname': 'Ann',
      'title': 'A broadcast',
    },
  },
});

/// The `getControlServer` answer granting one control socket.
String _grant({int status = 0, String token = 'tok-1', String orz = 'orz-1', String? url}) => jsonEncode({
  'status': status,
  'url': url ?? 'wss://a1.live.fc2.com/control/channels/$_channel',
  'control_token': token,
  'orz_raw': orz,
});

/// One control frame, as the site writes it.
String _frame(String name, Map<String, Object?> arguments, {Object? id}) =>
    jsonEncode({'name': name, 'arguments': arguments, 'id': ?id});

/// A comment row the site would show.
Map<String, Object?> _row({String text = 'hello', String name = 'Ann', String id = 'u1'}) => {
  'comment': text,
  'user_name': name,
  'encrypted_user_id': id,
  'timestamp': 1790733600000,
};

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

/// The transport under the site: the two calls of a grant answered by
/// [member] and [grant]; [breaks] throws instead of answering, [hold] holds the
/// member answer until its completer is completed or the request is cancelled.
final class _Http implements LiveHttp {
  _Http({this.member, this.grant});

  String? member;
  String? grant;

  /// When set, every request throws this, as a transport breakdown does.
  Exception? breaks;

  /// When set, the member answer comes only after this completes.
  Completer<void>? hold;

  final asked = <String>[];
  final cancelled = <bool>[];
  int _grants = 0;

  /// Which node each grant named, so a test can follow the version the site
  /// handed to `getControlServer`.
  final versions = <String>[];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request.url.path);
    if (breaks case final error?) throw error;
    if (request.url.path == Fc2LiveEndpoints.memberPath) {
      if (hold case final waiting?) {
        final cancel = request.cancelToken;
        await Future.any([waiting.future, cancel.whenCancel]);
        if (cancel.isCancelled) {
          cancelled.add(true);
          throw const CancelledFailure();
        }
        cancelled.add(false);
      }
      return _answer(member ?? _member());
    }
    if (request.url.path == Fc2LiveEndpoints.controlPath) {
      _grants += 1;
      versions.add('${Uri(query: request.body ?? '').queryParameters['version']}');
      return _answer(grant ?? _grant(token: 'tok-$_grants'));
    }
    throw StateError('the chat asked ${request.url.path}');
  }

  LiveResponse _answer(String text) => LiveResponse(
    statusCode: 200,
    headers: const <String, String>{},
    bodyBytes: Uint8List.fromList(utf8.encode(text)),
  );

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

  Fc2LiveTimers get timers => (
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

  /// The delays of the one-shot timers currently armed.
  List<Duration> get delays => [for (final timer in _after) timer.delay];

  /// How many one-shot timers armed for [delay] are still waiting.
  int countArmed(Duration delay) => _after.where((timer) => timer.delay == delay).length;

  /// The delay of the last timer armed.
  Duration? get lastArmed => _after.isEmpty ? null : _after.last.delay;

  /// Fires the last timer armed for [delay]: the join watch or the silence watch.
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

/// A session with its connector, clock and grant answers.
(_Room, _Connector, _Clock, _Http) _session({String? member, String? grant, String channelId = _channel}) {
  final connector = _Connector();
  final clock = _Clock();
  final http = _Http(member: member, grant: grant);
  final site = Fc2LiveSite(http: Fc2LiveHttp(http), connect: connector.connect);
  final session = Fc2LiveDanmakuSession(
    args: Fc2LiveDanmakuArgs(channelId),
    site: site,
    timers: clock.timers,
    now: () => _at,
  );
  return (_Room(session), connector, clock, http);
}

/// The session, with its event log already collected.
final class _Room {
  _Room(this.session) {
    subscription = session.events.listen(seen.add, onDone: closed.complete);
  }

  final Fc2LiveDanmakuSession session;
  late final StreamSubscription<LiveMessage> subscription;
  final seen = <LiveMessage>[];
  final closed = Completer<void>();

  Future<LiveSiteError?> connect() => session.connect();

  /// The messages of the reported kind.
  List<LiveMessage> ofType(LiveMessageType type) => seen.where((message) => message.type == type).toList();

  /// The chat lines reported so far.
  List<String> get chat => seen.where((message) => message.type == LiveMessageType.chat).map((m) => m.text).toList();

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
  group('the grant in front of every socket', () {
    test('the channel is read, the control asked, and the socket is what the grant named', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      expect(await room.connect(), isNull);
      await _settle();
      expect(http.asked, [Fc2LiveEndpoints.memberPath, Fc2LiveEndpoints.controlPath]);
      expect(connector.asked.single.toString(), 'wss://a1.live.fc2.com/control/channels/$_channel?control_token=tok-1');
      expect(connector.headers.single['cookie'], 'l_ortkn=orz-1');
      expect(connector.headers.single['origin'], Fc2LiveEndpoints.origin);
      expect(connector.budgets.single, Fc2LiveEndpoints.connectTimeout);
      expect(connector.last.sent, isEmpty, reason: 'the client sends nothing until its first heartbeat');
      expect(clock.countArmed(Fc2LiveDanmakuCodec.joinTimeout), 1);
      expect(clock.countArmed(Fc2LiveDanmakuCodec.inactivityTimeout), 1);
      expect(clock.lastEvery, Fc2LiveDanmakuCodec.heartbeatInterval);
    });

    test('a reason asking again will not mend ends the call, a breakdown only fails the run', () async {
      final (gone, goneConnector, goneClock, _) = _session(member: _member(status: 0));
      expect(await gone.connect(), isA<LiveSiteNotFound>(), reason: 'no such channel');
      expect(goneConnector.sockets, isEmpty);
      expect(goneClock.armedCount, isZero, reason: 'and nothing is retried');
      await gone.dispose();

      final (dark, darkConnector, darkClock, _) = _session(member: _member(publish: 0));
      expect(await dark.connect(), isA<LiveSiteError>(), reason: 'a channel that is not on air');
      expect(darkConnector.sockets, isEmpty);
      expect(darkClock.armedCount, isZero);
      await dark.dispose();

      final (broken, brokenConnector, brokenClock, brokenHttp) = _session();
      brokenHttp.breaks = const ConnectFailure('no route to the api');
      expect(await broken.connect(), isNull, reason: 'a breakdown is retried like any later failure');
      expect(brokenConnector.sockets, isEmpty);
      expect(brokenClock.lastArmed, Fc2LiveDanmakuCodec.reconnectBaseDelay);
      await broken.dispose();
    });

    test('every handshake takes its own grant', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fire(Fc2LiveDanmakuCodec.joinTimeout);
      await _settle();
      expect(clock.lastArmed, Fc2LiveDanmakuCodec.reconnectBaseDelay);
      clock.fireLast();
      await _settle();
      expect(http.asked, hasLength(4), reason: 'two calls per handshake');
      expect(connector.sockets, hasLength(2));
      expect(connector.asked.last.toString(), contains('control_token=tok-2'), reason: 'one grant, one socket');
      expect(connector.sockets.first.closed, isTrue);
    });

    test('a channel that is not a number is refused before any request', () async {
      final (room, connector, _, http) = _session(channelId: 'not-a-channel');
      expect(await room.connect(), isA<LiveSiteNotFound>());
      expect(http.asked, isEmpty);
      expect(connector.sockets, isEmpty);

      await room.session.dispose();
      expect(await room.connect(), isA<LiveSiteUnsupported>());
      await room.dispose();
    });
  });

  group('joining and the heartbeat', () {
    test('connect_complete joins, and its absence replaces the socket', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_frame('connect_complete', {}));
      await _settle();
      expect(clock.countArmed(Fc2LiveDanmakuCodec.joinTimeout), isZero, reason: 'the watch is discharged');
      expect(room.seen, isEmpty, reason: 'a join is not a message for the room');

      clock.fire(Fc2LiveDanmakuCodec.inactivityTimeout);
      await _settle();
      expect(clock.lastArmed, Fc2LiveDanmakuCodec.reconnectBaseDelay);
    });

    test('the heartbeat counts up and its answer restarts the count of replacements', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fireBeat();
      expect(connector.last.texts.single, Fc2LiveDanmakuCodec.heartbeat(1));

      connector.last.deliver(_response(1));
      await _settle();
      clock.fireBeat();
      expect(connector.last.texts.last, Fc2LiveDanmakuCodec.heartbeat(2), reason: 'ids count through the connection');

      clock.fire(Fc2LiveDanmakuCodec.inactivityTimeout);
      await _settle();
      expect(
        clock.lastArmed,
        Fc2LiveDanmakuCodec.reconnectBaseDelay,
        reason: 'the answered heartbeat cleared the count',
      );

      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(2));
      clock.fire(Fc2LiveDanmakuCodec.inactivityTimeout);
      await _settle();
      expect(clock.lastArmed, Fc2LiveDanmakuCodec.reconnectBaseDelay * 2, reason: 'this socket was never confirmed');
    });

    test('without an answered heartbeat the steps grow and the ninth ends the session', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      for (var step = 1; step <= Fc2LiveDanmakuCodec.maxReconnects; step++) {
        clock.fire(Fc2LiveDanmakuCodec.inactivityTimeout);
        await _settle();
        expect(clock.lastArmed, Fc2LiveDanmakuCodec.reconnectBaseDelay * step, reason: 'replacement $step');
        clock.fireLast();
        await _settle();
        expect(connector.sockets, hasLength(step + 1), reason: 'and the run after it asked for a socket');
      }
      clock.fire(Fc2LiveDanmakuCodec.inactivityTimeout);
      await _settle();
      await room.closed.future;
      expect(room.ofType(LiveMessageType.system).single.text, contains('Chat connection lost (socket silent)'));
      expect(room.ofType(LiveMessageType.system).single.sentAt, _at);
      expect(clock.armedCount, isZero);
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(Fc2LiveDanmakuCodec.maxReconnects + 1), reason: 'nothing reconnects');
    });

    test('a failure names the socket without its token', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      connector.failure = const ConnectFailure(
        'dial wss://a1.live.fc2.com/control/channels/1?control_token=SECRET failed',
      );
      await room.connect();
      await _settle();
      for (var step = 1; step < Fc2LiveDanmakuCodec.maxReconnects; step++) {
        clock.fireLast();
        await _settle();
      }
      clock.fireLast();
      await _settle();
      await room.closed.future;
      final terminal = room.ofType(LiveMessageType.system).single;
      expect(terminal.text, contains('control_token=…'));
      expect(terminal.text, isNot(contains('SECRET')), reason: 'a grant’s token never reaches the room');
    });
  });

  group('what the site says', () {
    test('comments are reported, and the ng list the site pushes hides them', () async {
      final (room, connector, _, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_frame('connect_complete', {}));
      connector.last.deliver(
        _frame('comment', {
          'comments': [_row(), _row(text: 'bad word')],
        }),
      );
      await _settle();
      expect(room.chat, ['hello', 'bad word']);

      connector.last.deliver(
        _frame('ng_comment', {
          'ng_comments': [_ngKeyword('bad')],
        }),
      );
      connector.last.deliver(
        _frame('comment', {
          'comments': [_row(text: 'bad again'), _row(text: 'fine')],
        }),
      );
      await _settle();
      expect(room.chat, ['hello', 'bad word', 'fine'], reason: 'the site’s own list hides what it hides');
    });

    test('the ng list is kept across the run’s sockets', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(
        _frame('ng_comment', {
          'ng_comments': [_ngKeyword('bad')],
        }),
      );
      await _settle();
      clock.fire(Fc2LiveDanmakuCodec.inactivityTimeout);
      await _settle();
      expect(clock.delays, [Fc2LiveDanmakuCodec.reconnectBaseDelay]);
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(2));

      connector.last.deliver(
        _frame('comment', {
          'comments': [_row(text: 'bad luck'), _row(text: 'well met')],
        }),
      );
      await _settle();
      expect(room.chat, ['well met'], reason: 'a new socket does not forget the filters');
    });

    test('control_disconnection is replaced and named by its code', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      for (var step = 1; step <= Fc2LiveDanmakuCodec.maxReconnects; step++) {
        connector.last.deliver(_frame('control_disconnection', {'code': 4500}));
        await _settle();
        expect(room.seen, isEmpty, reason: 'the room is not told the socket was dropped');
        expect(clock.lastArmed, Fc2LiveDanmakuCodec.reconnectBaseDelay * step, reason: 'replacement $step');
        clock.fireLast();
        await _settle();
        expect(connector.sockets, hasLength(step + 1));
      }
      connector.last.deliver(_frame('control_disconnection', {'code': 4500}));
      await _settle();
      await room.closed.future;
      expect(
        room.ofType(LiveMessageType.system).single.text,
        contains('control_disconnection 4500'),
        reason: 'the line names the code the site sent',
      );
    });

    test('move_server is followed at once and quietly, and still counted', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_frame('move_server', {}));
      await _settle();
      expect(connector.sockets, hasLength(2), reason: 'no backoff wait between');
      expect(clock.armedCount, 2, reason: 'the new socket’s own join and silence watches');
      expect(room.seen, isEmpty);
      expect(http.asked, hasLength(4));

      for (var move = 2; move <= Fc2LiveDanmakuCodec.maxReconnects; move++) {
        connector.last.deliver(_frame('move_server', {}));
        await _settle();
        expect(room.closed.isCompleted, isFalse, reason: 'move $move');
      }
      connector.last.deliver(_frame('move_server', {}));
      await _settle();
      await room.closed.future;
      expect(
        room.ofType(LiveMessageType.system).single.text,
        contains('the site kept moving this session'),
        reason: 'a node that ping-pongs this viewer is ended, not followed forever',
      );
    });

    test('an error, a close and a silent socket are all replaced', () async {
      for (final breakWith in <void Function(_Socket)>[(s) => s.fail(StateError('boom')), (s) => s.end()]) {
        final (room, connector, clock, _) = _session();
        addTearDown(room.dispose);

        await room.connect();
        await _settle();
        breakWith(connector.last);
        await _settle();
        expect(clock.lastArmed, Fc2LiveDanmakuCodec.reconnectBaseDelay);
        clock.fireLast();
        await _settle();
        expect(connector.sockets, hasLength(2));
      }

      final (silent, silentConnector, silentClock, _) = _session();
      addTearDown(silent.dispose);
      await silent.connect();
      await _settle();
      silentConnector.last.deliver(
        _frame('comment', {
          'comments': [_row()],
        }),
      );
      await _settle();
      expect(silentClock.countArmed(Fc2LiveDanmakuCodec.inactivityTimeout), 1, reason: 'a frame re-arms the watch');
    });
  });

  group('stopping', () {
    test('a grant in flight is cancelled and leaves no socket', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      http.hold = Completer<void>();
      // connect() waits for its grant, so the call is left running here.
      unawaited(room.session.connect());
      await _settle();
      expect(http.asked, [Fc2LiveEndpoints.memberPath]);
      await room.session.disconnect();
      http.hold!.complete();
      await _settle();
      expect(http.cancelled.single, isTrue);
      expect(connector.sockets, isEmpty, reason: 'the late grant opens nothing');
      expect(clock.armedCount, isZero);
      expect(room.closed.isCompleted, isFalse, reason: 'the session can be followed again');

      await room.connect();
      await _settle();
      expect(connector.sockets, hasLength(1));
    });

    test('a socket that opens after the session stopped is closed and unused', () async {
      final (room, connector, _, _) = _session();
      addTearDown(room.dispose);

      connector.hold = Completer<void>();
      unawaited(room.session.connect());
      await _settle();
      await room.session.disconnect();
      connector.hold!.complete();
      await _settle();
      expect(connector.sockets, hasLength(1));
      expect(connector.last.closed, isTrue);
      expect(connector.last.sent, isEmpty);
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

/// The answer to the heartbeat with id [id].
String _response(int id) => _frame('_response_', {'status': 0}, id: id);

/// A keyword entry of the site’s ng list.
Map<String, Object?> _ngKeyword(String keyword) => {
  'type': 'keyword',
  'ng_keyword': keyword,
  'ng_comment_id': 1,
  'mode': 'add',
};
