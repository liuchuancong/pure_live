import 'dart:convert';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/kilakila/danmaku/kilakila_danmaku_codec.dart';
import 'package:test/test.dart';

const String _room = '555';
const String _ns = '/live_chat_room_guest';

/// One socket.io event frame of the guest namespace: `42<ns>,["name","payload"]`
/// with the payload a JSON string, as the live page sends it.
String _event(String name, Object? payload) => '42$_ns,${jsonEncode([name, jsonEncode(payload)])}';

/// A `text_message` frame whose response carries this content.
String _text({Object? content, Object? roomId = _room, Object? mid = 'm1', Object? at}) {
  final response = <String, Object?>{
    'room_id': ?roomId,
    'mid': mid,
    'created_at': ?at,
    'content': content == null
        ? null
        : content is String
        ? content
        : jsonEncode(content),
  };
  return _event('text_message', {
    'body': {'response': response},
  });
}

/// A chat content (`t` 200).
Map<String, Object?> _chatContent({
  int t = KilakilaDanmakuCodec.chatType,
  Object? c = '你好',
  Object? n = 'Ann',
  Object? u = 12,
  Object? l,
}) => {'t': t, 'c': ?c, 'n': ?n, 'u': ?u, 'l': ?l};

/// A room state (`t` 637) whose `c` is the URL-encoded JSON the page sends.
Map<String, Object?> _stateContent(Object? state, {bool encode = true}) => {
  't': KilakilaDanmakuCodec.roomStateType,
  'c': encode ? Uri.encodeComponent(jsonEncode(state)) : state,
};

/// A board question whose `uc.question` fields the page writes encoded.
Map<String, Object?> _question({
  Object? uiType = 2,
  Object? content,
  Object? goldPrice = 6000,
  Object? nickname = 'Ann',
  Object? questionId = 'q1',
  Object? uid = 33,
  Object? headUrl,
  bool encoded = true,
}) => {
  't': 240,
  'uc': {
    'uiType': ?uiType,
    'question': {
      'content': content ?? '想要一首歌',
      'goldPrice': ?goldPrice,
      'questionNickname': ?nickname,
      'questionId': ?questionId,
      'questionUid': ?uid,
      'questionHeadUrl': ?headUrl,
    }.map((key, value) => MapEntry(key, encoded && value is String ? Uri.encodeComponent(value) : value)),
  },
};

/// A gift (220 the animation, 10004 the combo's line) with its `c` object.
Map<String, Object?> _gift({
  int t = KilakilaDanmakuCodec.giftType,
  Object? name = '念念相守',
  Object? count,
  Object? price = 30,
  Object? no = 'combo-1',
  bool hit = false,
  Object? pic,
  Object? receiver,
  Object? id = 9,
  Object? level,
}) => {
  't': t,
  'c': {
    'name': ?name,
    'price': ?price,
    'no': ?no,
    'id': ?id,
    'pic': ?pic,
    'giftReceiverName': ?receiver,
    'isDoubleHit': hit ? true : null,
    'doubleCount': ?count,
    'u': 12,
    'l': ?level,
  },
  'n': 'Ann',
  'u': 12,
};

KilakilaDanmakuFrame _read(String data) => KilakilaDanmakuCodec.decode(data, roomId: _room);

/// The single message of one frame, or null when it gives nothing.
LiveMessage? _one(String data) => _read(data).messages.singleOrNull;

/// The one message of a `text_message` frame whose content is [body].
LiveMessage? _of(Map<String, Object?> body, {Object? roomId = _room, Object? at}) =>
    _one(_text(content: body, roomId: roomId, at: at));

