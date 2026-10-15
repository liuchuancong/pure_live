import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_gift_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/soop/api/soop_endpoints.dart';
import 'package:live_sites/src/platforms/soop/api/soop_http.dart';
import 'package:live_sites/src/platforms/soop/danmaku/soop_danmaku_codec.dart';
import 'package:live_sites/src/platforms/soop/danmaku/soop_danmaku_session.dart';
import 'package:live_sites/src/platforms/soop/soop_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

const String _id = 'loo3672';

const String _escape = '\x1b\t';

const String _uuid = '0b6e1111-1111-4111-8111-111111111111';

Uri _chatUrl() => Uri(scheme: 'wss', host: 'chat-6E0A4C4E.sooplive.com', port: 1568, pathSegments: ['Websocket', _id]);

Uri _chatPlainUrl() =>
    Uri(scheme: 'ws', host: 'chat-6E0A4C4E.sooplive.com', port: 1567, pathSegments: ['Websocket', _id]);

SoopDanmakuArgs _args() => SoopDanmakuArgs(
  url: _chatUrl(),
  plainUrl: _chatPlainUrl(),
  chatNo: '12345678',
  headers: SoopEndpoints.apiHeaders(),
);

/// One chat packet: `ESC TAB`, the 4-digit service, the 6-digit body length
/// in bytes, two filler bytes and the body (its fields joined by form feeds,
/// the first one empty as the wire carries it).
List<int> _packet(int service, List<String> fields) {
  final body = utf8.encode(fields.join('\f'));
  final header = utf8.encode('$_escape${service.toString().padLeft(4, '0')}${body.length.toString().padLeft(6, '0')}');
  return [...header, 0x00, 0x00, ...body];
}

Uint8List _frame(Iterable<List<int>> packets) => Uint8List.fromList([for (final packet in packets) ...packet]);

/// A chat line's body: text in field 1, the sender's id in field 2 (with the
/// second session's `(2)` on it), the nick in field 6.
List<int> _chatPacket({String text = '안녕하세요', String id = 'loo3672(2)', String name = '观众甲'}) =>
    _packet(5, ['', text, id, 'a', 'b', 'c', name, 'd']);

List<int> _balloonPacket(
  int service, {
  required int senderAt,
  required int nameAt,
  required int countAt,
  int? idAt,
  int? pictureAt,
  String sender = 'sender01',
  String name = '观众乙',
  String count = '3',
  String id = '',
  String picture = '',
}) {
  final fields = List<String>.filled(20, '');
  fields[senderAt] = sender;
  fields[nameAt] = name;
  fields[countAt] = count;
  if (idAt != null) fields[idAt] = id;
  if (pictureAt != null) fields[pictureAt] = picture;
  return _packet(service, fields);
}

/// A subscription (91) or its ceremony (93): the sender and the nick where
/// each service carries them, the months (`accMonth`, else `month`) and the
/// packet's uuid.
List<int> _subscriptionPacket({bool ceremony = false, String months = '', String fallback = ''}) {
  final fields = List<String>.filled(12, '');
  if (ceremony) {
    fields[2] = 'sendId';
    fields[3] = '观众丙';
    if (months.isNotEmpty) fields[7] = months;
    if (fallback.isNotEmpty) fields[4] = fallback;
  } else {
    fields[3] = 'sendId';
    fields[4] = '观众丙';
  }
  fields[9] = _uuid;
  return _packet(ceremony ? 93 : 91, fields);
}

final class _IdleTimer implements Timer {
  @override
  bool get isActive => false;

  @override
  int get tick => 0;

  @override
  void cancel() {}
}

final class FakeTimers {
  final List<({Duration delay, void Function() callback})> after = [];
  final List<({Duration period, void Function(Timer timer) callback})> every = [];

  SoopTimers get timers => (after: _after, every: _every);

  Timer _after(Duration delay, void Function() callback) {
    after.add((delay: delay, callback: callback));
    return _IdleTimer();
  }

  Timer _every(Duration period, void Function(Timer timer) callback) {
    every.add((period: period, callback: callback));
    return _IdleTimer();
  }

  void fireLatest() => after.last.callback();

  void fireAt(int index) => after[index].callback();

  void ringLatest() => every.last.callback(_IdleTimer());
}

/// The socket a test drives by hand.
final class _FakeSocket implements SocketChannel {
  final StreamController<Object?> _stream = StreamController<Object?>();
  final List<Object?> sentList = [];
  bool closed = false;

  @override
  Stream<Object?> get stream => _stream.stream;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  void add(Object data) => sentList.add(data);

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
  }

  void push(Object? frame) => _stream.add(frame);

  Future<void> ended() => _stream.close();

  String get sentText => sentList.whereType<String>().join('\n');
}

