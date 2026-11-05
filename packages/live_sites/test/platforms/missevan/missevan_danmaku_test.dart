import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:brotli_neo/v2.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/platforms/missevan/danmaku/missevan_danmaku_codec.dart';
import 'package:test/test.dart';

const String _room = '777';
const String _uuid = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';

/// A binary server frame: flag 1, the UTF-8 length as 24-bit little-endian,
/// then the Brotli stream the site sends.
List<int> _binary(String text, {int flag = MissevanDanmakuCodec.brotliFlag, int? declares, List<int>? body}) {
  final plain = Uint8List.fromList(utf8.encode(text));
  final packed = body ?? BrotliEncoderV2.encode(plain);
  final length = declares ?? plain.length;
  return [flag, length & 0xFF, (length >> 8) & 0xFF, (length >> 16) & 0xFF, ...packed];
}

/// A JSON frame of one object.
String _json(Map<String, Object?> item) => jsonEncode(item);

/// Decode one frame for [_room] joined with [_uuid].
MissevanDanmakuFrame _read(Object? data, {String room = _room, String uuid = _uuid, DateTime? at}) =>
    MissevanDanmakuCodec.decode(data, roomId: room, uuid: uuid, receivedAt: at);

/// The single message of a frame.
LiveMessage? _one(Object? data, {DateTime? at}) => _read(data, at: at).messages.singleOrNull;

/// A chat item (`message`/`new`).
Map<String, Object?> _chatItem({
  Object? message = '你好',
  Object? text = 'Ann',
  Object? userId = 21,
  Object? msgId = 'm1',
  Object? time = 1790733600000,
  List<Object?>? titles,
  String event = 'new',
}) => {
  'type': 'message',
  'event': event,
  'room_id': int.tryParse(_room),
  'message': ?message,
  'msg_id': ?msgId,
  'time': ?time,
  'user': {'username': ?text, 'user_id': ?userId, 'titles': ?titles},
};

