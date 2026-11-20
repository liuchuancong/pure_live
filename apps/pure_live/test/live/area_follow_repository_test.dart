import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/live/areas/data/area_follow_repository.dart';

/// The area-follows data layer over the in-memory store: what a follow
/// lands as, how the toggle answers, and which fields the round trip keeps.
void main() {
  late StorageStores stores;
  late JsonStore store;
  late AreaFollowRepository repository;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
    store = await stores.openStore('area_follows');
    repository = AreaFollowRepository(store);
  });

  tearDown(() => stores.close());

  LiveArea areaOf(String platform, String id, {String? parent, String? icon}) =>
      LiveArea.normalized(platform: platform, areaId: id, areaName: 'Area $id', parentAreaName: parent, iconUrl: icon);

  test('add lists in insertion order, toggle answers and flips', () async {
    await repository.add(areaOf('douyu', '1'));
    await repository.add(areaOf('huya', '2'));
    expect([for (final area in repository.list()) area.identityKey], ['douyu:1', 'huya:2']);
    expect(repository.contains('douyu:1'), isTrue);

    expect(await repository.toggle(areaOf('douyu', '1')), isFalse);
    expect(repository.contains('douyu:1'), isFalse);
    expect(await repository.toggle(areaOf('douyu', '1')), isTrue);
    expect(repository.contains('douyu:1'), isTrue);
    // A never-followed area unfollowed is a no-op.
    await repository.remove('ghost:9');
    expect(repository.list().length, 2);
  });

  test('the round trip keeps the names and the optional fields', () async {
    await repository.add(areaOf('douyu', '1', parent: '网游', icon: 'https://icon/1.png'));
    final stored = repository.list().single;
    expect(stored.platform, 'douyu');
    expect(stored.areaId, '1');
    expect(stored.areaName, 'Area 1');
    expect(stored.parentAreaName, '网游');
    expect(stored.iconUrl, 'https://icon/1.png');

    // A follow without the optional fields reads back empties, not nulls
    // the card cannot render.
    await repository.add(areaOf('huya', '2'));
    final bare = repository.list().firstWhere((area) => area.identityKey == 'huya:2');
    expect(bare.parentAreaName, isNull);
    expect(bare.iconUrl, isNull);
  });
}
