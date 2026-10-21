// The follow page's two rules, pinned: the platform tabs follow the user's
// platform order, and the grid orders by the chosen tag then the audience —
// with the "real viewers" preference lifting the platforms it trusts.
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom, RoomAudience, RoomContent;
import 'package:pure_live/features/follow/follow_rules.dart';

LiveRoom _room(String platform, String id, {int? viewers, int? popularity}) => LiveRoom.normalized(
  platform: platform,
  roomId: id,
  content: const RoomContent(title: 't'),
  audience: RoomAudience(onlineViewers: viewers, popularity: popularity),
);

void main() {
  group('platform tabs', () {
    test('the stored order first, then the registry, unknown ids last', () {
      final rooms = [
        _room('douyu', '1'),
        _room('huya', '2'),
        _room('bilibili', '3'),
        _room('zzz_unknown', '4'),
      ];
      expect(
        followPlatformTabs(rooms, ['huya', 'douyu'], registryOrder: ['bilibili', 'douyu', 'huya']),
        ['huya', 'douyu', 'bilibili', 'zzz_unknown'],
      );
    });

    test('platforms without a follow are left out', () {
      expect(followPlatformTabs([_room('douyu', '1')], ['huya', 'douyu'], registryOrder: ['huya', 'douyu']), ['douyu']);
    });
  });

  group('ordering', () {
    FollowOrdering order({bool preferRealOnline = false, Set<String> enabled = const {}, Map<String, int> tags = const {}}) =>
        FollowOrdering(preferRealOnline: preferRealOnline, realOnlinePlatforms: enabled, tagRank: tags);

    test('larger audience first', () {
      final rooms = [_room('douyu', 'a', viewers: 10), _room('douyu', 'b', viewers: 99)];
      final sorted = [...rooms]..sort(order().compare);
      expect([for (final room in sorted) room.ref.roomId], ['b', 'a']);
    });

    test('a room with a figure outranks one without', () {
      final rooms = [_room('douyu', 'silent'), _room('douyu', 'known', popularity: 1)];
      final sorted = [...rooms]..sort(order().compare);
      expect([for (final room in sorted) room.ref.roomId], ['known', 'silent']);
    });

    test('the trusted platform is lifted even with fewer viewers', () {
      final rooms = [_room('douyu', 'big', viewers: 100), _room('bilibili', 'real', viewers: 5)];
      final sorted = [...rooms]..sort(order(preferRealOnline: true, enabled: {'bilibili'}).compare);
      expect([for (final room in sorted) room.ref.roomId], ['real', 'big']);
    });

    test('without the preference the plain audience decides', () {
      final rooms = [_room('douyu', 'big', viewers: 100), _room('bilibili', 'real', viewers: 5)];
      final sorted = [...rooms]..sort(order().compare);
      expect([for (final room in sorted) room.ref.roomId], ['big', 'real']);
    });

    test('the chosen tag outweighs the audience', () {
      final rooms = [_room('douyu', 'big', viewers: 100), _room('douyu', 'tagged', viewers: 1)];
      final sorted = [...rooms]..sort(order(tags: {'douyu:tagged': 2}).compare);
      expect([for (final room in sorted) room.ref.roomId], ['tagged', 'big']);
    });

    test('equal audiences keep a stable identity order', () {
      final rooms = [_room('douyu', 'b', viewers: 7), _room('douyu', 'a', viewers: 7)];
      final sorted = [...rooms]..sort(order().compare);
      expect([for (final room in sorted) room.ref.roomId], ['a', 'b']);
    });
  });
}
