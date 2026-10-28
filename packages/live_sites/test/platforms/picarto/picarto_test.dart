import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/picarto/danmaku/picarto_danmaku_codec.dart';
import 'package:test/test.dart';

DateTime get _received => DateTime.utc(2026, 9, 27, 12, 49, 35);

/// A chip tip of [chips] from `Ann` with [text] and receiver [receiver].
Map<Object?, Object?> _tip({int chips = 5, String text = ' nice ', String receiver = 'Chan'}) => {
  'id': 'tip1',
  'x': chips,
  'n': 'Ann',
  'u': 'u1',
  'i': 'avatar/1.png',
  'm': text,
  'rn': receiver,
  'd': 1790733600000,
};

void main() {
  group('tips (Kudos)', () {
    test('a tip is a super chat in Kudos for a minute', () {
      final message = PicartoDanmakuCodec.tip(_tip(), receivedAt: _received, channelName: 'chan')!;
      expect(message.type, LiveMessageType.superChat);
      expect(message.text, 'nice');
      expect(message.messageId, 'tip1');
      expect(message.sender?.userId, 'u1');
      expect(message.sender?.userName, 'Ann');
      expect(message.sender?.avatarUrl, 'https://images.picarto.tv/avatar/1.png');
      final chat = message.payload! as LiveSuperChatMessage;
      expect(chat.price.amount, 5);
      expect(chat.price.currency, PicartoDanmakuCodec.tipUnit);
      expect(chat.price.displayText, '5 Kudos');
      expect(chat.startTime, DateTime.fromMillisecondsSinceEpoch(1790733600000));
      expect(chat.endTime, chat.startTime!.add(PicartoDanmakuCodec.tipDuration));
    });

    test('a tip to another channel of a multistream says who it is for', () {
      final message = PicartoDanmakuCodec.tip(
        _tip(receiver: 'Other'),
        receivedAt: _received,
        channelName: 'chan',
      )!;
      expect(message.text, '打赏给 Other：nice');
      final bare = PicartoDanmakuCodec.tip(
        _tip(receiver: 'Other', text: ''),
        receivedAt: _received,
        channelName: 'chan',
      )!;
      expect(bare.text, '打赏给 Other');
    });

    test('a tip without chips is nothing', () {
      expect(PicartoDanmakuCodec.tip(_tip(chips: 0), receivedAt: _received), isNull);
      expect(PicartoDanmakuCodec.tip({'x': '5'}, receivedAt: _received), isNull);
    });
  });

  group('subscriptions', () {
    test('a community gift names its count, and a plain subscription its level', () {
      final gift = PicartoDanmakuCodec.subscription({
        'sn': 'Ann',
        'n': 'Chan',
        'sg': true,
        'sc': [1, 2, 3],
      })!;
      expect(gift.type, LiveMessageType.notice);
      expect(gift.payload, LiveNoticeKind.subscription);
      expect(gift.text, 'Ann 向 Picarto 社区赠送了 3 份 Chan 的订阅');
      final plain = PicartoDanmakuCodec.subscription({'sn': 'Ann', 'n': 'Chan', 'md': '2', 'slvl': '2'})!;
      expect(plain.text, 'Ann 开通了 Chan 的 2 级订阅');
      expect(PicartoDanmakuCodec.subscription({'n': 'Chan'}), isNull);
    });
  });
}
