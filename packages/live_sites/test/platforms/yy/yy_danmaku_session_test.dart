import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/yy/api/yy_http.dart';
import 'package:live_sites/src/platforms/yy/danmaku/yy_danmaku_codec.dart';
import 'package:live_sites/src/platforms/yy/danmaku/yy_danmaku_session.dart';
import 'package:live_sites/src/platforms/yy/danmaku/yy_packet.dart';
import 'package:live_sites/src/platforms/yy/yy_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The uris of the anonymous handshake (the session keeps its own copies
/// private; naming them here is the point of the pin).
const int _anonymousLoginRequest = 778244;
const int _anonymousLoginResponse = 778500;
const int _anonymousLoginReal = 20078;
const int _apLoginRequest = 775684;
const int _apLoginResponse = 775940;
const int _apRouterResponse = 512011;
const int _joinChannelRequest = 513035;
const int _joinChannelResponse = 2048514;
const int _bySidMessage = 28760;
const int _textChat = 3104600;
const int _popularity = 3139586;
const int _chatAppId = 31;
const int _audienceAppId = 103;

const int _topSid = 123456;
const int _subSid = 789012;
final DateTime _at = DateTime.utc(2026, 11, 5, 12);

/// A packet of [uri] with [body] behind its header.
Uint8List _packetOf(int uri, void Function(YyPacketWriter writer) body) {
  final writer = YyPacketWriter(uri: uri);
  body(writer);
  return writer.takeBytes();
}

/// A bare field list (a payload that rides inside another packet).
Uint8List _fields(void Function(YyPacketWriter writer) body) {
  final writer = YyPacketWriter();
  body(writer);
  return writer.takeBytes();
}

/// The uris of the packets one frame holds, in order (the header is a
/// little-endian length, uri and response code).
List<int> _urisOf(List<int> frame) {
  final bytes = Uint8List.fromList(frame);
  final found = <int>[];
  var at = 0;
  while (at + 10 <= bytes.length) {
    final data = ByteData.sublistView(bytes, at);
    final length = data.getUint32(0, Endian.little);
    if (length < 10 || at + length > bytes.length) break;
    found.add(data.getUint32(4, Endian.little));
    at += length;
  }
  return found;
}

/// The anonymous login's answer, as the edge writes it.
Uint8List _anonymousLoginReply({int resultCode = 200}) {
  final payload = _fields((w) {
    w
      ..writeString('')
      ..writeUint32(resultCode)
      ..writeUint32(4242)
      ..writeUint32(4242)
      ..writeString('guest')
      ..writeString('ticket-password')
      ..writeByteArray(utf8Bytes('cookie'))
      ..writeByteArray(<int>[1, 2, 3])
      ..writeString('')
      ..writeString('');
  });
  return _packetOf(_anonymousLoginResponse, (w) {
    w
      ..writeString('')
      ..writeUint32(200)
      ..writeUint32(_anonymousLoginReal)
      ..writeByteArray32(payload);
  });
}

/// The AP login's answer: [resultCode] 200 lets the handshake go on.
Uint8List _apLoginReply({int resultCode = 200}) => _packetOf(_apLoginResponse, (w) {
  w
    ..writeUint32(0)
    ..writeUint32(resultCode)
    ..writeString('1:0');
});

/// A routed answer of [realUri].
Uint8List _routed(int realUri, Uint8List payload, {int responseCode = 0}) => _packetOf(_apRouterResponse, (w) {
  w
    ..writeString('')
    ..writeUint32(realUri)
    ..writeUint16(responseCode)
    ..writeByteArray32(payload);
});

/// The join's answer inside the router's envelope.
Uint8List _joinReply({int topSid = _topSid, int subSid = _subSid, int loginStatus = 4}) => _fields((w) {
  w
    ..writeUint32(topSid)
    ..writeUint32(4242)
    ..writeUint32(subSid)
    ..writeUint32(1)
    ..writeUint32(1790519893)
    ..writeUint8(loginStatus)
    ..writeUtf8String('');
});

/// The handshake, walked to the point where the channel is joined.
void _join(_Socket socket) {
  socket
    ..deliver(_anonymousLoginReply())
    ..deliver(_apLoginReply())
    ..deliver(_routed(_joinChannelResponse, _joinReply()));
}

/// A chat service of app 31.
Uint8List _chatBody({String text = 'hello', String userName = 'speaker'}) {
  final block = _fields((w) {
    w
      ..writeUint32(0)
      ..writeUcs2String32('微软雅黑')
      ..writeUint32(0xFFFFFF)
      ..writeUint32(18)
      ..writeUcs2String32(text)
      ..writeUint32(0);
  });
  final tail = _fields((w) {
    w
      ..writeString('')
      ..writeString('')
      ..writeUtf8String(userName)
      ..writeUint32(0);
  });
  return _packetOf(_textChat, (w) {
    w
      ..writeUint32(4242)
      ..writeUint32(_topSid)
      ..writeUint32(_subSid)
      ..writeUint16(block.length)
      ..writeBytes(block)
      ..writeBytes(tail);
  });
}

