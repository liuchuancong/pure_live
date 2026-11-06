import 'package:live_sites/src/models/audience/audience_capability/audience_capability.dart';
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

void main() {
  group('the audience fallback of a fresh answer', () {
    test('a figure the answer leaves out keeps the previous one', () {
      final previous = _room('douyu', '1', popularity: 500, total: 30, primary: LiveAudienceMetricType.popularity);
      final fresh = _room('douyu', '1', online: 7);
      final audience = fresh.withAudienceFallbackFrom(previous).audience;
      expect(audience.popularity, 500);
      expect(audience.onlineViewers, 7);
      expect(audience.totalViewers, 30);
      expect(audience.primaryMetric, LiveAudienceMetricType.popularity);
    });

    test("Bilibili's transient 1 keeps the busy room's figure; a plausible one is taken", () {
      final list = _room('bilibili', '545068', popularity: 278000, primary: LiveAudienceMetricType.popularity);
      int? after(int popularity) => _room(
        'bilibili',
        '545068',
        popularity: popularity,
        primary: LiveAudienceMetricType.popularity,
      ).withAudienceFallbackFrom(list).audience.popularity;
      expect(after(1), 278000);
      expect(after(0), 278000);
      expect(after(281500), 281500, reason: 'a later heartbeat-sized figure is accepted');
      expect(after(2), 2);
    });

    test('a small room may really drop to one', () {
      final previous = _room('bilibili', '1', popularity: 999);
      expect(_room('bilibili', '1', popularity: 1).withAudienceFallbackFrom(previous).audience.popularity, 1);
    });

    test('only a platform whose detail glitches so is guarded', () {
      final previous = _room('douyu', '1', popularity: 278000);
      expect(_room('douyu', '1', popularity: 1).withAudienceFallbackFrom(previous).audience.popularity, 1);
      expect(LiveAudienceCapability.of('bilibili').hasTransientPopularityDrop, isTrue);
      expect(LiveAudienceCapability.of('douyu').hasTransientPopularityDrop, isFalse);
      expect(LiveAudienceCapability.of('no-such-site').hasTransientPopularityDrop, isFalse);
    });

    test('another identity is ignored, and nothing to fill returns the room itself', () {
      final detail = _room('bilibili', '545068', popularity: 1);
      expect(detail.withAudienceFallbackFrom(_room('bilibili', 'other', popularity: 278000)), same(detail));
      final complete = _room(
        'douyu',
        '1',
        popularity: 10,
        online: 2,
        total: 3,
        primary: LiveAudienceMetricType.popularity,
      );
      expect(complete.withAudienceFallbackFrom(_room('douyu', '1', popularity: 99)), same(complete));
    });

    test("the stored copy's refresh merge takes the same guard", () {
      final stored = _room('bilibili', '545068', popularity: 278000, total: 1200);
      expect(stored.mergedWith(_room('bilibili', '545068', popularity: 1)).audience.popularity, 278000);
      expect(stored.mergedWith(_room('bilibili', '545068', popularity: 281500)).audience.popularity, 281500);
      expect(stored.mergedWith(_room('bilibili', '545068')).audience.totalViewers, 1200);
    });

    test('the audience merge itself is guarded only when asked', () {
      final stored = RoomAudience.of(popularity: 278000);
      final glitch = RoomAudience.of(popularity: 1);
      expect(stored.mergedWith(glitch, hasTransientPopularityDrop: true).popularity, 278000);
      expect(stored.mergedWith(glitch).popularity, 1);
      expect(RoomAudience().mergedWith(glitch, hasTransientPopularityDrop: true).popularity, 1);
    });
  });
}
