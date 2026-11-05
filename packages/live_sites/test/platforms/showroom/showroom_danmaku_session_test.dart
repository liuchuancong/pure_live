import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/showroom/api/showroom_http.dart';
import 'package:live_sites/src/platforms/showroom/danmaku/showroom_danmaku_codec.dart';
import 'package:live_sites/src/platforms/showroom/danmaku/showroom_danmaku_session.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_models.dart';
import 'package:live_sites/src/platforms/showroom/showroom_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _key = '6e6c686835796846:23483509';
const String _host = 'bcsvr001.showroom-live.com';

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

  ShowroomTimers get timers => (
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

  /// The timers currently armed through the clock's `after`.
  int get armedCount => _after.length;

  /// The delay of the last such timer.
  Duration? get lastArmed => _after.isEmpty ? null : _after.last.delay;

  /// Fires the last timer armed through `after`: the silence watch, or the next
  /// reconnect.
  void fireAfter() {
    if (_after.isEmpty) return;
    final timer = _after.removeLast();
    fired.add(timer.delay);
    timer.fire();
  }

  /// Fires the heartbeat beat.
  void fireBeat() => _every.last.fire();
}

/// The transport under the site: the gift table answers this; anything else is
/// an ordinary empty object.
final class _Http implements LiveHttp {
  _Http({this.gifts});

