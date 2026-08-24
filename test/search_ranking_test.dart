import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/modules/search/search_capability.dart';
import 'package:pure_live/modules/search/search_ranking.dart';

void main() {
  LiveRoom room({
    required String id,
    required String platform,
    required LiveStatus status,
    String audience = '0',
    String followers = '0',
  }) {
    return LiveRoom(
      roomId: id,
      platform: platform,
      liveStatus: status,
      onlineViewers: audience,
      followers: followers,
      title: id,
    );
  }

  int audienceValue(LiveRoom value) => LiveRoom.parseAudienceNumber(value.onlineViewers);

  group('search ranking', () {
    test('keeps live rooms before a larger offline channel', () {
      final ranked = LiveSearchRanking.apply(
        rooms: [
          room(id: 'offline', platform: 'bilibili', status: LiveStatus.offline, audience: '500000'),
          room(id: 'live', platform: 'huya', status: LiveStatus.live, audience: '100'),
        ],
        mode: LiveSearchSortMode.smart,
        includeOffline: true,
        platformOrder: const ['bilibili', 'huya'],
        audienceValue: audienceValue,
      );

      expect(ranked.map((item) => item.roomId), ['live', 'offline']);
    });

    test('platform mode follows the user configured home order', () {
      final ranked = LiveSearchRanking.apply(
        rooms: [
          room(id: 'bili', platform: 'bilibili', status: LiveStatus.live, audience: '9000'),
          room(id: 'huya', platform: 'huya', status: LiveStatus.live, audience: '100'),
        ],
        mode: LiveSearchSortMode.platform,
        includeOffline: true,
        platformOrder: const ['huya', 'bilibili'],
        audienceValue: audienceValue,
      );

      expect(ranked.map((item) => item.roomId), ['huya', 'bili']);
    });

    test('audience and follower modes use their respective values', () {
      final rooms = [
        room(id: 'audience', platform: 'huya', status: LiveStatus.live, audience: '2万', followers: '10'),
        room(id: 'followers', platform: 'bilibili', status: LiveStatus.live, audience: '100', followers: '30万'),
      ];

      final byAudience = LiveSearchRanking.apply(
        rooms: rooms,
        mode: LiveSearchSortMode.audience,
        includeOffline: true,
        platformOrder: const ['bilibili', 'huya'],
        audienceValue: audienceValue,
      );
      final byFollowers = LiveSearchRanking.apply(
        rooms: rooms,
        mode: LiveSearchSortMode.followers,
        includeOffline: true,
        platformOrder: const ['bilibili', 'huya'],
        audienceValue: audienceValue,
      );

      expect(byAudience.first.roomId, 'audience');
      expect(byFollowers.first.roomId, 'followers');
    });

    test('offline filter only keeps currently live rooms', () {
      final ranked = LiveSearchRanking.apply(
        rooms: [
          room(id: 'live', platform: 'huya', status: LiveStatus.live),
          room(id: 'offline', platform: 'bilibili', status: LiveStatus.offline),
        ],
        mode: LiveSearchSortMode.smart,
        includeOffline: false,
        platformOrder: const ['bilibili', 'huya'],
        audienceValue: audienceValue,
      );

      expect(ranked.single.roomId, 'live');
    });
  });

  test('declares native and web-only platform search coverage', () {
    expect(LiveSearchCapabilities.forPlatform('bilibili').mayIncludeOffline, isTrue);
    expect(LiveSearchCapabilities.forPlatform('twitch').mayIncludeOffline, isTrue);
    expect(LiveSearchCapabilities.forPlatform('soop').coverage, NativeSearchCoverage.liveOnly);
    expect(LiveSearchCapabilities.forPlatform('yy').supportsNativeSearch, isTrue);
    expect(LiveSearchCapabilities.forPlatform('kuaishou').supportsNativeSearch, isFalse);
    expect(LiveSearchCapabilities.forPlatform('iptv').supportsPagination, isFalse);
    expect(LiveSearchCapabilities.forPlatform('iptv').supportsWebSearch, isFalse);
  });
}
