import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/live/history/history_repository.dart';

/// The history data layer over the in-memory store: what a watch lands as,
/// what a refresh keeps, where the cap cuts, and what a clear may delete.
/// The page and the recorder both read their answers from here.
void main() {
  late StorageStores stores;
  late JsonStore store;
  late HistoryRepository repository;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
    store = await stores.openStore('history');
    repository = HistoryRepository(store);
  });

  tearDown(() => stores.close());

  LiveRoom roomOf(String platform, String id, {String? title}) => LiveRoom.normalized(
    platform: platform,
    roomId: id,
    content: RoomContent.of(title: title ?? 'Room $id'),
  );

  DateTime daysAgo(int days) => DateTime.now().toUtc().subtract(Duration(days: days));

  test('record lists newest first, watching again moves to the top', () async {
    await repository.record(roomOf('douyu', '1'), daysAgo(3));
    await repository.record(roomOf('huya', '2'), daysAgo(2));
    await repository.record(roomOf('douyu', '3'), daysAgo(1));
    expect(repository.list().map((room) => room.identityKey).toList(), ['douyu:3', 'huya:2', 'douyu:1']);

    // The oldest room watched again: it moves to the top, no second row.
    await repository.record(roomOf('douyu', '1'), daysAgo(0));
    expect(repository.list().map((room) => room.identityKey).toList(), ['douyu:1', 'douyu:3', 'huya:2']);
  });

  test('record merges the fresh read into the stored copy', () async {
    await repository.record(roomOf('douyu', '1', title: 'Old Title'), daysAgo(1));
    await repository.record(roomOf('douyu', '1', title: 'New Title'), daysAgo(0));
    expect(repository.list().single.content.title, 'New Title');
  });

  test("entries answer their moments in the viewer's own timezone", () async {
    // A watch stored at 02:30 UTC: the day sections cut local days, and an
    // after-midnight Shanghai evening must not read as yesterday.
    final moment = DateTime.utc(2026, 1, 10, 2, 30);
    await repository.record(roomOf('douyu', '1'), moment);
    final (room, watchedAt) = repository.entries().single;
    expect(room.identityKey, 'douyu:1');
    expect(watchedAt.isUtc, isFalse);
    expect(watchedAt.toUtc(), moment);
  });

  test('updateRoom keeps the watch moment and takes the fresh fields', () async {
    await repository.record(roomOf('douyu', '1', title: 'Old'), daysAgo(5));
    await repository.record(roomOf('douyu', '2'), daysAgo(1));
    await repository.updateRoom(roomOf('douyu', '1', title: 'Fresh'));

    final records = repository.entries();
    expect(records[0].$1.identityKey, 'douyu:2'); // the order never moved
    expect(records[1].$1.content.title, 'Fresh');
    // A room never watched is not added by a refresh.
    await repository.updateRoom(roomOf('douyu', '9'));
    expect(repository.list().length, 2);
  });

  test('updateAll lands one write, keeps moments, skips strangers', () async {
    await repository.record(roomOf('douyu', '1', title: 'One'), daysAgo(2));
    await repository.record(roomOf('huya', '2', title: 'Two'), daysAgo(1));
    var events = 0;
    final subscription = store.watch().listen((_) => events++);
    addTearDown(subscription.cancel);

    await repository.updateAll([
      roomOf('douyu', '1', title: 'One Fresh'),
      roomOf('huya', '2', title: 'Two Fresh'),
      roomOf('douyu', '9'), // never watched
    ]);
    await pumpEventQueue();
    expect(events, 1);
    final records = repository.list();
    expect(records.map((room) => room.content.title), ['Two Fresh', 'One Fresh']);
    // The order — and so the moments behind it — never moved.
    expect(records[1].identityKey, 'douyu:1');
  });

  test('the cap keeps the newest and zero keeps everything', () async {
    for (final (index, room) in ['1', '2', '3', '4', '5'].indexed) {
      await repository.record(roomOf('douyu', room), daysAgo(5 - index));
    }
    await repository.record(roomOf('huya', '6'), daysAgo(0), limit: 3);
    expect(repository.list().map((room) => room.identityKey), ['huya:6', 'douyu:5', 'douyu:4']);

    // 不设上限: nothing leaves.
    await repository.record(roomOf('douyu', '1'), daysAgo(9), limit: 0);
    expect(repository.list().length, 4);
  });

  test('clear drops what was shown and spares what moved on', () async {
    await repository.record(roomOf('douyu', '1'), daysAgo(2));
    await repository.record(roomOf('huya', '2'), daysAgo(1));
    final shown = repository.entries();

    // huya:2 watched again between the render and the clear: the version
    // the viewer looked at is not theirs to delete.
    await repository.record(roomOf('huya', '2'), daysAgo(0));
    await repository.clear(shown);
    expect(repository.list().map((room) => room.identityKey), ['huya:2']);
    // A record never shown is a no-op.
    await repository.clear([(roomOf('douyu', '9'), daysAgo(0))]);
    expect(repository.list().length, 1);
  });
}
