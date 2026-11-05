import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/jdlive/api/jdlive_http.dart';
import 'package:live_sites/src/platforms/jdlive/danmaku/jdlive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/jdlive/danmaku/jdlive_danmaku_session.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _liveId = '12345678';
const int _millis = 1790733600000;

/// The `liveauth` answer: a socket URL, its token and the mask the frames come
/// with.
String _auth({String url = 'wss://live.jd.com/ws', String token = 'abc', String? mask, int code = 0}) => jsonEncode({
  'code': code,
  'msg': 'ok',
  'data': {'liveUrl': url, 'token': token, 'msgMaskKey': ?mask},
});

/// A chat frame of this broadcast.
String _chat([String content = ' hello ']) => jsonEncode({
  'type': 'chat_group_message',
  'id': 'm1',
  'datetime': _millis,
  'from': {'pinmd5': 'hash1'},
  'body': {'groupid': _liveId, 'type': 'viewer_send_message', 'nickName': 'Ann', 'content': content},
});

/// The same frame as the site sends it when the answer named a mask: XORed with
/// that key, as the page unmasks it.
List<int> _masked(String text, {String key = 'mask'}) {
  final plain = utf8.encode(text);
  final units = key.codeUnits;
  return [for (var index = 0; index < plain.length; index++) plain[index] ^ units[index % units.length]];
}

/// The audience frame.
String _statistics([int current = 10]) => jsonEncode({
  'type': 'get_statistics_result',
  'body': {'groupid': _liveId, 'current_viewer': current, 'total_viwer': '20'},
});

/// The frame saying the broadcast is over.
String get _ended => jsonEncode({
  'type': 'chat_group_message',
  'body': {'groupid': _liveId, 'type': 'stop_live_broadcast'},
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
}

/// The connector the site was built with: every request recorded, and it can be
/// told to refuse, to answer with the token in its face, or to wait.
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

/// The transport under the site: every `liveauth` POST answers from [answers],
/// the last of which repeats, or throws [breaks].
final class _Http implements LiveHttp {
  _Http([List<String> answers = const []]) : answers = answers.isEmpty ? [_auth()] : answers;

  final List<String> answers;

  /// When set, every request throws this, as a transport breakdown does.
  Exception? breaks;

  /// When set, an answer comes only after its completer is completed, and the
  /// request is cancelled if its token goes first.
  Completer<void>? hold;

  final asked = <Uri>[];
  final bodies = <String>[];
  final cancelled = <bool>[];
  var _handed = 0;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request.url);
    if (hold case final waiting?) {
      final cancel = request.cancelToken;
      await Future.any([waiting.future, cancel.whenCancel]);
      if (cancel.isCancelled) {
        cancelled.add(true);
        throw const CancelledFailure();
      }
      cancelled.add(false);
    }
    if (breaks case final error?) throw error;
    bodies.add(request.body ?? '');
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

  /// Every delay whose timer was fired, in order.
  final fired = <Duration>[];

  JdliveTimers get timers => (
    after: (delay, callback) {
      final record = (delay: delay, fire: callback);
      _after.add(record);
      return _Armed(() => _after.remove(record));
    },
    every: (period, callback) => throw StateError('the client sends no heartbeat'),
  );

  /// The one-shot timers currently armed.
  int get armedCount => _after.length;

  /// The delay of the last timer armed.
  Duration? get lastArmed => _after.isEmpty ? null : _after.last.delay;

  /// Fires the last timer armed for [delay]: the silence watch.
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
}

/// A session with its connector, clock and transport.
(_Room, _Connector, _Clock, _Http) _session({List<String> answers = const [], String liveId = _liveId}) {
  final connector = _Connector();
  final clock = _Clock();
  final http = _Http(answers);
  final site = JdliveSite(http: JdliveHttp(http), connect: connector.connect);
  final session = JdliveDanmakuSession(
    args: JdliveDanmakuArgs(liveId: liveId),
    site: site,
    timers: clock.timers,
    now: () => DateTime.utc(2026, 11, 5, 12),
    random: Random(3),
  );
  return (_Room(session), connector, clock, http);
}

