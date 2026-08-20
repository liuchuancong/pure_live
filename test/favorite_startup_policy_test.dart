import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/modules/favorite/favorite_startup_policy.dart';

void main() {
  test('startup snapshot never carries a stale live state', () {
    final original = LiveRoom(
      roomId: '100',
      platform: 'bilibili',
      title: 'cached title',
      cover: 'cached cover',
      status: true,
      liveStatus: LiveStatus.live,
      tagIds: const ['sleep'],
    );

    final pending = markFavoriteRoomsPendingVerification([original]).single;

    expect(pending.status, isFalse);
    expect(pending.liveStatus, LiveStatus.unknown);
    expect(pending.title, original.title);
    expect(pending.cover, original.cover);
    expect(pending.tagIds, original.tagIds);
    expect(original.liveStatus, LiveStatus.live, reason: 'the persisted input is not mutated in place');
  });

  test('refresh merge preserves local tags and does not restore removed rooms', () {
    final kept = LiveRoom(
      roomId: '100',
      platform: 'bilibili',
      title: 'cached',
      popularity: '9000',
      liveStatus: LiveStatus.unknown,
      tagIds: const ['sleep'],
    );
    final removedResponse = LiveRoom(roomId: '200', platform: 'huya', liveStatus: LiveStatus.live);
    final refreshed = LiveRoom(
      roomId: '100',
      platform: 'bilibili',
      title: 'fresh',
      popularity: '',
      liveStatus: LiveStatus.live,
      tagIds: const ['remote-tag'],
    );

    final result = mergeFavoriteRoomUpdates(
      [kept],
      {favoriteRoomIdentity(refreshed): refreshed, favoriteRoomIdentity(removedResponse): removedResponse},
    );

    expect(result.changed, isTrue);
    expect(result.rooms, hasLength(1));
    expect(result.rooms.single.title, 'fresh');
    expect(result.rooms.single.liveStatus, LiveStatus.live);
    expect(result.rooms.single.tagIds, ['sleep']);
    expect(result.rooms.single.effectivePopularity, '9000');
    expect(refreshed.tagIds, ['remote-tag'], reason: 'network response is not mutated in place');
  });

  test('refresh merge keeps object identity when no response matches', () {
    final current = LiveRoom(roomId: '100', platform: 'bilibili');
    final result = mergeFavoriteRoomUpdates([current], {'huya:200': LiveRoom(roomId: '200', platform: 'huya')});

    expect(result.changed, isFalse);
    expect(result.rooms.single, same(current));
  });
}
