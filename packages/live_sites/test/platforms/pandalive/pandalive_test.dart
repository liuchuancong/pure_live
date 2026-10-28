import 'dart:convert';

import 'package:live_sites/src/models/enums/live_gift_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/pandalive/danmaku/pandalive_danmaku_codec.dart';
import 'package:test/test.dart';

/// A `SponCoin` publication of the channel the tests read (`ch1`), offset 42.
Map<String, Object?> _hearts({
  String type = 'SponCoin',
  int coin = 5,
  String nick = '보내는이',
  String? words,
  String excelNick = '',
}) => {
  'offset': 42,
  'data': {
    'type': type,
    'created_at': 1790733600,
    'message': jsonEncode({
      'nick': nick,
      'id': 'user1',
      'coin': coin,
      'excelNick': excelNick,
      'heartMessage': words == null ? null : {'message': words},
    }),
  },
};

void main() {
  group('hearts (SponCoin)', () {
    test('the hearts are a tip and the words sent with them come as chat', () {
      final messages = PandaliveDanmakuCodec.hearts(_hearts(words: '고마워'), channel: 'ch1');
      expect(messages, hasLength(2));

      final gift = messages.first;
      expect(gift.type, LiveMessageType.gift);
      expect(gift.text, '하트 ×5');
      expect(gift.sender?.userId, 'user1');
      expect(gift.sender?.userName, '보내는이');
      expect(gift.messageId, 'ch1:42');
      expect(gift.sentAt, DateTime.fromMillisecondsSinceEpoch(1790733600 * 1000));
      final present = gift.giftOrNull! as LiveGift;
      expect(present.name, '하트');
      expect(present.count, 5);
      expect(present.kind, LiveGiftKind.tip);
      expect(present.value.unit, LiveGiftUnit.heart);
      expect(present.value.unitPrice, 1);
      expect(present.value.totalValue, 5);

      final chat = messages.last;
      expect(chat.type, LiveMessageType.chat);
      expect(chat.text, '고마워');
      expect(chat.messageId, 'ch1:42:words');
    });

    test('a show of several broadcasters names who receives the hearts', () {
      final messages = PandaliveDanmakuCodec.hearts(_hearts(excelNick: '받는이'), channel: 'ch1');
      expect((messages.single.giftOrNull! as LiveGift).recipientName, '받는이');
    });

    test('anything else is no heart', () {
      expect(PandaliveDanmakuCodec.hearts(_hearts(type: 'ItemCoin'), channel: 'ch1'), isEmpty);
      expect(PandaliveDanmakuCodec.hearts(_hearts(coin: 0), channel: 'ch1'), isEmpty);
      expect(PandaliveDanmakuCodec.hearts(_hearts(nick: ''), channel: 'ch1'), isEmpty);
      expect(PandaliveDanmakuCodec.hearts('not a map', channel: 'ch1'), isEmpty);
      final broken = _hearts();
      (broken['data']! as Map<String, Object?>)['message'] = '{not json';
      expect(PandaliveDanmakuCodec.hearts(broken, channel: 'ch1'), isEmpty);
    });
  });
}
