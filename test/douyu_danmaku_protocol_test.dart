import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/danmaku/douyu_danmaku.dart';

void main() {
  group('Douyu danmaku protocol', () {
    test('decodes every packet coalesced in one websocket frame', () {
      final danmaku = DouyuDanmaku();
      danmaku.markConnected();
      final received = <LiveMessage>[];
      danmaku.onMessage = received.add;
      final first = danmaku.serializeDouyu('type@=chatmsg/rid@=100/dms@=1/uid@=7/nn@=A/txt@=one/cid@=c1/col@=0/');
      final second = danmaku.serializeDouyu('type@=chatmsg/rid@=100/dms@=1/uid@=8/nn@=B/txt@=two/cid@=c2/col@=0/');

      // start() normally owns this value; set it directly to keep the parser
      // regression test independent from a network connection.
      danmaku.debugSetRoomId('100');
      danmaku.decodeMessage(<int>[...first, ...second]);

      expect(received.map((message) => message.message), ['one', 'two']);
      expect(received.map((message) => message.messageId), ['douyu:c1', 'douyu:c2']);
    });

    test('drops a packet explicitly tagged for a different room', () {
      final danmaku = DouyuDanmaku()..debugSetRoomId('100');
      final received = <LiveMessage>[];
      danmaku.onMessage = received.add;

      danmaku.decodeMessage(danmaku.serializeDouyu('type@=chatmsg/rid@=200/dms@=1/uid@=7/nn@=A/txt@=wrong/cid@=c1/'));

      expect(received, isEmpty);
    });

    test('keeps unmarked room chat by default', () {
      final danmaku = DouyuDanmaku()..debugSetRoomId('71415');
      final received = <LiveMessage>[];
      danmaku.onMessage = received.add;

      danmaku.decodeMessage(
        danmaku.serializeDouyu('type@=chatmsg/rid@=71415/uid@=7/nn@=A/txt@=ordinary/cid@=c1/col@=0/'),
      );

      expect(received, hasLength(1));
      expect(received.single.message, 'ordinary');
      expect(received.single.messageId, 'douyu:c1');
    });

    test('filters unmarked room chat only after explicit opt-in', () {
      final danmaku = DouyuDanmaku(filterSuspectedAutomatedMessages: () => true)..debugSetRoomId('71415');
      final received = <LiveMessage>[];
      danmaku.onMessage = received.add;

      danmaku.decodeMessage(
        danmaku.serializeDouyu('type@=chatmsg/rid@=71415/uid@=7/nn@=A/txt@=ordinary/cid@=c1/col@=0/'),
      );

      expect(received, isEmpty);
    });

    test('applies a changed platform-filter preference without reconnecting', () {
      var enabled = false;
      final danmaku = DouyuDanmaku(filterSuspectedAutomatedMessages: () => enabled)..debugSetRoomId('71415');
      final received = <LiveMessage>[];
      danmaku.onMessage = received.add;

      danmaku.decodeMessage(danmaku.serializeDouyu('type@=chatmsg/rid@=71415/uid@=7/nn@=A/txt@=first/cid@=c1/col@=0/'));
      enabled = true;
      danmaku.decodeMessage(
        danmaku.serializeDouyu('type@=chatmsg/rid@=71415/uid@=8/nn@=B/txt@=second/cid@=c2/col@=0/'),
      );

      expect(received.map((message) => message.message), ['first']);
    });

    test('ignores empty chat payloads without affecting the next packet', () {
      final danmaku = DouyuDanmaku(filterSuspectedAutomatedMessages: () => false)..debugSetRoomId('71415');
      final received = <LiveMessage>[];
      danmaku.onMessage = received.add;
      final empty = danmaku.serializeDouyu('type@=chatmsg/rid@=71415/uid@=7/nn@=A/txt@=/cid@=empty/');
      final valid = danmaku.serializeDouyu('type@=chatmsg/rid@=71415/uid@=8/nn@=B/txt@=next/cid@=next/');

      danmaku.decodeMessage(<int>[...empty, ...valid]);

      expect(received.map((message) => message.message), ['next']);
    });

    test('keeps ordinary chat and a super-chat coalesced in one frame', () {
      final danmaku = DouyuDanmaku()..debugSetRoomId('100');
      final received = <LiveMessage>[];
      danmaku.onMessage = received.add;
      final chat = danmaku.serializeDouyu('type@=chatmsg/rid@=100/dms@=1/uid@=7/nn@=A/txt@=hello/cid@=c1/');
      final superChat = danmaku.serializeDouyu(
        'type@=comm_chatmsg/now@=1700000000000/cet@=60/cprice@=500/'
        'chatmsg@=nn@A=Supporter@Stxt@A=Great@Sic@A=avatar/',
      );

      danmaku.decodeMessage(<int>[...chat, ...superChat]);

      expect(received.map((message) => message.type), [LiveMessageType.chat, LiveMessageType.superChat]);
      final data = received.last.data as LiveSuperChatMessage;
      expect(data.userName, 'Supporter');
      expect(data.message, 'Great');
      expect(data.price, 5);
    });
  });
}
