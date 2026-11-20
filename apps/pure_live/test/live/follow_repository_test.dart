import 'dart:convert' show jsonEncode;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/live/favorites/data/follow_repository.dart';

/// The follows data layer over the in-memory store: what a follow lands
/// as, what a refresh merge keeps, and what a failed pass marks. The
/// controller and the page both read their answers from here.
void main() {
  late StorageStores stores;
  late JsonStore store;
  late FollowRepository repository;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
    store = await stores.openStore('follows');
    repository = FollowRepository(store);
  });

  tearDown(() => stores.close());

  LiveRoom roomOf(String platform, String id, {LiveStatus? status, List<String> tags = const [], String? title}) =>
      LiveRoom.normalized(
        platform: platform,
        roomId: id,
        content: RoomContent.of(title: title ?? 'Room $id'),
      ).rebuild(
        (b) => b
          ..broadcast.liveStatus = status
          ..local.tagIds.addAll(tags),
      );

  test('add lists in insertion order, a re-add replaces in place', () async {
    await repository.add(roomOf('douyu', '1'));
    await repository.add(roomOf('huya', '2'));
    await repository.add(roomOf('douyu', '3'));
    expect([for (final room in repository.list()) room.identityKey], ['douyu:1', 'huya:2', 'douyu:3']);
    expect(repository.contains('huya:2'), isTrue);

    // The re-add is the follow refresh a card does on open: the entry is
    // replaced whole, the order keeps its place, no second row appears.
    await repository.add(roomOf('huya', '2', title: 'Renamed'));
    expect([for (final room in repository.list()) room.identityKey], ['douyu:1', 'huya:2', 'douyu:3']);
    expect(repository.list()[1].content.title, 'Renamed');

    await repository.remove('douyu:1');
    expect(repository.contains('douyu:1'), isFalse);
    // A room never followed leaves nothing behind and answers nothing.
    await repository.remove('ghost:9');
    expect(repository.list().map((room) => room.identityKey), ['huya:2', 'douyu:3']);
  });

  test('merge stores a stranger and folds a refresh into the stored copy', () async {
    // A room never followed is stored as given.
    await repository.merge(roomOf('douyu', '1', status: LiveStatus.live));
    expect(repository.contains('douyu:1'), isTrue);

    // The stored copy keeps its local tags; the refresh's fresh title and
    // status win; a field the refresh left out never erases the stored one.
    await repository.add(roomOf('douyu', '2', status: LiveStatus.live, tags: ['t1'], title: 'Kept Title'));
    await repository.merge(roomOf('douyu', '2', status: LiveStatus.offline, title: 'Fresh Title'));
    final merged = repository.list().firstWhere((room) => room.identityKey == 'douyu:2');
    expect(merged.content.title, 'Fresh Title');
    expect(merged.broadcast.liveStatus, LiveStatus.offline);
    expect(merged.local.tagIds, ['t1']);
  });

  test('mergeAll lands a whole pass as one write and skips nothing', () async {
    await repository.add(roomOf('douyu', '1', status: LiveStatus.offline));
    var events = 0;
    final subscription = store.watch().listen((_) => events++);
    addTearDown(subscription.cancel);

    await repository.mergeAll([
      roomOf('douyu', '1', status: LiveStatus.live, title: 'Now Live'),
      roomOf('huya', '2', status: LiveStatus.live),
    ]);
    await pumpEventQueue();
    // One pass, one broadcast — not one per room arriving.
    expect(events, 1);
    expect(repository.contains('huya:2'), isTrue);
    expect(repository.list().firstWhere((room) => room.identityKey == 'douyu:1').broadcast.liveStatus, LiveStatus.live);
    // Nothing to write is no write at all.
    await repository.mergeAll(const []);
    await pumpEventQueue();
    expect(events, 1);
  });

  test('markUnknown demotes a stale live badge, makes the silence explicit once, and is idempotent', () async {
    await repository.add(roomOf('douyu', '1', status: LiveStatus.live));
    // A room whose source never said anything reads unknown through the
    // null: the first pass spells that unknown out (null is not the
    // unknown value), and every pass after it must leave the entry be.
    await repository.add(roomOf('huya', '2'));
    var events = 0;
    final subscription = store.watch().listen((_) => events++);
    addTearDown(subscription.cancel);

    await repository.markUnknown(['douyu:1', 'huya:2', 'ghost:9']);
    await pumpEventQueue();
    final demoted = repository.list().firstWhere((room) => room.identityKey == 'douyu:1');
    expect(demoted.broadcast.liveStatus, LiveStatus.unknown);
    expect(
      repository.list().firstWhere((room) => room.identityKey == 'huya:2').broadcast.liveStatus,
      LiveStatus.unknown,
    );
    expect(events, 1); // one batch, one broadcast; the ghost key never existed

    // The second pass over the same failures writes nothing at all.
    final settled = jsonEncode(store.get('huya:2'));
    await repository.markUnknown(['huya:2', 'ghost:9']);
    await pumpEventQueue();
    expect(jsonEncode(store.get('huya:2')), settled);
    expect(events, 1);
  });

  test('watch emits after every committed change', () async {
    final events = <int>[];
    final subscription = store.watch().listen((_) => events.add(events.length));
    addTearDown(subscription.cancel);
    await repository.add(roomOf('douyu', '1'));
    await pumpEventQueue();
    expect(events, [0]);
  });
}
