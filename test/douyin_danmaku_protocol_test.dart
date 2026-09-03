import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/danmaku/douyin_danmaku.dart';
import 'package:pure_live/core/danmaku/proto/douyin.pb.dart';

void main() {
  group('Douyin danmaku protocol', () {
    DouyinDanmaku createDanmaku(List<LiveMessage> received) {
      final danmaku = DouyinDanmaku();
      danmaku.danmakuArgs = DouyinDanmakuArgs(
        webRid: 'web',
        roomId: '100',
        userId: 'guest',
        cookie: '',
      );
      danmaku.onMessage = received.add;
      return danmaku;
    }

    test('preserves room, id, user and timestamp metadata', () {
      final received = <LiveMessage>[];
      final danmaku = createDanmaku(received);
      final createdAt = DateTime(2026, 8, 17, 12).millisecondsSinceEpoch;
      final chat = ChatMessage(
        common: Common(roomId: Int64(100), msgId: Int64(9001), createTime: Int64(createdAt)),
        user: User(id: Int64(7), nickName: 'viewer'),
        content: 'hello',
      );

      danmaku.unPackWebcastChatMessage(chat.writeToBuffer(), envelopeMessageId: '8001');

      expect(received, hasLength(1));
      expect(received.single.userId, '7');
      expect(received.single.messageId, 'douyin:9001');
      expect(received.single.sentAt?.millisecondsSinceEpoch, createdAt);
    });

    test('drops chat payloads carrying another room id', () {
      final received = <LiveMessage>[];
      final danmaku = createDanmaku(received);
      final chat = ChatMessage(
        common: Common(roomId: Int64(200), msgId: Int64(1)),
        user: User(id: Int64(7), nickName: 'viewer'),
        content: 'wrong room',
      );

      danmaku.unPackWebcastChatMessage(chat.writeToBuffer());

      expect(received, isEmpty);
    });
  });
}
