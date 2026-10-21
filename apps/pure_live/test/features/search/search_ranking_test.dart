// The search ordering, pinned: live rooms first, then playable ones; inside
// a state the picked mode decides, and the platform order is the user's.
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom, LiveStatus, RoomAudience, RoomBroadcast, RoomContent;
import 'package:pure_live/features/search/search_ranking.dart';

LiveRoom _room(
  String platform,
  String id, {
  int? viewers,
  int? total,
  LiveStatus status = LiveStatus.live,
  String title = 't',
}) => LiveRoom.normalized(
  platform: platform,
  roomId: id,
  content: RoomContent(title: title),
  audience: RoomAudience(onlineViewers: viewers, totalViewers: total),
  broadcast: RoomBroadcast(liveStatus: status),
);

List<String> _ids(List<LiveRoom> rooms) => [for (final room in rooms) room.ref.roomId];

void main() {
  const always = _playable;

  test('live rooms lead, then playable ones, then the rest', () {
    final ordered = rankedSearchRooms(
      [
        _room('douyu', 'off', status: LiveStatus.offline),
        _room('douyu', 'live', viewers: 1),
        _room('douyu', 'replay', status: LiveStatus.replay, viewers: 999),
      ],
      mode: SearchSortMode.smart,
      includeOffline: true,
      platformOrder: const [],
      playable: always,
    );
    expect(_ids(ordered), ['live', 'replay', 'off']);
  });

  test('smart mode orders by audience first', () {
    final ordered = rankedSearchRooms(
      [_room('douyu', 'a', viewers: 10), _room('douyu', 'b', viewers: 99)],
      mode: SearchSortMode.smart,
      includeOffline: true,
      platformOrder: const [],
      playable: always,
    );
    expect(_ids(ordered), ['b', 'a']);
  });

  test('platform mode puts the user order first', () {
    final ordered = rankedSearchRooms(
      [_room('douyu', 'a', viewers: 100), _room('huya', 'b', viewers: 1)],
      mode: SearchSortMode.platform,
      includeOffline: true,
      platformOrder: const ['huya', 'douyu'],
      playable: always,
    );
    expect(_ids(ordered), ['b', 'a']);
  });

  test('offline rooms are dropped when the switch is off', () {
    final ordered = rankedSearchRooms(
      [_room('douyu', 'off', status: LiveStatus.offline)],
      mode: SearchSortMode.smart,
      includeOffline: false,
      platformOrder: const [],
      playable: (_) => false,
    );
    expect(ordered, isEmpty);
  });

  test('equal rooms keep a stable identity order', () {
    final ordered = rankedSearchRooms(
      [_room('douyu', 'b', viewers: 5), _room('douyu', 'a', viewers: 5)],
      mode: SearchSortMode.smart,
      includeOffline: true,
      platformOrder: const [],
      playable: always,
    );
    expect(_ids(ordered), ['a', 'b']);
  });
}

bool _playable(LiveRoom room) => room.broadcast.effectiveLiveStatus == LiveStatus.replay;