/// The channel's heat, app 103.
Uint8List _popularityBody({int heat = 5856}) => _packetOf(_popularity, (w) {
  w
    ..writeUint32(heat)
    ..writeUint32(1)
    ..writeUint32(_topSid)
    ..writeUint32(heat - 40);
});

/// A by-sid message of [appId] carrying [service].
Uint8List _bySid(int appId, Uint8List service) => _packetOf(_bySidMessage, (w) {
  w
    ..writeUint16(appId)
    ..writeUint32(_topSid)
    ..writeByteArray(service);
});

List<int> utf8Bytes(String text) => text.codeUnits;

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

  /// The uris of every packet the session has sent, in order.
  List<int> get uris => [for (final frame in sent) ..._urisOf(frame as List<int>)];
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

  YyTimers get timers => (
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

  /// Fires the last timer armed for [delay]: the handshake watch or the silence
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

  /// Fires the AP ping beat.
  void fireBeat() => _every.last.fire();
}

/// The transport under the site: the chat asks it for nothing, so any request is
/// a test failure.
final class _Never implements LiveHttp {
  @override
  Future<LiveResponse> send(LiveRequest request) async => throw StateError('the chat asks for no request');

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

/// A session with its connector and clock; [topSid]/[subSid] choose the channel.
(_Room, _Connector, _Clock) _session({int topSid = _topSid, int subSid = _subSid}) {
  final connector = _Connector();
  final clock = _Clock();
  final site = YySite(http: YyHttp(_Never()), connect: connector.connect);
  final session = YyDanmakuSession(
    args: YyDanmakuArgs(topSid: topSid, subSid: subSid),
    site: site,
    timers: clock.timers,
    now: () => _at,
    random: Random7(),
  );
  return (_Room(session), connector, clock);
}

/// A source of zeros: the connection's uuid and the handshake's ids become
// deterministic without a new dependency.
final class Random7 implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

/// The session, with its event log already collected.
final class _Room {
  _Room(this.session) {
    subscription = session.events.listen(seen.add, onDone: closed.complete);
  }

  final YyDanmakuSession session;
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
  for (var turn = 0; turn < 20; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('the anonymous handshake', () {
    test('one uuid names the connection, and the first packet is the UDB login', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      expect(await room.connect(), isNull);
      await _settle();
      final uri = connector.asked.single.toString();
      expect(uri, startsWith('wss://h5-sinchl.yy.com/websocket?appid=yymwebh5&version='));
      expect(uri, contains('uuid=00000000-0000-4000-8000-000000000000'));
      expect(connector.budgets.single, YyDanmakuProtocol.handshakeTimeout);
      expect(connector.last.uris.first, _anonymousLoginRequest);
      expect(clock.countArmed(YyDanmakuProtocol.handshakeTimeout), 1);
      expect(clock.countArmed(YyDanmakuProtocol.inactivityTimeout), 1);

      connector.last.deliver(_anonymousLoginReply());
      await _settle();
      expect(connector.last.uris, contains(_apLoginRequest), reason: 'the answer hands back the next step');
    });

    test('the join’s answer is the join: the watch is discharged and the ping starts', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fireBeat();
      expect(connector.last.uris, isNot(contains(794116)), reason: 'no ping before the AP login was sent');

      _join(connector.last);
      await _settle();
      expect(connector.last.uris, contains(_joinChannelRequest), reason: 'the join was asked for on this socket');
      expect(clock.countArmed(YyDanmakuProtocol.handshakeTimeout), isZero);
      expect(room.seen, isEmpty, reason: 'a join is not a message for the room');
      expect(clock.lastEvery, YyDanmakuProtocol.heartbeatInterval);

      clock.fireBeat();
      expect(connector.last.uris, contains(794116), reason: 'the AP ping after the beat');
    });

    test('the same uuid and channel ride every reconnect of the session', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      final first = connector.last;
      clock.fire(YyDanmakuProtocol.handshakeTimeout);
      await _settle();
      expect(clock.lastArmed, YyDanmakuProtocol.reconnectBaseDelay);
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(2));
      expect(first.closed, isTrue);
      expect(connector.asked.first.queryParameters['uuid'], connector.asked.last.queryParameters['uuid']);
      expect(connector.last.uris.first, _anonymousLoginRequest, reason: 'the handshake starts over on the new socket');
    });

