import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_danmaku_codec.dart';
import 'package:test/test.dart';

const String _room = '555';

/// A 601 gift packet of room [_room].
Map<String, Object?> _packet({
  String item = '77',
  String name = '玫瑰',
  int num = 2,
  int price = 10,
  String? comboV2 = 'c1',
  int comboSum = 4,
  String image = '/fxstatic/images/giftres/rose.png',
}) => {
  'roomid': _room,
  'msgId': 'm1',
  'time': 1790733600000,
  'content': {
    'roomid': _room,
    'giftid': item,
    'giftname': name,
    'num': num,
    'price': price,
    'comboIdV2': ?comboV2,
    'comboGiftSum': comboSum,
    'sendername': 'Ann',
    'senderid': '1001',
    'receivername': '主播',
    'image': image,
    'senderrichlevelV2': 12,
  },
};

void main() {
  group('gifts (601)', () {
    test('a gift carries its star-coin worth, combo and receiver', () {
      final message = KugouliveDanmakuCodec.gift(_packet(), roomId: _room)!;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, '玫瑰 ×2');
      expect(message.messageId, 'm1');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1790733600000));
      expect(message.sender?.userId, '1001');
      expect(message.sender?.userName, 'Ann');
      expect(message.sender?.userLevel, '12');

      final gift = message.giftOrNull! as LiveGift;
      expect(gift.giftId, '77');
      expect(gift.name, '玫瑰');
      expect(gift.count, 2);
      expect(gift.value.unit, LiveGiftUnit.starCoin);
      expect(gift.value.unitPrice, 10);
      expect(gift.value.totalValue, 20);
      expect(gift.combo.comboKey, 'c1');
      expect(gift.combo.comboTotal, 4);
      expect(gift.recipientName, '主播');
      expect(gift.iconUrl, 'https://s4fx.kgimg.com/fxstatic/images/giftres/rose.png');
    });

    test('a free gift has the free unit, and another room is no gift', () {
      final gift = KugouliveDanmakuCodec.gift(_packet(price: 0), roomId: _room)!.giftOrNull! as LiveGift;
      expect(gift.value.unit, LiveGiftUnit.free);
      expect(gift.value.totalValue, 0);
      expect(KugouliveDanmakuCodec.gift(_packet(), roomId: '999'), isNull);
      expect(KugouliveDanmakuCodec.gift(_packet(item: '0'), roomId: _room), isNull);
    });

    test('without a combo id the gift has no key but keeps the sends so far', () {
      final gift = KugouliveDanmakuCodec.gift(_packet(comboV2: null), roomId: _room)!.giftOrNull! as LiveGift;
      expect(gift.combo.comboKey, '');
      expect(gift.combo.comboTotal, 4);
    });
  });
}
