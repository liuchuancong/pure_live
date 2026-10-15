import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:es_compression/brotli.dart';
import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/missevan/api/missevan_endpoints.dart';
import 'package:live_sites/src/platforms/missevan/api/missevan_http.dart';
import 'package:live_sites/src/platforms/missevan/danmaku/missevan_danmaku_codec.dart';
import 'package:live_sites/src/platforms/missevan/danmaku/missevan_danmaku_session.dart';
import 'package:live_sites/src/platforms/missevan/missevan_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

/// The room the fixtures describe.
const String _roomId = '12345';

/// A time the fixtures date their messages with.
final DateTime _at = DateTime.fromMillisecondsSinceEpoch(1791900000000);

/// The chat socket the room entry hands over.
Uri _socketUrl([String roomId = _roomId]) =>
    Uri(scheme: 'wss', host: 'im.missevan.com', path: '/ws', queryParameters: {'room_id': roomId});

final BrotliCodec _brotli = BrotliCodec();
final Random _random = Random(7);

String _json(Object? data) => jsonEncode(data);

MissevanDanmakuFrame _frameOf(Object? data, {String uuid = 'u-1'}) =>
    MissevanDanmakuCodec.decode(data, roomId: _roomId, uuid: uuid, receivedAt: _at);

/// A real binary frame: flag 1, the UTF-8 length in three little-endian
/// bytes, then the text Brotli-compressed.
Uint8List _brotliFrame(String text) {
  final bytes = utf8.encode(text);
  final compressed = _brotli.encode(bytes);
  return Uint8List.fromList([
    MissevanDanmakuCodec.brotliFlag,
    bytes.length & 0xff,
    (bytes.length >> 8) & 0xff,
    (bytes.length >> 16) & 0xff,
    ...compressed,
  ]);
}

Map<String, Object?> _chatItem({String room = _roomId, Object text = ' 大家好 '}) => {
  'type': 'message',
  'event': 'new',
  if (room.isNotEmpty) 'room_id': room,
  'msg_id': 'm-1',
  'time': 1791900000000,
  'message': text,
  'user': {
    'username': '观众乙',
    'user_id': 777,
    'titles': [
      {'type': 'level', 'level': 8},
      {'type': 'medal', 'name': '猫耳粉丝团', 'level': 6},
    ],
  },
};

Map<String, Object?> _giftItem({Object? oid = '900001', Object? combo, Object? lucky}) => {
  'type': 'gift',
  'event': 'send',
  'room_id': _roomId,
  'gift': {'gift_id': 1024, 'name': ' 幻彩礼炮 ', 'num': 2, 'price': 100, 'icon_url': 'https://i0.hdslb.com/bfs/gift.png'},
  'user': {'user_id': 777, 'username': '观众乙'},
  'time': 1791900000000,
  'oid': oid,
  'combo': ?combo,
  'lucky': ?lucky,
};

