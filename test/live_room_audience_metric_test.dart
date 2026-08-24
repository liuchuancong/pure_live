import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';

void main() {
  group('audience metric semantics', () {
    test('maps platform fields without calling every value online viewers', () {
      expect(LiveRoom(platform: 'bilibili').effectiveAudienceMetricType, AudienceMetricType.popularity);
      expect(LiveRoom(platform: 'douyu').effectiveAudienceMetricType, AudienceMetricType.popularity);
      expect(LiveRoom(platform: 'huya').effectiveAudienceMetricType, AudienceMetricType.popularity);
      expect(LiveRoom(platform: 'kuaishou').effectiveAudienceMetricType, AudienceMetricType.onlineViewers);
      expect(LiveRoom(platform: 'twitch').effectiveAudienceMetricType, AudienceMetricType.onlineViewers);
      expect(LiveRoom(platform: 'twitch').supportsRealOnlineCount, isTrue);
      expect(LiveRoom(platform: 'soop').effectiveAudienceMetricType, AudienceMetricType.onlineViewers);
      expect(LiveRoom(platform: 'soop').supportsRealOnlineCount, isTrue);
      expect(LiveRoom(platform: 'douyin').effectiveAudienceMetricType, AudienceMetricType.totalViewers);
      expect(LiveRoom(platform: 'cc').effectiveAudienceMetricType, AudienceMetricType.popularity);
      expect(LiveRoom(platform: 'yy').effectiveAudienceMetricType, AudienceMetricType.popularity);
      expect(LiveRoom(platform: 'huya', onlineViewers: '3210').supportsRealOnlineCount, isFalse);
      expect(LiveRoom(platform: 'huya').supportsRealOnlineCount, isFalse);
      expect(LiveRoom(platform: 'huya').hasRealOnlineCount, isFalse);
      expect(LiveRoom(platform: 'douyin').supportsRealOnlineCount, isTrue);
      expect(LiveRoom(platform: 'bilibili').supportsRealOnlineCount, isFalse);
    });

    test('keeps heat and concurrent viewers separate when selecting a mode', () {
      final room = LiveRoom(
        platform: 'douyin',
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
      expect(LiveRoom.parseAudienceNumber('1.5M'), 1500000);
      expect(LiveRoom.parseAudienceNumber('2.4千'), 2400);
      expect(LiveRoom.parseAudienceNumber('534，739'), 534739);
    });

    test('keeps an explicit zero concurrent count instead of falling back to heat', () {
      final room = LiveRoom(platform: 'douyin', popularity: '500万', onlineViewers: '0');

      expect(room.supportsRealOnlineCount, isTrue);
      expect(room.audienceValue(preferRealOnline: true, platformEnabled: true), '0');
      expect(room.audienceType(preferRealOnline: true, platformEnabled: true), AudienceMetricType.onlineViewers);
    });

    test('shows a pending online value instead of relabelling heat while waiting for a platform value', () {
      final room = LiveRoom(platform: 'douyin', popularity: '500万');

      expect(room.audienceValue(preferRealOnline: true, platformEnabled: true), isEmpty);
      expect(room.audienceType(preferRealOnline: true, platformEnabled: true), AudienceMetricType.onlineViewers);
      expect(room.audienceSortValue(preferRealOnline: true, platformEnabled: true), 0);
    });

    test('puts unsupported heat values behind supported platforms in concurrent mode', () {
      final bilibili = LiveRoom(platform: 'bilibili', popularity: '500万');
      final douyin = LiveRoom(platform: 'douyin', onlineViewers: '3200');

      expect(bilibili.audienceSortValue(preferRealOnline: true, platformEnabled: true), -1);
      expect(douyin.audienceSortValue(preferRealOnline: true, platformEnabled: true), 3200);
    });

    test('concurrent ranking separates explicit, pending, and native metric tiers', () {
      final explicit = LiveRoom(roomId: 'explicit', platform: 'douyin', onlineViewers: '120');
      final pending = LiveRoom(roomId: 'pending', platform: 'soop', popularity: '900万');
      final heat = LiveRoom(roomId: 'heat', platform: 'bilibili', popularity: '900万');
      final rooms = [heat, pending, explicit]
        ..sort(
          (left, right) =>
              LiveRoom.compareAudienceRanking(left, right, preferRealOnline: true, platformEnabled: (_) => true),
        );

      expect(rooms.map((room) => room.roomId), ['explicit', 'pending', 'heat']);
      expect(explicit.audienceRankKey(preferRealOnline: true, platformEnabled: true).metricPriority, 3);
      expect(pending.audienceRankKey(preferRealOnline: true, platformEnabled: true).metricPriority, 2);
      expect(heat.audienceRankKey(preferRealOnline: true, platformEnabled: true).metricPriority, 1);
    });

    test('equal ranking values use stable platform-room identity', () {
      final rooms =
          [
            LiveRoom(roomId: '2', platform: 'twitch', onlineViewers: '50'),
            LiveRoom(roomId: '1', platform: 'twitch', onlineViewers: '50'),
          ]..sort(
            (left, right) =>
                LiveRoom.compareAudienceRanking(left, right, preferRealOnline: true, platformEnabled: (_) => true),
          );

      expect(rooms.map((room) => room.roomId), ['1', '2']);
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

    test('room refresh merge preserves local metadata and omitted status fields', () {
      final playback = <String, dynamic>{'url': 'fixture'};
      final danmaku = <String, dynamic>{'token': 'fixture'};
      final stored = LiveRoom(
        roomId: ' 100 ',
        platform: 'BILIBILI',
        title: 'old title',
        nick: 'stored nick',
        liveStatus: LiveStatus.live,
        status: true,
        isRecord: true,
        data: playback,
        danmakuData: danmaku,
        tagIds: const ['local-tag'],
        lastWatchedAt: 123,
      ).normalizedIdentityCopy();
      final sparseRefresh = LiveRoom(
        roomId: '100',
        platform: 'bilibili',
        title: 'fresh title',
        nick: '',
        liveStatus: null,
        status: null,
        isRecord: null,
        tagIds: const ['remote-tag'],
      );

      final merged = stored.mergeFrom(sparseRefresh);

      expect(merged.title, 'fresh title');
      expect(merged.nick, 'stored nick');
      expect(merged.liveStatus, LiveStatus.live);
      expect(merged.status, isTrue);
      expect(merged.isRecord, isTrue);
      expect(merged.tagIds, const ['local-tag']);
      expect(merged.data, same(playback));
      expect(merged.danmakuData, same(danmaku));
      expect(merged.lastWatchedAt, 123);
    });

    test('room refresh merge accepts an explicit offline snapshot', () {
      final stored = LiveRoom(
        roomId: '100',
        platform: 'bilibili',
        liveStatus: LiveStatus.live,
        status: true,
        isRecord: true,
      );
      final offline = LiveRoom(
        roomId: '100',
        platform: 'bilibili',
        liveStatus: LiveStatus.offline,
        status: false,
        isRecord: false,
      );

      final merged = stored.mergeFrom(offline);

      expect(merged.liveStatus, LiveStatus.offline);
      expect(merged.status, isFalse);
      expect(merged.isRecord, isFalse);
    });

    test('room refresh merge ignores a different platform-room identity', () {
      final stored = LiveRoom(roomId: '100', platform: 'bilibili', title: 'stored');
      final unrelated = LiveRoom(roomId: '100', platform: 'huya', title: 'other');

      expect(stored.mergeFrom(unrelated), same(stored));
    });

    test('migrates Huya URI 8006 heat out of the online-viewer field', () {
      final room = LiveRoom.fromJson({
        'roomId': '998',
        'platform': 'HUYA',
        'watching': '5636930',
        'popularity': '5636930',
        'onlineViewers': '3212923',
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
