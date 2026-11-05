import 'dart:convert';
import 'dart:io' show GZipCodec;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/kugoulive/api/kugoulive_endpoints.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_protobuf.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_failure.dart';
import 'package:test/test.dart';

const String _room = '555';

/// `SocketProtocol.Message`: 1 offset, 2 ack, 3 rpt, 4 msgId, 5 compression,
/// 6 codec (1 reads the content as protobuf), 7 content.
Uint8List _envelope(
  List<int> content, {
  String offset = 'o1',
  int ack = 0,
  int rpt = 0,
  String msgId = 'm1',
  int compression = 0,
  int codec = 1,
}) =>
    (KugouliveProtoWriter()
          ..string(1, offset)
          ..integer(2, ack)
          ..integer(3, rpt)
          ..string(4, msgId)
          ..integer(5, compression)
          ..integer(6, codec)
          ..bytes(7, content))
        .toBytes();

/// A server frame of [command]: the 18-byte header over [envelope].
Uint8List _frame(int command, Uint8List envelope, {int headerLength = 12, int? declaredLength}) {
  final header = ByteData(18)
    ..setUint8(0, 100)
    ..setInt16(1, 3)
    ..setUint8(3, 1)
    ..setInt16(4, headerLength)
    ..setInt32(6, command)
    ..setInt32(10, declaredLength ?? envelope.length);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...envelope]);
}

/// The decoded message of a JSON (codec 0) chat packet of room [room].
LiveMessage? _jsonChat(Object content, {String room = _room}) => KugouliveDanmakuCodec.decode(
  _frame(KugouliveDanmakuCodec.chatCommand, _envelope(utf8.encode(jsonEncode(content)), codec: 0)),
  roomId: room,
).messages.singleOrNull;

/// The decoded message of one protobuf chat.
LiveMessage? _protobufChat(
  Uint8List chat, {
  int room = 555,
  int receiverId = 0,
  int senderId = 1001,
  int time = 1790733600,
  List<int>? ext,
  List<int>? sinfo,
  List<int>? source,
  String msgId = 'env-1',
  int command = KugouliveDanmakuCodec.chatCommand,
}) => KugouliveDanmakuCodec.decode(
  _frame(
    command,
    _envelope(
      _chatMessage(
        chat: chat,
        room: room,
        receiverId: receiverId,
        senderId: senderId,
        time: time,
        ext: ext,
        sinfo: sinfo,
        source: source,
      ),
      msgId: msgId,
    ),
  ),
  roomId: _room,
).messages.singleOrNull;

/// A JSON (codec 0) chat packet.
Map<String, Object?> _chatPacket({
  Object? roomid = _room,
  Object? receiverid,
  Object? senderid = 1001,
  Object? time = 1790733600,
  Object? chatmsg = '你好',
  Object? sendername = 'Ann',
  Object? seq = 77,
  Object? privateType,
  Object? senderrichlevel,
  Object? senderrichlevelV2,
  Object? ext,
  Object? sinfo,
  Object? source,
}) => {
  'roomid': ?roomid,
  'receiverid': ?receiverid,
  'senderid': ?senderid,
  'time': ?time,
  'ext': ?ext,
  'sinfo': ?sinfo,
  'source': ?source,
  'content': {
    'chatmsg': ?chatmsg,
    'sendername': ?sendername,
    'seq': ?seq,
    'privateType': ?privateType,
    'senderrichlevel': ?senderrichlevel,
    'senderrichlevelV2': ?senderrichlevelV2,
  },
};

/// `Content.ContentMessage` of a chat: 2 the response, 3 room, 4 receiver, 6
/// sender, 11 time, 14 ext, 15 sinfo, 16 content codec, 18 source.
Uint8List _chatMessage({
  List<int> chat = const [],
  int room = 555,
  int receiverId = 0,
  int senderId = 1001,
  int time = 1790733600,
  List<int>? ext,
  List<int>? sinfo,
  List<int>? source,
}) {
  final writer = KugouliveProtoWriter()
    ..bytes(2, chat.isEmpty ? _chatResponse() : chat)
    ..integer(3, room)
    ..integer(4, receiverId)
    ..integer(6, senderId)
    ..integer(11, time)
    ..integer(16, 1);
  if (ext != null) writer.bytes(14, ext);
  if (sinfo != null) writer.bytes(15, sinfo);
  if (source != null) writer.bytes(18, source);
  return writer.toBytes();
}

/// `Chat.ChatResponse`: 1 text, 2 sender, 3 kugou id, 4 name, 5 level, 6
/// receiver, 8 receiver name, 13 seq, 25 wealth level.
Uint8List _chatResponse({
  String text = '你好',
  int senderId = 1001,
  String name = 'Ann',
  int level = 3,
  int richLevelV2 = 0,
  int seq = 77,
  int receiverId = 0,
}) =>
    (KugouliveProtoWriter()
          ..string(1, text)
          ..integer(2, senderId)
          ..integer(3, senderId)
          ..string(4, name)
          ..integer(5, level)
          ..integer(6, receiverId)
          ..string(8, '主播')
          ..integer(13, seq)
          ..integer(25, richLevelV2))
        .toBytes();

