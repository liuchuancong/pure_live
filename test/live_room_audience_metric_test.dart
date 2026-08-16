import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';

void main() {
  group('audience metric semantics', () {
    test('maps platform fields without calling every value online viewers', () {
      expect(LiveRoom(platform: 'bilibili').effectiveAudienceMetricType, AudienceMetricType.popularity);
      expect(LiveRoom(platform: 'douyu').effectiveAudienceMetricType, AudienceMetricType.popularity);
      expect(LiveRoom(platform: 'huya').effectiveAudienceMetricType, AudienceMetricType.onlineViewers);
      expect(LiveRoom(platform: 'kuaishou').effectiveAudienceMetricType, AudienceMetricType.onlineViewers);
      expect(LiveRoom(platform: 'douyin').effectiveAudienceMetricType, AudienceMetricType.totalViewers);
      expect(LiveRoom(platform: 'huya').supportsRealOnlineCount, isTrue);
      expect(LiveRoom(platform: 'bilibili').supportsRealOnlineCount, isFalse);
    });

    test('round-trips an explicit metric and migrates older records', () {
      final room = LiveRoom.fromJson({'roomId': '1', 'platform': 'cc', 'audienceMetricType': 'followers'});
      expect(room.effectiveAudienceMetricType, AudienceMetricType.followers);
      expect(room.toJson()['audienceMetricType'], 'followers');

      final legacy = LiveRoom.fromJson({'roomId': '2', 'platform': 'bilibili'});
      expect(legacy.effectiveAudienceMetricType, AudienceMetricType.popularity);
    });
  });
}