void main() {
  group('the socket', () {
    test('the address is the site’s own, or the form the site uses', () {
      Uri of(Uri url, {String room = _room}) => MissevanDanmakuCodec.endpoint(url, roomId: room);

      expect(of(Uri.parse('wss://im.missevan.com/ws?room_id=777')).toString(), 'wss://im.missevan.com/ws?room_id=777');
      expect(
        of(Uri.parse('wss://im.missevan.com/ws')).queryParameters['room_id'],
        _room,
        reason: 'a socket without the room gets it',
      );
      expect(of(Uri.parse('wss://missevan.com/ws')).host, 'missevan.com');
      expect(
        of(Uri.parse('wss://im.missevan.com/ws?room_id=888')).toString(),
        'wss://im.missevan.com/ws?room_id=777',
        reason: 'a socket for another room is not this room’s',
      );
      expect(
        of(Uri.parse('wss://im.missevan.com/ws?room_id=777&room_id=777')).toString(),
        contains('room_id=777'),
        reason: 'the name twice is not the name once',
      );
      expect(of(Uri.parse('wss://evil.test/ws?room_id=777')).host, 'im.missevan.com');
      expect(of(Uri.parse('ws://im.missevan.com/ws?room_id=777')).host, 'im.missevan.com', reason: 'wss only');
      expect(
        of(Uri.parse('wss://me@im.missevan.com/ws?room_id=777')).toString(),
        'wss://im.missevan.com/ws?room_id=777',
        reason: 'credentials never ride to the socket',
      );
      expect(of(Uri.parse('wss://im.missevan.com/ws?%zz=1')).queryParameters['room_id'], _room);
    });

    test('the guest session is the FM_SESS cookie and nothing else', () {
      String? sessionOf(List<String> lines) => MissevanDanmakuCodec.session(lines);
      expect(sessionOf(['FM_SESS=abc123; Path=/; HttpOnly']), 'abc123');
      expect(sessionOf(['  FM_SESS=abc123 ; Path=/']), 'abc123', reason: 'trimmed, and the value ends at the first ;');
      expect(sessionOf(['FM_SESS.sig=deadbeef', 'FM_SESS=abc']), 'abc', reason: 'the signature is not the session');
      expect(sessionOf(['OTHER=1', 'FM_SESS=abc']), 'abc');
      expect(sessionOf(['FM_SESS=has space']), isNull, reason: 'a cookie value cannot hold a space');
      expect(sessionOf(['FM_SESS="quoted"']), isNull);
      expect(sessionOf(['FM_SESS=; Path=/']), isNull, reason: 'an empty value is no session');
      expect(sessionOf(const <String>[]), isNull);
    });

    test('the handshake carries the session in place of any cookie', () {
      final headers = MissevanDanmakuCodec.handshakeHeaders({
        'Cookie': 'stale=1',
        'user-agent': 'ua',
        'origin': 'https://m.missevan.com',
      }, 'abc123');
      expect(headers['cookie'], 'FM_SESS=abc123');
      expect(headers.containsKey('Cookie'), isFalse, reason: 'the old cookie is replaced, not added beside');
      expect(headers['user-agent'], 'ua');
      expect(headers['origin'], 'https://m.missevan.com');
    });

    test('the join sends the room as a number and the rejoin says so', () {
      expect(jsonDecode(MissevanDanmakuCodec.join(_room, uuid: _uuid)), {
        'action': 'join',
        'uuid': _uuid,
        'type': 'room',
        'room_id': 777,
      });
      expect(
        (jsonDecode(MissevanDanmakuCodec.join(_room, uuid: _uuid, reconnect: true))
            as Map<String, Object?>)['reconnect'],
        1,
      );
      expect(() => MissevanDanmakuCodec.join('abc', uuid: _uuid), throwsFormatException);
    });

    test('the join’s uuid is a version-4 one', () {
      final text = MissevanDanmakuCodec.uuid(Random(7));
      expect(text, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(MissevanDanmakuCodec.uuid(Random(7)), text, reason: 'the same seed gives the same uuid');
      expect(MissevanDanmakuCodec.uuid(Random(8)), isNot(text));
    });

    test('a binary frame is Brotli-decoded only when it says exactly how long', () {
      expect(MissevanDanmakuCodec.text('plain'), 'plain');
      expect(MissevanDanmakuCodec.text(_binary('{"a":1}')), '{"a":1}');
      expect(MissevanDanmakuCodec.text(_binary('❤️')), '❤️');
      expect(MissevanDanmakuCodec.text(_binary('a' * 400)), 'a' * 400);
      expect(MissevanDanmakuCodec.text(_binary('{"a":1}', flag: 2)), isNull, reason: 'another flag is not Brotli');
      expect(MissevanDanmakuCodec.text(_binary('{"a":1}', declares: 5)), isNull, reason: 'a lie about the length');
      expect(MissevanDanmakuCodec.text(_binary('{"a":1}', body: const [0xFF, 0xFF])), isNull, reason: 'not a stream');
      expect(MissevanDanmakuCodec.text(const [1, 0, 0]), isNull, reason: 'shorter than its header');
      expect(MissevanDanmakuCodec.text(7), isNull);
    });
  });

  group('one frame', () {
    test('the answer to this socket’s join', () {
      final joined = _read(_json({'type': 'room', 'event': 'join', 'uuid': _uuid, 'code': 0}));
      expect(joined.joined, isTrue);
      expect(joined.refusal, isEmpty);
      expect(_read(_json({'type': 'room', 'event': 'join', 'uuid': _uuid, 'code': 5})).joined, isFalse);
      expect(
        _read(_json({'type': 'room', 'event': 'join', 'uuid': _uuid, 'code': 500030004, 'info': '无法找到该聊天室'})).refusal,
        '500030004 无法找到该聊天室',
      );
      expect(
        _read(_json({'type': 'room', 'event': 'join', 'uuid': 'other', 'code': 5})).joined,
        isNull,
        reason: 'another socket’s answer is not ours',
      );
      expect(_read(_json({'type': 'room', 'event': 'join', 'code': 0})).joined, isNull, reason: 'no uuid at all');
    });

    test('the chat kinds, and the room the item names', () {
      expect(_one(_json(_chatItem()))!.text, '你好');
      expect(_one(_json(_chatItem(event: 'danmaku')))!.text, '你好', reason: 'a paid danmaku is a chat line');
      expect(_one(_json({..._chatItem(), 'room_id': 888})), isNull, reason: 'another room');
      expect(_one(_json({..._chatItem(), 'room_id': '777'}))!.text, '你好', reason: 'the id may be text');
      expect(_one(_json(_chatItem(message: '   '))), isNull);
      expect(_one(_json(_chatItem(message: null))), isNull);
      expect(_one(_json(_chatItem(message: 7)))!.text, '7', reason: 'a number is still a line');
      expect(_one(_json(_chatItem(msgId: 42)))!.messageId, '42');
      expect(_one(_json(_chatItem(time: 0)))!.sentAt, isNull);
      expect(_one(_json(_chatItem(time: '1790733600000')))!.sentAt, isNull, reason: 'only an int is a time');
    });

    test('a level and a fan medal come out of the user’s titles', () {
      final message = _one(
        _json(
          _chatItem(
            titles: [
              {'type': 'level', 'level': 9},
              {'type': 'medal', 'name': ' 团长 ', 'level': 3},
              'not a title',
            ],
          ),
        ),
      )!;
      expect(message.sender?.userLevel, '9');
      expect(message.sender?.fanBadgeName, '团长');
      expect(message.sender?.fanBadgeLevel, '3');
      final none = _one(
        _json(
          _chatItem(
            titles: [
              {'type': 'level', 'level': 'x'},
            ],
          ),
        ),
      )!;
      expect(none.sender?.userLevel, isEmpty);
      expect(none.sender?.fanBadgeName, isEmpty);
      expect(_one(_json(_chatItem()))!.sender?.fanBadgeName, isEmpty, reason: 'no titles');
      expect(_one(_json(_chatItem(msgId: null)))!.sender?.userId, '21');
    });

    test('the room statistics give heat and listeners', () {
      final frame = _read(
        _json({
          'type': 'room',
          'event': 'statistics',
          'statistics': {'score': 4200, 'online': 30},
        }),
      );
      expect(frame.messages, hasLength(2));
      expect(frame.messages.map((message) => (message.payload! as LiveAudienceUpdate).kind), [
        LiveAudienceSignalKind.popularity,
        LiveAudienceSignalKind.onlineViewers,
      ]);
      expect((frame.messages.first.payload! as LiveAudienceUpdate).value, 4200);
      expect(
        _read(
          _json({
            'type': 'room',
            'event': 'statistics',
            'statistics': {'score': 0, 'online': -1},
          }),
        ).messages,
        hasLength(1),
        reason: 'zero is a figure, a negative one is not',
      );
      expect(_read(_json({'type': 'room', 'event': 'statistics'})).messages, isEmpty);
      expect(
        _read(
          _json({
            'type': 'room',
            'event': 'statistics',
            'statistics': {'score': '12'},
          }),
        ).messages.single.text,
        isEmpty,
        reason: 'text digits count too',
      );
    });

    test('the admin clearing takes lines back', () {
      final all = _one(_json({'type': 'admin', 'event': 'message_clear', 'opt': 1}))!;
      expect((all.payload! as LiveRetraction).all, isTrue);
      final specific = _read(
        _json({
          'type': 'admin',
          'event': 'message_clear',
          'opt': 2,
          'msg_ids': ['m1', 'm1', '  ', 2, null],
        }),
      ).messages;
      expect(specific.map((message) => (message.payload! as LiveRetraction).messageId), ['m1', '2']);
      expect(
        _read(_json({'type': 'admin', 'event': 'message_clear', 'opt': 2, 'msg_ids': 'not a list'})).messages,
        isEmpty,
      );
      expect(_read(_json({'type': 'admin', 'event': 'message_clear', 'opt': 3})).messages, isEmpty);
      expect(_read(_json({'type': 'admin', 'event': 'message_clear'})).messages, isEmpty);
    });

    test('everything the frame does not show', () {
      expect(_read('not json').messages, isEmpty);
      expect(_read(jsonEncode([1, 'x', _chatItem()])).messages, hasLength(1), reason: 'an array, item by item');
      expect(_read(MissevanDanmakuCodec.heartbeat).messages, isEmpty, reason: 'the heartbeat’s echo');
      expect(_read(_json({'type': 'room', 'event': 'enter'})).messages, isEmpty);
      expect(_read(_json({'type': 'other'})).messages, isEmpty);
      expect(_read(null).messages, isEmpty);
      expect(MissevanDanmakuFrame.empty.messages, isEmpty);
      expect(_read(_binary(_json(_chatItem()))).messages.single.text, '你好', reason: 'a binary frame of the same shape');
    });
  });

  group('the noble and the PK notices', () {
    test('a noble title bought, renewed, or for another host', () {
      LiveMessage? noble(Map<String, Object?> item) => _one(_json({'type': 'noble', ...item}));
      expect(
        noble({
          'event': 'registration',
          'noble': {'name': '神话'},
          'user': {'username': 'Ann', 'user_id': 5},
          'time': 1790733600000,
        })!.text,
        'Ann 开通了神话贵族',
      );
      expect(
        noble({
          'event': 'renewal',
          'noble': {'name': '神话'},
          'user': {'username': 'Ann'},
        })!.text,
        'Ann 续费了神话贵族',
      );
      expect(
        noble({
          'event': 'cross_registration',
          'noble': {'name': '神话'},
          'user': {'username': 'Ann'},
          'room': {'creator_username': '主播'},
        })!.text,
        'Ann 开通了主播的神话贵族',
      );
      expect(
        noble({
          'event': 'cross_renewal',
          'noble': {'name': '神话'},
          'user': <String, Object?>{},
        })!.text,
        '续费了神话贵族',
      );
      expect(
        noble({
          'event': 'other',
          'noble': {'name': '神话'},
        }),
        isNull,
      );
      expect(noble({'event': 'registration'}), isNull, reason: 'no noble');
      expect(
        noble({
          'event': 'registration',
          'noble': {'name': ' '},
        }),
        isNull,
      );
      expect(
        noble({
          'event': 'registration',
          'noble': {'name': '神话'},
          'user': {'username': 'Ann', 'user_id': 5},
        })!.sender?.userId,
        '5',
      );
      expect(
        noble({
          'event': 'registration',
          'noble': {'name': '神话'},
        })!.type,
        LiveMessageType.notice,
      );
    });

    test('a PK writes the site’s own lines, in the room they belong to', () {
      List<LiveMessage> pk(Map<String, Object?> item) => _read(_json({'type': 'pk', ...item})).messages;
      expect(pk({'event': 'match_start'}).single.text, '主播正在匹配 PK 对手，请耐心等候');
      expect(pk({'event': 'invite_refuse'}).single.text, '对方未接受邀请');
      expect(
        pk({
          'event': 'invite_timeout',
          'pk': {'from_room_id': 777},
        }).single.text,
        '对方未接受邀请',
        reason: 'the inviting room sees it',
      );
      expect(
        pk({
          'event': 'invite_timeout',
          'pk': {'from_room_id': '888'},
        }),
        isEmpty,
        reason: 'the other room does not',
      );
      expect(
        pk({
          'event': 'finish',
          'pk': {'result': 1},
        }).single.text,
        '恭喜主播获得 PK 胜利，继续支持主播吧',
      );
      expect(
        pk({
          'event': 'close',
          'pk': {'result': 0},
        }).single.text,
        '主播 PK 失败，再接再厉哦',
      );
      expect(
        pk({
          'event': 'finish',
          'pk': {'result': 7},
        }),
        isEmpty,
        reason: 'a result the site has no line for',
      );
      expect(pk({'event': 'unknown'}), isEmpty);
      expect(
        pk({
          'event': 'match_success',
          'raid': {
            'progress': {'message_tip': '花神赐福 已生效'},
          },
        }).map((message) => message.text),
        ['花神赐福 已生效', 'PK 已开始，快送礼支持主播吧'],
        reason: 'the 花神赐福 line comes first',
      );
      expect(pk({'event': 'finish'}), isEmpty, reason: 'a finish with no result names no line');
      expect(
        pk({
          'event': 'finish',
          'pk': {'result': 2},
        }).single.text,
        '主播 PK 平局，再接再厉哦',
      );
    });

    test('a 幻影 PK writes its tip, or the site’s line, or nothing', () {
      List<LiveMessage> globalPk(Map<String, Object?> item) => _read(_json({'type': 'global_pk', ...item})).messages;
      expect(
        globalPk({
          'event': 'update',
          'pk': {'message_tip': '比分 120:80'},
        }).single.text,
        '比分 120:80',
      );
      expect(globalPk({'event': 'update', 'pk': <String, Object?>{}}), isEmpty, reason: 'an update without a tip');
      expect(globalPk({'event': 'match_ready', 'pk': <String, Object?>{}}).single.text, '幻影 PK 即将开启，准备迎战！');
      expect(
        globalPk({
          'event': 'finish',
          'pk': {'result': 2},
        }).single.text,
        '本场幻影 PK 战成平局',
      );
      expect(globalPk({'event': 'finish', 'pk': <String, Object?>{}}).single.text, '幻影 PK 已结束');
      expect(globalPk({'event': 'mute', 'pk': <String, Object?>{}}), isEmpty);
      expect(globalPk({'event': 'not_an_event', 'pk': <String, Object?>{}}), isEmpty);
      expect(globalPk({'event': 'finish'}), isEmpty, reason: 'no pk object');
      expect(
        globalPk({
          'event': 'finish',
          'pk': {'message_tip': '结束 <font color="#BDBDBD">详情</font>'},
        }).single.text,
        '结束',
      );
    });

    test('a team PK shows only its tip', () {
      expect(
        _one(
          _json({
            'type': 'team_pk',
            'pk': {'message_tip': '团队 PK 开始了'},
          }),
        )!.text,
        '团队 PK 开始了',
      );
      expect(_read(_json({'type': 'team_pk', 'pk': <String, Object?>{}})).messages, isEmpty);
      expect(_read(_json({'type': 'team_pk'})).messages, isEmpty);
    });

    test('the 花神赐福 line only for the events the site shows', () {
      expect(
        _read(
          _json({
            'type': 'pk',
            'event': 'close',
            'pk': {'result': 0},
            'raid': {
              'progress': {'message_tip': '赐福结束'},
            },
          }),
        ).messages.map((message) => message.text),
        ['赐福结束', '主播 PK 失败，再接再厉哦'],
      );
      expect(
        _read(
          _json({
            'type': 'pk',
            'event': 'close',
            'raid': {
              'progress': {'message_tip': '赐福结束'},
            },
          }),
        ).messages.map((message) => message.text),
        ['赐福结束'],
        reason: 'a raid tip still shows when the PK itself has no line',
      );
      expect(MissevanDanmakuCodec.raidEvents, {'match_success', 'update', 'finish', 'close'});
      expect(MissevanDanmakuCodec.plainText('赐福<br/>结束'), '赐福 结束');
      expect(MissevanDanmakuCodec.plainText('a  <b>bold</b>  b'), 'a bold b');
      expect(MissevanDanmakuCodec.plainText('<font color="#BDBDBD">详情</font>only'), 'only');
      expect(MissevanDanmakuCodec.plainText('<font color="#bdbdbd" >详情</font>x'), 'x', reason: 'the grey is a link');
      expect(
        MissevanDanmakuCodec.plainText('<font color="#BDBDBD">unclosed'),
        'unclosed',
        reason: 'not a whole link, but still a tag: the word survives, the markup does not',
      );
      expect(MissevanDanmakuCodec.plainText('a &amp; b &#20320; &#x4F60; &unknown;'), 'a & b 你 你 &unknown;');
      expect(MissevanDanmakuCodec.plainText('<img src="x.png">text'), 'text');
      expect(MissevanDanmakuCodec.plainText(null), isEmpty);
      expect(MissevanDanmakuCodec.plainText(7), isEmpty);
      expect(MissevanDanmakuCodec.pkLines['match_start'], '主播正在匹配 PK 对手，请耐心等候');
      expect(MissevanDanmakuCodec.globalPkLines['update'], isNull);
    });
  });
}