final class _Connector {
  new({this.acceptScheme, this.failures});

  /// When set, only endpoints of this scheme open; others throw.
  final String? acceptScheme;

  /// When non-null, the first [failures] connects throw.
  int? failures;
  int thrown = 0;

  final List<_FakeSocket> sockets = [];
  final List<Uri> endpoints = [];

  _FakeSocket get latest => sockets.last;

  Future<SocketChannel> call(
    Uri endpoint, {
    required Map<String, String> headers,
    required Iterable<String>? protocols,
    required Duration connectTimeout,
    Duration? pingInterval,
  }) async {
    endpoints.add(endpoint);
    if (acceptScheme != null && endpoint.scheme != acceptScheme) throw StateError('refused ${endpoint.scheme}');
    if (failures != null && thrown < failures!) {
      thrown++;
      throw StateError('connect failed');
    }
    final socket = _FakeSocket();
    sockets.add(socket);
    return socket;
  }
}

Future<SocketChannel> _refuseSocket(
  Uri endpoint, {
  required Map<String, String> headers,
  required Iterable<String>? protocols,
  required Duration connectTimeout,
  Duration? pingInterval,
}) async => throw StateError('no socket was asked for in this test');

LiveResponse _ok(String body) =>
    LiveResponse(statusCode: 200, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(body)));

LiveResponse _playerLive({int result = 1, bool withChat = true}) => _ok(
  jsonEncode({
    'CHANNEL': {
      'RESULT': result,
      if (withChat) ...{'CHATNO': '12345678', 'CHDOMAIN': 'chat-6e0a4c4e.sooplive.com', 'CHPT': '1567'},
    },
  }),
);

final class _Seen {
  new(LiveRequest request) : url = request.url;
  final Uri url;
}

