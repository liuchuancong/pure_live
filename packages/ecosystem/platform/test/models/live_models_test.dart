// Module: test/models/live_models_test.dart
// Purpose: The live-domain models round-trip and stay tolerant of the shapes the platforms actually send.
// Author: liuchuancong
// Created: 2026-10-11
//
// These three are the freezed-generated live models (models/live/). What is being pinned is not the generator -
// it is the converters hanging off it: a stored row read back must equal the row that was written, and a field
// the platform sent in a shape we did not predict must read as "not stated", never as a crash and never as a
// zero a surface will render as a fact.

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

void main() {
  group('test_anchorSummary', () {
    test('roundTripsThroughJson', () {
      final anchor = AnchorSummary(
        ref: ContentRef(sourceId: 'huya.live', contentId: '12345', kind: ContentKind.anchor),
        name: '主播甲',
        avatar: 'https://cdn/avatar.png',
        fans: 4200,
        currentRoom: ContentRef(sourceId: 'huya.live', contentId: '12345', kind: ContentKind.liveRoom),
        extra: <String, Object?>{'platform': 'web'},
      );
      expect(AnchorSummary.fromJson(anchor.toJson()), anchor);
      expect(anchor.isLiveNow, isTrue);
    });

    test('aFansFieldThatIsAStringStillReadsAsANumber', () {
      final anchor = AnchorSummary.fromJson(<String, Object?>{
        'ref': <Object?, Object?>{'sourceId': 'douyu.live', 'contentId': '9', 'kind': 'anchor'},
        'name': '乙',
        'fans': '18',
      });
      expect(anchor.fans, 18);
      // The nested map is Map<Object?,Object?>, not Map<String,Object?>: a hard cast here used to lose the row.
      expect(anchor.ref.contentId, '9');
      expect(anchor.isLiveNow, isFalse);
    });

    test('anUnreadableFansCountIsAbsentNotZero', () {
      final anchor = AnchorSummary.fromJson(<String, Object?>{
        'ref': <String, Object?>{'sourceId': 'huya.live', 'contentId': '1', 'kind': 'anchor'},
        'name': '丙',
        'fans': '1.2万',
      });
      expect(anchor.fans, isNull);
      expect(anchor.toJson().containsKey('fans'), isFalse);
    });
  });

  group('test_danmakuMessage', () {
    final at = DateTime.utc(2026, 10, 11, 3, 30);

    test('roundTripsThroughJson', () {
      final message = DanmakuMessage(
        room: ContentRef(sourceId: 'huya.live', contentId: '77', kind: ContentKind.liveRoom),
        kind: DanmakuKind.superChat,
        text: '醒目留言',
        at: at,
        senderId: 'u1',
        senderName: '丁',
        amount: 30,
        itemName: '火箭',
        color: 0xFF8800,
        isSelf: true,
      );
      expect(DanmakuMessage.fromJson(message.toJson()), message);
      expect(message.isPaid, isTrue);
    });

    test('anUnknownKindFallsBackToTextRatherThanDroppingTheRow', () {
      final message = DanmakuMessage.fromJson(<String, Object?>{
        'room': <String, Object?>{'sourceId': 'huya.live', 'contentId': '77', 'kind': 'liveRoom'},
        'kind': 'guard_buy',
        'text': '加入了直播间',
        'at': '2026-10-11T03:30:00.000Z',
      });
      expect(message.kind, DanmakuKind.text);
      expect(message.isPaid, isFalse);
      expect(message.at, at);
    });

    test('aRowWithoutTextOrSenderIsStillARow', () {
      final message = DanmakuMessage.fromJson(<String, Object?>{
        'room': <String, Object?>{'sourceId': 'huya.live', 'contentId': '77', 'kind': 'liveRoom'},
        'kind': 'entry',
      });
      expect(message.text, '');
      expect(message.displaySender, '匿名');
      // A missing timestamp is epoch-0 UTC, which is "the provider had to guess", not "it happened in 1970".
      expect(message.at, DateTime.fromMillisecondsSinceEpoch(0).toUtc());
      expect(message.toString(), 'DanmakuMessage(entry 匿名: )');
    });
  });

  group('test_liveRoomStatus', () {
    test('unknownIsNotEnded', () {
      final status = LiveRoomStatus(
        ref: ContentRef(sourceId: 'huya.live', contentId: '1', kind: ContentKind.liveRoom),
        state: LiveRoomState.unknown,
      );
      expect(status.isLive, isFalse);
      expect(status.state, isNot(LiveRoomState.ended));
      expect(LiveRoomStatus.fromJson(status.toJson()), status);
    });

    test('viewersSentAsAStringAreStillCounted', () {
      final status = LiveRoomStatus.fromJson(<String, Object?>{
        'ref': <String, Object?>{'sourceId': 'huya.live', 'contentId': '1', 'kind': 'liveRoom'},
        'state': 'live',
        'viewers': '4321',
      });
      expect(status.state, LiveRoomState.live);
      expect(status.viewers, 4321);
    });
  });
}
