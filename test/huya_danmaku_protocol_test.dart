import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/danmaku/huya_danmaku.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';

void main() {
  group('Huya danmaku protocol', () {
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
  });
}