void main() {
  group('the socket and its packets', () {
    test('the address, the join and the keep-alive', () {
      final uri = KilakilaDanmakuCodec.endpoint(_room);
      expect(uri.scheme, 'wss');
      expect(uri.host, 'wim.hongrenshuo.com.cn');
      expect(uri.path, '/socket.io/');
      expect(uri.queryParameters['roomId'], _room);
      expect(uri.queryParameters['appId'], '111');
      expect(uri.queryParameters['clientType'], '1');
      expect(uri.queryParameters['EIO'], '3');
      expect(uri.queryParameters['transport'], 'websocket');
      expect(KilakilaDanmakuCodec.join(_room), '40$_ns?roomId=555&appId=111&clientType=1,');
      expect(KilakilaDanmakuCodec.ping, '2');
    });

    test('the budgets, the kinds and the currency', () {
      expect(KilakilaDanmakuCodec.namespace, _ns);
      expect(KilakilaDanmakuCodec.heartbeatInterval, const Duration(seconds: 25));
      expect(KilakilaDanmakuCodec.silenceTimeout, const Duration(seconds: 90));
      expect(KilakilaDanmakuCodec.joinTimeout, const Duration(seconds: 8));
      expect(KilakilaDanmakuCodec.maxRefusals, 3);
      expect(KilakilaDanmakuCodec.maxReconnects, 8);
      expect(KilakilaDanmakuCodec.reconnectBaseDelay, const Duration(seconds: 1));
      expect(KilakilaDanmakuCodec.handshakeHeaders['origin'], isNotNull);
      expect(KilakilaDanmakuCodec.chatType, 200);
      expect(KilakilaDanmakuCodec.roomStateType, 637);
      expect(KilakilaDanmakuCodec.giftType, 220);
      expect(KilakilaDanmakuCodec.giftLineType, 10004);
      expect(KilakilaDanmakuCodec.questionAskedType, 241);
      expect(KilakilaDanmakuCodec.boardTypes, {240, 300, 301, 532, 534, 706});
      expect(KilakilaDanmakuCodec.questionUiTypes, {2, 3, 6, 7, 10, 11, 14, 15});
      expect(KilakilaDanmakuCodec.questionDisplay, const Duration(minutes: 5));
      expect(KilakilaDanmakuCodec.currency, '红豆');
    });

    test('the engine.io frames the socket itself speaks', () {
      expect(_read('0').joined, isFalse, reason: 'the open packet is not the join');
      expect(_read('3').dropped, isFalse, reason: 'a pong is not a drop');
      expect(_read('6').messages, isEmpty);
      expect(_read('1').dropped, isTrue, reason: 'the server is closing');
      expect(_read('').messages, isEmpty);
      expect(_read('x').messages, isEmpty);
      expect(KilakilaDanmakuCodec.decode(null, roomId: _room).messages, isEmpty);
      expect(KilakilaDanmakuCodec.decode([0xFF], roomId: _room).messages, isEmpty, reason: 'binary frames');
      expect(KilakilaDanmakuFrame.empty.messages, isEmpty);
    });

    test('the namespace decides whether the packet is ours', () {
      expect(_read('40$_ns,').joined, isTrue);
      expect(_read('40$_ns').joined, isTrue, reason: 'the comma may be absent at the end');
      expect(_read('40/live_chat_room,').joined, isFalse, reason: 'another namespace');
      expect(_read('40$_ns?x,').joined, isFalse, reason: 'the packet data must follow a comma');
      expect(_read('41$_ns,').dropped, isTrue);
      expect(_read('44$_ns,"gone"').refusal, 'gone');
      expect(_read('44$_ns,').refusal, 'error', reason: 'an empty body still names itself');
      expect(_read('44$_ns,${jsonEncode({'message': 'room closed'})}').refusal, 'room closed');
      expect(_read('44$_ns,${jsonEncode({'message': ''})}').refusal, '{"message":""}');
      expect(_read('44$_ns,not json').refusal, 'not json', reason: 'a body that is not JSON is its own text');
      expect(_read('45$_ns,').messages, isEmpty);
    });

    test('the connect error is a join only when its code says so', () {
      expect(_read(_event('connect_error', {'code': 0})).joined, isTrue);
      expect(_read(_event('connect_error', {'code': 1002})).refusal, 'code 1002');
      expect(
        _read(_event('connect_error', {'code': 1002, 'message': 'no room'})).refusal,
        'no room',
        reason: 'the platform’s own words come first',
      );
      expect(
        _read(
          '42$_ns,${jsonEncode([
            'text_message',
            {'other': 1},
          ])}',
        ).messages,
        isEmpty,
        reason: 'a payload that is not a JSON string',
      );
      expect(_read('42$_ns,[7]').messages, isEmpty, reason: 'an event without a name and a payload');
      expect(_read('42$_ns,${jsonEncode(['other_event', '{}'])}').messages, isEmpty);
      expect(_read('42$_ns,${jsonEncode(['text_message', 'not json'])}').messages, isEmpty);
    });
  });

  group('the message of a text_message', () {
    test('only this broadcast’s lines, and only the kinds the page shows', () {
      expect(_of(_chatContent())!.text, '你好');
      expect(_of(_chatContent(), roomId: '999'), isNull);
      expect(_of(_chatContent(), roomId: 555)!.text, '你好', reason: 'the id may be a number');
      expect(_of(_chatContent(), roomId: null)!.text, '你好', reason: 'a line naming no room is ours');
      expect(_of({'t': 103}), isNull, reason: 'the broadcast ended');
      expect(_of({'t': 210}), isNull, reason: 'likes');
      expect(_of({'t': 603}), isNull, reason: 'entries');
      expect(_of(_question(goldPrice: 100)), isNotNull, reason: 'a board question is shown');
      expect(_of(_chatContent(t: 241)), isNull, reason: 'a question being asked is not');
      expect(_one(_text(content: 'not json')), isNull);
      expect(_one(_text()), isNull, reason: 'no content at all');
      expect(
        _read(
          _event('text_message', {
            'body': {
              'response': {'t': 200},
            },
          }),
        ).messages,
        isEmpty,
      );
    });

    test('a chat line carries its name, level, id and time', () {
      final message = _of(_chatContent(l: '7'), at: 1790733600000)!;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, '你好');
      expect(message.sender?.userName, 'Ann');
      expect(message.sender?.userId, '12');
      expect(message.sender?.userLevel, '7');
      expect(message.messageId, 'm1');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1790733600000));
      expect(message.color, LiveMessageColor.white);

      expect(_of(_chatContent(c: '   ')), isNull, reason: 'nothing to show');
      expect(_of(_chatContent(c: 7)), isNull, reason: 'text that is not text');
      expect(_of(_chatContent(c: ' x '))!.text, 'x', reason: 'trimmed');
      expect(_of(_chatContent(n: 7))!.sender?.userName, isEmpty, reason: 'a name is text only');
      expect(_of(_chatContent(l: 'x'))!.sender?.userLevel, isEmpty, reason: 'a level is a number');
      expect(_of(_chatContent(l: 2.0))!.sender?.userLevel, isEmpty, reason: 'a level written as a double is not one');
      expect(_of(_chatContent(u: null))!.sender?.userId, isEmpty);
      expect(_one(_text(content: _chatContent(), mid: 42))!.messageId, '42');
      expect(_one(_text(content: _chatContent(), mid: null))!.messageId, isEmpty);
      expect(_one(_text(content: _chatContent()))!.sentAt, isNull);
    });

    test('a time is a positive whole number of milliseconds only', () {
      DateTime? at(Object? value) => _of(_chatContent(), at: value)?.sentAt;
      expect(at(1790733600000), DateTime.fromMillisecondsSinceEpoch(1790733600000));
      expect(at(1790733600), DateTime.fromMillisecondsSinceEpoch(1790733600), reason: 'no seconds guess');
      expect(at(0), isNull);
      expect(at(-1), isNull);
      expect(at(8640000000000001), isNull);
      expect(at('1790733600000'), isNull, reason: 'the response writes a number');
      expect(at(1.5), isNull);
    });

    test('the room state’s listeners come from URL-encoded JSON', () {
      final message = _of(_stateContent({'watchNumber': 42}))!;
      expect(message.type, LiveMessageType.audienceUpdate);
      final audience = message.payload! as LiveAudienceUpdate;
      expect(audience.value, 42);
      expect(
        _of(_stateContent({'watchNumber': 0}))!.type,
        LiveMessageType.audienceUpdate,
        reason: 'nobody listening is still a figure',
      );
      expect(_of(_stateContent({'watchNumber': -1})), isNull);
      expect(_of(_stateContent({'watchNumber': '42'})), isNull, reason: 'a number, not text');
      expect(_of(_stateContent({'other': 1})), isNull);
      expect(_of(_stateContent({'watchNumber': 42}, encode: false)), isNull, reason: 'the page sends it encoded');
      expect(_of(_stateContent('not json')), isNull);
      expect(_of(_chatContent(c: '%zz')), isNotNull, reason: 'a chat is never decoded');
    });
  });

  group('the board question', () {
    test('a paid question is a super chat for five minutes', () {
      final message = _of(_question(), at: 1790733600000)!;
      expect(message.type, LiveMessageType.superChat);
      expect(message.text, '想要一首歌', reason: 'Chinese text with no escapes stays as it is');
      expect(message.messageId, 'q1');
      expect(message.sender?.userName, 'Ann');
      expect(message.sender?.userId, '33');
      final paid = message.payload! as LiveSuperChatMessage;
      expect(paid.price.amount, 6000);
      expect(paid.price.currency, '红豆');
      expect(paid.price.displayText, '6,000红豆');
      expect(paid.startTime, DateTime.fromMillisecondsSinceEpoch(1790733600000));
      expect(paid.endTime!.difference(paid.startTime!), KilakilaDanmakuCodec.questionDisplay);
      expect(paid.faceUrl, isEmpty, reason: 'no picture named');
    });

    test('the board’s own kinds and shapes', () {
      for (final uiType in KilakilaDanmakuCodec.questionUiTypes) {
        expect(_of(_question(uiType: uiType)), isNotNull, reason: 'ui $uiType');
      }
      expect(_of(_question(uiType: 4)), isNull, reason: 'an ui the page does not show');
      expect(_of(_question(uiType: null)), isNull);
      expect(_of({'t': 240}), isNull, reason: 'no uc');
      expect(
        _of({
          't': 240,
          'uc': {'uiType': 2},
        }),
        isNull,
        reason: 'no question',
      );
      expect(_of(_question(content: '   ')), isNull, reason: 'no text');
      expect(_of(_question(goldPrice: null)), isNull, reason: 'a free question is not a super chat');
      expect(_of(_question(goldPrice: 0)), isNull);
      expect(_of(_question(goldPrice: -100)), isNull);
      expect(_of(_question(goldPrice: '6000')), isNotNull, reason: 'text digits are a price');
      expect(_of(_question(nickname: null))!.sender?.userName, isEmpty);
      expect(_of(_question(questionId: null))!.messageId, isEmpty);
    });

    test('every field is percent-decoded, and one broken escape loses the question', () {
      expect(_of(_question(content: 'a%E4%BD%A0b', encoded: false))!.text, 'a你b');
      expect(
        _of(_question(content: 'bad %zz', encoded: false)),
        isNull,
        reason: 'where JavaScript’s decodeURIComponent throws, nothing is shown',
      );
      expect(_of(_question(content: 'cut %E4%BD', encoded: false)), isNull, reason: 'half of a UTF-8 sequence');
      expect(_of(_question(content: '100%25', encoded: false))!.text, '100%');
      expect(
        (_of(_question(headUrl: 'https://cdn.test/a.png'))!.payload! as LiveSuperChatMessage).faceUrl,
        'https://cdn.test/a.png',
        reason: 'the page writes the picture encoded, and it comes back whole',
      );
      expect(
        (_of(_question(headUrl: 'http://cdn.test/a.png'))!.payload! as LiveSuperChatMessage).faceUrl,
        '',
        reason: 'https only',
      );
      expect((_of(_question(headUrl: 'a.png'))!.payload! as LiveSuperChatMessage).faceUrl, '');
    });

    test('an amount is written with the page’s commas', () {
      expect(KilakilaDanmakuCodec.amount(0), '0');
      expect(KilakilaDanmakuCodec.amount(999), '999');
      expect(KilakilaDanmakuCodec.amount(1000), '1,000');
      expect(KilakilaDanmakuCodec.amount(6000), '6,000');
      expect(KilakilaDanmakuCodec.amount(1234567), '1,234,567');
      expect(KilakilaDanmakuCodec.amount(-6000), '-6,000');
      expect(KilakilaDanmakuCodec.amount(1000000000), '1,000,000,000');
    });
  });

  group('gifts and their combos', () {
    test('a gift picture is https or nothing, and the unit follows the price', () {
      final paid = _of(_gift(pic: 'https://cdn.test/a.png'), at: 1790733600000)!;
      expect(paid.type, LiveMessageType.gift);
      expect(paid.text, '念念相守 ×1');
      expect((paid.payload! as LiveGift).iconUrl, 'https://cdn.test/a.png');
      expect((paid.payload! as LiveGift).giftId, '9');
      expect((paid.payload! as LiveGift).value.unit, LiveGiftUnit.redBean);
      expect((_of(_gift(pic: 'http://cdn.test/a.png'))!.payload! as LiveGift).iconUrl, isNull);
      expect((_of(_gift())!.payload! as LiveGift).iconUrl, isNull);
      expect((_of(_gift(price: 0))!.payload! as LiveGift).value.unit, LiveGiftUnit.free);
      expect((_of(_gift(price: 0))!.payload! as LiveGift).value.totalValue, isNull);
      expect(_of(_gift(name: '  ')), isNull, reason: 'a gift with no name');
      expect(_of(_gift(receiver: ' 主播 ')), isNotNull);
      expect((_of(_gift(receiver: '主播'))!.payload! as LiveGift).recipientName, '主播');
      expect(_of({'t': 220}), isNull, reason: 'no c object');
    });

    test('a combo key is the platform’s number, shared by hits and the line', () {
      final hit = _of(_gift(count: 3, hit: true))!;
      final line = _of(_gift(t: KilakilaDanmakuCodec.giftLineType, count: 3))!;
      expect((hit.payload! as LiveGift).combo.comboKey, 'combo-1');
      expect((hit.payload! as LiveGift).combo.comboTotal, 3, reason: 'a hit counts the combo so far');
      expect((line.payload! as LiveGift).combo.comboTotal, 3, reason: 'so does its line');
      expect((line.payload! as LiveGift).value.unitPrice, 30, reason: 'the line prices one gift');
      expect((line.payload! as LiveGift).count, 3);
      expect(
        (_of(_gift(count: 3))!.payload! as LiveGift).combo.comboTotal,
        isNull,
        reason: 'an animation of one gift is not a combo count',
      );
      expect((_of(_gift(count: 3, price: 90))!.payload! as LiveGift).value.unitPrice, 30);
      expect(
        (_of(_gift(count: 4, price: 90))!.payload! as LiveGift).value.unitPrice,
        isNull,
        reason: 'a price that does not divide its count is not split',
      );
      expect((_of(_gift(no: null))!.payload! as LiveGift).combo.comboKey, isEmpty);
      expect((_of(_gift(count: 0))!.payload! as LiveGift).count, 1, reason: 'a count of zero still shows one');
      expect((_of(_gift(count: -2))!.payload! as LiveGift).count, 1);
    });

    test('the combo filter shows one count per combo', () {
      final seen = KilakilaGiftCombos();
      LiveMessage hit(int count, {String no = 'combo-1'}) => _of(_gift(count: count, no: no, hit: true))!;
      expect(seen.report(hit(1)), isTrue);
      expect(seen.report(hit(2)), isTrue);
      expect(seen.report(hit(2)), isFalse, reason: 'the same count of the same combo is not a new one');
      expect(seen.report(hit(1)), isFalse, reason: 'nor a smaller one');
      expect(seen.report(hit(3, no: 'combo-2')), isTrue, reason: 'another combo is another line');
      expect(seen.report(_of(_chatContent())!), isTrue, reason: 'a chat is never filtered');
      expect(seen.report(_of(_gift(count: 3))!), isTrue, reason: 'an animation has no combo total to compare');
      expect(seen.report(_of(_gift(no: null, count: 3, hit: true))!), isTrue, reason: 'nor has a gift with no key');
    });

    test('the oldest combo goes when the memory is full', () {
      final seen = KilakilaGiftCombos();
      LiveMessage hit(String no) => _of(_gift(count: 1, no: no, hit: true))!;
      for (var index = 0; index < KilakilaGiftCombos.capacity; index++) {
        expect(seen.report(hit('c$index')), isTrue);
      }
      expect(seen.report(hit('c0')), isFalse, reason: 'the first is still remembered, and now the newest');
      expect(seen.report(hit('brand-new')), isTrue, reason: 'the six-hundred-and-fiftieth pushes one out');
      expect(seen.report(hit('c1')), isTrue, reason: 'the oldest combo was the one forgotten');
      expect(seen.report(hit('c0')), isFalse, reason: 'the newest is kept');
    });
  });
}
