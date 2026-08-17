import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';

void main() {
  group('audience metric semantics', () {
    test('maps platform fields without calling every value online viewers', () {
      expect(LiveRoom(platform: 'bilibili').effectiveAudienceMetricType, AudienceMetricType.popularity);
      expect(LiveRoom(platform: 'douyu').effectiveAudienceMetricType, AudienceMetricType.popularity);
      expect(LiveRoom(platform: 'huya').effectiveAudienceMetricType, AudienceMetricType.popularity);
      expect(LiveRoom(platform: 'kuaishou').effectiveAudienceMetricType, AudienceMetricType.onlineViewers);
      expect(LiveRoom(platform: 'douyin').effectiveAudienceMetricType, AudienceMetricType.totalViewers);
      expect(LiveRoom(platform: 'huya', onlineViewers: '3210').supportsRealOnlineCount, isTrue);
      expect(LiveRoom(platform: 'bilibili').supportsRealOnlineCount, isFalse);
    });

    test('keeps heat and concurrent viewers separate when selecting a mode', () {
      final room = LiveRoom(
        platform: 'huya',
        watching: '5600000',
        popularity: '5600000',
        onlineViewers: '18342',
        audienceMetricType: AudienceMetricType.popularity,
      );

      expect(room.audienceValue(preferRealOnline: false, platformEnabled: true), '5600000');
      expect(room.audienceValue(preferRealOnline: true, platformEnabled: true), '18342');
      expect(room.audienceType(preferRealOnline: true, platformEnabled: true), AudienceMetricType.onlineViewers);
      expect(room.audienceSortValue(preferRealOnline: true, platformEnabled: true), 18342);
    });

    test('parses localized audience values for ranking', () {
      expect(LiveRoom.parseAudienceNumber('5.6万'), 56000);
      expect(LiveRoom.parseAudienceNumber('1.2亿'), 120000000);
      expect(LiveRoom.parseAudienceNumber('18.3k'), 18300);
    });

    test('keeps an explicit zero concurrent count instead of falling back to heat', () {
      final room = LiveRoom(platform: 'huya', popularity: '500万', onlineViewers: '0');

      expect(room.supportsRealOnlineCount, isTrue);
      expect(room.audienceValue(preferRealOnline: true, platformEnabled: true), '0');
      expect(room.audienceType(preferRealOnline: true, platformEnabled: true), AudienceMetricType.onlineViewers);
    });

    test('round-trips an explicit metric and migrates older records', () {
      final room = LiveRoom.fromJson({'roomId': '1', 'platform': 'cc', 'audienceMetricType': 'followers'});
      expect(room.effectiveAudienceMetricType, AudienceMetricType.followers);
      expect(room.toJson()['audienceMetricType'], 'followers');

      final legacy = LiveRoom.fromJson({'roomId': '2', 'platform': 'bilibili'});
      expect(legacy.effectiveAudienceMetricType, AudienceMetricType.popularity);
    });

    test('copyWith keeps playback and danmaku payloads while updating audience data', () {
      final playback = {'url': 'fixture'};
      final danmaku = {'token': 'fixture'};
      final room = LiveRoom(roomId: '3', platform: 'huya', data: playback, danmakuData: danmaku, popularity: '500万');

      final updated = room.copyWith(onlineViewers: '3200');

      expect(updated.data, same(playback));
      expect(updated.danmakuData, same(danmaku));
      expect(updated.popularity, '500万');
      expect(updated.onlineViewers, '3200');
    });

    test('migrates duplicated Huya heat out of the online-viewer field', () {
      final room = LiveRoom.fromJson({
        'roomId': '998',
        'platform': 'huya',
        'watching': '5636930',
        'popularity': '5636930',
        'onlineViewers': '5636930',
        'audienceMetricType': 'onlineViewers',
      });

      expect(room.effectivePopularity, '5636930');
      expect(room.effectiveOnlineViewers, isEmpty);
      expect(room.effectiveAudienceMetricType, AudienceMetricType.popularity);
    });

    test('keeps Bilibili list popularity when detail temporarily returns one', () {
      final listRoom = LiveRoom(
        roomId: '545068',
        platform: 'bilibili',
        watching: '278000',
        popularity: '278000',
        audienceMetricType: AudienceMetricType.popularity,
      );
      final detailRoom = LiveRoom(
        roomId: '545068',
        platform: 'bilibili',
        watching: '1',
        popularity: '1',
        audienceMetricType: AudienceMetricType.popularity,
      );

      final merged = detailRoom.withAudienceFallbackFrom(listRoom);

      expect(merged.watching, '278000');
      expect(merged.effectivePopularity, '278000');
    });

    test('accepts a plausible later Bilibili popularity heartbeat', () {
      final previous = LiveRoom(
        roomId: '545068',
        platform: 'bilibili',
        watching: '278000',
        popularity: '278000',
        audienceMetricType: AudienceMetricType.popularity,
      );
      final heartbeat = previous.copyWith(watching: '281500', popularity: '281500');

      final merged = heartbeat.withAudienceFallbackFrom(previous);

      expect(merged.watching, '281500');
      expect(merged.effectivePopularity, '281500');
    });
  });
}
