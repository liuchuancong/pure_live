import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/soop/api/soop_http.dart';
import 'package:live_sites/src/platforms/soop/danmaku/soop_danmaku_codec.dart';
import 'package:live_sites/src/platforms/soop/danmaku/soop_danmaku_session.dart';
import 'package:live_sites/src/platforms/soop/soop_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

final Uri _tls = Uri.parse('wss://chat.sooplive.co.kr:20003/Websocket/room1');
final Uri _plain = Uri.parse('ws://chat.sooplive.co.kr:20002/Websocket/room1');
final Uri _none = Uri.parse('');

/// The body of a packet whose fields follow the leading empty field.
String _body(List<String> fields) => '\f${fields.join('\f')}';

/// A frame of binary packets, in the `ESC TAB` service/length form.
Uint8List _frame(List<(int, String)> packets) {
  final out = BytesBuilder();
  for (final (service, body) in packets) {
    final bytes = utf8.encode(body);
    final header = '\x1b\t${service.toString().padLeft(4, '0')}${bytes.length.toString().padLeft(6, '0')}00';
    out
      ..add(ascii.encode(header))
      ..add(bytes);
  }
  return out.toBytes();
}

/// A chat packet of the room.
Uint8List _chatFrame([String text = 'hello']) => _frame([
  (SoopDanmakuCodec.chatService, _body([text, 'loo3672(2)', 'x', 'x', 'x', 'Ann'])),
]);

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

  /// The text packets sent, in order.
  List<String> get texts => sent.map((frame) => '$frame').toList();
}

/// The connector the site was built with: every request recorded, and it can be
/// told to refuse, to refuse once, or to wait.
final class _Connector {
  final sockets = <_Socket>[];
  final asked = <Uri>[];
  final headers = <Map<String, String>>[];
  final protocols = <List<String>?>[];
  final budgets = <Duration>[];

  /// When set, opening the socket throws this instead of answering.
  Exception? failure;

  /// When set, only this many attempts are refused.
  int? refuses;

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
    this.protocols.add(protocols?.toList());
    budgets.add(connectTimeout);
    final refused = failure != null || (refuses != null && refuses! > 0);
    if (refuses != null && refuses! > 0) refuses = refuses! - 1;
    if (refused) throw failure ?? const ConnectFailure('handshake refused');
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

