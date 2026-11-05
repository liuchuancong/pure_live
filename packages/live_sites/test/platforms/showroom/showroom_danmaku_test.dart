import 'dart:convert';

import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/showroom/api/showroom_endpoints.dart';
import 'package:live_sites/src/platforms/showroom/danmaku/showroom_danmaku_codec.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_models.dart';
import 'package:test/test.dart';

const String _key = '6e6c686835796846:23483509';

/// One `MSG` frame of the broadcast key carrying this event (or raw text).
String _frame(Object? event, {String frameKey = _key}) =>
    'MSG\t$frameKey\t${event is String ? event : jsonEncode(event)}';

/// A comment event (`t` 1).
Map<String, Object?> _commentEvent({
  Object? t = 1,
  Object? cm = 'こんにちは',
  Object? ac = '視聴者',
  Object? u = 'u1',
  Object? cl,
  Object? createdAt = 1790733600,
}) => {'t': ?t, 'cm': ?cm, 'ac': ?ac, 'u': ?u, 'cl': ?cl, 'created_at': ?createdAt};

/// A gift event (`t` 2) naming one gift id.
Map<String, Object?> _giftEvent({Object? g = '12', Object? n = 1, Object? gt, Object? cl}) => {
  't': 2,
  'g': ?g,
  'n': ?n,
  'gt': ?gt,
  'cl': ?cl,
  'ac': '送礼的',
  'u': 'u1',
  'created_at': 1790733600,
};

List<LiveMessage> _decode(
  Object? data, {
  String frameKey = _key,
  ShowroomGiftCatalog gifts = ShowroomGiftCatalog.empty,
}) => ShowroomDanmakuCodec.decode(data, key: frameKey, gifts: gifts);