/// The session, with its event log already collected.
final class _Room {
  _Room(this.session) {
    subscription = session.events.listen(seen.add, onDone: closed.complete);
  }

  final JdliveDanmakuSession session;
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
  group('the liveauth handshake', () {
    test('a token is asked for, and the socket it names opens with nothing sent', () async {
      final (room, connector, clock, http) = _session(answers: [_auth(mask: 'mask')]);
      addTearDown(room.dispose);

      expect(await room.connect(), isNull);
      await _settle();
      expect(http.asked.single, JdliveDanmakuCodec.endpoint(_liveId));
      expect(
        http.bodies.single,
        contains('functionId'),
        reason: 'the form the page posts: loginType, appid, functionId, body and t',
      );
      expect(connector.asked.single, Uri.parse('wss://live.jd.com/ws?token=abc'));
      expect(connector.budgets.single, JdliveDanmakuCodec.silenceTimeout);
      expect(connector.headers.single, JdliveDanmakuCodec.socketHeaders);
      expect(connector.last.sent, isEmpty, reason: 'the website’s join frame only announces a visitor');
      expect(room.seen, isEmpty);
      expect(clock.armedCount, 1, reason: 'the only watch is silence');
      expect(clock.lastArmed, JdliveDanmakuCodec.silenceTimeout);
    });

    test('every handshake asks again, with a fresh nonce and a fresh token', () async {
      final (room, connector, clock, http) = _session(
        answers: [
          _auth(token: 't1'),
          _auth(token: 't2', mask: 'mask'),
        ],
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fire(JdliveDanmakuCodec.silenceTimeout);
      await _settle();
      clock.fireLast();
      await _settle();
      expect(http.asked, hasLength(2));
      expect(
        http.bodies.first == http.bodies.last,
        isFalse,
        reason: 'the encrypted body carries its own nonce and time',
      );
      expect(connector.asked.last.toString(), contains('token=t2'));
      expect(connector.sockets, hasLength(2));
      expect(connector.sockets.first.closed, isTrue);
    });

    test('a refused liveauth is a failed run, not the end', () async {
      final (room, connector, clock, _) = _session(
        answers: [
          jsonEncode({
            'code': 1,
            'msg': '鉴权失败',
            'data': {'error': '解密失败!'},
          }),
          _auth(),
        ],
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      expect(connector.asked, isEmpty, reason: 'a refused token opens no socket');
      expect(room.closed.isCompleted, isFalse);
      expect(clock.lastArmed, JdliveDanmakuCodec.reconnectBaseDelay);

      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(1), reason: 'the next run gets a token, so it came to live');
    });

    test('a broadcast without an id is refused before any request', () async {
      final (room, connector, _, http) = _session(liveId: 'not-an-id');
      expect(await room.connect(), isA<LiveSiteNotFound>());
      expect(http.asked, isEmpty);
      expect(connector.sockets, isEmpty);

      await room.session.dispose();
      expect(await room.connect(), isA<LiveSiteUnsupported>());
      await room.dispose();
    });

    test('a failure names the socket URL without its token', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      connector.failure = const ConnectFailure('dial wss://live.jd.com/ws?token=abc refused');
      await room.connect();
      await _settle();
      for (var step = 1; step <= JdliveDanmakuCodec.maxReconnects; step++) {
        clock.fireLast();
        await _settle();
        expect(clock.fired.last, JdliveDanmakuCodec.reconnectBaseDelay * step, reason: 'failure $step');
      }
      await room.closed.future;
      final terminal = room.ofType(LiveMessageType.system).single;
      expect(terminal.text, contains('token=…'), reason: 'the line keeps the shape of the URL');
      expect(terminal.text, isNot(contains('abc')));
      expect(terminal.sentAt, DateTime.utc(2026, 11, 5, 12));
      expect(clock.armedCount, isZero);
      expect(connector.sockets, isEmpty, reason: 'nothing reconnects after the budget');
    });
  });

