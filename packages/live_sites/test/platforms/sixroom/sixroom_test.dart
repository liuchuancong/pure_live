import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/sixroom/danmaku/sixroom_danmaku_codec.dart';
import 'package:test/test.dart';

/// A frame time (late September 2026, seconds).
const int _tm = 1790733600;

void main() {
  group('fly screens (108)', () {
    test('a fly-screen is a super chat priced in six coins for one minute', () {
      final message = SixroomDanmakuCodec.fly({'from': '飞屏客', 'fid': 'u1', 'tm': '$_tm', 'content': '老板大气&amp;谢谢'})!;
      expect(message.type, LiveMessageType.superChat);
      expect(message.text, '老板大气&谢谢');
      expect(message.sender?.userId, 'u1');
      expect(message.sender?.userName, '飞屏客');
      final chat = message.payload! as LiveSuperChatMessage;
      expect(chat.price.amount, SixroomDanmakuCodec.flyScreenPrice);
      expect(chat.price.currency, SixroomDanmakuCodec.currency);
      expect(chat.startTime, DateTime.fromMillisecondsSinceEpoch(_tm * 1000));
      expect(chat.endTime, DateTime.fromMillisecondsSinceEpoch(_tm * 1000).add(SixroomDanmakuCodec.flyScreenDuration));
    });

    test('a fly-screen without text is not shown', () {
      expect(SixroomDanmakuCodec.fly({'from': 'x', 'content': ' '}), isNull);
    });
  });

  group('follow fly screens (324)', () {
    test('a follow fly-screen is a 2000-coin super chat of its own id', () {
      final message = SixroomDanmakuCodec.followFly({
        'tm': '$_tm',
        'content': {'type': '1', 'alias': '跟风客', 'uid': 'u2', 'msg': '跟一个', 'id': 7},
      })!;
      expect(message.type, LiveMessageType.superChat);
      expect(message.messageId, 'follow-fly:7');
      expect(message.sender?.userId, 'u2');
      final chat = message.payload! as LiveSuperChatMessage;
      expect(chat.price.amount, SixroomDanmakuCodec.followFlyScreenPrice);
      expect(chat.text, '跟一个');
    });

    test('the other types and empty words are not fly-screens', () {
      expect(
        SixroomDanmakuCodec.followFly({
          'content': {'type': '2', 'msg': 'x'},
        }),
        isNull,
      );
      expect(
        SixroomDanmakuCodec.followFly({
          'content': {'type': '1', 'msg': ''},
        }),
        isNull,
      );
    });
  });

  group('gifts (201)', () {
    test('a gift carries its coins, combo and receiver', () {
      final message = SixroomDanmakuCodec.giftMessage({
        'from': '送礼客',
        'fid': 'u3',
        'to': '主播',
        'askId': 'a1',
        'tm': '$_tm',
        'content': {
          'item': '999',
          'itemName': '火箭',
          'num': 3,
          'giftCoin': 300,
          'isContinue': '1',
          'keep': {'tmp_id': 'abc'},
          'groupnum': 2,
          'aiGiftPic': 'http://cdn.example.com/gift.png',
        },
      })!;
      expect(message.type, LiveMessageType.gift);
      expect(message.messageId, 'a1');
      final gift = message.giftOrNull! as LiveGift;
      expect(gift.giftId, '999');
      expect(gift.name, '火箭');
      expect(gift.count, 3);
      expect(gift.value.unit, LiveGiftUnit.sixCoin);
      expect(gift.value.totalValue, 300);
      expect(gift.value.unitPrice, 100);
      expect(gift.combo.comboKey, 'u3:abc');
      expect(gift.combo.comboTotal, 6);
      expect(gift.recipientName, '主播');
      expect(gift.iconUrl, 'https://cdn.example.com/gift.png');
    });

    test('a stock gift has no value, and a fly-screen purchase is no gift', () {
      final stock = SixroomDanmakuCodec.giftMessage({
        'from': '库存客',
        'fid': 'u4',
        'content': {'item': '5', 'itemName': '花', 'num': 1, 'giftCoin': 0},
      })!;
      final gift = stock.giftOrNull! as LiveGift;
      expect(gift.value.unit, LiveGiftUnit.free);
      expect(gift.value.totalValue, isNull);
      for (final item in SixroomDanmakuCodec.flyScreenGifts) {
        expect(
          SixroomDanmakuCodec.giftMessage({
            'from': 'x',
            'fid': 'u5',
            'content': {'item': item, 'itemName': '飞屏', 'num': 1},
          }),
          isNull,
          reason: 'a fly-screen purchase shows as its fly-screen, not as a gift',
        );
      }
      expect(
        SixroomDanmakuCodec.giftMessage({
          'fid': '0',
          'content': {'item': '5', 'itemName': '花', 'num': 1},
        }),
        isNull,
      );
    });
  });
}
