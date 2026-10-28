import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/chzzk/danmaku/chzzk_danmaku_codec.dart';
import 'package:test/test.dart';

/// A pushed line of the given type, by user `u1`, at the test time.
Map<String, Object?> _line(int type, {String text = 'hi', Map<String, Object?> extras = const {}}) => {
  'msg': text,
  'uid': 'u1',
  'msgTime': 1790733600000,
  'msgTypeCode': type,
  'msgStatusType': 'NORMAL',
  'profile': {'nickname': 'Ann', 'profileImageUrl': 'https://nng-phinf.pstatic.net/1.png'},
  'extras': extras,
};

void main() {
  group('chat lines', () {
    test('a pushed line is chat of its user and time', () {
      final message = ChzzkDanmakuCodec.line(_line(ChzzkDanmakuCodec.textType))!;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'hi');
      expect(message.sender?.userId, 'u1');
      expect(message.sender?.userName, 'Ann');
      expect(message.messageId, 'u1:1790733600000');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1790733600000));
    });

    test('a blinded line is not shown', () {
      final line = _line(ChzzkDanmakuCodec.textType)..['msgStatusType'] = 'BLIND';
      expect(ChzzkDanmakuCodec.line(line), isNull);
    });
  });

  group('donations (10)', () {
    test('a donation is a super chat of cheese for its tier duration', () {
      final message = ChzzkDanmakuCodec.line(
        _line(ChzzkDanmakuCodec.donationType, text: '加油', extras: {'payAmount': 1000}),
      )!;
      expect(message.type, LiveMessageType.superChat);
      final chat = message.payload! as LiveSuperChatMessage;
      expect(chat.price.amount, 1000);
      expect(chat.price.currency, ChzzkDanmakuCodec.cheeseCurrency);
      expect(chat.price.displayText, '1,000 치즈');
      expect(chat.endTime, chat.startTime!.add(const Duration(minutes: 1)));
      expect(chat.faceUrl, 'https://nng-phinf.pstatic.net/1.png');
    });

    test('a large donation shows longer, and an anonymous one has no id', () {
      final message = ChzzkDanmakuCodec.line(
        _line(ChzzkDanmakuCodec.donationType, text: '', extras: {'payAmount': 100000, 'isAnonymous': true}),
      )!;
      final chat = message.payload! as LiveSuperChatMessage;
      expect(chat.endTime, chat.startTime!.add(ChzzkDanmakuCodec.superChatDuration(100000)));
      expect(chat.endTime, chat.startTime!.add(const Duration(minutes: 5)));
      expect(message.sender?.userName, ChzzkDanmakuCodec.anonymousDonor);
      expect(message.sender?.userId, '');
    });
  });

  group('subscriptions (11)', () {
    test('a subscription is a notice naming the tier and months beside its text as chat', () {
      final item = _line(ChzzkDanmakuCodec.subscriptionType, text: '왔어요', extras: {'tierName': '팬', 'month': 3});
      final notice = ChzzkDanmakuCodec.subscription(item)!;
      expect(notice.type, LiveMessageType.notice);
      expect(notice.text, 'Ann 订阅了「팬」，已订阅 3 个月');
      expect(notice.payload, LiveNoticeKind.subscription);
      expect(notice.messageId, startsWith('subscription:u1:'));
      final chat = ChzzkDanmakuCodec.line(item)!;
      expect(chat.type, LiveMessageType.chat);
      expect(chat.text, '왔어요');
    });

    test('a subscription without a tier or months still names the subscriber', () {
      final notice = ChzzkDanmakuCodec.subscription(_line(ChzzkDanmakuCodec.subscriptionType))!;
      expect(notice.text, 'Ann 订阅了频道');
    });
  });
}