void main() {
  group('the socket and its frames', () {
    test('the comment server, its subscription and its keep-alive', () {
      expect(
        ShowroomDanmakuCodec.endpoint('bcsvr001.showroom-live.com').toString(),
        'wss://bcsvr001.showroom-live.com/',
      );
      expect(ShowroomDanmakuCodec.subscribe(_key), 'SUB\t$_key');
      expect(ShowroomDanmakuCodec.ping, 'PING\tshowroom');
      expect(ShowroomDanmakuCodec.ack, 'ACK\tshowroom');
      expect(ShowroomDanmakuCodec.heartbeatInterval, const Duration(seconds: 60));
      expect(ShowroomDanmakuCodec.silenceTimeout, const Duration(seconds: 180));
      expect(ShowroomDanmakuCodec.maxReconnects, 8);
      expect(ShowroomDanmakuCodec.reconnectBaseDelay, const Duration(seconds: 1));
      expect(ShowroomDanmakuCodec.commentType, 1);
      expect(ShowroomDanmakuCodec.giftType, 2);
      expect(ShowroomDanmakuCodec.socketHeaders['origin'], ShowroomEndpoints.origin);
      expect(ShowroomDanmakuCodec.giftImage('12').toString(), 'https://static.showroom-live.com/image/gift/12_s.png');
    });

    test('only a MSG frame of this broadcast is read', () {
      expect(_decode(_frame(_commentEvent())).single.text, 'こんにちは');
      expect(
        _decode(_frame(_commentEvent(), frameKey: 'other.key')).map((message) => message.text),
        isEmpty,
        reason: 'another broadcast’s frame',
      );
      expect(_decode('ACK\tshowroom'), isEmpty, reason: 'the server’s own ack');
      expect(_decode('PING\tshowroom'), isEmpty);
      expect(_decode('MSG\t$_key'), isEmpty, reason: 'a frame with no payload');
      expect(
        _decode('MSG\tkey-with	a-tab\t${jsonEncode(_commentEvent())}'),
        isEmpty,
        reason: 'the key is read up to the next tab',
      );
      expect(_decode('MSG\t$_key\nsecond line\t{}'), isEmpty, reason: 'a stray newline leaves a frame we cannot place');
      expect(_decode('MSG\t$_key\tnot json'), isEmpty);
      expect(_decode('MSG\t$_key\t[1,2]'), isEmpty, reason: 'an array is not an event');
      expect(_decode(7), isEmpty);
      expect(_decode(utf8.encode(_frame(_commentEvent()))).single.text, 'こんにちは', reason: 'bytes are decoded');
      expect(_decode([0xFF, 0xFF]).isEmpty, isTrue, reason: 'malformed bytes are replaced, not thrown');
    });

    test('the arguments are kept only when the server and the key are usable', () {
      ShowroomDanmakuArgs? checked(String host, String key) =>
          ShowroomDanmakuCodec.checked(ShowroomDanmakuArgs(roomId: '456', host: host, key: key));
      final kept = checked('BCSVR001.SHOWROOM-LIVE.COM', _key)!;
      expect(kept.host, 'bcsvr001.showroom-live.com', reason: 'lower-cased, as the site writes it');
      expect(kept.key, _key);
      expect(kept.roomId, '456', reason: 'the room id rides through untouched');
      expect(checked('evil.test', _key), isNull);
      expect(checked('showroom-live.com.evil.test', _key), isNull);
      expect(checked('bcsvr001.showroom-live.com', 'has space'), isNull);
      expect(checked('bcsvr001.showroom-live.com', 'a' * 257), isNull);
      expect(checked('bcsvr001.showroom-live.com', ''), isNull);
    });
  });

  group('a comment', () {
    test('a comment carries its text, name, level and seconds', () {
      final message = _decode(_frame(_commentEvent(cl: 7))).single;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'こんにちは');
      expect(message.sender?.userName, '視聴者');
      expect(message.sender?.userId, 'u1');
      expect(message.sender?.userLevel, '7');
      expect(message.color, LiveMessageColor.white);
      expect(message.messageId, isEmpty, reason: 'the platform sends no message id');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1790733600 * 1000));
    });

    test('the text may be a number, and everything else is not a comment', () {
      expect(_decode(_frame(_commentEvent(cm: 3))).single.text, '3', reason: 'a counting comment');
      expect(_decode(_frame(_commentEvent(cm: '  '))), isEmpty, reason: 'blank');
      expect(_decode(_frame(_commentEvent(cm: null))), isEmpty, reason: 'absent');
      expect(_decode(_frame(_commentEvent(cm: 1.5))), isEmpty, reason: 'a double is neither text nor a count');
      expect(_decode(_frame(_commentEvent(cm: ['x']))), isEmpty);
      expect(_decode(_frame(_commentEvent(t: '1'))), hasLength(1), reason: 'the kind may be written as text');
      expect(_decode(_frame(_commentEvent(t: 2))), isEmpty, reason: 'a gift is not a comment');
      expect(_decode(_frame(_commentEvent(t: 9))), isEmpty);
      expect(_decode(_frame({'cm': 'no kind at all'})), isEmpty);
    });

    test('a class level shows only above zero, and a time only within the clock', () {
      String? level(Object? value) => _decode(_frame(_commentEvent(cl: value))).single.sender!.userLevel;
      expect(level(0), isEmpty, reason: 'the web shows “Class” only above zero');
      expect(level(-2), isEmpty);
      expect(level('3'), isEmpty, reason: 'a text level is not read');
      expect(level(2.0), isEmpty);
      DateTime? at(Object? value) => _decode(_frame(_commentEvent(createdAt: value))).singleOrNull?.sentAt;
      expect(at(1790733600), DateTime.fromMillisecondsSinceEpoch(1790733600 * 1000));
      expect(at(0), isNull);
      expect(at(-1), isNull);
      expect(at('1790733600'), isNull, reason: 'a time written as text is not read');
      expect(at(8640000000000), isNotNull);
      expect(at(8640000000001), isNull);
      expect(_decode(_frame(_commentEvent(createdAt: null))).single.sentAt, isNull);
    });

    test('an event naming no sender still shows its line', () {
      final message = _decode(_frame(_commentEvent(ac: null, u: null))).single;
      expect(message.sender?.userName, isEmpty);
      expect(message.sender?.userId, isEmpty);
    });
  });

  group('a gift', () {
    test('a gift of an unknown kind is not read, and the id may be a number', () {
      final message = _decode(_frame(_giftEvent(g: 12))).single;
      expect(message.type, LiveMessageType.gift);
      expect((message.payload! as LiveGift).giftId, '12');
      expect(message.text, '×1', reason: 'without the room’s table the gift has no name, and a line is trimmed');
      expect((_decode(_frame(_giftEvent(gt: 2))).single.payload! as LiveGift).value.unit, LiveGiftUnit.free);
      expect(_decode(_frame(_giftEvent(g: '0'))), isEmpty, reason: 'id 0 is no gift');
      expect(_decode(_frame(_giftEvent(g: ''))), isEmpty);
      expect(_decode(_frame(_giftEvent(g: null))), isEmpty);
      expect(_decode(_frame(_giftEvent(g: 1.5))), isEmpty, reason: 'a double id is neither text nor a number');
      expect(_decode(_frame({'t': '1', 'g': '12'})), isEmpty, reason: 'a comment is not a gift');
    });

    test('the count is the platform’s number, and the paid total counts at least one', () {
      LiveGift giftOf(Object? count) {
        final messages = _decode(
          _frame(_giftEvent(n: count)),
          gifts: ShowroomGiftCatalog({'12': const ShowroomGiftInfo(name: 'バラ', point: 500, free: false)}),
        );
        return messages.single.payload! as LiveGift;
      }

      expect(giftOf(3).count, 3);
      expect(giftOf(3).value.unitPrice, 500);
      expect(giftOf(3).value.totalValue, 1500);
      expect(giftOf(1).value.totalValue, 500);
      expect(giftOf(0).count, 0, reason: 'the count is written as the platform sent it');
      expect(giftOf(0).value.totalValue, 500, reason: 'but a paid total never pretends there were none');
      expect(giftOf(-2).count, -2);
      expect(giftOf(-2).value.totalValue, 500);
      expect(giftOf('2').count, 1, reason: 'a count written as text is not a number');
      expect(giftOf(null).count, 1);
      expect(_decode(_frame(_giftEvent(n: 3))).single.text, '×3', reason: 'no table: only the name is missing');
    });

    test('the picture is the table’s own, else the platform’s address', () {
      LiveGift giftWith(ShowroomGiftInfo? info) =>
          _decode(
                _frame(_giftEvent()),
                gifts: info == null ? ShowroomGiftCatalog.empty : ShowroomGiftCatalog({'12': info}),
              ).single.payload!
              as LiveGift;
      expect(giftWith(null).iconUrl, 'https://static.showroom-live.com/image/gift/12_s.png');
      expect(
        giftWith(const ShowroomGiftInfo(name: 'バラ', point: 0, free: false)).iconUrl,
        'https://static.showroom-live.com/image/gift/12_s.png',
      );
      expect(
        giftWith(const ShowroomGiftInfo(name: 'バラ', point: 0, free: false)).value.unit,
        LiveGiftUnit.point,
        reason: 'unknown is not free: a gift the table prices nothing for still reads as paid',
      );
      expect(giftWith(const ShowroomGiftInfo(name: 'たね', point: 0, free: true)).value.unit, LiveGiftUnit.free);
      expect(
        giftWith(const ShowroomGiftInfo(name: 'たね', point: 1, free: true)).value.unitPrice,
        isNull,
        reason: 'a free gift’s point is its ranking weight, not money',
      );
    });

    test('a gift line carries its sender, level and time like a comment', () {
      final message = _decode(_frame(_giftEvent(cl: 9))).single;
      expect(message.sender?.userName, '送礼的');
      expect(message.sender?.userId, 'u1');
      expect(message.sender?.userLevel, '9');
      expect(message.messageId, isEmpty, reason: 'the platform gives no id and no combo');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1790733600 * 1000));
    });
  });
}
