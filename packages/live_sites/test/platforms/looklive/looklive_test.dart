import 'dart:convert';

import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/looklive/danmaku/looklive_danmaku_codec.dart';
import 'package:test/test.dart';

/// A `custom` gift frame: `custom.type` 102 with [content].
Map<String, Object?> _frame(Map<String, Object?> content, {int type = 102, Object? customType}) => {
  '1': 'm1',
  '2': 100,
  '4': jsonEncode({'type': customType ?? type, 'content': content}),
  '20': 1790733600000,
  '21': 'from1',
};

/// A gift's `content` priced in notes.
Map<String, Object?> _content({
  int giftId = 7,
  String name = '玫瑰',
  int number = 3,
  int worth = 10,
  String icon = 'http://cdn.example.com/rose.png',
}) => {
  'giftId': giftId,
  'giftName': name,
  'number': number,
  'giftWorth': worth,
  'giftIconUrl': icon,
  'receiver': {'nickName': '主播'},
  'user': {'nickname': '送花的', 'userId': 'u1', 'liveLevel': 12},
};

void main() {
  group('gifts (custom 102)', () {
    test('the gift carries its worth in notes, its picture and who receives it', () {
      final message = LookliveDanmakuCodec.gift(_frame(_content()))!;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, '玫瑰 ×3');
      expect(message.messageId, 'm1');
      expect(message.sender?.userId, 'u1');
      expect(message.sender?.userName, '送花的');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1790733600000));

      final gift = message.giftOrNull! as LiveGift;
      expect(gift.giftId, '7');
      expect(gift.name, '玫瑰');
      expect(gift.count, 3);
      expect(gift.recipientName, '主播');
      expect(gift.iconUrl, 'https://cdn.example.com/rose.png');
      expect(gift.value.unit, LiveGiftUnit.note);
      expect(gift.value.unitPrice, 10);
      expect(gift.value.totalValue, 30);
    });

    test('another custom type, a missing gift id or a broken custom is no gift', () {
      expect(LookliveDanmakuCodec.gift(_frame(_content(), customType: 2601)), isNull);
      expect(LookliveDanmakuCodec.gift(_frame(_content(giftId: 0))), isNull);
      expect(LookliveDanmakuCodec.gift({'2': 100, '4': '{not json'}), isNull);
      expect(LookliveDanmakuCodec.gift({'2': 0, '4': jsonEncode(_frame(_content()))}), isNull);
      expect(LookliveDanmakuCodec.gift('not a map'), isNull);
    });
  });
}
