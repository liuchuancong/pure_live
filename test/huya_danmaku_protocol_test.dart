import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/danmaku/huya_danmaku.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';

void main() {
  group('Huya danmaku protocol', () {
    LiveSuperChatMessage superChat(String message, {String messageId = '', Duration startOffset = Duration.zero}) {
      final now = DateTime.utc(2026, 9, 1, 12).add(startOffset);
      return LiveSuperChatMessage(
        messageId: messageId,
        backgroundBottomColor: '#246488',
        backgroundColor: '#ffffff',
        endTime: now.add(const Duration(minutes: 1)),
        face: '',
        message: message,
        price: 100,
        startTime: now,
        userName: 'tester',
      );
    }

    List<int> superChatNotification() {
      final push = HYPushMessageV2()
        ..groupId = 'live:2272316519'
        ..items = <HYMessageItem>[
          HYMessageItem()
            ..uri = 2001314
            ..msg = <int>[]
            ..messageId = 2018964510849866753,
        ];
      final pushPayload = TarsOutputStream();
      push.writeTo(pushPayload);
      return (TarsOutputStream()
            ..write(22, 0)
            ..write(pushPayload.toUint8List(), 1))
          .toUint8List();
    }

    test('uses the current website heartbeat command', () {
      final heartbeat = HuyaDanmaku().heartbeatData;
      final outer = TarsInputStream(Uint8List.fromList(heartbeat));

      expect(outer.read(0, 0, false), 20);
      expect(outer.readBytes(1, false), isEmpty);
    });

    test('registers the current live and chat room groups', () {
      const uid = 294636272;
      final packet = HuyaDanmaku().getJoinData(uid);
      final outer = TarsInputStream(Uint8List.fromList(packet));

      expect(outer.read(0, 0, false), 16);
      final inner = TarsInputStream(Uint8List.fromList(outer.readBytes(1, false)));
      expect(inner.readList<String>(<String>[''], 0, false), <String>['live:$uid', 'chat:$uid']);
      expect(inner.read('', 1, false), isEmpty);
    });

    test('decodes current batched URI 8006 as popularity rather than concurrent viewers', () {
      final metricPayload = TarsOutputStream()..write(3212923, 0);
      final push = HYPushMessageV2()
        ..groupId = 'live:2272316519'
        ..items = <HYMessageItem>[
          HYMessageItem()
            ..uri = 8006
            ..msg = metricPayload.toUint8List()
            ..messageId = 2018964510849866752,
        ];
      final pushPayload = TarsOutputStream();
      push.writeTo(pushPayload);
      final frame = TarsOutputStream()
        ..write(22, 0)
        ..write(pushPayload.toUint8List(), 1);

      final messages = <LiveMessage>[];
      final danmaku = HuyaDanmaku()..onMessage = messages.add;
      danmaku.decodeMessage(frame.toUint8List());

      expect(messages, hasLength(1));
      final update = messages.single.data as LiveAudienceUpdate;
      expect(update.kind, LiveAudienceMetricKind.popularity);
      expect(update.value, 3212923);
      expect(messages.single.messageId, 'huya:2018964510849866752');
    });

    test('retries a delayed Huya super-chat board without blocking websocket decode', () async {
      var fetches = 0;
      final firstResponse = Completer<List<LiveSuperChatMessage>>();
      final received = <LiveMessage>[];
      final danmaku =
          HuyaDanmaku(
              superChatFetcher: (_) {
                fetches++;
                return fetches == 1
                    ? firstResponse.future
                    : Future<List<LiveSuperChatMessage>>.value(<LiveSuperChatMessage>[superChat('delayed')]);
              },
              superChatRetryDelays: const <Duration>[Duration.zero, Duration.zero],
            )
            ..danmakuArgs = HuyaDanmakuArgs(uid: 1, topSid: 2, subSid: 3)
            ..onMessage = received.add;

      await danmaku.decodeMessage(superChatNotification());
      expect(fetches, 1, reason: 'websocket decode must not await WUP reconciliation');
      expect(received, isEmpty);

      firstResponse.complete(<LiveSuperChatMessage>[]);

      await danmaku.waitForPendingSuperChatRefresh();

      expect(fetches, 2);
      expect(received, hasLength(1));
      expect(received.single.type, LiveMessageType.superChat);
      expect((received.single.data as LiveSuperChatMessage).message, 'delayed');
    });

    test('coalesces duplicate Huya board snapshots into one super-chat event', () async {
      final item = superChat('same');
      final received = <LiveMessage>[];
      final danmaku =
          HuyaDanmaku(
              superChatFetcher: (_) async => <LiveSuperChatMessage>[item],
              superChatRetryDelays: const <Duration>[Duration.zero, Duration.zero, Duration.zero],
            )
            ..danmakuArgs = HuyaDanmakuArgs(uid: 1, topSid: 2, subSid: 3)
            ..onMessage = received.add;

      await danmaku.decodeMessage(superChatNotification());
      await danmaku.waitForPendingSuperChatRefresh();

      expect(received, hasLength(1));
      expect((received.single.data as LiveSuperChatMessage).message, 'same');
    });

    test('uses stable Huya event identity instead of reconstructed countdown times', () {
      final first = superChat('same', messageId: 'huya:101');
      final refreshedSnapshot = superChat(
        'same',
        messageId: 'huya:101',
        startOffset: const Duration(milliseconds: 850),
      );
      final laterEvent = superChat('same', messageId: 'huya:102', startOffset: const Duration(minutes: 5));

      expect(first, refreshedSnapshot);
      expect(first.hashCode, refreshedSnapshot.hashCode);
      expect(first, isNot(laterEvent));
    });

    test('keeps distinct Huya paid messages with identical visible content', () async {
      var fetches = 0;
      final received = <LiveMessage>[];
      final first = superChat('same visible content', messageId: 'huya:101');
      final second = superChat('same visible content', messageId: 'huya:102');
      final danmaku =
          HuyaDanmaku(
              superChatFetcher: (_) async {
                fetches++;
                return fetches == 1 ? <LiveSuperChatMessage>[first] : <LiveSuperChatMessage>[first, second];
              },
              superChatRetryDelays: const <Duration>[Duration.zero],
            )
            ..danmakuArgs = HuyaDanmakuArgs(uid: 1, topSid: 2, subSid: 3)
            ..onMessage = received.add;

      await danmaku.decodeMessage(superChatNotification());
      await danmaku.waitForPendingSuperChatRefresh();
      await danmaku.decodeMessage(superChatNotification());
      await danmaku.waitForPendingSuperChatRefresh();

      expect(received, hasLength(2));
      expect(received.map((item) => (item.data as LiveSuperChatMessage).messageId), <String>['huya:101', 'huya:102']);
    });

    test('a stale room refresh cannot suppress the next room notification', () async {
      final staleResponse = Completer<List<LiveSuperChatMessage>>();
      var fetches = 0;
      final received = <LiveMessage>[];
      final danmaku =
          HuyaDanmaku(
              superChatFetcher: (_) {
                fetches++;
                return fetches == 1
                    ? staleResponse.future
                    : Future<List<LiveSuperChatMessage>>.value(<LiveSuperChatMessage>[superChat('next-room')]);
              },
              superChatRetryDelays: const <Duration>[Duration.zero],
            )
            ..danmakuArgs = HuyaDanmakuArgs(uid: 1, topSid: 2, subSid: 3)
            ..onMessage = received.add;

      await danmaku.decodeMessage(superChatNotification());
      expect(fetches, 1);

      await danmaku.stop();
      danmaku.danmakuArgs = HuyaDanmakuArgs(uid: 4, topSid: 5, subSid: 6);
      danmaku.onMessage = received.add;
      await danmaku.decodeMessage(superChatNotification());
      await danmaku.waitForPendingSuperChatRefresh();
      staleResponse.complete(<LiveSuperChatMessage>[superChat('stale-room')]);
      await Future<void>.delayed(Duration.zero);

      expect(fetches, 2);
      expect(received, hasLength(1));
      expect((received.single.data as LiveSuperChatMessage).message, 'next-room');
    });
  });
}