  /// The `live/gift_list` body, or null for an answer the parser refuses.
  final String? gifts;
  final asked = <Uri>[];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request.url);
    return LiveResponse(
      statusCode: 200,
      headers: const <String, String>{},
      bodyBytes: Uint8List.fromList(utf8.encode(gifts ?? '{"unexpected":1}')),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

/// A session with its connector and clock; [host]/[key] choose what `connect`
/// accepts, [gifts] the room's gift table.
(ShowroomDanmakuSession, _Connector, _Clock) _session({String host = _host, String key = _key, String? gifts}) {
  final connector = _Connector();
  final clock = _Clock();
  final site = ShowroomSite(
    http: ShowroomHttp(_Http(gifts: gifts)),
    connect: connector.connect,
  );
  final session = ShowroomDanmakuSession(
    args: ShowroomDanmakuArgs(roomId: '456', host: host, key: key),
    site: site,
    timers: clock.timers,
    now: () => DateTime.utc(2026, 11, 5, 12),
  );
  return (session, connector, clock);
}

/// One comment frame of this broadcast.
String _comment(String text) => 'MSG\t$_key\t${jsonEncode({'t': 1, 'cm': text, 'ac': 'Ann'})}';

Future<void> _settle() async {
  for (var turn = 0; turn < 12; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('joining the comment server', () {
    test('an open socket is the join: SUB goes out at once and nothing is reported', () async {
      final (session, connector, clock) = _session();
      final seen = <LiveMessage>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(session.dispose);

      expect(await session.connect(), isNull);
      await _settle();
      expect(connector.asked.single.toString(), 'wss://$_host/');
      expect(connector.last.sent, ['SUB\t$_key']);
      expect(connector.headers.single['origin'], isNotNull, reason: 'the handshake carries the site’s origin');
      expect(connector.budgets.single, ShowroomDanmakuCodec.silenceTimeout);
      expect(seen, isEmpty, reason: 'the server confirms nothing, so there is no join answer to report');
      expect(clock.lastEvery, ShowroomDanmakuCodec.heartbeatInterval);
      expect(clock.lastAfter, ShowroomDanmakuCodec.silenceTimeout, reason: 'the only watch at first is silence');
      await subscription.cancel();
    });

    test('a server or key that cannot be subscribed to never opens a socket', () async {
      final (badHost, connector, _) = _session(host: 'evil.test');
      expect(await badHost.connect(), isA<LiveSiteNotFound>());
      expect(connector.sockets, isEmpty);

      final (badKey, _, _) = _session(key: 'has space');
      expect(await badKey.connect(), isA<LiveSiteNotFound>());
      expect(connector.sockets, isEmpty);

      await badHost.dispose();
      expect(await badHost.connect(), isA<LiveSiteUnsupported>());
    });

    test('frames of this broadcast are reported, and every one re-arms the watch', () async {
      final (session, connector, clock) = _session();
      final seen = <LiveMessage>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(session.dispose);

      await session.connect();
      await _settle();
      expect(clock.armedCount, 1);
      connector.last.deliver(_comment('こんにちは'));
      connector.last.deliver('MSG\tother.key\t${jsonEncode({'t': 1, 'cm': 'not ours'})}');
      connector.last.deliver(utf8.encode(_comment('bytes')));
      await _settle();
      expect(seen.map((message) => message.text), ['こんにちは', 'bytes']);
      expect(clock.armedCount, 1, reason: 'each frame replaces the watch: the old timer is cancelled');

      clock.fireBeat();
      expect(connector.last.sent.last, 'PING\tshowroom');
      await subscription.cancel();
    });

    test('the gift table arrives with the join and names the later gifts', () async {
      final table = jsonEncode({
        'normal': [
          {
            'gift_id': 12,
            'gift_name': 'バラ',
            'point': 500,
            'free': false,
            'image': 'https://static.showroom-live.com/image/gift/12_s.png',
          },
        ],
      });
      final (session, connector, _) = _session(gifts: table);
      final seen = <LiveMessage>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(session.dispose);

      await session.connect();
      await _settle();
      connector.last.deliver('MSG\t$_key\t${jsonEncode({'t': 2, 'g': '12', 'n': 1})}');
      await _settle();
      expect(seen.single.type, LiveMessageType.gift);
      expect(seen.single.text, 'バラ ×1', reason: 'asked for once, in the background, as the site loads it');
      expect((seen.single.payload! as LiveGift).value.unitPrice, 500);
      expect(seen.single.messageId, isEmpty, reason: 'the platform still sends no message id');
      await subscription.cancel();
    });

    test('a room whose table cannot be read still reports its gifts', () async {
      final (session, connector, _) = _session();
      final seen = <LiveMessage>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(session.dispose);

      await session.connect();
      await _settle();
      connector.last.deliver('MSG\t$_key\t${jsonEncode({'t': 2, 'g': '12', 'n': 2})}');
      await _settle();
      expect(seen.single.text, ' ×2'.trim(), reason: 'no name without the table, but the gift is shown');
      expect((seen.single.payload! as LiveGift).iconUrl, 'https://static.showroom-live.com/image/gift/12_s.png');
      await subscription.cancel();
    });
  });

  group('a socket that stops', () {
    test('silence replaces the socket, and the new one subscribes again', () async {
      final (session, connector, clock) = _session();
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      await session.connect();
      await _settle();
      final first = connector.last;
      clock.fireAfter();
      await _settle();
      expect(clock.fired.single, ShowroomDanmakuCodec.silenceTimeout);
      expect(connector.sockets, hasLength(1), reason: 'the silence only arms the next step');
      expect(clock.lastArmed, ShowroomDanmakuCodec.reconnectBaseDelay);
      clock.fireAfter();
      await _settle();
      expect(first.closed, isTrue, reason: 'the silent socket is closed, not left to rot');
      expect(connector.sockets, hasLength(2));
      expect(connector.last.sent, ['SUB\t$_key']);
      expect(clock.lastArmed, ShowroomDanmakuCodec.silenceTimeout, reason: 'the fresh socket watches silence again');
      await subscription.cancel();
    });

    test('an error and a close both go to the retry path', () async {
      for (final breakWith in <void Function(_Socket)>[(s) => s.fail(StateError('boom')), (s) => s.end()]) {
        final (session, connector, clock) = _session();
        final subscription = session.events.listen((_) {});
        addTearDown(session.dispose);

        await session.connect();
        await _settle();
        breakWith(connector.last);
        await _settle();
        clock.fireAfter();
        await _settle();
        expect(connector.sockets, hasLength(2), reason: 'the session asked for a new socket');
        await subscription.cancel();
      }
    });

    test('the backoff steps once per failed run and the budget is told once', () async {
      final (session, connector, clock) = _session();
      final seen = <LiveMessage>[];
      final closed = Completer<void>();
      final subscription = session.events.listen(seen.add, onDone: closed.complete);
      addTearDown(session.dispose);

      connector.failure = const ConnectFailure('handshake refused');
      await session.connect();
      await _settle();
      expect(seen, isEmpty, reason: 'a failed first handshake is retried, not an error to the caller');
      expect(
        clock.lastArmed,
        ShowroomDanmakuCodec.reconnectBaseDelay,
        reason: 'the first failure already armed its step',
      );

      for (var step = 1; step <= ShowroomDanmakuCodec.maxReconnects; step++) {
        clock.fireAfter();
        await _settle();
        expect(clock.fired.last, ShowroomDanmakuCodec.reconnectBaseDelay * step, reason: 'failure $step');
      }
      clock.fireAfter();
      await _settle();
      await closed.future;
      expect(seen.single.type, LiveMessageType.system);
      expect(seen.single.text, contains('handshake refused'), reason: 'the terminal line names what never came');
      expect(seen.single.sentAt, DateTime.utc(2026, 11, 5, 12), reason: 'the clock the session was given');
      expect(clock.armedCount, isZero, reason: 'everything is cancelled once the session is over');

      clock.fireAfter();
      await _settle();
      expect(connector.sockets, isEmpty, reason: 'nothing reconnects after the budget');
      await subscription.cancel();
    });

    test('a socket that came to live starts the budget again', () async {
      final (session, connector, clock) = _session();
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      await session.connect();
      await _settle();
      connector.failure = const ConnectFailure('refused');
      clock.fireAfter();
      await _settle();
      expect(clock.fired.last, ShowroomDanmakuCodec.silenceTimeout);
      expect(clock.lastArmed, ShowroomDanmakuCodec.reconnectBaseDelay, reason: 'one silent socket is one step');
      connector.failure = null;
      clock.fireAfter();
      await _settle();
      expect(connector.sockets, hasLength(2), reason: 'and the next one joined');
      connector.failure = const ConnectFailure('refused');
      clock.fireAfter();
      await _settle();
      expect(clock.lastArmed, ShowroomDanmakuCodec.reconnectBaseDelay, reason: 'counted from the live run again');
      await subscription.cancel();
    });
  });

  group('stopping', () {
    test('disconnect closes the socket and drops a retry that was already armed', () async {
      final (session, connector, clock) = _session();
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      await session.connect();
      await _settle();
      await session.disconnect();
      expect(connector.last.closed, isTrue);
      clock.fireAfter();
      await _settle();
      expect(connector.sockets, hasLength(1), reason: 'the queued retry found the session gone');
      await session.connect();
      await _settle();
      expect(connector.sockets, hasLength(2), reason: 'and it can be joined again');
      await subscription.cancel();
    });

    test('a socket that opens after the session stopped is closed and unused', () async {
      final (session, connector, _) = _session();
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      connector.hold = Completer<void>();
      await session.connect();
      await _settle();
      await session.disconnect();
      connector.hold!.complete();
      await _settle();
      expect(connector.sockets, hasLength(1));
      expect(connector.last.closed, isTrue, reason: 'the late socket is not handed to the room');
      expect(connector.last.sent, isEmpty, reason: 'and nothing was subscribed with it');
      await subscription.cancel();
    });

    test('dispose ends the stream and leaves no timer armed', () async {
      final (session, connector, clock) = _session();
      final closed = Completer<void>();
      final subscription = session.events.listen((_) {}, onDone: closed.complete);
      await session.connect();
      await _settle();
      expect(connector.last.sent, ['SUB\t$_key']);
      await session.dispose();
      await closed.future;
      expect(clock.armedCount, isZero);
      expect(connector.last.closed, isTrue);
      await session.dispose();
      await subscription.cancel();
    });
  });
}
