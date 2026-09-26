import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/sites.dart';
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

  int audienceCompare(LiveRoom left, LiveRoom right) =>
      LiveRoom.parseAudienceNumber(right.onlineViewers).compareTo(LiveRoom.parseAudienceNumber(left.onlineViewers));

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
        audienceCompare: audienceCompare,
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
        audienceCompare: audienceCompare,
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
        audienceCompare: audienceCompare,
      );
      final byFollowers = LiveSearchRanking.apply(
        rooms: rooms,
        mode: LiveSearchSortMode.followers,
        includeOffline: true,
        platformOrder: const ['bilibili', 'huya'],
        audienceCompare: audienceCompare,
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
        audienceCompare: audienceCompare,
      );

      expect(ranked.single.roomId, 'live');
    });

    test('concurrent mode does not let platform heat overwhelm real viewers', () {
      final online = LiveRoom(roomId: 'online', platform: 'soop', liveStatus: LiveStatus.live, onlineViewers: '120');
      final heat = LiveRoom(roomId: 'heat', platform: 'bilibili', liveStatus: LiveStatus.live, popularity: '900万');
      final ranked = LiveSearchRanking.apply(
        rooms: [heat, online],
        mode: LiveSearchSortMode.audience,
        includeOffline: true,
        platformOrder: const ['bilibili', 'soop'],
        audienceCompare: (left, right) =>
            LiveRoom.compareAudienceRanking(left, right, preferRealOnline: true, platformEnabled: (_) => true),
      );

      expect(ranked.map((item) => item.roomId), ['online', 'heat']);
    });
  });

  test('declares native platform search coverage', () {
    expect(LiveSearchCapabilities.forPlatform('bilibili').mayIncludeOffline, isTrue);
    expect(LiveSearchCapabilities.forPlatform('twitch').mayIncludeOffline, isTrue);
    expect(LiveSearchCapabilities.forPlatform('soop').coverage, NativeSearchCoverage.liveOnly);
    expect(LiveSearchCapabilities.forPlatform('yy').supportsNativeSearch, isTrue);
    expect(LiveSearchCapabilities.forPlatform('kuaishou').coverage, NativeSearchCoverage.liveAndOffline);
    expect(LiveSearchCapabilities.forPlatform('kuaishou').supportsWebSearch, isTrue);
    expect(LiveSearchCapabilities.forPlatform('iptv').supportsPagination, isFalse);
    expect(LiveSearchCapabilities.forPlatform('iptv').supportsWebSearch, isFalse);
  });

  test('every registered adapter with native search is exposed in the search UI', () {
    final expected = <String, (NativeSearchCoverage, bool)>{
      Sites.fc2LiveSite: (NativeSearchCoverage.liveAndOffline, true),
      Sites.steamBroadcastSite: (NativeSearchCoverage.liveAndOffline, true),
      Sites.jdLiveSite: (NativeSearchCoverage.liveAndOffline, true),
      Sites.kugouLiveSite: (NativeSearchCoverage.liveAndOffline, true),
      Sites.baiduLiveSite: (NativeSearchCoverage.roomLookup, false),
      Sites.sixRoomSite: (NativeSearchCoverage.liveAndOffline, false),
      Sites.lookLiveSite: (NativeSearchCoverage.roomLookup, false),
    };
    expect(expected.keys, everyElement(isIn(Sites.supportedSiteIds)));
    for (final entry in expected.entries) {
      final actual = LiveSearchCapabilities.forPlatform(entry.key);
      expect(actual.coverage, entry.value.$1, reason: entry.key);
      expect(actual.supportsPagination, entry.value.$2, reason: entry.key);
      expect(actual.supportsWebSearch, isFalse, reason: entry.key);
    }
    for (final id in Sites.supportedSiteIds) {
      expect(LiveSearchCapabilities.forPlatform(id).supportsNativeSearch, isTrue, reason: id);
    }
  });
}