    test('a channel without a top id is refused before any socket', () async {
      final (room, connector, _) = _session(topSid: 0);
      expect(await room.connect(), isA<LiveSiteContentUnavailable>());
      expect(connector.sockets, isEmpty);

      await room.session.dispose();
      expect(await room.connect(), isA<LiveSiteUnsupported>());
      await room.dispose();
    });
  });

  group('a handshake that is refused', () {
    test('a refused AP login is one attempt, named in its own words', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_anonymousLoginReply());
      connector.last.deliver(_apLoginReply(resultCode: 403));
      await _settle();
      expect(room.seen, isEmpty, reason: 'the room is not told the attempt failed');
      expect(clock.lastArmed, YyDanmakuProtocol.reconnectBaseDelay);

      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(2));
    });

    test('a refused join is one attempt too', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      connector.last.deliver(_anonymousLoginReply());
      connector.last.deliver(_apLoginReply());
      connector.last.deliver(_routed(_joinChannelResponse, _joinReply(), responseCode: 403));
      await _settle();
      expect(clock.lastArmed, YyDanmakuProtocol.reconnectBaseDelay);
      expect(room.closed.isCompleted, isFalse);
    });

    test('eight attempts that never join end the session with a compact line', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      connector.failure = ConnectFailure('${'dial failed ' * 30}and more');
      await room.connect();
      await _settle();
      expect(clock.lastArmed, YyDanmakuProtocol.reconnectBaseDelay);

      for (var attempt = 2; attempt <= YyDanmakuProtocol.maxReconnects; attempt++) {
        clock.fireLast();
        await _settle();
        expect(clock.lastArmed, YyDanmakuProtocol.reconnectBaseDelay * attempt, reason: 'attempt $attempt');
      }
      clock.fireLast();
      await _settle();
      await room.closed.future;
      final terminal = room.ofType(LiveMessageType.system).single;
      expect(terminal.text, startsWith('YY danmaku gave up after ${YyDanmakuProtocol.maxReconnects} attempts:'));
      expect(terminal.text.length, lessThanOrEqualTo('YY danmaku gave up after 8 attempts: '.length + 120));
      expect(terminal.text, endsWith('...'), reason: 'the long reason is folded to 120 characters');
      expect(terminal.sentAt, _at);
      expect(clock.armedCount, isZero);

      clock.fireLast();
      await _settle();
      expect(connector.sockets, isEmpty, reason: 'nothing reconnects after the budget');
    });
  });

  group('a joined socket', () {
    test('chat and heat are reported, and a text frame is nothing', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      _join(connector.last);
      await _settle();
      connector.last.deliver(_bySid(_chatAppId, _chatBody(text: '你好')));
      connector.last.deliver(_bySid(_audienceAppId, _popularityBody()));
      connector.last.deliver('{"not":"binary"}');
      await _settle();
      expect(room.seen.map((message) => message.type), [LiveMessageType.chat, LiveMessageType.audienceUpdate]);
      expect(room.seen.first.text, '你好');
      expect(room.seen.first.sender?.userName, 'speaker');
      expect(clock.countArmed(YyDanmakuProtocol.inactivityTimeout), 1, reason: 'each binary frame re-arms the watch');
    });

    test('a joined socket that goes silent is replaced at once, and the attempt after it counts', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      _join(connector.last);
      await _settle();

      clock.fire(YyDanmakuProtocol.inactivityTimeout);
      await _settle();
      expect(
        clock.lastArmed,
        Duration.zero,
        reason: 'the run joined once, so the replacement is not counted and does not wait',
      );

      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(2));
      clock.fire(YyDanmakuProtocol.handshakeTimeout);
      await _settle();
      expect(
        clock.lastArmed,
        YyDanmakuProtocol.reconnectBaseDelay,
        reason: 'and this attempt, which never joined, is the one that counts',
      );
    });

    test('an error and a close both replace the socket', () async {
      for (final breakWith in <void Function(_Socket)>[(s) => s.fail(StateError('boom')), (s) => s.end()]) {
        final (room, connector, clock) = _session();
        addTearDown(room.dispose);

        await room.connect();
        await _settle();
        breakWith(connector.last);
        await _settle();
        expect(clock.lastArmed, Duration.zero, reason: 'no attempt was lost yet');
        clock.fireLast();
        await _settle();
        expect(connector.sockets, hasLength(2));
      }
    });
  });

  group('stopping', () {
    test('disconnect closes the socket, drops the watches and lets the room rejoin', () async {
      final (room, connector, clock) = _session();
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      _join(connector.last);
      await _settle();
      await room.session.disconnect();
      expect(connector.last.closed, isTrue);
      expect(clock.armedCount, isZero);
      clock.fireLast();
      await _settle();
      expect(connector.sockets, hasLength(1));

      await room.connect();
      await _settle();
      expect(connector.sockets, hasLength(2), reason: 'and the handshake starts over');
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
      expect(connector.last.closed, isTrue);
      expect(connector.last.sent, isEmpty, reason: 'and nothing was handshaked with it');
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