/// `ContentExt`: 8 guard, 9 little guard, 39 intimacy.
Uint8List _ext({
  int? intimacyLevel,
  String nameplate = '车神',
  int intimacyType = 1,
  int lightUp = 1,
  String? guard,
  int? littleGuard,
}) {
  final writer = KugouliveProtoWriter();
  if (guard != null) writer.bytes(8, (KugouliveProtoWriter()..string(1, guard)).toBytes());
  if (littleGuard != null) writer.bytes(9, (KugouliveProtoWriter()..integer(1, littleGuard)).toBytes());
  if (intimacyLevel != null) {
    writer.bytes(
      39,
      (KugouliveProtoWriter()
            ..integer(1, intimacyLevel)
            ..string(2, nameplate)
            ..integer(3, intimacyType)
            ..integer(5, lightUp))
          .toBytes(),
    );
  }
  return writer.toBytes();
}

/// `SInfo`: 5 `ck` (1 is a mystery guest), 8 `ckid`.
Uint8List _sinfo(int ck, {String ckid = 'alias-9'}) =>
    (KugouliveProtoWriter()
          ..integer(5, ck)
          ..string(8, ckid))
        .toBytes();

/// The PK partner `source`: 1 room, 2 tags.
Uint8List _source(int room, int tags) =>
    (KugouliveProtoWriter()
          ..integer(1, room)
          ..integer(2, tags))
        .toBytes();

/// `ErrorResponse` of a status (901) frame: 2 type, 4 status, 5 errorno, 6 msg,
/// 7 socsid.
Uint8List _status({int type = 1, int status = 1, int errorno = 0, String msg = '', String socsid = 'sid-1'}) =>
    (KugouliveProtoWriter()
          ..integer(2, type)
          ..integer(4, status)
          ..integer(5, errorno)
          ..string(6, msg)
          ..string(7, socsid))
        .toBytes();

/// A 601 gift packet as its JSON content names the fields.
Map<String, Object?> _giftPacket({
  Object? room = _room,
  Object? giftId = '77',
  String name = '玫瑰',
  int num = 2,
  int price = 10,
  String? comboV2 = 'c1',
  String? combo = '9',
  int comboSum = 4,
  String image = '/fxstatic/images/giftres/rose.png',
  String sender = 'Ann',
  String senderId = '1001',
}) => {
  'roomid': ?room,
  'content': {
    'roomid': room,
    'giftid': giftId,
    'giftname': name,
    'num': num,
    'price': price,
    'comboIdV2': ?comboV2,
    'comboId': ?combo,
    'comboGiftSum': comboSum,
    'image': image,
    'sendername': sender,
    'senderid': senderId,
    'receivername': '主播',
    'senderrichlevelV2': 12,
  },
};

/// A `HEAT_NUM` audience packet of [room].
Map<String, Object?> _audiencePacket({
  String actionId = 'roomAuNumber',
  Object? count,
  Object? visited,
  String room = _room,
}) => {
  'roomid': room,
  'content': {
    'actionId': actionId,
    'data': {'count': ?count, 'visited': ?visited},
  },
};

/// The scheduler answer of these hosts, protocol and token.
String _dispatch({
  String protocol = 'wss://',
  List<Object?> hosts = const [
    'a.chat.test',
    'a.chat.test',
    'b.chat.test',
    7,
    {'host': ''},
  ],
  Object? token = 'tok-en.9',
  Object? code = 0,
  Object? age,
  Object? msg,
}) => jsonEncode({
  'code': ?code,
  'msg': ?msg,
  'data': {
    if (protocol.isNotEmpty) 'protocol': protocol,
    'addrs': [
      for (final host in hosts)
        if (host is String) {'host': host} else host,
    ],
    'soctoken': ?token,
    'age': ?age,
  },
});

final class _Random implements math.Random {
  _Random(this.value);

  final int value;

