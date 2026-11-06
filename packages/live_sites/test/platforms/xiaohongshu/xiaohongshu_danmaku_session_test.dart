import 'dart:async';
import 'dart:convert';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/xiaohongshu/danmaku/xiaohongshu_danmaku_codec.dart';
import 'package:live_sites/src/platforms/xiaohongshu/danmaku/xiaohongshu_danmaku_session.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_guest.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _room = '570000000000000017';
const XiaohongshuPushIdentity _identity = XiaohongshuPushIdentity(
  sid: 'synthetic-visitor-sid',
  uid: 'synthetic-visitor',
  deviceId: 'synthetic-device',
  fingerprint: 'synthetic-fingerprint',
  userAgent: 'Synthetic browser',
);
const XiaohongshuPushIdentity _renewed = XiaohongshuPushIdentity(
  sid: 'renewed-sid',
  uid: 'renewed-visitor',
  deviceId: 'renewed-device',
  fingerprint: 'renewed-fingerprint',
  userAgent: 'Renewed browser',
);

/// The socket the session drives, by hand.
final class _Socket implements SocketChannel {
  final _incoming = StreamController<Object?>.broadcast(sync: true);
  final sent = <Map<String, Object?>>[];
  bool closed = false;

  @override
  Stream<Object?> get stream => _incoming.stream;

  @override
  void add(Object data) => sent.add(Map<String, Object?>.from(jsonDecode(data as String) as Map));

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
    if (!_incoming.isClosed) await _incoming.close();
  }

  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;

  /// Pushes a frame while the socket is open; a closed one delivers nothing.
  void deliver(Object? data) {
    if (!_incoming.isClosed) _incoming.add(data);
  }

  Future<void> end() => _incoming.close();

  /// The acknowledgement of the last frame the session sent, with [code].
  void ack({int code = 0}) => deliver(
    jsonEncode({
      'v': 1,
      't': 2,
      'm': sent.last['m'],
      'b': {
        'a': {'c': code, 'm': 'synthetic ack'},
      },
    }),
  );

  /// The operation of the last control frame sent (a push frame, viewing
  /// heart or transport ping is skipped), or null when none was.
  int? get lastOperation {
    for (final frame in sent.reversed) {
      if (frame['t'] == 2) return ((frame['b']! as Map)['d']! as Map)['s']! as int;
    }
    return null;
  }

  /// The text frames sent, in order.
  List<String> get texts => sent.map(jsonEncode).toList();
}

/// The connector the session was built with: every socket recorded, and it
/// can be told to refuse.
final class _Connector {
  final channels = <_Socket>[];
  final headers = <Map<String, String>>[];

  /// When set, opening the socket throws this instead of answering.
  Exception? failure;

  Future<SocketChannel> call(
    Uri endpoint, {
    required Map<String, String> headers,
    required Iterable<String>? protocols,
    required Duration connectTimeout,
    Duration? pingInterval,
  }) async {
    expect(endpoint, XiaohongshuDanmakuCodec.endpoint);
    expect(headers.keys, isNot(contains('Cookie')));
    this.headers.add(headers);
    if (failure != null) throw failure!;
    final channel = _Socket();
    channels.add(channel);
    return channel;
  }

  _Socket get last => channels.last;
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

  XiaohongshuDanmakuTimers get timers => (
    after: (delay, callback) {
      final record = (delay: delay, fire: callback);
      _after.add(record);
      return _Armed(() => _after.remove(record));
    },
    every: (period, callback) {
      final record = (period: period, fire: () => callback(_Armed(() {})));
      _every.add(record);
      return _Armed(() {});
    },
  );

  /// The delay of the last one-shot timer armed.
  Duration? get lastArmed => _after.isEmpty ? null : _after.last.delay;

  /// Fires the last timer armed for [delay] (the bootstrap watch or the next
  /// reconnect step) and forgets it.
  void fire(Duration delay) {
    for (var index = _after.length - 1; index >= 0; --index) {
      if (_after[index].delay != delay) continue;
      final timer = _after.removeAt(index);
      timer.fire();
      return;
    }
    throw StateError('nothing is armed for $delay');
  }

  /// Fires the last one-shot timer armed, whatever it watches.
  void fireLast() {
    if (_after.isEmpty) return;
    _after.removeLast().fire();
  }

  /// Fires the beat.
  void fireBeat() => _every.last.fire();
}