LiveResponse _resp(int status, String body, {List<String> setCookies = const []}) => LiveResponse(
  statusCode: status,
  headers: const {},
  setCookies: setCookies,
  bodyBytes: Uint8List.fromList(utf8.encode(body)),
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

/// The answers of the site: the guest session and one offline room entry.
LiveResponse _api(_Seen request) {
  if (request.url.path == '/api/user/info') {
    return _resp(200, '', setCookies: ['FM_SESS=guest123; Path=/; Max-Age=259200', 'FM_SESS.sig=abc; Path=/']);
  }
  if (request.url.path == '/api/v2/live/$_roomId') {
    return _resp(
      200,
      _json({
        'code': 0,
        'info': {
          'room': {
            'room_id': _roomId,
            'creator_id': '888',
            'creator_username': '主播甲',
            'name': '深夜电台',
            'status': {'open': 0, 'open_time': 0},
            'statistics': {'score': 10, 'online': 0},
          },
        },
      }),
    );
  }
  return _resp(404, 'nope');
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

  /// The text frames sent, for a search through them.
  String get sentText => sentList.whereType<String>().join('\n');

  /// The `uuid` of the join this socket sent.
  String get joinUuid {
    final join = sentList.whereType<String>().firstWhere((text) => text.contains('"action":"join"'));
    return (jsonDecode(join) as Map<String, Object?>)['uuid']! as String;
  }
}

final class _Connector {
  final List<_FakeSocket> sockets = [];
  final List<Uri> endpoints = [];
  final List<Map<String, String>> headers = [];

  _FakeSocket get latest => sockets.last;

  Future<SocketChannel> call(
    Uri endpoint, {
    required Map<String, String> headers,
    required Iterable<String>? protocols,
    required Duration connectTimeout,
    Duration? pingInterval,
  }) async {
    endpoints.add(endpoint);
    this.headers.add(headers);
    final socket = _FakeSocket();
    sockets.add(socket);
    return socket;
  }
}

/// A timer that never goes off: the watches are kept by [_FakeTimers] instead.
final class _IdleTimer implements Timer {
  @override
  bool get isActive => false;

  @override
  int get tick => 0;

  @override
  void cancel() {}
}

final class _FakeTimers {
  final List<({Duration delay, void Function() callback})> after = [];
  final List<({Duration period, void Function(Timer timer) callback})> every = [];

  MissevanTimers get timers => (after: _after, every: _every);

  Timer _after(Duration delay, void Function() callback) {
    after.add((delay: delay, callback: callback));
    return _IdleTimer();
  }

  Timer _every(Duration period, void Function(Timer timer) callback) {
    every.add((period: period, callback: callback));
    return _IdleTimer();
  }

  void fire({int index = 0}) => after[index].callback();

  void ring({int index = 0}) => every[index].callback(_IdleTimer());
}

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

Future<List<LiveMessage>> _next(Stream<LiveMessage> events, int count) {
  final seen = <LiveMessage>[];
  final done = Completer<void>();
  late StreamSubscription<LiveMessage> subscription;
  subscription = events.listen((message) {
    seen.add(message);
    if (seen.length == count && !done.isCompleted) {
      done.complete();
      unawaited(subscription.cancel());
    }
  });
  return done.future.then((_) => seen);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

Future<({MissevanDanmakuSession session, _FakeSocket socket, _FakeTimers timers, _Connector connector, _FakeHttp http})>
_chat({LiveResponse Function(_Seen request)? onApi, Duration sessionRetryDelay = Duration.zero}) async {
  final connector = _Connector();
  final timers = _FakeTimers();
  final http = _FakeHttp(onApi ?? _api);
  final session = MissevanDanmakuSession(
    args: MissevanDanmakuArgs(roomId: _roomId, url: _socketUrl()),
    site: MissevanSite(http: MissevanHttp(http), connect: connector.call),
    timers: timers.timers,
    sessionRetryDelay: sessionRetryDelay,
  );
  expect(await session.connect(), isNull);
  await _settle();
  await _settle();
  return (session: session, socket: connector.latest, timers: timers, connector: connector, http: http);
}

LiveMessage? _single(Map<String, Object?> item) => _frameOf(_json(item)).messages.firstOrNull;

void main() {
  group('chat protocol', () {
    test('the socket address follows the entry, or is the site form', () {
      expect(MissevanDanmakuCodec.endpoint(_socketUrl(), roomId: _roomId), _socketUrl());
      expect(
        MissevanDanmakuCodec.endpoint(Uri.parse('wss://im.missevan.com/ws'), roomId: _roomId),
        _socketUrl(),
        reason: 'a url without room_id gets it',
      );
      final foreign = Uri.parse('wss://ws.missevan.com/im?room_id=999');
      expect(MissevanDanmakuCodec.endpoint(foreign, roomId: _roomId), _socketUrl(), reason: 'another room is replaced');
      for (final bad in [
        Uri.parse('ws://im.missevan.com/ws?room_id=$_roomId'),
        Uri.parse('wss://evil.com/ws?room_id=$_roomId'),
        Uri.parse('wss://u@im.missevan.com/ws?room_id=$_roomId'),
      ]) {
        expect(MissevanDanmakuCodec.endpoint(bad, roomId: _roomId), _socketUrl(), reason: '$bad');
      }
    });

    test('the guest session and the handshake headers carry the cookie', () {
      expect(MissevanDanmakuCodec.session(['FM_SESS=abc123; Path=/', 'FM_SESS.sig=zzz; Path=/']), 'abc123');
      expect(MissevanDanmakuCodec.session(['FM_SESS=a b; Path=/']), isNull, reason: 'not cookie octets');
      expect(MissevanDanmakuCodec.session(['other=1']), isNull);
      final headers = MissevanDanmakuCodec.handshakeHeaders({'referer': 'x', 'cookie': 'old'}, 'abc');
      expect(headers, {'referer': 'x', 'cookie': 'FM_SESS=abc'});
    });

    test('the join names the room as a number and the rejoins reconnect', () {
      expect(
        MissevanDanmakuCodec.join(_roomId, uuid: 'u'),
        '{"action":"join","uuid":"u","type":"room","room_id":$_roomId}',
      );
      expect(
        MissevanDanmakuCodec.join(_roomId, uuid: 'u', reconnect: true),
        '{"action":"join","uuid":"u","type":"room","room_id":$_roomId,"reconnect":1}',
      );
    });

    test('a version 4 uuid comes out', () {
      final pattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(pattern.hasMatch(MissevanDanmakuCodec.uuid(_random)), isTrue);
      expect(MissevanDanmakuCodec.uuid(_random), isNot(MissevanDanmakuCodec.uuid(_random)));
    });

    test('a text frame passes, a binary one is brotli-decoded against its length', () {
      const hello = '{"a":1}';
      expect(MissevanDanmakuCodec.text(hello), hello);
      expect(MissevanDanmakuCodec.text(_brotliFrame(hello)), hello);
      // Another flag, a short frame, a broken stream, a wrong declared length.
      expect(MissevanDanmakuCodec.text([2, 5, 0, 0, 1, 2, 3, 4, 5]), isNull);
      expect(MissevanDanmakuCodec.text([1, 0, 0]), isNull);
      expect(MissevanDanmakuCodec.text([1, 9, 0, 0, 1, 2, 3]), isNull);
      final compressed = _brotli.encode(utf8.encode(hello));
      expect(MissevanDanmakuCodec.text([1, 3, 0, 0, ...compressed]), isNull, reason: '6 bytes, not 3');
      expect(MissevanDanmakuCodec.text(1), isNull);
    });

    test('the join answer is known by its uuid', () {
      expect(_frameOf(_json({'type': 'room', 'event': 'join', 'uuid': 'u-1', 'code': 0})).joined, isTrue);
      final refused = _frameOf(_json({'type': 'room', 'event': 'join', 'uuid': 'u-1', 'code': 1, 'info': 'full'}));
      expect(refused.joined, isFalse);
      expect(refused.refusal, '1 full');
      final unknownRoom = _frameOf(
        _json({'type': 'room', 'event': 'join', 'uuid': 'u-1', 'code': 500030004, 'info': '无法找到该聊天室'}),
      );
      expect(unknownRoom.joined, isFalse);
      expect(unknownRoom.refusal, '500030004 无法找到该聊天室');
      expect(_frameOf(_json({'type': 'room', 'event': 'join', 'uuid': 'other', 'code': 0})).joined, isNull);
    });

    test('the heartbeat echo, other rooms and noise are left out', () {
      expect(_frameOf(MissevanDanmakuCodec.heartbeat), MissevanDanmakuFrame.empty);
      expect(_frameOf('not json'), MissevanDanmakuFrame.empty);
      expect(_frameOf(null), MissevanDanmakuFrame.empty);
      expect(_frameOf(_json({..._chatItem(room: '999')})).messages, isEmpty);
      expect(_frameOf(_json([42, 'x'])).messages, isEmpty);
      expect(_frameOf(_json(_chatItem(room: ''))).messages, hasLength(1), reason: 'an unnamed room is this one');
    });

    test('a chat line carries the sender, level, medal and time', () {
      final message = _single(_chatItem())!;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, '大家好');
      final sender = message.effectiveSender;
      expect(sender.userName, '观众乙');
      expect(sender.userId, '777');
      expect(sender.userLevel, '8');
      expect(sender.fanBadgeName, '猫耳粉丝团');
      expect(sender.fanBadgeLevel, '6');
      expect(message.messageId, 'm-1');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1791900000000));
      // A paid danmaku is a chat line too.
      expect(_single(_chatItem()..['event'] = 'danmaku'), isNotNull);
      expect(_single(_chatItem(text: '   ')), isNull);
      expect(_single(_chatItem(text: 42)), isNotNull, reason: 'a numeric message is text');
    });

    test('the statistics carry heat and listeners now', () {
      final messages = _frameOf(
        _json({
          'type': 'room',
          'event': 'statistics',
          'statistics': {'score': 4321, 'online': 12},
        }),
      ).messages;
      expect(messages, hasLength(2));
      expect(
        messages[0].payload,
        isA<LiveAudienceUpdate>()
            .having((update) => update.kind, 'kind', LiveAudienceSignalKind.popularity)
            .having((update) => update.value, 'value', 4321),
      );
      expect(
        messages[1].payload,
        isA<LiveAudienceUpdate>()
            .having((update) => update.kind, 'kind', LiveAudienceSignalKind.onlineViewers)
            .having((update) => update.value, 'value', 12),
      );
      expect(_single({'type': 'room', 'event': 'statistics', 'statistics': 'nope'}), isNull);
    });

    test('a paid question is a super chat', () {
      final shown = _single({
        'type': 'question',
        'event': 'ask',
        'user': {'user_id': 999, 'username': '观众丙'},
        'question': {
          'question_id': 'q-1',
          'question': '唱一首晴天',
          'price': 50,
          'created_time': 1791900000000,
          'iconurl': '//i0.hdslb.com/bfs/q.png',
        },
      })!;
      expect(shown.type, LiveMessageType.superChat);
      expect(shown.text, '唱一首晴天');
      expect(shown.effectiveSender.userName, '观众丙');
      expect(shown.effectiveSender.userId, '999');
      final superChat = shown.payload! as LiveSuperChatMessage;
      expect(superChat.price.amount, 50);
      expect(superChat.price.currency, '钻');
      expect(superChat.price.displayText, '50 钻');
      expect(superChat.startTime, _at);
      expect(superChat.endTime, _at.add(MissevanDanmakuCodec.questionDuration));
      expect(superChat.faceUrl, 'https://i0.hdslb.com/bfs/q.png');
      // Without a time the question starts when it arrived.
      final fresh = MissevanDanmakuCodec.decode(
        _json({
          'type': 'question',
          'event': 'ask',
          'user': {'user_id': 999, 'username': '观众丙'},
          'question': {'question_id': 'q-1', 'question': '唱一首晴天', 'price': 50},
        }),
        roomId: _roomId,
        uuid: 'u-1',
        receivedAt: _at,
      ).messages.single;
      expect((fresh.payload! as LiveSuperChatMessage).startTime, _at);
      expect(
        _single({
          'type': 'question',
          'event': 'ask',
          'question': {'question': '', 'price': 5},
        }),
        isNull,
      );
      expect(
        _single({
          'type': 'question',
          'event': 'ask',
          'question': {'question': 'x', 'price': -1},
        }),
        isNull,
      );
      expect(_single({'type': 'question', 'event': 'ask'}), isNull);
    });

    test('a message clear retracts all or the named lines', () {
      final all = _frameOf(_json({'type': 'admin', 'event': 'message_clear', 'opt': 1})).messages.single;
      expect((all.payload! as LiveRetraction).all, isTrue);
      final some = _frameOf(
        _json({
          'type': 'admin',
          'event': 'message_clear',
          'opt': 2,
          'msg_ids': ['a', 'a', 'b'],
        }),
      ).messages;
      expect(some.map((message) => (message.payload! as LiveRetraction).messageId), ['a', 'b']);
      expect(_single({'type': 'admin', 'event': 'message_clear', 'opt': 9}), isNull);
      expect(_single({'type': 'admin', 'event': 'message_clear', 'opt': 2, 'msg_ids': 'a'}), isNull);
    });

    test('a noble title bought or renewed is a notice in the site words', () {
      final bought = _single({
        'type': 'noble',
        'event': 'registration',
        'user': {'user_id': 555, 'username': '观众丁'},
        'noble': {'name': '神话'},
        'time': 1791900000000,
      })!;
      expect(bought.type, LiveMessageType.notice);
      expect(bought.text, '观众丁 开通了神话贵族');
      expect(bought.payload, LiveNoticeKind.system);
      final renewed = _single({
        'type': 'noble',
        'event': 'renewal',
        'user': {'username': '观众丁'},
        'noble': {'name': '神话'},
      });
      expect(renewed!.text, '观众丁 续费了神话贵族');
      final cross = _single({
        'type': 'noble',
        'event': 'cross_registration',
        'user': {'username': '观众丁'},
        'room': {'creator_username': '主播甲'},
        'noble': {'name': '神话'},
      });
      expect(cross!.text, '观众丁 开通了主播甲的神话贵族');
      expect(
        _single({
          'type': 'noble',
          'event': 'expiry',
          'noble': {'name': '神话'},
        }),
        isNull,
      );
      expect(_single({'type': 'noble', 'event': 'registration', 'noble': {}}), isNull);
    });

    test('a pk is narrated as the site narrates it', () {
      expect(_single({'type': 'pk', 'event': 'match_start'})!.text, '主播正在匹配 PK 对手，请耐心等候');
      expect(
        _single({
          'type': 'pk',
          'event': 'finish',
          'pk': {'result': 1},
        })!.text,
        '恭喜主播获得 PK 胜利，继续支持主播吧',
      );
      expect(
        _single({
          'type': 'pk',
          'event': 'close',
          'pk': {'result': 2},
        })!.text,
        '主播 PK 平局，再接再厉哦',
      );
      expect(
        _single({
          'type': 'pk',
          'event': 'invite_timeout',
          'pk': {'from_room_id': _roomId},
        })!.text,
        '对方未接受邀请',
        reason: 'this room invited, and was refused',
      );
      expect(
        _single({
          'type': 'pk',
          'event': 'invite_timeout',
          'pk': {'from_room_id': '999'},
        }),
        isNull,
        reason: 'an invitation refused elsewhere is told there',
      );
      // The 花神赐福 progress precedes the pk line.
      final raid = _frameOf(
        _json({
          'type': 'pk',
          'event': 'match_success',
          'raid': {
            'progress': {'message_tip': '花神赐福进度 <font color="#bdbdbd"><a>详情</a></font>30%'},
          },
        }),
      ).messages;
      expect(raid.map((message) => message.text), ['花神赐福进度 30%', 'PK 已开始，快送礼支持主播吧']);
    });

    test('a global pk prefers its own tip, else the site line', () {
      expect(_single({'type': 'global_pk', 'event': 'match_ready', 'pk': {}})!.text, '幻影 PK 即将开启，准备迎战！');
      expect(
        _single({
          'type': 'global_pk',
          'event': 'update',
          'pk': {'message_tip': '<b>战况</b>'},
        })!.text,
        '战况',
      );
      expect(_single({'type': 'global_pk', 'event': 'update', 'pk': {}}), isNull);
      expect(
        _single({
          'type': 'global_pk',
          'event': 'finish',
          'pk': {'result': 0},
        })!.text,
        '本场幻影 PK 遗憾落败',
      );
      expect(
        _single({
          'type': 'global_pk',
          'event': 'finish',
          'pk': {'result': 1, 'message_tip': '辛苦了'},
        })!.text,
        '辛苦了',
      );
      expect(_single({'type': 'global_pk', 'event': 'surprise', 'pk': {}}), isNull);
    });

    test('a team pk tells its tip, the entities decoded', () {
      expect(
        _single({
          'type': 'team_pk',
          'event': 'x',
          'pk': {'message_tip': 'A&nbsp;B&nbsp;&amp;&nbsp;C'},
        })!.text,
        'A B & C',
      );
      expect(_single({'type': 'team_pk', 'event': 'x', 'pk': {}}), isNull);
    });

    test('a message tip loses its tags, links and double spaces', () {
      expect(
        MissevanDanmakuCodec.plainText(
          '结算 <font color=\'#bdbdbd\'><a>结算详情</a></font><br/> <img src="x"/>  A&lt;B&gt;&amp;C ',
        ),
        '结算 A<B>&C',
      );
      expect(MissevanDanmakuCodec.plainText(7), '');
    });

    test('a gift is priced in diamonds, a combo counted', () {
      final hit = _single(_giftItem(combo: {'id': '900001', 'num': 3}))!;
      expect(hit.type, LiveMessageType.gift);
      expect(hit.text, '幻彩礼炮 ×2');
      expect(hit.effectiveSender.userName, '观众乙');
      expect(hit.messageId, '900001');
      final gift = hit.payload! as LiveGift;
      expect(gift.giftId, '1024');
      expect(gift.name, '幻彩礼炮');
      expect(gift.iconUrl, 'https://i0.hdslb.com/bfs/gift.png');
      expect(gift.count, 2);
      expect(gift.value.unit, LiveGiftUnit.gold);
      expect(gift.value.unitPrice, 100);
      expect(gift.value.totalValue, 200);
      expect(gift.combo.comboKey, '900001');
      expect(gift.combo.comboTotal, 3);
      // The later sends of a combo carry a zero order: no message id.
      final later = _single(_giftItem(oid: '000000', combo: {'id': '000000', 'num': 4}))!;
      expect(later.messageId, '');
      expect((later.payload! as LiveGift).combo.comboKey, '');
      // A free gift costs nothing.
      final free = _single(_giftItem()..['gift'] = {'gift_id': 7, 'name': '喵', 'num': 1, 'price': 0})!;
      expect((free.payload! as LiveGift).value.unit, LiveGiftUnit.free);
      expect((free.payload! as LiveGift).value.unitPrice, isNull);
      // The lucky gift a draw came from has no v2 field and is left out.
      final lucky = _single(_giftItem(lucky: {'gift_id': 8, 'name': '幸运盒', 'num': 1, 'price': 10}))!;
      expect(lucky.text, '幻彩礼炮 ×2');
      expect(_single(_giftItem()..['gift'] = {'gift_id': 7, 'name': '', 'num': 1, 'price': 1}), isNull);
    });

    test('an array frame reads each item in order', () {
      final messages = _frameOf(
        _json([
          _chatItem(),
          {
            'type': 'gift',
            'event': 'send',
            'gift': {'name': '喵'},
          },
        ]),
      ).messages;
      expect(messages.map((message) => message.type), [LiveMessageType.chat, LiveMessageType.gift]);
    });
  });

  group('chat session', () {
    test('a session asks the guest session and joins with its cookie', () async {
      final chat = await _chat();
      expect(chat.http.sent.single.url, MissevanEndpoints.guestSession);
      expect(chat.connector.endpoints.single, _socketUrl());
      expect(chat.connector.headers.single['cookie'], 'FM_SESS=guest123');
      expect(chat.connector.headers.single['origin'], MissevanEndpoints.origin);
      final join = jsonDecode(chat.socket.sentText) as Map<String, Object?>;
      expect(join['room_id'], 12345, reason: 'the room goes out as a number');
      expect(join['uuid'], chat.socket.joinUuid);
      chat.timers.ring(index: chat.timers.every.length - 1);
      expect(chat.socket.sentText, endsWith(MissevanDanmakuCodec.heartbeat));
      expect(chat.timers.every.single.period, MissevanDanmakuCodec.heartbeatInterval);
      expect(
        chat.timers.after.map((wait) => wait.delay),
        containsAll([MissevanDanmakuCodec.joinTimeout, MissevanDanmakuCodec.silenceTimeout]),
      );
      await chat.session.dispose();
      expect(chat.socket.closed, isTrue);
    });

    test('the guest session is asked again before it gives up', () async {
      var calls = 0;
      final chat = await _chat(
        onApi: (request) {
          if (request.url.path != '/api/user/info') return _resp(404, 'nope');
          calls += 1;
          return calls >= 3 ? _resp(200, '', setCookies: ['FM_SESS=late123; Path=/']) : _resp(200, '');
        },
      );
      expect(calls, 3, reason: 'two answers without a cookie, the third sets one');
      expect(chat.connector.headers.single['cookie'], 'FM_SESS=late123');
      await chat.session.dispose();
    });

    test('the join is confirmed and chat flows through a brotli frame', () async {
      final chat = await _chat();
      final after = _next(chat.session.events, 1);
      chat.socket.push(_json({'type': 'room', 'event': 'join', 'uuid': chat.socket.joinUuid, 'code': 0}));
      chat.socket.push(_brotliFrame(_json(_chatItem())));
      expect((await after).single.text, '大家好');
      await chat.session.dispose();
    });

    test('a refused join asks a fresh session and socket; the next refusal ends it', () async {
      final chat = await _chat();
      String refusalOf(_FakeSocket socket) =>
          _json({'type': 'room', 'event': 'join', 'uuid': socket.joinUuid, 'code': 1, 'info': 'full'});
      final seen = <LiveMessage>[];
      final done = chat.session.events.listen(seen.add).asFuture<void>();
      for (var attempt = 0; attempt < MissevanDanmakuCodec.maxRejoins; attempt++) {
        chat.connector.latest.push(refusalOf(chat.connector.latest));
        await _settle();
        chat.timers.fire(index: chat.timers.after.length - 1);
        await _settle();
        await _settle();
      }
      expect(chat.connector.sockets, hasLength(MissevanDanmakuCodec.maxRejoins + 1), reason: 'three replacements');
      expect(
        chat.http.sent.where((seen_) => seen_.url.path == '/api/user/info'),
        hasLength(MissevanDanmakuCodec.maxRejoins + 1),
        reason: 'a fresh guest session for every refusal',
      );
      chat.connector.latest.push(refusalOf(chat.connector.latest));
      await done;
      expect(seen.where((message) => message.type == LiveMessageType.system), isNotEmpty);
      await chat.session.dispose();
    });

    test('a socket that never joins, closes or goes silent is replaced', () async {
      final chat = await _chat();
      final first = chat.socket;
      // No join in time: the socket is replaced.
      final joinWatch = chat.timers.after.indexWhere((wait) => wait.delay == MissevanDanmakuCodec.joinTimeout);
      chat.timers.fire(index: joinWatch);
      await _settle();
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      await _settle();
      expect(chat.connector.sockets, hasLength(2));
      expect(identical(chat.connector.latest, first), isFalse);
      expect(first.closed, isTrue);
      // The join is confirmed, then the server closes: replaced, reconnecting.
      final second = chat.connector.latest;
      second.push(_json({'type': 'room', 'event': 'join', 'uuid': second.joinUuid, 'code': 0}));
      await second.ended();
      await _settle();
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      await _settle();
      expect(chat.connector.sockets, hasLength(3));
      expect(
        (jsonDecode(chat.connector.latest.sentText) as Map<String, Object?>)['reconnect'],
        1,
        reason: 'the room was joined before in this session',
      );
      // Silence: replaced again.
      chat.connector.latest.push(
        _json({'type': 'room', 'event': 'join', 'uuid': chat.connector.latest.joinUuid, 'code': 0}),
      );
      await _settle();
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      await _settle();
      expect(chat.connector.sockets, hasLength(4));
      await chat.session.dispose();
    });

    test('without a guest session the attempts are spent, then the session ends', () async {
      final connector = _Connector();
      final timers = _FakeTimers();
      final http = _FakeHttp((request) => request.url.path == '/api/user/info' ? _resp(200, '') : _resp(404, 'nope'));
      final session = MissevanDanmakuSession(
        args: MissevanDanmakuArgs(roomId: _roomId, url: _socketUrl()),
        site: MissevanSite(http: MissevanHttp(http), connect: connector.call),
        timers: timers.timers,
        sessionRetryDelay: Duration.zero,
      );
      expect(await session.connect(), isNull);
      for (var settle = 0; settle < 4; settle++) {
        await _settle();
      }
      expect(connector.sockets, isEmpty, reason: 'no socket without a cookie');
      expect(
        http.sent.where((seen_) => seen_.url.path == '/api/user/info'),
        hasLength(MissevanDanmakuCodec.sessionAttempts),
        reason: 'the first handshake asks three times',
      );
      final seen = <LiveMessage>[];
      final done = session.events.listen(seen.add).asFuture<void>();
      for (var round = 0; round < MissevanDanmakuCodec.maxReconnects; round++) {
        timers.fire(index: timers.after.length - 1);
        for (var settle = 0; settle < 4; settle++) {
          await _settle();
        }
      }
      await done;
      expect(seen.where((message) => message.type == LiveMessageType.system), isNotEmpty);
      expect(
        http.sent.where((seen_) => seen_.url.path == '/api/user/info'),
        hasLength(MissevanDanmakuCodec.sessionAttempts * (MissevanDanmakuCodec.maxReconnects + 1)),
      );
      await session.dispose();
    });

    test('an id that is no room is refused before any request', () async {
      final connector = _Connector();
      final http = _FakeHttp(_api);
      final session = MissevanDanmakuSession(
        args: MissevanDanmakuArgs(roomId: 'x', url: _socketUrl()),
        site: MissevanSite(http: MissevanHttp(http), connect: connector.call),
        timers: _FakeTimers().timers,
      );
      expect(await session.connect(), isA<LiveSiteNotFound>());
      expect(connector.sockets, isEmpty);
      expect(http.sent, isEmpty);
      await session.dispose();
    });

    test('the provider builds a session from the entered room, gone rooms are refused', () async {
      final connector = _Connector();
      final http = _FakeHttp(_api);
      final site = MissevanSite(http: MissevanHttp(http), connect: connector.call);
      final session = _right(await MissevanDanmakuProvider(site: site).createSession(roomId: _roomId));
      expect(session, isA<MissevanDanmakuSession>());
      expect(http.sent.first.url.path, '/api/v2/live/$_roomId');
      for (var settle = 0; settle < 4; settle++) {
        await _settle();
      }
      expect(connector.sockets, hasLength(1));
      await session.dispose();
      final gone = _FakeHttp((request) => _resp(404, _json({'code': 500030004})));
      final other = MissevanSite(http: MissevanHttp(gone), connect: connector.call);
      expect(
        _leftOf(await MissevanDanmakuProvider(site: other).createSession(roomId: _roomId)),
        isA<LiveSiteNotFound>(),
      );
    });
  });
}
