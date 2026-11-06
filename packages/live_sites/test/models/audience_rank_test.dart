import 'package:live_sites/src/models/audience/audience_rank.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:test/test.dart';

LiveRoom _room(
  String platform,
  String id, {
  int? popularity,
  int? online,
  int? total,
  LiveAudienceMetricType? primary,
}) => LiveRoom.normalized(
  platform: platform,
  roomId: id,
  audience: RoomAudience.of(popularity: popularity, onlineViewers: online, totalViewers: total, primaryMetric: primary),
);

List<String> _ids(Iterable<LiveRoom> rooms) => [for (final room in rooms) room.roomId];

void main() {
  group('the figure a card leads with', () {
    test('the asked-for figure first, then the others in order', () {
      final all = RoomAudience.of(popularity: 5600000, onlineViewers: 18342, totalViewers: 900000);
      expect(all.leadingFigure(LiveAudienceMetricType.onlineViewers), 18342);
      expect(all.leadingFigure(LiveAudienceMetricType.popularity), 5600000);
      expect(all.leadingFigure(LiveAudienceMetricType.totalViewers), 900000);

      final noOnline = RoomAudience.of(popularity: 10, totalViewers: 20);
      expect(noOnline.leadingFigure(LiveAudienceMetricType.onlineViewers), 10, reason: 'heat before cumulative');
      final noTotal = RoomAudience.of(popularity: 10, onlineViewers: 5);
      expect(noTotal.leadingFigure(LiveAudienceMetricType.totalViewers), 10, reason: 'heat before concurrent');
      final noHeat = RoomAudience.of(onlineViewers: 5, totalViewers: 20);
      expect(noHeat.leadingFigure(LiveAudienceMetricType.popularity), 5, reason: 'concurrent before cumulative');
    });

    test('left to the platform, its primary metric leads', () {
      RoomAudience audience(LiveAudienceMetricType? primary) =>
          RoomAudience.of(popularity: 1, onlineViewers: 2, totalViewers: 3, primaryMetric: primary);
      expect(audience(LiveAudienceMetricType.totalViewers).leadingFigure(null), 3);
      expect(audience(LiveAudienceMetricType.onlineViewers).leadingFigure(null), 2);
      expect(audience(LiveAudienceMetricType.followers).leadingFigure(null), 1);
      expect(audience(null).leadingFigure(null), 1);
      expect(
        audience(LiveAudienceMetricType.totalViewers).leadingFigure(LiveAudienceMetricType.unknown),
        3,
        reason: 'a lead that names no figure is the platform own',
      );
    });

    test('a real zero is a figure; no figure is null', () {
      expect(RoomAudience.of(onlineViewers: 0).leadingFigure(null), 0);
      expect(RoomAudience().leadingFigure(null), isNull);
    });
  });

  group('the audience ranking', () {
    test('with real viewers preferred: an explicit count, then a pending one, then heat', () {
      final explicit = _room('douyin', 'explicit', online: 120);
      final pending = _room('soop', 'pending', popularity: 9000000);
      final heat = _room('bilibili', 'heat', popularity: 9000000);
      int compare(LiveRoom a, LiveRoom b) => compareAudienceRanking(a, b, preferRealOnline: true);

      expect(_ids([heat, pending, explicit]..sort(compare)), ['explicit', 'pending', 'heat']);
      expect(explicit.audienceRankKey(preferRealOnline: true).tier, LiveAudienceRankTier.concurrent);
      expect(pending.audienceRankKey(preferRealOnline: true).tier, LiveAudienceRankTier.pendingConcurrent);
      expect(heat.audienceRankKey(preferRealOnline: true).tier, LiveAudienceRankTier.native);
    });

    test('a platform the preference does not reach ranks by its native figure', () {
      final douyin = _room('douyin', 'd', online: 120, total: 50000, primary: LiveAudienceMetricType.totalViewers);
      final key = douyin.audienceRankKey(preferRealOnline: true, platformEnabled: false);
      expect(key.tier, LiveAudienceRankTier.native);
      expect(key.value, 50000);

      final twitch = _room('twitch', 't', online: 300);
      int compare(LiveRoom a, LiveRoom b) =>
          compareAudienceRanking(a, b, preferRealOnline: true, platformEnabled: (platform) => platform == 'twitch');
      expect(_ids([douyin, twitch]..sort(compare)), ['t', 'd'], reason: 'real viewers outrank any native figure');
    });

    test('without the preference, the native figures compete as they are', () {
      final heat = _room('bilibili', 'heat', popularity: 5000000);
      final online = _room('douyin', 'online', online: 3200, primary: LiveAudienceMetricType.onlineViewers);
      expect(_ids([online, heat]..sort(compareAudienceRanking)), ['heat', 'online']);
      expect(online.audienceRankKey().tier, LiveAudienceRankTier.native);
    });

    test('asking for concurrent viewers ranks them first on every platform that has them', () {
      final twitch = _room('twitch', 'twitch', online: 3000);
      final douyin = _room('douyin', 'douyin', total: 120000, primary: LiveAudienceMetricType.totalViewers);
      final bilibili = _room('bilibili', 'bilibili', popularity: 5000000);
      int compare(LiveRoom a, LiveRoom b) => compareAudienceRanking(a, b, lead: LiveAudienceMetricType.onlineViewers);
      expect(_ids([bilibili, douyin, twitch]..sort(compare)), ['twitch', 'douyin', 'bilibili']);
    });

    test('a pending room keeps the figure its card falls back to', () {
      final small = _room('douyin', 'small', total: 300, primary: LiveAudienceMetricType.totalViewers);
      final large = _room('douyin', 'large', total: 120000, primary: LiveAudienceMetricType.totalViewers);
      int compare(LiveRoom a, LiveRoom b) => compareAudienceRanking(a, b, preferRealOnline: true);
      expect(_ids([small, large]..sort(compare)), ['large', 'small']);
      expect(large.audienceRankKey(preferRealOnline: true).value, 120000);
      expect(_room('douyin', 'bare').audienceRankKey(preferRealOnline: true).value, 0);
    });

    test('an explicit zero is a concurrent count and outranks a pending one', () {
      final zero = _room('douyin', 'zero', online: 0);
      final pending = _room('soop', 'pending', popularity: 9000000);
      int compare(LiveRoom a, LiveRoom b) => compareAudienceRanking(a, b, preferRealOnline: true);
      expect(_ids([pending, zero]..sort(compare)), ['zero', 'pending']);
    });

    test('a room without any figure ranks last', () {
      final bare = _room('twitch', 'bare');
      final zero = _room('bilibili', 'zero', popularity: 0);
      expect(bare.audienceRankKey().tier, LiveAudienceRankTier.none);
      expect(_ids([bare, zero]..sort(compareAudienceRanking)), ['zero', 'bare']);
    });

    test('equal ranks fall back to identity, whatever order they arrive in', () {
      final first = _room('twitch', '1', online: 50);
      final second = _room('twitch', '2', online: 50);
      expect(_ids([second, first]..sort(compareAudienceRanking)), ['1', '2']);
      expect(_ids([first, second]..sort(compareAudienceRanking)), ['1', '2']);
      expect(compareAudienceRanking(first, first), 0);
    });

    test('a key orders by tier before value', () {
      const concurrent = LiveAudienceRankKey(tier: LiveAudienceRankTier.concurrent, value: 1);
      const heat = LiveAudienceRankKey(tier: LiveAudienceRankTier.native, value: 1000000);
      expect(concurrent.compareTo(heat), greaterThan(0));
      expect(heat.compareTo(concurrent), lessThan(0));
      expect(
        const LiveAudienceRankKey(tier: LiveAudienceRankTier.native, value: 2).compareTo(heat),
        lessThan(0),
        reason: 'within a tier the value decides',
      );
    });
  });
}