/// The visitor bootstrap the session asks: every request recorded with its
/// refresh flag and cancellation, an optional in-flight hold.
final class _Guest implements XiaohongshuGuest {
  final requests = <({String room, bool refresh, CancelToken? cancel})>[];

  /// When set, the identity arrives only when its completer is completed.
  Completer<XiaohongshuPushIdentity>? pending;

  /// When set, the bootstrap refuses instead of answering.
  bool refuse = false;

  @override
  Future<XiaohongshuPushIdentity> pushIdentity(String roomId, {bool refresh = false, CancelToken? cancel}) async {
    requests.add((room: roomId, refresh: refresh, cancel: cancel));
    if (refuse) throw const XiaohongshuRefusal();
    return pending == null ? (refresh ? _renewed : _identity) : await pending!.future;
  }

  @override
  Future<String> categories({CancelToken? cancel}) => throw UnimplementedError();
  @override
  Future<String> directory({required String category, required String cursor, CancelToken? cancel}) =>
      throw UnimplementedError();
}

/// Any bootstrap breakdown the fake guest can raise.
final class XiaohongshuRefusal implements Exception {
  const XiaohongshuRefusal();
}

/// A push frame with one chat item of [text], id [id].
String _chatPush({String text = '真实文本🙂', String id = 'synthetic-message'}) {
  final item = {
    'd': base64Encode(
      utf8.encode(
        jsonEncode({
          'roomId': _room,
          'roomType': 'LIVE',
          'msgId': id,
          'ts': 1793753000000,
          'customData': jsonEncode({
            'type': 'text',
            'profile': {'nickname': 'Ann', 'user_id': 'u1'},
            'desc': text,
          }),
        }),
      ),
    ),
  };
  return jsonEncode({
    'v': 1,
    't': 4,
    'b': {
      'd': {
        'biz': 'room',
        'b': [item],
      },
    },
  });
}

/// The session, with its event log already collected.
final class _Room {
  _Room(this.session, this.connector, this.clock) {
    subscription = session.events.listen(seen.add, onDone: closed.complete);
  }

  final XiaohongshuDanmakuSession session;
  final _Connector connector;
  final _Clock clock;
  late final StreamSubscription<LiveMessage> subscription;
  final seen = <LiveMessage>[];
  final closed = Completer<void>();

  Future<LiveSiteError?> connect() => session.connect();

  /// Walks the three-step bootstrap of the last socket.
  Future<void> join() async {
    for (var step = 0; step < 3; step++) {
      connector.last.ack();
      await _settle();
    }
  }

  List<LiveMessage> ofType(LiveMessageType type) => seen.where((message) => message.type == type).toList();

  Future<void> dispose() async {
    await subscription.cancel();
    await session.dispose();
  }
}

(_Room, _Guest) _make() {
  final guest = _Guest();
  final connector = _Connector();
  final clock = _Clock();
  final session = XiaohongshuDanmakuSession(
    args: const XiaohongshuDanmakuArgs(roomId: _room),
    guest: guest,
    connector: connector.call,
    timers: clock.timers,
  );
  return (_Room(session, connector, clock), guest);
}