  @override
  int nextInt(int max) => value;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

void main() {
  group('the scheduler address', () {
    test('a room number is trimmed into the request, anything else is no room', () {
      expect(KugouliveDanmakuCodec.checkedRoom(' 555 '), '555');
      expect(KugouliveDanmakuCodec.checkedRoom('100'), '100');
      expect(KugouliveDanmakuCodec.checkedRoom('0555'), isNull, reason: 'the page reads no leading zero');
      expect(KugouliveDanmakuCodec.checkedRoom('55'), isNull, reason: 'two digits is not a room');
      expect(KugouliveDanmakuCodec.checkedRoom('555a'), isNull);
      expect(KugouliveDanmakuCodec.checkedRoom(''), isNull);
    });

    test('the signature sorts the query, adds the salt, and takes sixteen hex characters', () {
      const query = {
        '_p': '0',
        '_v': '7.0.0',
        'at': '102',
        'cid': '100',
        'clienttime': '1790519893000',
        'pv': '20240801',
        'rid': '555',
      };
      expect(KugouliveDanmakuCodec.sign(query), '8a4d211c14613626');
      expect(
        KugouliveDanmakuCodec.sign({for (final entry in query.entries.toList().reversed) entry.key: entry.value}),
        KugouliveDanmakuCodec.sign(query),
        reason: 'the order sent is not the order signed',
      );
      expect(KugouliveDanmakuCodec.sign({...query, 'rid': '556'}), isNot(KugouliveDanmakuCodec.sign(query)));
      expect(KugouliveDanmakuCodec.sign(const {}), hasLength(16), reason: 'even the empty query is salted');
    });

    test('the dispatch URL is the page’s parameters in order with its sign', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1790519893000);
      final uri = KugouliveDanmakuCodec.dispatchUrl(_room, now: now);
      expect(uri.host, KugouliveEndpoints.apiHost);
      expect(uri.path, KugouliveDanmakuCodec.dispatchPath);
      expect(uri.queryParametersAll.keys, ['_p', '_v', 'pv', 'rid', 'clienttime', 'cid', 'at', 'sign']);
      expect(uri.queryParameters['_p'], '0');
      expect(uri.queryParameters['_v'], KugouliveDanmakuCodec.pageVersion);
      expect(uri.queryParameters['pv'], '${KugouliveDanmakuCodec.socketVersion}');
      expect(uri.queryParameters['at'], '${KugouliveDanmakuCodec.roomType}');
      expect(uri.queryParameters['cid'], '${KugouliveDanmakuCodec.clientId}');
      expect(uri.queryParameters['rid'], _room);
      expect(uri.queryParameters['clienttime'], '1790519893000');
      expect(
        uri.queryParameters['sign'],
        KugouliveDanmakuCodec.sign({
          ...?null,
          ...{
            '_p': '0',
            '_v': KugouliveDanmakuCodec.pageVersion,
            'pv': '${KugouliveDanmakuCodec.socketVersion}',
            'rid': _room,
            'clienttime': '1790519893000',
            'cid': '${KugouliveDanmakuCodec.clientId}',
            'at': '${KugouliveDanmakuCodec.roomType}',
          },
        }),
      );

      final headers = KugouliveDanmakuCodec.dispatchHeaders(_room);
      expect(headers['referer'], KugouliveEndpoints.roomUrl(_room));
      expect(headers['user-agent'], KugouliveEndpoints.userAgent);
      expect(KugouliveDanmakuCodec.socketHeaders['origin'], KugouliveEndpoints.webOrigin);
    });

    test('the grant reads its endpoints, its token and how long it lives', () {
      final grant = KugouliveDanmakuCodec.grant(_dispatch(age: 90000));
      expect(grant.endpoints.map((uri) => uri.toString()), [
        'wss://a.chat.test',
        'wss://b.chat.test',
      ], reason: 'in order, and deduplicated');
      expect(grant.token, 'tok-en.9');
      expect(grant.age, const Duration(milliseconds: 90000));

      expect(KugouliveDanmakuCodec.grant(_dispatch(protocol: '')).endpoints.first.toString(), 'ws://a.chat.test');
      expect(KugouliveDanmakuCodec.grant(_dispatch(age: 0)).age, KugouliveDanmakuCodec.defaultAge);
      expect(KugouliveDanmakuCodec.grant(_dispatch(age: -5)).age, KugouliveDanmakuCodec.defaultAge);
      expect(KugouliveDanmakuCodec.grant(_dispatch(hosts: ['b.test', 'a.test'])).endpoints.map((uri) => uri.host), [
        'b.test',
        'a.test',
      ]);
    });

    test('a scheduler that will not answer says why', () {
      KugouliveFailureKind? of(String answer, {int status = 200}) {
        try {
          KugouliveDanmakuCodec.grant(answer, status: status);
          return null;
        } on KugouliveDispatchRefusal catch (refusal) {
          expect(refusal.code, 622, reason: 'the refusal names the code the page asked about');
          expect(refusal.message, 'slider required');
          return null;
        } on KugouliveFailure catch (failure) {
          return failure.kind;
        }
      }

      expect(of('not json'), KugouliveFailureKind.apiChanged);
      expect(of('[1,2]'), KugouliveFailureKind.apiChanged);
      expect(of('{"code":0}'), KugouliveFailureKind.apiChanged, reason: 'no data');
      expect(of(_dispatch(hosts: const [])), KugouliveFailureKind.apiChanged, reason: 'no chat address');
      expect(of(_dispatch(token: 'tok en')), KugouliveFailureKind.apiChanged, reason: 'a token with a space');
      expect(of(_dispatch(token: null)), KugouliveFailureKind.apiChanged);
      expect(
        of(_dispatch(code: 622, msg: 'slider required')),
        isNull,
        reason: 'a refusal is its own error, not a transport one',
      );
      expect(of('{}', status: 401), KugouliveFailureKind.riskControl);
      expect(of('{}', status: 404), KugouliveFailureKind.notFound);
      expect(of('{}', status: 429), KugouliveFailureKind.rateLimited);
      expect(of('{}', status: 451), KugouliveFailureKind.regionBlocked);
      expect(of('{}', status: 500), KugouliveFailureKind.network);
    });
  });

  group('the bytes the client sends', () {
    test('a frame is the 18-byte header over its envelope', () {
      final frame = KugouliveDanmakuCodec.frame(KugouliveDanmakuCodec.chatCommand, [1, 2, 3]);
      final header = ByteData.sublistView(frame, 0, 18);
      expect(frame[0], 100);
      expect(header.getInt16(1), 3, reason: 'version, big-endian');
      expect(frame[3], 1, reason: 'a data frame, not a heartbeat');
      expect(header.getInt16(4), 12);
      expect(header.getInt32(6), KugouliveDanmakuCodec.chatCommand);
      expect(header.getInt32(10), frame.length - 18);
      expect(KugouliveProtoMessage.decode(Uint8List.sublistView(frame, 18)).bytes(7), [1, 2, 3]);
    });

    test('the login is the page’s fields in field order, and a re-login is another command', () {
      List<int> numbers(Uint8List frame) =>
          KugouliveProtoMessage.decode(KugouliveProtoMessage.decode(Uint8List.sublistView(frame, 18)).bytes(7)!).fields
              .map((field) => field.number)
              .toList();
      final frame = KugouliveDanmakuCodec.login(
        roomId: _room,
        token: 't',
        sid: 'sid',
        deviceNo: 'dev',
        sessionId: 'session',
      );
      expect(ByteData.sublistView(frame, 6, 10).getInt32(0), KugouliveDanmakuCodec.loginCommand);
      expect(numbers(frame), [1, 2, 3, 4, 6, 7, 10, 12, 13, 14, 15, 18, 23, 29, 38]);
      final again = KugouliveDanmakuCodec.login(roomId: _room, token: 't', sid: 'sid', deviceNo: 'dev', again: true);
      expect(ByteData.sublistView(again, 6, 10).getInt32(0), KugouliveDanmakuCodec.reloginCommand);
      expect(numbers(again), numbers(frame), reason: 'only the command changes');
    });

    test('the heartbeat is four bytes, and the acknowledgement repeats what the envelope asked', () {
      expect(KugouliveDanmakuCodec.heartbeat(), [100, 0, 1, 0]);
      final ack = KugouliveDanmakuCodec.ack(roomId: _room, offset: 'o', msgId: 'm', repeat: 2);
      expect(ByteData.sublistView(ack, 6, 10).getInt32(0), KugouliveDanmakuCodec.ackCommand);
      final content = KugouliveProtoMessage.decode(
        KugouliveProtoMessage.decode(Uint8List.sublistView(ack, 18)).bytes(7)!,
      );
      expect(content.integer(1), KugouliveDanmakuCodec.ackCommand);
      expect(content.integer(2), 555);
      expect(content.integer(3), 0, reason: 'no login: kugouId 0');
      expect(content.string(4), 'o');
      expect(content.string(5), 'm');
      expect(content.integer(6), 2);
    });

    test('the uuid is the page’s version-4 form, including the variant nibble', () {
      final text = KugouliveDanmakuCodec.uuid(_Random(15));
      expect(text, 'ffffffff-ffff-4fff-bfff-ffffffffffff');
      expect(text, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(KugouliveDanmakuCodec.uuid(_Random(0)).split('-')[3], '8000', reason: 'the variant nibble is 8..b');
      expect(KugouliveDanmakuCodec.uuid(_Random(3)).split('-')[3], 'b333', reason: 'y is 0..3 ORed into 8');
      expect(
        KugouliveDanmakuCodec.uuid(_Random(8)).split('-')[2],
        '4888',
        reason: 'the version nibble is written, not drawn',
      );
    });
  });

  group('one server frame', () {
    test('the heartbeat’s answer is a heartbeat, not a message', () {
      expect(KugouliveDanmakuCodec.decode([100, 0, 3, 0], roomId: _room).heartbeat, isTrue);
      expect(KugouliveDanmakuCodec.decode([0, 0, 0, 1], roomId: _room).heartbeat, isFalse);
      expect(KugouliveDanmakuCodec.decode('text, not bytes', roomId: _room).messages, isEmpty);
    });

    test('status 901 joins with its session, refuses with its reason, and says nothing otherwise', () {
      KugouliveDanmakuFrame of(Uint8List body) =>
          KugouliveDanmakuCodec.decode(_frame(KugouliveDanmakuCodec.statusCommand, _envelope(body)), roomId: _room);
      expect(of(_status(socsid: 'sid-9')).joined, isTrue);
      expect(of(_status(socsid: 'sid-9')).sessionId, 'sid-9');
      expect(of(_status(socsid: '')).sessionId, isNull);
      expect(of(_status(type: 4)).joined, isFalse, reason: 'the first type-4 answer says nothing');

      final refusal = of(_status(status: 0, errorno: 622, msg: 'token expired')).refusal!;
      expect(refusal.errorNo, 622);
      expect(refusal.tokenRejected, isTrue);
      expect(refusal.message, 'token expired');
      expect(of(_status(status: 0)).refusal!.errorNo, 0);
      expect(of(_status(status: 0)).refusal!.tokenRejected, isFalse);
    });

    test('a chat arrives through the protobuf path with the envelope’s id', () {
      final message = _protobufChat(_chatResponse());
      expect(message?.text, '你好');
      expect(message?.messageId, 'env-1');
      expect(message?.sender?.userId, '1001');
      expect(message?.sender?.userName, 'Ann');
      expect(message?.sentAt, DateTime.fromMillisecondsSinceEpoch(1790733600000));
    });

    test('a gift the envelope asks for is answered with an acknowledgement', () {
      final asked = KugouliveDanmakuCodec.decode(
        _frame(
          KugouliveDanmakuCodec.giftCommand,
          _envelope(utf8.encode(jsonEncode(_giftPacket())), codec: 0, ack: 1, rpt: 2, offset: 'o9', msgId: 'g1'),
        ),
        roomId: _room,
      );
      expect(asked.messages.single.type, LiveMessageType.gift);
      expect(
        asked.ack,
        KugouliveDanmakuCodec.ack(roomId: _room, offset: 'o9', msgId: 'g1', repeat: 2),
        reason: 'exactly what the page sends back',
      );

      final quiet = KugouliveDanmakuCodec.decode(
        _frame(
          KugouliveDanmakuCodec.giftCommand,
          _envelope(utf8.encode(jsonEncode(_giftPacket())), codec: 0, msgId: ''),
        ),
        roomId: _room,
      );
      expect(quiet.ack, isNull);
      expect(quiet.messages.single.messageId, isEmpty, reason: 'an envelope without a msgId names nothing');
    });

    test('the audience of a minute gives the viewers now and the viewers so far', () {
      List<LiveMessage> of(Map<String, Object?> packet) => KugouliveDanmakuCodec.decode(
        _frame(KugouliveDanmakuCodec.audienceCommand, _envelope(utf8.encode(jsonEncode(packet)), codec: 0)),
        roomId: _room,
      ).messages;
      final both = of(_audiencePacket(count: '1200', visited: 30000));
      expect(both, hasLength(2));
      expect(both.map((message) => (message.payload! as LiveAudienceUpdate).kind), [
        LiveAudienceSignalKind.onlineViewers,
        LiveAudienceSignalKind.totalViewers,
      ]);
      expect((both.first.payload! as LiveAudienceUpdate).value, 1200, reason: 'a numeric string is a number');
      expect(both.first.text, isEmpty, reason: 'a figure is a payload, not a chat line');
      expect(of(_audiencePacket(count: 0)), hasLength(1), reason: 'zero is a figure, absent is not');
      expect(of(_audiencePacket(count: -1)), isEmpty, reason: 'a negative figure is not read');
      expect(of(_audiencePacket(count: '1.2万')), isEmpty, reason: 'a figure with a unit is not a number');
      expect(of(_audiencePacket(actionId: 'hot')), isEmpty);
      expect(of(_audiencePacket(room: '999')), isEmpty);
      expect(
        of({
          'roomid': _room,
          'content': {'actionId': 'roomAuNumber'},
        }),
        isEmpty,
        reason: 'no data map',
      );
    });

    test('a frame that cannot be read gives nothing, and is not thrown at the caller', () {
      expect(KugouliveDanmakuCodec.decode([1, 2, 3], roomId: _room).messages, isEmpty, reason: 'shorter than a header');
      final badStart = _frame(KugouliveDanmakuCodec.chatCommand, _envelope(_chatMessage()), headerLength: 1000);
      expect(
        KugouliveDanmakuCodec.decode(badStart, roomId: _room).messages,
        isEmpty,
        reason: 'the envelope start is out of range',
      );
      final lying = _frame(KugouliveDanmakuCodec.chatCommand, _envelope(_chatMessage()), declaredLength: 9999);
      expect(
        KugouliveDanmakuCodec.decode(lying, roomId: _room).messages.single.text,
        '你好',
        reason: 'the header length is not trusted: the envelope is read from where it starts',
      );
      expect(
        KugouliveDanmakuCodec.decode(
          _frame(KugouliveDanmakuCodec.chatCommand, _envelope([0xFF, 0xFF])),
          roomId: _room,
        ).messages,
        isEmpty,
        reason: 'content that is not protobuf',
      );
      expect(
        KugouliveDanmakuCodec.decode(
          _frame(KugouliveDanmakuCodec.chatCommand, _envelope(utf8.encode('nope'), codec: 0)),
          roomId: _room,
        ).messages,
        isEmpty,
        reason: 'content that is not JSON',
      );
      expect(KugouliveDanmakuCodec.decode(_frame(123456, _envelope(_chatMessage())), roomId: _room).messages, isEmpty);
      expect(
        KugouliveDanmakuCodec.decode(
          _frame(KugouliveDanmakuCodec.chatCommand, _envelope(utf8.encode(jsonEncode(_chatPacket())), codec: 0)),
          roomId: '999',
        ).messages,
        isEmpty,
        reason: 'a frame of another room is dropped by the room check',
      );
    });

    test('a gzip envelope is inflated before it is read, and an over-long one is dropped', () {
      expect(
        KugouliveDanmakuCodec.decode(
          _frame(KugouliveDanmakuCodec.chatCommand, _envelope(GZipCodec().encode(_chatMessage()), compression: 1)),
          roomId: _room,
        ).messages.single.text,
        '你好',
      );
      final huge = GZipCodec().encode(Uint8List(KugouliveDanmakuCodec.maxContentBytes + 1));
      expect(
        KugouliveDanmakuCodec.decode(
          _frame(KugouliveDanmakuCodec.chatCommand, _envelope(huge, compression: 1)),
          roomId: _room,
        ).messages,
        isEmpty,
        reason: 'the cap is enforced while inflating, not after',
      );
    });

    test('a snappy envelope is unpacked before it is read', () {
      final packed = _snappy(Uint8List.fromList(_chatMessage()));
      expect(
        KugouliveDanmakuCodec.decode(
          _frame(KugouliveDanmakuCodec.chatCommand, _envelope(packed, compression: 2)),
          roomId: _room,
        ).messages.single.text,
        '你好',
      );
    });
  });

  group('what the page would show', () {
    test('a private, foreign or empty chat is not shown', () {
      expect(_protobufChat(_chatResponse(), receiverId: 2002), isNull, reason: 'the envelope sends it to someone');
      expect(
        _protobufChat(_chatResponse(receiverId: 7)),
        isNotNull,
        reason: 'the page marks a private chat by the envelope’s receiver, not the content’s',
      );
      expect(_protobufChat(_chatResponse(), room: 999), isNull, reason: 'it is about another room');
      expect(_protobufChat(_chatResponse(text: ' \u2028 ')), isNull, reason: 'nothing is left after the marks');
      expect(_protobufChat(_chatResponse(), senderId: -1), isNull, reason: 'a negative sender is not a viewer');
      expect(_jsonChat(_chatPacket(privateType: 1)), isNull, reason: 'the packet marks it private');
      expect(_jsonChat(_chatPacket(chatmsg: null)), isNull);
      expect(_jsonChat(_chatPacket(roomid: null)), isNotNull, reason: 'a packet without a room is this room’s');
    });

    test('the partner room’s chat is shown only when it really is the partner’s', () {
      LiveMessage? of(List<int> source) =>
          _protobufChat(_chatResponse(), source: source, command: KugouliveDanmakuCodec.otherRoomChatCommand);
      expect(of(_source(777, 1))?.sourceRoomId, '777');
      expect(of(_source(777, 1))?.text, '你好');
      expect(of(_source(777, 0)), isNull, reason: 'the tag does not mark a partner chat');
      expect(of(_source(0, 1)), isNull, reason: 'no partner room named');
      expect(of(_source(777, 3)), isNotNull, reason: 'the tag is read as a bit');
    });

    test('the partner room cannot be the room already open', () {
      expect(
        KugouliveDanmakuCodec.decode(
          _frame(KugouliveDanmakuCodec.otherRoomChatCommand, _envelope(_chatMessage(source: _source(555, 1)))),
          roomId: _room,
        ).messages,
        isEmpty,
      );
    });

    test('the identity is the envelope’s sender, and a mystery guest borrows its alias', () {
      expect(_protobufChat(_chatResponse())?.sender?.userId, '1001');
      expect(
        _protobufChat(_chatResponse(), sinfo: _sinfo(0))?.sender?.userId,
        '1001',
        reason: 'ck 0 is not a mystery guest',
      );
      final mystery = _protobufChat(_chatResponse(), sinfo: _sinfo(1), ext: _ext(intimacyLevel: 9));
      expect(mystery?.sender?.userId, 'alias-9');
      expect(
        mystery?.color,
        KugouliveDanmakuCodec.mysteryColor,
        reason: 'the gold of a mystery guest beats the club orange',
      );
      expect(
        _protobufChat(_chatResponse(senderId: 2222), senderId: 0)?.sender?.userId,
        '2222',
        reason: 'the content’s sender stands in',
      );
    });

    test('the level is the wealth level, else the old one, and never a zero', () {
      String? level({int v1 = 0, int v2 = 0}) =>
          _protobufChat(_chatResponse(level: v1, richLevelV2: v2))!.sender!.userLevel;
      expect(level(v1: 3, v2: 12), '12');
      expect(level(v1: 3), '3');
      expect(level(), isEmpty);
      expect(level(v1: -5), isEmpty, reason: 'a negative level is not shown');
      expect(
        _jsonChat(_chatPacket(senderrichlevel: '9'))?.sender?.userLevel,
        '9',
        reason: 'a level written as text is still a level',
      );
    });

    test('the fan badge shows only when the page shows it', () {
      String badge(List<int> ext) => _protobufChat(_chatResponse(), ext: ext)!.sender!.fanBadgeName;
      expect(badge(_ext(intimacyLevel: 4)), '车神');
      expect(badge(_ext(intimacyLevel: 4, intimacyType: 0)), isEmpty, reason: 'type 0 has no club');
      expect(badge(_ext(intimacyLevel: 4, intimacyType: 5)), isEmpty);
      expect(badge(_ext(intimacyLevel: 4, lightUp: 0)), isEmpty, reason: 'not lit up');
      expect(badge(_ext(intimacyLevel: 0)), isEmpty);
      expect(badge(_ext(intimacyLevel: 4, nameplate: ' ')), isEmpty);
      expect(badge(_ext(intimacyLevel: 4)), '车神');
      expect(_protobufChat(_chatResponse(), ext: _ext(intimacyLevel: 4))!.sender!.fanBadgeLevel, '4');
    });

    test('the colour is the club orange, the mystery gold, or white', () {
      LiveMessageColor? color(List<int>? ext, {int ck = 0}) =>
          _protobufChat(_chatResponse(), ext: ext, sinfo: ck == 0 ? null : _sinfo(ck))!.color;
      expect(color(null), LiveMessageColor.white, reason: 'no ext is read as the page without the switch on');
      expect(color(_ext()), LiveMessageColor.white);
      expect(color(_ext(intimacyLevel: 9)), KugouliveDanmakuCodec.highlightColor, reason: 'a club level above 7');
      expect(color(_ext(intimacyLevel: 7)), LiveMessageColor.white);
      expect(color(_ext(littleGuard: 2)), KugouliveDanmakuCodec.highlightColor);
      expect(color(_ext(littleGuard: 0)), LiveMessageColor.white);
      expect(color(_ext(guard: 'G')), KugouliveDanmakuCodec.highlightColor);
      expect(color(_ext(guard: '')), LiveMessageColor.white, reason: 'an empty guard is JavaScript-false');
      expect(color(_ext(intimacyLevel: 1), ck: 1), KugouliveDanmakuCodec.mysteryColor);
      expect(
        _protobufChat(_chatResponse(), ext: [0xFF]),
        isNull,
        reason: 'an unreadable ext drops the whole line, not only its badge',
      );
      expect(
        _jsonChat(
          _chatPacket(
            ext: {
              'intimacyVo': {'level': '9', 'type': 1, 'lightUp': 1, 'nameplate': '车神'},
            },
          ),
        )!.color,
        KugouliveDanmakuCodec.highlightColor,
        reason: 'a level written as text still lights the orange up',
      );
    });

    test('the ext of a JSON packet may be URL-encoded, and a broken escape is no ext', () {
      final encoded = Uri.encodeComponent(
        jsonEncode({
          'intimacyVo': {'level': 9, 'type': 1, 'lightUp': 1, 'nameplate': '车神'},
        }),
      );
      expect(_jsonChat(_chatPacket(ext: encoded))!.color, KugouliveDanmakuCodec.highlightColor);
      expect(_jsonChat(_chatPacket(ext: ''))!.color, LiveMessageColor.white);
      expect(
        _jsonChat(_chatPacket(ext: 'level%2'))!.color,
        LiveMessageColor.white,
        reason: 'a bad percent escape is refused',
      );
      expect(_jsonChat(_chatPacket(ext: 'not json'))!.color, LiveMessageColor.white);
      expect(_jsonChat(_chatPacket(ext: '[1,2]'))!.color, LiveMessageColor.white);
    });

    test('the id is the envelope’s, else the sender and sequence, else nothing', () {
      String? id({String msgId = '', int seq = 77, int senderId = 1001}) => _protobufChat(
        _chatResponse(seq: seq, senderId: senderId),
        senderId: senderId,
        msgId: msgId,
      )?.messageId;
      expect(id(msgId: 'env'), 'env');
      expect(id(), '1001:77');
      expect(id(seq: 0), isEmpty, reason: 'a sequence of zero names no line');
      expect(id(senderId: 0), isEmpty, reason: 'a chat with no sender id has no fallback key');
    });

    test('the name and text lose the direction marks the page takes out', () {
      final message = _protobufChat(_chatResponse(text: '\u202A\u202Ax\u2027\u202E', name: '\u202DAnn\u202C'))!;
      expect(message.text, 'x', reason: 'U+2027 to U+202E go, and the rest is trimmed');
      expect(message.sender?.userName, 'Ann');
    });

    test('the time is seconds, or milliseconds once it is big enough', () {
      DateTime? at(Object? time) => _jsonChat(_chatPacket(time: time))?.sentAt;
      expect(at(1790733600), DateTime.fromMillisecondsSinceEpoch(1790733600000));
      expect(at(1790733600000), DateTime.fromMillisecondsSinceEpoch(1790733600000), reason: 'already milliseconds');
      expect(at('1790733600'), DateTime.fromMillisecondsSinceEpoch(1790733600000), reason: 'a number written as text');
      expect(at(0), isNull);
      expect(at(-3), isNull);
      expect(at(null), isNull);
      expect(at(8640000000000001), isNull, reason: 'no DateTime holds it');
    });
  });

  group('the gift and its picture', () {
    test('a gift of another room is not this room’s, whichever field names it', () {
      expect(KugouliveDanmakuCodec.gift(_giftPacket(), roomId: _room), isNotNull);
      expect(KugouliveDanmakuCodec.gift(_giftPacket(room: '999'), roomId: _room), isNull);
      final contentOnly = _giftPacket(room: null);
      expect(KugouliveDanmakuCodec.gift(contentOnly, roomId: _room), isNotNull);
      expect(
        KugouliveDanmakuCodec.gift(_giftPacket(room: 0), roomId: _room),
        isNotNull,
        reason: 'a room of 0 is no room',
      );
    });

    test('the gift id is a number, the count is at least one, and a negative price names none', () {
      LiveGift? giftOf(Map<String, Object?> packet) =>
          KugouliveDanmakuCodec.gift(packet, roomId: _room)?.payload as LiveGift?;
      expect(giftOf(_giftPacket(giftId: '0')), isNull, reason: 'id 0 is not a gift');
      expect(giftOf(_giftPacket(giftId: null)), isNull);
      expect(giftOf(_giftPacket(giftId: 'abc')), isNull, reason: 'a non-numeric id is not one');
      expect(giftOf(_giftPacket(giftId: 77))!.giftId, '77', reason: 'a numeric id is read as text');
      expect(giftOf(_giftPacket(num: 0))!.count, 1);
      expect(giftOf(_giftPacket(num: -5))!.count, 1);
      expect(giftOf(_giftPacket(price: -7))!.value.unitPrice, isNull);
      expect(giftOf(_giftPacket(price: -7))!.value.totalValue, isNull);
      expect(giftOf(_giftPacket())!.value.totalValue, 20);
      expect(giftOf(_giftPacket(price: 0))!.value.unit, LiveGiftUnit.free);
      expect(KugouliveDanmakuCodec.gift(_giftPacket(name: ' 玫瑰 '), roomId: _room)!.text, '玫瑰 ×2');
    });

    test('a combo key is the v2 id, else the old one, and never the literal 0', () {
      String combo({String? v2, String? old}) =>
          (KugouliveDanmakuCodec.gift(
                    _giftPacket(comboV2: v2, combo: old),
                    roomId: _room,
                  )!.payload!
                  as LiveGift)
              .combo
              .comboKey;
      expect(combo(v2: 'c1', old: 'o1'), 'c1');
      expect(combo(old: 'o1'), 'o1');
      expect(
        combo(v2: '0', old: 'o1'),
        'o1',
        reason: 'a v2 id of 0 is no id',
      );
      expect(combo(v2: ' ', old: '0'), isEmpty);
      expect(combo(), isEmpty);
      expect(
        (KugouliveDanmakuCodec.gift(_giftPacket(comboSum: 0), roomId: _room)!.payload! as LiveGift).combo.comboTotal,
        isNull,
      );
    });

    test('the picture is the image host, made https, and nothing else', () {
      String? image(String path) =>
          (KugouliveDanmakuCodec.gift(_giftPacket(image: path), roomId: _room)!.payload! as LiveGift).iconUrl;
      expect(image('/fxstatic/a.png'), 'https://s4fx.kgimg.com/fxstatic/a.png');
      expect(image('  /fxstatic/a.png  '), 'https://s4fx.kgimg.com/fxstatic/a.png', reason: 'trimmed first');
      expect(image('http://cdn.test/a.png'), 'https://cdn.test/a.png');
      expect(image('https://cdn.test/a.png'), 'https://cdn.test/a.png');
      expect(image('//cdn.test/a.png'), isNull, reason: 'a protocol-relative address is not read as one');
      expect(image('cdn.test/a.png'), isNull);
      expect(image(''), isNull);
    });

    test('the gift line carries its sender, its receiver and the envelope id', () {
      final message = KugouliveDanmakuCodec.decode(
        _frame(
          KugouliveDanmakuCodec.giftCommand,
          _envelope(utf8.encode(jsonEncode(_giftPacket())), codec: 0, msgId: 'g9'),
        ),
        roomId: _room,
      ).messages.single;
      expect(message.messageId, 'g9');
      expect(message.sender?.userId, '1001');
      expect(message.sender?.userName, 'Ann');
      expect(message.sender?.userLevel, '12');
      expect(message.sentAt, isNull, reason: 'a JSON packet without a time is undated');
      expect((message.payload! as LiveGift).recipientName, '主播');
    });
  });

  group('the raw block reader', () {
    test('a snappy block of literals and one copy is decoded', () {
      expect(KugouliveDanmakuCodec.snappy(Uint8List.fromList([2, 4, 0x61, 0x62])), utf8.encode('ab'));
      expect(KugouliveDanmakuCodec.snappy(Uint8List.fromList([6, 4, 0x61, 0x62, 1, 2])), utf8.encode('ababab'));
      expect(KugouliveDanmakuCodec.snappy(Uint8List.fromList([0])), isEmpty);
      expect(KugouliveDanmakuCodec.snappy(_snappy(utf8.encode('repeat repeat'))), utf8.encode('repeat repeat'));
    });

    test('a snappy block that lies about itself is refused', () {
      for (final bytes in <List<int>>[
        [1, 4, 0x61, 0x62],
        [6, 4, 0x61, 0x62, 1],
        [4, 5, 0x61],
        [2, 0x01, 0x02],
        [4, 4, 0x61, 0x62, 1, 0x00],
        [200, 0x80],
      ]) {
        expect(
          () => KugouliveDanmakuCodec.snappy(Uint8List.fromList(bytes)),
          throwsA(isA<FormatException>()),
          reason: '$bytes',
        );
      }
    });
  });
}

/// A raw snappy block of [input] (literals only): the length, then one literal
/// tag per 60 bytes.
Uint8List _snappy(List<int> input) {
  final out = BytesBuilder(copy: false)..add(_varint(input.length));
  var rest = input.length;
  var position = 0;
  while (rest > 0) {
    final size = rest < 60 ? rest : 60;
    out
      ..addByte((size - 1) << 2)
      ..add(input.sublist(position, position + size));
    position += size;
    rest -= size;
  }
  return out.toBytes();
}

List<int> _varint(int value) {
  final out = <int>[];
  var rest = value;
  while (true) {
    final byte = rest & 0x7F;
    rest >>>= 7;
    if (rest == 0) return [...out, byte];
    out.add(byte | 0x80);
  }
}
