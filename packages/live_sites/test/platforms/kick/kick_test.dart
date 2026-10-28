import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/kick/danmaku/kick_danmaku_codec.dart';
import 'package:test/test.dart';

DateTime get _sentAt => DateTime.utc(2026, 9, 27, 12, 49, 35);

/// A `KicksGifted` event of [amount] Kicks, with [message] when given.
Map<String, dynamic> _kicks({int amount = 1000, String? message, int? pinned}) => {
  'gift_transaction_id': 't1',
  'created_at': _sentAt.toIso8601String(),
  'sender': {'id': 7, 'username': 'Ann'},
  'gift': {'amount': amount, 'name': 'Kicks', 'pinned_time': ?pinned},
  'message': ?message,
};

void main() {
  group('KicksGifted', () {
    test('Kicks without a message are a gift priced in Kicks', () {
      final message = KickDanmakuCodec.kicks(_kicks())!;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, 'Kicks ×1');
      expect(message.messageId, 'kick:t1');
      expect(message.sentAt, _sentAt);
      expect(message.sender?.userId, '7');
      expect(message.sender?.userName, 'Ann');
      final gift = message.giftOrNull! as LiveGift;
      expect(gift.name, 'Kicks');
      expect(gift.value.unit, LiveGiftUnit.kicks);
      expect(gift.value.unitPrice, 1000);
      expect(gift.value.totalValue, 1000);
    });

    test('Kicks with a message are a super chat for the tier duration', () {
      final message = KickDanmakuCodec.kicks(_kicks(message: '干得好'))!;
      expect(message.type, LiveMessageType.superChat);
      expect(message.text, '干得好');
      final chat = message.payload! as LiveSuperChatMessage;
      expect(chat.price.amount, 1000);
      expect(chat.price.currency, 'Kicks');
      expect(chat.price.displayText, '1000 Kicks');
      expect(chat.startTime, _sentAt);
      expect(chat.endTime, _sentAt.add(KickDanmakuCodec.superChatDuration(1000)));
      expect(chat.endTime, _sentAt.add(const Duration(minutes: 2)));
    });

    test('a pinned time overrides the tier duration, up to a day', () {
      final pinned = KickDanmakuCodec.kicks(_kicks(message: 'x', pinned: 30))!.payload! as LiveSuperChatMessage;
      expect(pinned.endTime, _sentAt.add(const Duration(seconds: 30)));
      final over = KickDanmakuCodec.kicks(_kicks(message: 'x', pinned: 86401))!.payload! as LiveSuperChatMessage;
      expect(over.endTime, _sentAt.add(KickDanmakuCodec.superChatDuration(1000)));
    });

    test('an event without a sender or gift is nothing', () {
      expect(
        KickDanmakuCodec.kicks({
          'gift': {'amount': 1},
        }),
        isNull,
      );
      expect(
        KickDanmakuCodec.kicks({
          'sender': {'username': 'Ann'},
        }),
        isNull,
      );
    });
  });
}