Future<void> _settle() async {
  for (var turn = 0; turn < 12; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('the bootstrap', () {
    test('auth, register and join need their own acknowledgements, then the heart starts', () async {
      final (room, guest) = _make();
      addTearDown(room.dispose);

      expect(await room.connect(), isNull);
      expect(guest.requests.single.refresh, isFalse);
      final channel = room.connector.channels.single;
      expect(channel.lastOperation, 0);
      expect(room.seen, isEmpty, reason: 'nothing is reported before the bootstrap finished');

      // An acknowledgement of another step is ignored.
      channel.deliver(
        jsonEncode({
          'v': 1,
          't': 2,
          'm': 'wrong-id',
          'b': {
            'a': {'c': 0},
          },
        }),
      );
      await _settle();
      expect(channel.sent, hasLength(1));

      await room.join();
      expect(room.connector.channels, hasLength(1));
      expect(channel.lastOperation, 8);
      expect(room.ofType(LiveMessageType.chat), isEmpty);

      // A chat push is reported once, a repeat not at all.
      final push = _chatPush();
      channel
        ..deliver(push)
        ..deliver(push);
      await _settle();
      expect(room.ofType(LiveMessageType.chat), hasLength(1));

      room.clock.fireBeat();
      expect(channel.texts.last, XiaohongshuDanmakuCodec.transportHeartbeat);
      expect(jsonEncode(channel.sent), isNot(contains('sendMessage')), reason: 'nothing is ever posted');
      await room.session.dispose();
      expect(channel.closed, isTrue);
      expect(guest.requests.single.cancel!.isCancelled, isTrue);
      final count = room.seen.length;
      channel.deliver(_chatPush(id: 'late'));
      await _settle();
      expect(room.seen, hasLength(count), reason: 'a disposed session reports nothing');
    });

    test('a room id that is not one is refused before any socket or bootstrap', () async {
      final guest = _Guest();
      final connector = _Connector();
      final clock = _Clock();
      final session = XiaohongshuDanmakuSession(
        args: const XiaohongshuDanmakuArgs(roomId: '0x'),
        guest: guest,
        connector: connector.call,
        timers: clock.timers,
      );
      addTearDown(session.dispose);
      expect(await session.connect(), isA<LiveSiteNotFound>());
      expect(connector.channels, isEmpty);
      expect(guest.requests, isEmpty);
    });

    test('a bootstrap that never answers is refused', () async {
      final guest = _Guest()..refuse = true;
      final connector = _Connector();
      final clock = _Clock();
      final session = XiaohongshuDanmakuSession(
        args: const XiaohongshuDanmakuArgs(roomId: _room),
        guest: guest,
        connector: connector.call,
        timers: clock.timers,
      );
      addTearDown(session.dispose);
      expect(await session.connect(), isA<LiveSiteAuthenticationError>());
      expect(connector.channels, isEmpty);
    });
  });

  group('refusals', () {
    test('an authentication refusal renews once; a second refusal ends without a ready beat', () async {
      final (room, guest) = _make();
      addTearDown(room.dispose);

      await room.connect();
      room.connector.channels.first.ack(code: 3100001);
      await _settle();
      expect(guest.requests.map((request) => request.refresh), [false, true]);
      expect(room.connector.channels.first.closed, isTrue, reason: 'the refused socket is replaced');
      expect(room.connector.channels, hasLength(2));
      expect(room.connector.headers.last['user-agent'], _renewed.userAgent);
      expect(room.connector.channels.last.lastOperation, 0);

      room.connector.channels.last.ack(code: 3100001);
      await _settle();
      await room.closed.future;
      expect(room.ofType(LiveMessageType.system).single.text, contains('push credentials unavailable'));
      expect(guest.requests, hasLength(2));
      expect(room.connector.channels, hasLength(2), reason: 'nothing reconnects');
    });

    test('a later expired identity can renew after an earlier renewal joined successfully', () async {
      final (room, guest) = _make();
      addTearDown(room.dispose);

      await room.connect();
      room.connector.channels.last.ack(code: 3100001);
      await _settle();
      expect(room.connector.channels, hasLength(2));
      await room.join();
      expect(room.connector.channels, hasLength(2));

      await room.connector.channels.last.end();
      await _settle();
      room.clock.fireLast();
      await _settle();
      expect(room.connector.channels, hasLength(3), reason: 'the closed socket is replaced');
      room.connector.channels.last.ack(code: 3100001);
      await _settle();
      expect(guest.requests.map((request) => request.refresh), [false, true, true]);
      expect(room.connector.channels, hasLength(4));
      await room.join();
      expect(room.ofType(LiveMessageType.system), isEmpty);
    });

    test('a register or join refusal cannot report ready or endlessly bootstrap', () async {
      for (final refusalAt in [1, 2]) {
        final (room, guest) = _make();
        addTearDown(room.dispose);

        await room.connect();
        for (var step = 0; step < refusalAt; step++) {
          room.connector.last.ack();
          await _settle();
        }
        room.connector.last.ack(code: 3100001);
        await _settle();
        await room.closed.future;
        expect(room.ofType(LiveMessageType.system).single.text, contains('push credentials unavailable'));
        expect(guest.requests, hasLength(1), reason: 'no renewal for a refusal at step $refusalAt');
        expect(room.connector.channels, hasLength(1));
      }
    });
  });

  group('a socket that stops', () {
    test('closing after a joined bootstrap replaces it, keeping identity and dedup', () async {
      final (room, guest) = _make();
      addTearDown(room.dispose);

      await room.connect();
      await room.join();
      room.connector.last.deliver(_chatPush(id: 'first'));
      await _settle();
      await room.connector.last.end();
      await _settle();
      expect(room.clock.lastArmed, const Duration(seconds: 1), reason: 'the first reconnect step');

      room.clock.fireLast();
      await _settle();
      expect(room.connector.channels, hasLength(2));
      expect(room.connector.channels.last.lastOperation, 0, reason: 'the bootstrap repeats');
      expect(guest.requests, hasLength(1), reason: 'the identity is kept');
      await room.join();
      room.connector.last.deliver(_chatPush(id: 'first'));
      await _settle();
      expect(room.ofType(LiveMessageType.chat), hasLength(1), reason: 'the id is still known');
    });

    test('a bootstrap that does not finish in time is replaced', () async {
      final (room, _) = _make();
      addTearDown(room.dispose);

      await room.connect();
      expect(room.clock.lastArmed, XiaohongshuDanmakuSession.joinTimeout);
      room.clock.fire(XiaohongshuDanmakuSession.joinTimeout);
      await _settle();
      expect(room.connector.channels, hasLength(1), reason: 'the replacement is on its way');
      room.clock.fireLast();
      await _settle();
      expect(room.connector.channels, hasLength(2));
      expect(room.connector.channels.last.lastOperation, 0);
    });

    test('the eighth failed reconnect ends the session', () async {
      final (room, _) = _make();
      addTearDown(room.dispose);

      await room.connect();
      await room.connector.channels.first.end();
      await _settle();
      room.connector.failure = const ConnectFailure('handshake refused');
      for (var attempt = 1; attempt < XiaohongshuDanmakuSession.maxReconnectAttempts; attempt++) {
        room.clock.fireLast();
        await _settle();
        expect(room.closed.isCompleted, isFalse, reason: 'failure $attempt is still retried');
      }
      room.clock.fireLast();
      await _settle();
      await room.closed.future;
      expect(room.ofType(LiveMessageType.system).single.text, contains('handshake refused'));
    });
  });

  group('dedup and runs', () {
    test('storage is bounded and resets for a new connect run', () async {
      final (room, _) = _make();
      addTearDown(room.dispose);

      await room.connect();
      await room.join();
      for (var i = 0; i < 513; i++) {
        room.connector.last.deliver(_chatPush(id: 'message-$i'));
      }
      room.connector.last.deliver(_chatPush(id: 'message-0'));
      await _settle();
      expect(room.ofType(LiveMessageType.chat), hasLength(514));

      await room.session.disconnect();
      await room.connect();
      await room.join();
      room.connector.last.deliver(_chatPush(id: 'message-0'));
      await _settle();
      expect(room.ofType(LiveMessageType.chat), hasLength(515), reason: 'the new run forgot the ids');
    });
  });

  group('stopping', () {
    test('close during the bootstrap suppresses the old run and opens no socket', () async {
      final guest = _Guest()..pending = Completer<XiaohongshuPushIdentity>();
      final connector = _Connector();
      final clock = _Clock();
      final session = XiaohongshuDanmakuSession(
        args: const XiaohongshuDanmakuArgs(roomId: _room),
        guest: guest,
        connector: connector.call,
        timers: clock.timers,
      );
      final events = <LiveMessage>[];
      final sub = session.events.listen(events.add);
      addTearDown(sub.cancel);
      final connecting = session.connect();
      await _settle();
      await session.dispose();
      expect(guest.requests.single.cancel!.isCancelled, isTrue);
      guest.pending!.complete(_identity);
      await connecting;
      expect(connector.channels, isEmpty);
      expect(events, isEmpty);
    });

    test('disconnect drops an armed retry, connect can be joined again', () async {
      final (room, _) = _make();
      addTearDown(room.dispose);

      await room.connect();
      await room.join();
      await room.connector.last.end();
      await _settle();
      expect(room.clock.lastArmed, isNotNull);
      await room.session.disconnect();
      expect(room.clock.lastArmed, isNull, reason: 'the retry that was armed is dropped');
      room.clock.fireLast();
      await _settle();
      expect(room.connector.channels, hasLength(1), reason: 'the queued retry found the session gone');

      await room.connect();
      await room.join();
      expect(room.connector.channels, hasLength(2), reason: 'and it can be joined again');
    });

    test('dispose ends the stream and leaves no timer armed', () async {
      final (room, _) = _make();
      await room.connect();
      await room.join();
      expect(room.connector.channels.last.lastOperation, 8);
      await room.session.dispose();
      await room.closed.future;
      expect(room.connector.last.closed, isTrue);
      await room.session.dispose();
      expect(room.seen, isEmpty);
      await room.dispose();
    });
  });
}