final class _FakeHttp implements LiveHttp {
  new(this.onSend);
  final FutureOr<LiveResponse> Function(_Seen request) onSend;
  final List<_Seen> sent = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final seen = _Seen(request);
    sent.add(seen);
    return await onSend(seen);
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

Future<void> _settle() => Future<void>.delayed(Duration.zero);

SoopSite _site({_Connector? connector}) => SoopSite(
  http: SoopHttp(
    _FakeHttp(
      (request) => request.url.path == '/api/$_id/station'
          ? _ok(
              jsonEncode({
                'station': {'user_nick': '主播甲'},
              }),
            )
          : _playerLive(),
    ),
  ),
  connect: connector?.call ?? _refuseSocket,
  now: () => DateTime.parse('2026-09-30T14:00:00.000Z'),
);

Future<({SoopDanmakuSession session, _FakeSocket socket, FakeTimers timers, _Connector connector})> _chat({
  _Connector? connector,
}) async {
  final timers = FakeTimers();
  final used = connector ?? _Connector();
  final session = SoopDanmakuSession(
    args: _args(),
    site: _site(connector: used),
    timers: timers.timers,
    joinDelay: Duration.zero,
  );
  expect(await session.connect(), isNull);
  await _settle();
  return (session: session, socket: used.latest, timers: timers, connector: used);
}

void main() {
  group('chat protocol', () {
    test('the fixed packets are as the wire carries them', () {
      expect(SoopDanmakuCodec.login, '${_escape}000100000600\f\f\f16\f');
      expect(SoopDanmakuCodec.heartbeat, '${_escape}000000000100\f');
      expect(SoopDanmakuCodec.join('12345678'), '${_escape}000200001400\f12345678\f\f\f\f\f');
      // The length counts UTF-8 bytes: 별풍선 is nine of them.
      expect(SoopDanmakuCodec.join('별풍선'), '${_escape}000200001500\f별풍선\f\f\f\f\f');
      expect(SoopDanmakuCodec.protocols, ['chat']);
    });

    test('the endpoints are the TLS port first, the plain one second', () {
      expect(SoopDanmakuCodec.endpoints(_args()), [_chatUrl(), _chatPlainUrl()]);
    });

    test('handshake headers are spelled as 3.x wrote them', () {
      expect(SoopDanmakuCodec.handshakeHeaders({'user-agent': 'x', 'sec-fetch-dest': 'empty', 'origin': 'o'}), {
        'User-Agent': 'x',
        'Sec-Fetch-Dest': 'empty',
        'Origin': 'o',
      });
    });

    test('packets are cut at the header, malformed tails dropped', () {
      final frame = _frame([_chatPacket(text: 'one'), _chatPacket(text: 'two')]);
      final packets = SoopDanmakuCodec.packets(frame);
      expect(packets, hasLength(2));
      expect(packets.every((packet) => packet.service == 5), isTrue);
      // A packet whose length runs past the frame ends the read.
      final truncated = Uint8List.fromList([..._chatPacket(text: 'x').take(20)]);
      expect(SoopDanmakuCodec.packets(truncated), isEmpty);
      // A body without the ESC TAB prefix stops the read at it.
      final withGarbage = Uint8List.fromList([..._chatPacket(text: 'x'), 1, 2, 3, 0x1b, 0x09, 48, 48, 48, 48]);
      expect(SoopDanmakuCodec.packets(withGarbage), hasLength(1));
      expect(SoopDanmakuCodec.packets(Uint8List.fromList(const [0x1b, 0x09])), isEmpty);
    });

    test('a chat line is read from its fields', () {
      final messages = SoopDanmakuCodec.decode(_frame([_chatPacket()]));
      expect(messages, hasLength(1));
      expect(messages.single.type, LiveMessageType.chat);
      expect(messages.single.text, '안녕하세요');
      expect(messages.single.effectiveSender.userName, '观众甲');
      expect(messages.single.effectiveSender.userId, 'loo3672', reason: 'the second session suffix goes');
      // Fewer than seven fields, an empty text and an empty nick are nothing.
      expect(
        SoopDanmakuCodec.decode(
          _frame([
            _packet(5, ['', 'text', 'id']),
          ]),
        ),
        isEmpty,
      );
      expect(
        SoopDanmakuCodec.decode(
          _frame([
            _packet(5, ['', '', 'id', 'a', 'b', 'c', 'nick']),
          ]),
        ),
        isEmpty,
      );
      expect(
        SoopDanmakuCodec.decode(
          _frame([
            _packet(5, ['', 'text', 'id', 'a', 'b', 'c', '']),
          ]),
        ),
        isEmpty,
      );
    });

    test('a star balloon is a tip of one star balloon apiece', () {
      final messages = SoopDanmakuCodec.decode(
        _frame([_balloonPacket(18, senderAt: 2, nameAt: 3, countAt: 4, idAt: 12, id: _uuid)]),
      );
      expect(messages, hasLength(1));
      final message = messages.single;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, '별풍선 ×3');
      expect(message.messageId, _uuid);
      final gift = message.payload! as LiveGift;
      expect(gift.name, '별풍선');
      expect(gift.count, 3);
      expect(gift.kind, LiveGiftKind.tip);
      expect(gift.value.unit, LiveGiftUnit.gold);
      expect(gift.value.unitPrice, 1.0);
      expect(gift.value.totalValue, 3.0);
      expect(gift.iconUrl, isNull);
      // Without a sender, a name or a count above zero: nothing.
      expect(
        SoopDanmakuCodec.decode(_frame([_balloonPacket(18, senderAt: 2, nameAt: 3, countAt: 4, sender: '')])),
        isEmpty,
      );
      expect(
        SoopDanmakuCodec.decode(_frame([_balloonPacket(18, senderAt: 2, nameAt: 3, countAt: 4, count: '0')])),
        isEmpty,
      );
    });

    test('the relayed balloon reads its fields one further on', () {
      final messages = SoopDanmakuCodec.decode(
        _frame([_balloonPacket(33, senderAt: 4, nameAt: 5, countAt: 6, count: '2')]),
      );
      expect((messages.single.payload! as LiveGift).name, '별풍선');
      expect(messages.single.text, '별풍선 ×2');
    });

    test('a video balloon names itself 영상풍선 and carries no uuid', () {
      final messages = SoopDanmakuCodec.decode(_frame([_balloonPacket(105, senderAt: 3, nameAt: 4, countAt: 5)]));
      expect((messages.single.payload! as LiveGift).name, '영상풍선');
      expect(messages.single.messageId, '');
    });

    test('an ad balloon has no value this app can place, its picture kept', () {
      final messages = SoopDanmakuCodec.decode(
        _frame([
          _balloonPacket(
            87,
            senderAt: 3,
            nameAt: 4,
            countAt: 10,
            pictureAt: 8,
            idAt: 16,
            picture: 'https://stimg.sooplive.co.kr/ad.png',
          ),
        ]),
      );
      final gift = messages.single.payload! as LiveGift;
      expect(gift.name, '애드벌룬');
      expect(gift.value.unit, LiveGiftUnit.other);
      expect(gift.value.unitPrice, isNull);
      expect(gift.value.totalValue, isNull);
      expect(gift.iconUrl, 'https://stimg.sooplive.co.kr/ad.png');
      // A picture that is not https is dropped.
      final http = SoopDanmakuCodec.decode(
        _frame([_balloonPacket(87, senderAt: 3, nameAt: 4, countAt: 10, pictureAt: 8, picture: 'http://ad/x.png')]),
      ).single;
      expect((http.payload! as LiveGift).iconUrl, isNull);
    });

    test('a subscription is a notice, its ceremony naming the months', () {
      final plain = SoopDanmakuCodec.decode(_frame([_subscriptionPacket()])).single;
      expect(plain.type, LiveMessageType.notice);
      expect(plain.payload, LiveNoticeKind.subscription);
      expect(plain.text, '观众丙 订阅了频道');
      expect(plain.messageId, 'subscription:$_uuid');

      final ceremony = SoopDanmakuCodec.decode(_frame([_subscriptionPacket(ceremony: true, months: '5')])).single;
      expect(ceremony.text, '观众丙 订阅了频道，已订阅 5 个月');
      // Without accMonth the month field is read.
      final fallback = SoopDanmakuCodec.decode(_frame([_subscriptionPacket(ceremony: true, fallback: '2')])).single;
      expect(fallback.text, '观众丙 订阅了频道，已订阅 2 个月');
      // Without a sender or a name: nothing.
      expect(
        SoopDanmakuCodec.decode(
          _frame([
            _packet(91, ['', '', '', '', 'x']),
          ]),
        ),
        isEmpty,
      );
    });

    test('viewer lists, flags and other services are ignored', () {
      expect(
        SoopDanmakuCodec.decode(
          _frame([
            _packet(0, ['ping']),
            _packet(4, ['flag']),
            _packet(97, ['x']),
          ]),
        ),
        isEmpty,
      );
      expect(SoopDanmakuCodec.decode(Uint8List.fromList(const <int>[])), isEmpty);
    });
  });