  group('what the socket says', () {
    test('a masked frame is read with the mask the answer named', () async {
      final (room, connector, _, _) = _session(answers: [_auth(mask: 'mask')]);
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_masked(_chat()));
      await _settle();
      expect(room.seen.single.text, 'hello', reason: 'unmasked, trimmed, as the page shows it');
      expect(room.seen.single.sender?.userName, 'Ann');
    });

    test('a frame of another broadcast is nothing, and every frame re-arms the watch', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(
        jsonEncode({
          'type': 'chat_group_message',
          'body': {'groupid': '9999'},
        }),
      );
      connector.last.deliver(_statistics());
      await _settle();
      expect(room.seen, hasLength(2), reason: 'the audience of this broadcast, two figures apart');
      expect(room.seen.map((message) => message.type), [
        LiveMessageType.audienceUpdate,
        LiveMessageType.audienceUpdate,
      ]);
      expect((room.seen.first.payload! as LiveAudienceUpdate).kind, LiveAudienceSignalKind.onlineViewers);
      expect((room.seen.last.payload! as LiveAudienceUpdate).kind, LiveAudienceSignalKind.totalViewers);
      expect(clock.lastArmed, JdliveDanmakuCodec.silenceTimeout);
      expect(clock.armedCount, 1);

      clock.fire(JdliveDanmakuCodec.silenceTimeout);
      await _settle();
      expect(clock.lastArmed, JdliveDanmakuCodec.reconnectBaseDelay);
    });

    test('the end of the broadcast is the end of the session', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_chat('bye'));
      connector.last.deliver(_ended);
      await _settle();
      await room.closed.future;
      expect(room.seen.map((message) => message.text), ['bye', 'Broadcast ended']);
      expect(room.ofType(LiveMessageType.system).single.sentAt, DateTime.utc(2026, 11, 5, 12));
      expect(clock.armedCount, isZero);
      expect(connector.last.closed, isTrue, reason: 'the socket of a broadcast that is over goes with it');
    });

    test('an error and a close both go to the retry path', () async {
      for (final breakWith in <void Function(_Socket)>[(s) => s.fail(StateError('boom')), (s) => s.end()]) {
        final (room, connector, clock, _) = _session();
        addTearDown(room.dispose);

        await room.connect();
        await _settle();
        breakWith(connector.last);
        await _settle();
        expect(clock.lastArmed, JdliveDanmakuCodec.reconnectBaseDelay);
        clock.fireLast();
        await _settle();
        expect(connector.sockets, hasLength(2), reason: 'and the run asks liveauth again');
        expect(room.closed.isCompleted, isFalse);
      }
    });
  });

  group('stopping with a handshake under way', () {
    test('the liveauth request is cancelled and counts as nothing', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      http.hold = Completer<void>();
      await room.connect();
      await _settle();
      expect(http.asked.single, JdliveDanmakuCodec.endpoint(_liveId));
      await room.session.disconnect();
      http.hold!.complete();
      await _settle();
      expect(http.cancelled.single, isTrue);
      expect(connector.sockets, isEmpty, reason: 'the late answer opens nothing');
      expect(clock.armedCount, isZero, reason: 'a cancelled handshake is not a failed one');
      expect(room.closed.isCompleted, isFalse, reason: 'and the session is still usable');
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
      expect(connector.last.closed, isTrue);
      expect(connector.last.sent, isEmpty);
    });

    test('disconnect drops an armed retry and lets the room join again', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fire(JdliveDanmakuCodec.silenceTimeout);
      await _settle();
      await room.session.disconnect();
      expect(clock.armedCount, isZero);
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(1), reason: 'the queued retry found the session gone');

      await room.connect();
      await _settle();
      expect(connector.sockets, hasLength(2), reason: 'and it can be joined again');
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
