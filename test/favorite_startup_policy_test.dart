import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/modules/favorite/favorite_startup_policy.dart';

void main() {
  test('favourite identity is platform scoped and normalizes imported values', () {
    final bilibili = LiveRoom(roomId: ' 100 ', platform: ' BILIBILI ');
    final canonicalBilibili = LiveRoom(roomId: '100', platform: 'bilibili');
    final huya = LiveRoom(roomId: '100', platform: 'huya');

    expect(favoriteRoomIdentity(bilibili), 'bilibili:100');
    expect(bilibili, canonicalBilibili);
    expect(bilibili.hashCode, canonicalBilibili.hashCode);
    expect(favoriteRoomIdentity(huya), 'huya:100');
    expect(bilibili, isNot(huya), reason: 'room numbers are only unique inside one platform');
  });

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

  test('startup verification publishes one complete success and failure snapshot', () {
    final first = LiveRoom(
      roomId: '100',
      platform: 'bilibili',
      title: 'old first',
      liveStatus: LiveStatus.live,
      tagIds: const ['sleep'],
    );
    final second = LiveRoom(roomId: '200', platform: 'huya', title: 'old second', liveStatus: LiveStatus.live);
    final firstUpdate = LiveRoom(
      roomId: '100',
      platform: 'bilibili',
      title: 'fresh first',
      liveStatus: LiveStatus.live,
    );

    final verified = buildVerifiedFavoriteSnapshot([first, second], {favoriteRoomIdentity(firstUpdate): firstUpdate});

    expect(verified, hasLength(2));
    expect(verified[0].title, 'fresh first');
    expect(verified[0].liveStatus, LiveStatus.live);
    expect(verified[0].tagIds, ['sleep']);
    expect(verified[1].title, 'old second');
    expect(verified[1].liveStatus, LiveStatus.unknown);
    expect(verified[1].status, isFalse);
  });
}
