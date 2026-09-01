import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/danmaku/kuaishou_danmaku.dart';

void main() {
  test('parses double-encoded mobile feed comments and audience count', () {
    final payload = jsonEncode(
      jsonEncode({
        'result': 1,
        'cursor': 'next-cursor',
        'pullCycleSeconds': 3,
        'currentWatchingCount': '1.2万',
        'liveStreamFeeds': [
          {
            'type': 'comment',
            'content': '测试弹幕',
            'time': 1788278277492,
            'author': {'userName': '快手用户A', 'userId': 4143159120},
          },
          {
            'type': 'gift',
            'content': '礼物',
            'author': {'userName': '礼物用户'},
          },
        ],
      }),
    );

    final batch = KuaishouDanmaku.parseFeedPayload(payload);

    expect(batch.cursor, 'next-cursor');
    expect(batch.pullDelay, const Duration(seconds: 3));
    expect(batch.onlineViewers, 12000);
    expect(batch.messages, hasLength(1));
    expect(batch.messages.single.message, '测试弹幕');
    expect(batch.messages.single.userName, '快手用户A');
    expect(batch.messages.single.userId, '4143159120');
    expect(batch.messages.single.messageId, startsWith('kuaishou:'));
    expect(batch.messages.single.sentAt?.millisecondsSinceEpoch, 1788278277492);
  });

  test('rejects unsuccessful response instead of presenting a false connection', () {
    expect(() => KuaishouDanmaku.parseFeedPayload({'result': 2, 'liveStreamFeeds': []}), throwsStateError);
  });

  test('initial poll marks ready and emits chat plus typed audience update', () async {
    final cursors = <String>[];
    final engine = KuaishouDanmaku(
      minimumPollDelay: const Duration(hours: 1),
      fetcher: (args, cursor, cancelToken) async {
        cursors.add(cursor);
        return {
          'result': 1,
          'cursor': 'cursor-1',
          'pullCycleSeconds': 3,
          'currentWatchingCount': '36',
          'liveStreamFeeds': [
            {
              'type': 'comment',
              'content': 'hello',
              'time': 1000,
              'author': {'userName': 'viewer', 'userId': 9},
            },
          ],
        };
      },
    );
    final messages = <LiveMessage>[];
    var readyCount = 0;
    engine.onReady = () => readyCount++;
    engine.onMessage = messages.add;

    await engine.start(const KuaishouDanmakuArgs(liveStreamId: 'live-id'));

    expect(cursors, ['']);
    expect(engine.isConnected, isTrue);
    expect(readyCount, 1);
    expect(messages.where((message) => message.type == LiveMessageType.chat).single.message, 'hello');
    final audience = messages.where((message) => message.type == LiveMessageType.online).single.data;
    expect(audience, isA<LiveAudienceUpdate>());
    expect((audience as LiveAudienceUpdate).kind, LiveAudienceMetricKind.onlineViewers);
    expect(audience.value, 36);

    await engine.stop();
    expect(engine.isConnected, isFalse);
  });

  test('stop cancels a pending feed request and leaves no live callbacks', () async {
    final request = Completer<dynamic>();
    CancelToken? observedToken;
    final engine = KuaishouDanmaku(
      fetcher: (args, cursor, cancelToken) {
        observedToken = cancelToken;
        return request.future;
      },
    );
    final started = engine.start(const KuaishouDanmakuArgs(liveStreamId: 'live-id'));
    await Future<void>.delayed(Duration.zero);
    await engine.stop();
    request.completeError(DioException(requestOptions: RequestOptions(), type: DioExceptionType.cancel));
    await started;

    expect(observedToken?.isCancelled, isTrue);
    expect(engine.isConnected, isFalse);
  });
}
