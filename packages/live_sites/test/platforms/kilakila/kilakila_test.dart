import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/kilakila/danmaku/kilakila_danmaku_codec.dart';
import 'package:test/test.dart';

const String _room = '555';

/// A gift frame of [type] carrying [item].
Map<Object?, Object?> _frame(int type, Map<Object?, Object?> item) => {
  'body': {
    'response': {
      'room_id': _room,
      'mid': 'm1',
      'created_at': 1790733600000,
      'content': {
        't': type,
        'n': 'Ann',
        'u': 1001,
        'l': 7,
        'c': {
          'id': 9,
          'name': '念念相守',
          'no': 'k1',
          'giftReceiverName': '主播',
          'pic': 'https://a.example.com/g.png',
          ...item,
        },
      },
    },
  },
};

void main() {
  group('gifts', () {
    test('a single gift carries its red-bean price', () {
      final message = KilakilaDanmakuCodec.textMessage(
        _frame(KilakilaDanmakuCodec.giftType, {'doubleCount': 1, 'price': 100}),
        roomId: _room,
      )!;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, '念念相守 ×1');
      expect(message.messageId, 'm1');
      expect(message.sender?.userId, '1001');
      expect(message.sender?.userName, 'Ann');
      expect(message.sender?.userLevel, '7');
      final gift = message.giftOrNull! as LiveGift;
      expect(gift.giftId, '9');
      expect(gift.value.unit, LiveGiftUnit.redBean);
      expect(gift.value.unitPrice, 100);
      expect(gift.value.totalValue, 100);
      expect(gift.combo.comboKey, 'k1');
      expect(gift.combo.comboTotal, isNull);
      expect(gift.recipientName, '主播');
    });

    test('a combo hit counts the whole combo so far', () {
      final message = KilakilaDanmakuCodec.textMessage(
        _frame(KilakilaDanmakuCodec.giftType, {'doubleCount': 3, 'price': 300, 'isDoubleHit': true}),
        roomId: _room,
      )!;
      final gift = message.giftOrNull! as LiveGift;
      expect(gift.count, 3);
      expect(gift.value.totalValue, 300);
      expect(gift.value.unitPrice, 100);
      expect(gift.combo.comboTotal, 3);
    });

    test('a combo line prices one gift and finishes the combo', () {
      final message = KilakilaDanmakuCodec.textMessage(
        _frame(KilakilaDanmakuCodec.giftLineType, {'doubleCount': 2, 'price': 200}),
        roomId: _room,
      )!;
      final gift = message.giftOrNull! as LiveGift;
      expect(gift.count, 2);
      expect(gift.value.unitPrice, 200);
      expect(gift.value.totalValue, 400, reason: 'the line prices one gift; the total is all of the count');
      expect(gift.combo.comboTotal, 2);
    });

    test('a line and the hit it closes value the same combo alike', () {
      // 飞天小猪: the third hit sends 204 for all three, its line 68 each.
      final hit = KilakilaDanmakuCodec.textMessage(
        _frame(KilakilaDanmakuCodec.giftType, {'doubleCount': 3, 'price': 204, 'isDoubleHit': true}),
        roomId: _room,
      )!;
      final line = KilakilaDanmakuCodec.textMessage(
        _frame(KilakilaDanmakuCodec.giftLineType, {'doubleCount': 3, 'price': 68}),
        roomId: _room,
      )!;
      expect((hit.giftOrNull! as LiveGift).value.totalValue, 204);
      expect((line.giftOrNull! as LiveGift).value.totalValue, 204);
      expect((hit.giftOrNull! as LiveGift).value.unitPrice, 68);
      expect((line.giftOrNull! as LiveGift).value.unitPrice, 68);
    });

    test('a free gift has no value, and another room or no name is nothing', () {
      final free = KilakilaDanmakuCodec.textMessage(
        _frame(KilakilaDanmakuCodec.giftType, {'doubleCount': 1, 'price': 0}),
        roomId: _room,
      )!;
      expect((free.giftOrNull! as LiveGift).value.unit, LiveGiftUnit.free);
      expect(
        KilakilaDanmakuCodec.textMessage(_frame(KilakilaDanmakuCodec.giftType, {'price': 1}), roomId: '999'),
        isNull,
      );
    });
  });
}