  group('comment session', () {
    test('a session opens the chat, logs in, then joins and pings', () async {
      final chat = await _chat();
      expect(chat.connector.endpoints.single, _chatUrl(), reason: 'the TLS port goes first');
      expect(chat.socket.sentText, SoopDanmakuCodec.login, reason: 'the login goes out at once');
      chat.timers.fireAt(0);
      await _settle();
      expect(chat.socket.sentText, '${SoopDanmakuCodec.login}\n${SoopDanmakuCodec.join('12345678')}');
      chat.timers.ringLatest();
      expect(chat.socket.sentText, endsWith(SoopDanmakuCodec.heartbeat), reason: 'the keep-alive');
      expect(chat.timers.every.single.period, SoopDanmakuCodec.heartbeatInterval);
      expect(
        chat.timers.after.map((wait) => wait.delay),
        contains(SoopDanmakuCodec.silenceTimeout),
        reason: 'the silence watchdog',
      );
      await chat.session.dispose();
    });

    test('a chat frame comes out as messages', () async {
      final chat = await _chat();
      final seen = <LiveMessage>[];
      final subscription = chat.session.events.listen(seen.add);
      chat.socket.push(_frame([_chatPacket(), _balloonPacket(18, senderAt: 2, nameAt: 3, countAt: 4)]));
      await _settle();
      expect(seen, hasLength(2));
      // A text frame carries nothing this protocol reads.
      chat.socket.push('not for us');
      await _settle();
      expect(seen, hasLength(2));
      await subscription.cancel();
      await chat.session.dispose();
    });

    test('the plain port answers where the TLS port refuses', () async {
      final connector = _Connector(acceptScheme: 'ws');
      final timers = FakeTimers();
      final session = SoopDanmakuSession(
        args: _args(),
        site: _site(connector: connector),
        timers: timers.timers,
        joinDelay: Duration.zero,
      );
      expect(await session.connect(), isNull);
      await _settle();
      timers.fireLatest();
      await _settle();
      expect(connector.endpoints, [_chatUrl(), _chatPlainUrl()]);
      expect(connector.latest.sentText, SoopDanmakuCodec.login);
      await session.dispose();
    });

    test('a socket that closes or goes silent is replaced', () async {
      final chat = await _chat();
      final first = chat.socket;
      // The socket closes: replaced after the backoff's step.
      await first.ended();
      await _settle();
      chat.timers.fireLatest();
      await _settle();
      expect(chat.connector.sockets, hasLength(2));
      expect(first.closed, isTrue);
      expect(identical(chat.connector.latest, first), isFalse);
      // Silence: the watchdog fires, the retry runs, the socket is replaced.
      // A frame re-arms the watchdog in between.
      chat.connector.latest.push(_frame([_chatPacket()]));
      await _settle();
      expect(chat.timers.after.length, greaterThan(2), reason: 'the watchdog re-armed on the frame');
      chat.timers.fireLatest();
      await _settle();
      chat.timers.fireLatest();
      await _settle();
      expect(chat.connector.sockets, hasLength(3));
      await chat.session.dispose();
    });

    test('the failure after the budget ends the session with a notice', () async {
      final connector = _Connector(failures: 100);
      final timers = FakeTimers();
      final session = SoopDanmakuSession(
        args: _args(),
        site: _site(connector: connector),
        timers: timers.timers,
      );
      final seen = <LiveMessage>[];
      final done = session.events.listen(seen.add).asFuture<void>();
      expect(await session.connect(), isNull);
      // Nine handshakes in all fail: eight retries, then the end. The
      // endpoints alternate TLS and plain.
      for (var attempt = 0; attempt < SoopDanmakuCodec.maxReconnects + 1; attempt++) {
        await _settle();
        if (attempt < SoopDanmakuCodec.maxReconnects) {
          expect(connector.endpoints, hasLength(attempt + 1));
          timers.fireLatest();
        }
      }
      await _settle();
      await done;
      expect(connector.endpoints, hasLength(SoopDanmakuCodec.maxReconnects + 1));
      expect(connector.endpoints[0].scheme, 'wss');
      expect(connector.endpoints[1].scheme, 'ws');
      expect(connector.endpoints[2].scheme, 'wss');
      expect(seen.where((message) => message.type == LiveMessageType.system), hasLength(1));
      await session.dispose();
    });

    test('an open socket clears the failure count', () async {
      final connector = _Connector(failures: 2);
      final timers = FakeTimers();
      final session = SoopDanmakuSession(
        args: _args(),
        site: _site(connector: connector),
        timers: timers.timers,
      );
      expect(await session.connect(), isNull);
      // Two failed handshakes (TLS, then plain), then a working one.
      await _settle();
      timers.fireLatest();
      await _settle();
      timers.fireLatest();
      await _settle();
      expect(connector.sockets, hasLength(1));
      // A later silence starts the budget from zero again: one watchdog fire
      // and one retry bring the next socket, not the end of the session.
      timers.fireLatest();
      await _settle();
      timers.fireLatest();
      await _settle();
      expect(connector.sockets, hasLength(2));
      await session.dispose();
    });

    test('args without a chat server are refused before any socket', () async {
      final connector = _Connector();
      final session = SoopDanmakuSession(
        args: SoopDanmakuArgs(url: Uri(), plainUrl: Uri(), chatNo: '', headers: const {}),
        site: _site(connector: connector),
        timers: FakeTimers().timers,
      );
      expect(await session.connect(), isA<LiveSiteContentUnavailable>());
      expect(connector.sockets, isEmpty);
      // A disposed session refuses too.
      await session.dispose();
      expect(await session.connect(), isA<LiveSiteUnsupported>());
    });

    test('disconnect stops delivery, dispose closes the stream', () async {
      final chat = await _chat();
      final seen = <LiveMessage>[];
      final subscription = chat.session.events.listen(seen.add);
      await chat.session.disconnect();
      chat.socket.push(_frame([_chatPacket()]));
      await _settle();
      expect(seen, isEmpty);
      await subscription.cancel();
      await chat.session.dispose();
      expect(await chat.session.events.isEmpty, isTrue);
    });
  });