  SoopTimers get timers => (
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

  /// Fires the last timer armed for [delay]: the join pause or the silence
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

/// The transport under the site: the chat asks it for nothing, so any request
/// fails the test.
final class _Never implements LiveHttp {
  @override
  Future<LiveResponse> send(LiveRequest request) async => throw StateError('the chat asks for no request');

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

/// A session with its connector and clock; [args] chooses the two ports and the
/// chat room, [delay] the pause before the join packet.
(_Room, _Connector, _Clock) _session({SoopDanmakuArgs? args, Duration delay = Duration.zero}) {
  final connector = _Connector();
  final clock = _Clock();
  final site = SoopSite(http: SoopHttp(_Never()), connect: connector.connect);
  final session = SoopDanmakuSession(
    args:
        args ??
        SoopDanmakuArgs(
          url: _tls,
          plainUrl: _plain,
          chatNo: '123',
          headers: const {'user-agent': 'Mozilla/5.0', 'origin': 'https://www.sooplive.co.kr'},
        ),
    site: site,
    timers: clock.timers,
    joinDelay: delay,
  );
  return (_Room(session), connector, clock);
}

/// The session, with its event log already collected.
final class _Room {
  _Room(this.session) {
    subscription = session.events.listen(seen.add, onDone: closed.complete);
  }

  final SoopDanmakuSession session;
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
  group('an open socket is the join', () {
    test('the login goes out at once, the join packet only after its pause', () async {
      final (room, connector, clock) = _session(delay: SoopDanmakuCodec.joinDelay);
      addTearDown(room.dispose);

      expect(await room.connect(), isNull);
      await _settle();
      expect(connector.asked.single, _tls);
      expect(connector.protocols.single, SoopDanmakuCodec.protocols);
      expect(connector.budgets.single, SoopDanmakuCodec.silenceTimeout);
      expect(connector.last.texts, [SoopDanmakuCodec.login]);
      expect(room.seen, isEmpty, reason: 'the server confirms nothing, so there is no join answer to report');
      expect(clock.lastEvery, SoopDanmakuCodec.heartbeatInterval);
      expect(clock.countArmed(SoopDanmakuCodec.joinDelay), 1);
      expect(clock.countArmed(SoopDanmakuCodec.silenceTimeout), 1);

      clock.fire(SoopDanmakuCodec.joinDelay);
      await _settle();
      expect(connector.last.texts, [SoopDanmakuCodec.login, SoopDanmakuCodec.join('123')]);
    });

    test('the handshake spells its headers as the edge reads them', () async {
      final (room, connector, _) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      expect(connector.headers.single, {'User-Agent': 'Mozilla/5.0', 'Origin': 'https://www.sooplive.co.kr'});
    });

    test('a room naming no chat server or no room is refused before any socket', () async {
      final (noHost, connector, _) = _session(
        args: SoopDanmakuArgs(url: _none, plainUrl: _plain, chatNo: '1', headers: const {}),
      );
      expect(await noHost.connect(), isA<LiveSiteContentUnavailable>());
      expect(connector.sockets, isEmpty);

      final (noRoom, _, _) = _session(
        args: SoopDanmakuArgs(url: _tls, plainUrl: _plain, chatNo: '', headers: const {}),
      );
      expect(await noRoom.connect(), isA<LiveSiteContentUnavailable>(), reason: 'no CHATNO to join with');

      await noHost.session.dispose();
      expect(await noHost.connect(), isA<LiveSiteUnsupported>());
      await noHost.dispose();
      await noRoom.dispose();
    });

    test('a socket that closes at once is the failed join', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.end();
      await _settle();
      expect(clock.armedCount, 1, reason: 'the join pause and the watch went with the socket');
      expect(clock.lastArmed, SoopDanmakuCodec.reconnectBaseDelay);
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(2));
      expect(connector.last.texts, [SoopDanmakuCodec.login]);
    });
  });

  group('the two ports', () {
    test('a refused connect tries the plain port next', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      connector.refuses = 1;
      await room.connect();
      await _settle();
      expect(connector.asked, [_tls]);
      expect(connector.sockets, isEmpty);
      expect(clock.lastArmed, SoopDanmakuCodec.reconnectBaseDelay);

      clock.fireLast();
      await _settle();
      expect(connector.asked, [_tls, _plain], reason: 'the plain port answers where the TLS one drops');
      expect(connector.sockets, hasLength(1));
      expect(connector.last.texts, [SoopDanmakuCodec.login]);
    });

    test('an opened socket starts the rotation again', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      connector.refuses = 1;
      await room.connect();
      await _settle();
      clock.fireLast();
      await _settle();
      expect(connector.asked.last, _plain);
      expect(clock.armedCount, 2, reason: 'the join pause and the silence watch of a live socket');

      clock.fire(SoopDanmakuCodec.silenceTimeout);
      await _settle();
      clock.fireLast();
      await _settle();
      expect(connector.asked.last, _tls, reason: 'the count and the index reset when a socket opens');
    });

    test('the ladder runs on one port while the other keeps refusing', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      connector.failure = const ConnectFailure('handshake refused');
      await room.connect();
      await _settle();
      expect(connector.asked, [_tls]);

      for (var step = 1; step <= SoopDanmakuCodec.maxReconnects; step++) {
        clock.fireLast();
        await _settle();
        expect(clock.fired.last, SoopDanmakuCodec.reconnectBaseDelay * step, reason: 'failure $step');
      }
      await room.closed.future;
      expect(connector.asked, hasLength(SoopDanmakuCodec.maxReconnects + 1));
      expect(connector.asked.take(3), [_tls, _plain, _tls], reason: 'the two ports alternate');
      final terminal = room.ofType(LiveMessageType.system).single;
      expect(terminal.text, contains('handshake refused'), reason: 'the line names what never came');
      expect(
        terminal.sentAt,
        isNull,
        reason: 'this session is given no clock, so the room stamps the line as it reads it',
      );
      expect(clock.armedCount, isZero);

      clock.fireLast();
      await _settle();
      expect(connector.sockets, isEmpty, reason: 'nothing reconnects after the budget');
    });
  });

  group('a live socket', () {
    test('binary chat is reported, a text frame is not even a sign of life', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_chatFrame());
      connector.last.deliver('{"not":"chat"}');
      await _settle();
      expect(room.seen.map((message) => message.text), ['hello']);
      expect(room.seen.single.sender?.userId, 'loo3672');
      expect(room.seen.single.sender?.userName, 'Ann');
      expect(clock.countArmed(SoopDanmakuCodec.silenceTimeout), 1, reason: 'the binary frame re-armed the watch');

      clock.fire(SoopDanmakuCodec.silenceTimeout);
      await _settle();
      expect(clock.lastArmed, SoopDanmakuCodec.reconnectBaseDelay);
    });

    test('the keep-alive goes out on the beat, and a joined run clears the count', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      connector.refuses = 1;
      await room.connect();
      await _settle();
      clock.fireLast();
      await _settle();
      clock.fireBeat();
      expect(connector.last.texts, [SoopDanmakuCodec.login, SoopDanmakuCodec.heartbeat]);

      clock.fire(SoopDanmakuCodec.silenceTimeout);
      await _settle();
      expect(clock.lastArmed, SoopDanmakuCodec.reconnectBaseDelay, reason: 'counted from the opened socket again');
    });

    test('an error goes to the retry path and replaces the socket', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.fail(StateError('boom'));
      await _settle();
      clock.fireLast();
      await _settle();
      expect(connector.sockets.first.closed, isTrue);
      expect(connector.sockets, hasLength(2));
    });
  });

  group('stopping', () {
    test('disconnect closes the socket and drops what was armed', () async {
      final (room, connector, clock) = _session(delay: const Duration(seconds: 5));
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      expect(connector.last.texts, [SoopDanmakuCodec.login]);
      await room.session.disconnect();
      expect(connector.last.closed, isTrue);
      expect(clock.armedCount, isZero, reason: 'neither the join pause nor the watch survives');
      clock.fireLast();
      await _settle();
      expect(connector.last.texts, [SoopDanmakuCodec.login], reason: 'and the join never went out');

      await room.connect();
      await _settle();
      expect(connector.sockets, hasLength(2), reason: 'the session can be joined again');
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
      expect(connector.last.sent, isEmpty, reason: 'and nothing was logged in with it');
    });

    test('dispose ends the stream and leaves no timer armed', () async {
      final (room, connector, clock) = _session();
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
