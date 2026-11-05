import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/twitcasting/api/twitcasting_endpoints.dart';
import 'package:live_sites/src/platforms/twitcasting/api/twitcasting_http.dart';
import 'package:live_sites/src/platforms/twitcasting/danmaku/twitcasting_danmaku_codec.dart';
import 'package:live_sites/src/platforms/twitcasting/danmaku/twitcasting_danmaku_session.dart';
import 'package:live_sites/src/platforms/twitcasting/twitcasting_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const int _movie = 12;

/// The signed socket URL one `eventpubsuburl.php` answer gives, with [token].
String _signed({String token = 't', String n = '1'}) =>
    'wss://${TwitcastingEndpoints.host}/event.pubsub/v1/streams/$_movie/events?token=$token&n=$n';

/// The answer body of `eventpubsuburl.php`.
String _urlBody(String url) => jsonEncode({'url': url});

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
/// told to refuse, to answer late, or to wait.
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
    if (failure case final error?) {
      await Future<void>.delayed(Duration.zero);
      throw error;
    }
    final socket = _Socket();
    sockets.add(socket);
    if (hold case final waiting?) await waiting.future;
    return socket;
  }

  _Socket get last => sockets.last;
}

/// The transport under the site: every `eventpubsuburl.php` POST answers from
/// [answers], the last of which repeats, or throws [breaks].
final class _Http implements LiveHttp {
  _Http({this.answers = const []});

  /// The `url` each answer names.
  final List<String> answers;

  /// When set, every request throws this, as a transport breakdown does.
  Exception? breaks;

  /// When set, an answer comes only after its completer is completed, and the
  /// request is cancelled if its token goes first.
  Completer<void>? hold;