  group('chat provider', () {
    test('a live room with chat data builds a session from its handle', () async {
      final connector = _Connector();
      final site = _site(connector: connector);
      final session = _right(await site.capability<LiveDanmakuProvider>()!.createSession(roomId: _id));
      expect(session, isA<SoopDanmakuSession>());
      await _settle();
      expect(connector.sockets, hasLength(1));
      expect(connector.endpoints.single, _chatUrl());
      await session.dispose();
    });

    test('a room without chat data is content-unavailable', () async {
      final site = SoopSite(
        http: SoopHttp(_FakeHttp((_) => _playerLive(result: 0, withChat: false))),
        connect: _refuseSocket,
        now: () => DateTime.parse('2026-09-30T14:00:00.000Z'),
      );
      expect(
        _leftOf(await site.capability<LiveDanmakuProvider>()!.createSession(roomId: _id)),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test('a room entry failure maps onto the error', () async {
      final site = SoopSite(
        http: SoopHttp(_FakeHttp((_) => _ok('not json'))),
        connect: _refuseSocket,
        now: () => DateTime.parse('2026-09-30T14:00:00.000Z'),
      );
      expect(
        _leftOf(await site.capability<LiveDanmakuProvider>()!.createSession(roomId: _id)),
        isA<LiveSiteParseError>(),
      );
    });
  });
}
