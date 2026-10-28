import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/missevan/danmaku/missevan_danmaku_codec.dart';
import 'package:test/test.dart';

/// A `gift`/`send` item priced in diamonds.
Map<String, Object?> _gift({int price = 20, int num = 2, String order = '77'}) => {
  'oid': order,
  'time': 1790733600000,
  'gift': {
    'gift_id': 'gd1',
    'name': '幻彩礼炮',
    'num': num,
    'price': price,
    'icon_url': 'https://static.missevan.com/gift/1.png',
  },
  'combo': {'id': 'c1', 'num': 5},
  'user': {'user_id': '1001', 'username': 'Ann'},
};

/// A paid question (the site's super chat).
Map<String, Object?> _question({int price = 5, String text = '这是什么歌？'}) => {
  'question': {
    'question_id': 'q1',
    'question': text,
    'price': price,
    'created_time': '1790733600000',
    'iconurl': 'https://static.missevan.com/avatar/1.png',
  },
  'user': {'user_id': '1002', 'username': 'Bob'},
};

void main() {
  group('gifts (gift/send)', () {
    test('a gift carries its diamonds, combo and receiver-less line', () {
      final message = MissevanDanmakuCodec.gift(_gift())!;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, '幻彩礼炮 ×2');
      expect(message.messageId, '77');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1790733600000));
      expect(message.sender?.userId, '1001');
      final gift = message.giftOrNull! as LiveGift;
      expect(gift.giftId, 'gd1');
      expect(gift.count, 2);
      expect(gift.value.unit, LiveGiftUnit.diamond);
      expect(gift.value.unitPrice, 20);
      expect(gift.value.totalValue, 40);
      expect(gift.combo.comboKey, 'c1');
      expect(gift.combo.comboTotal, 5);
      expect(gift.iconUrl, 'https://static.missevan.com/gift/1.png');
    });

    test('a free gift has no value, and a nameless gift is none', () {
      final gift = MissevanDanmakuCodec.gift(_gift(price: 0))!.giftOrNull! as LiveGift;
      expect(gift.value.unit, LiveGiftUnit.free);
      expect(gift.value.totalValue, isNull);
      expect(
        MissevanDanmakuCodec.gift({
          'gift': {'num': 1},
        }),
        isNull,
      );
    });
  });

  group('paid questions (super chats)', () {
    final received = DateTime.fromMillisecondsSinceEpoch(1790733600000);

    test('a question is a diamond-priced super chat for a minute', () {
      final message = MissevanDanmakuCodec.question(_question(), receivedAt: received)!;
      expect(message.type, LiveMessageType.superChat);
      expect(message.text, '这是什么歌？');
      expect(message.messageId, 'q1');
      expect(message.sender?.userId, '1002');
      expect(message.sender?.userName, 'Bob');
      final chat = message.payload! as LiveSuperChatMessage;
      expect(chat.price.amount, 5);
      expect(chat.price.currency, MissevanDanmakuCodec.currency);
      expect(chat.startTime, received);
      expect(chat.endTime, received.add(MissevanDanmakuCodec.questionDuration));
      expect(chat.faceUrl, 'https://static.missevan.com/avatar/1.png');
    });

    test('a question without text or price is no super chat', () {
      expect(
        MissevanDanmakuCodec.question({
          'question': {'price': 5},
        }, receivedAt: received),
        isNull,
      );
      expect(
        MissevanDanmakuCodec.question({
          'question': {'question': 'x', 'price': -1},
        }, receivedAt: received),
        isNull,
      );
    });
  });
}