  final asked = <Uri>[];
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
    final list = answers.isEmpty ? [_signed()] : answers;
    final url = list[_handed.clamp(0, list.length - 1)];
    _handed += 1;
    return LiveResponse(
      statusCode: 200,
      headers: const <String, String>{},
      bodyBytes: Uint8List.fromList(utf8.encode(_urlBody(url))),
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

  TwitcastingTimers get timers => (
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

/// A frame of the server's events.
String _frame(List<Map<String, Object?>> events) => jsonEncode(events);

/// A `comment` event.
Map<String, Object?> _comment([String text = 'こんにちは']) => {
  'type': 'comment',
  'message': text,
  'id': 'c1',
  'createdAt': 1790733600000,
  'author': {'id': 21, 'name': 'Ann', 'screenName': 'ann'},
};

/// A `gift` event, with the words sent with it.
Map<String, Object?> _gift([String message = 'お茶ｘ10']) => {
  'type': 'gift',
  'id': 'g1',
  'createdAt': 1790733600000,
  'plainMessage': 'ありがとう',
  'item': {'name': message, 'image': 'https://cs.p.twitcasting.tv/i/tea.png', 'showsSenderInfo': true},
  'sender': {'id': 21, 'name': 'Ann', 'screenName': 'ann'},
};

/// A session with its connector, clock and transport.
(_Room, _Connector, _Clock, _Http) _session({List<String> answers = const [], int movie = _movie}) {
  final connector = _Connector();
  final clock = _Clock();
  final http = _Http(answers: answers);
  final site = TwitcastingSite(http: TwitcastingHttp(http), connect: connector.connect);
  final session = TwitcastingDanmakuSession(
    args: TwitcastingDanmakuArgs(channel: 'ann', movieId: movie),
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

  final TwitcastingDanmakuSession session;
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
  group('the freshly signed socket URL', () {
    test('the player’s page is asked first, and the socket goes where it points', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      expect(await room.connect(), isNull);
      await _settle();
      expect(http.asked.single, TwitcastingDanmakuCodec.endpoint(_movie));
      expect(connector.asked.single.toString(), '${_signed()}&gift=1', reason: 'the request asks for gifts too');
      expect(connector.budgets.single, TwitcastingDanmakuCodec.silenceTimeout);
      expect(connector.headers.single, TwitcastingDanmakuCodec.socketHeaders);
      expect(room.seen, isEmpty);
      expect(connector.last.sent, isEmpty, reason: 'there is no join frame and no ping');
      expect(clock.armedCount, 1, reason: 'the only watch is silence');
      expect(clock.lastArmed, TwitcastingDanmakuCodec.silenceTimeout);
    });

    test('every handshake asks for a new signature', () async {
      final (room, connector, clock, http) = _session(
        answers: [
          _signed(token: 't1'),
          _signed(token: 't2'),
        ],
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fire(TwitcastingDanmakuCodec.silenceTimeout);
      await _settle();
      clock.fireLast();
      await _settle();
      expect(http.asked, hasLength(2));
      expect(connector.sockets, hasLength(2));
      expect(connector.asked.last.toString(), contains('token=t2'), reason: 'the old one is spent');
      expect(connector.sockets.first.closed, isTrue);
    });

    test('an answer that names no socket URL is a failed handshake, not the end', () async {
      final (room, connector, clock, _) = _session(answers: ['https://evil.test/x']);
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      expect(connector.asked, isEmpty, reason: 'a URL off the site is not a socket to open');
      expect(room.closed.isCompleted, isFalse);
      expect(clock.lastArmed, TwitcastingDanmakuCodec.reconnectBaseDelay);
    });

    test('a failure names the URL without its signature', () async {
      final (room, connector, clock, _) = _session();
      addTearDown(room.dispose);

      connector.failure = ConnectFailure('dial ${_signed(token: 'secret', n: '99')} refused');
      await room.connect();
      await _settle();
      for (var step = 1; step <= TwitcastingDanmakuCodec.maxReconnects; step++) {
        clock.fireLast();
        await _settle();
        expect(clock.fired.last, TwitcastingDanmakuCodec.reconnectBaseDelay * step, reason: 'failure $step');
      }
      clock.fireLast();
      await _settle();
      await room.closed.future;
      final terminal = room.ofType(LiveMessageType.system).single;
      expect(terminal.text, contains('token=…'), reason: 'the line keeps the shape');
      expect(terminal.text, isNot(contains('secret')));
      expect(terminal.text, isNot(contains('n=99')));
      expect(terminal.sentAt, DateTime.utc(2026, 11, 5, 12));
      expect(clock.armedCount, isZero);
      expect(connector.sockets, isEmpty, reason: 'nothing reconnects after the budget');
    });

    test('a broadcast without an id is refused before any request', () async {
      final (room, connector, _, http) = _session(movie: 0);
      expect(await room.connect(), isA<LiveSiteNotFound>(), reason: 'no movie id, no broadcast to join');
      expect(http.asked, isEmpty);
      expect(connector.sockets, isEmpty);

      await room.session.dispose();
      expect(await room.connect(), isA<LiveSiteUnsupported>());
      await room.dispose();
    });
  });

  group('a live socket', () {
    test('comments and gifts are reported, the keep-alive array is not, and each frame re-arms the watch', () async {
      final (room, connector, _, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_frame([_comment()]));
      connector.last.deliver('[]');
      connector.last.deliver(_frame([_gift()]));
      await _settle();
      expect(room.seen.map((message) => message.text), ['こんにちは', 'お茶ｘ10 ×1', 'ありがとう']);
      expect(room.seen.first.sender?.userId, '21');
      expect(room.seen.first.messageId, 'c1');
      expect(room.seen[1].type, LiveMessageType.gift);
      expect(room.seen.last.messageId, 'g1:words');
    });

    test('silence replaces the socket, and an open one clears the count', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      http.breaks = const ConnectFailure('no route');
      await room.connect();
      await _settle();
      expect(connector.sockets, isEmpty);
      expect(clock.lastArmed, TwitcastingDanmakuCodec.reconnectBaseDelay);

      http.breaks = null;
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(1));
      http.breaks = const ConnectFailure('no route');
      clock.fire(TwitcastingDanmakuCodec.silenceTimeout);
      await _settle();
      expect(clock.lastArmed, TwitcastingDanmakuCodec.reconnectBaseDelay, reason: 'counted from the live socket');

      http.breaks = null;
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(2));
      expect(connector.sockets.first.closed, isTrue);
    });

    test('an error and a close both go to the retry path', () async {
      for (final breakWith in <void Function(_Socket)>[(s) => s.fail(StateError('boom')), (s) => s.end()]) {
        final (room, connector, clock, _) = _session();
        addTearDown(room.dispose);

        await room.connect();
        await _settle();
        breakWith(connector.last);
        await _settle();
        expect(clock.lastArmed, TwitcastingDanmakuCodec.reconnectBaseDelay);
        clock.fireLast();
        await _settle();
        expect(connector.sockets, hasLength(2));
      }
    });
  });

  group('stopping with a handshake under way', () {
    test('the socket URL request is cancelled and counts as nothing', () async {
      final (room, connector, clock, http) = _session();
      addTearDown(room.dispose);

      http.hold = Completer<void>();
      await room.connect();
      await _settle();
      expect(http.asked.single, TwitcastingDanmakuCodec.endpoint(_movie));
      await room.session.disconnect();
      http.hold!.complete();
      await _settle();
      expect(http.cancelled.single, isTrue);
      expect(connector.sockets, isEmpty, reason: 'the late answer opens nothing');
      expect(clock.armedCount, isZero, reason: 'a cancelled handshake is not a failed one');
      expect(room.seen, isEmpty);
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
      clock.fire(TwitcastingDanmakuCodec.silenceTimeout);
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
