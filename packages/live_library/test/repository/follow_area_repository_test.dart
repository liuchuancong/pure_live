import 'package:live_library/live_library.dart';
import 'package:live_sites/live_sites.dart' show LiveArea;
import 'package:test/test.dart';

LiveArea _area({String platform = 'douyu', String id = '1', String name = '网游'}) =>
    LiveArea(platform: platform, areaId: id, areaName: name);

void main() {
  test('following a partition adds it once and reports it', () async {
    final repository = FollowAreaRepository(InMemoryLibraryStore());
    await repository.load();
    final area = _area();

    expect(repository.isFollowing(area), isFalse);
    await repository.follow(area);

    expect(repository.isFollowing(area), isTrue);
    expect(repository.areas, hasLength(1));
    expect(repository.areas.single.name, '网游');
    expect(repository.areas.single.identityKey, 'douyu:1');
    await repository.dispose();
  });

  test('following again moves it to the top and refreshes the name', () async {
    final repository = FollowAreaRepository(InMemoryLibraryStore());
    await repository.load();
    await repository.follow(_area());
    await repository.follow(_area(id: '2'));
    expect(repository.areas.map((a) => a.areaId), ['2', '1']);

    await repository.follow(_area(name: '端游'));

    expect(repository.areas.map((a) => a.areaId), ['1', '2']);
    expect(repository.areas.map((a) => a.position), [0, 1]);
    expect(repository.areas.first.name, '端游');
    await repository.dispose();
  });

  test('unfollowing a partition nobody followed changes nothing', () async {
    final repository = FollowAreaRepository(InMemoryLibraryStore());
    await repository.load();
    await repository.follow(_area());

    await repository.unfollow(_area(id: 'nope'));
    expect(repository.areas, hasLength(1));

    await repository.unfollow(_area());
    expect(repository.areas, isEmpty);
    await repository.dispose();
  });

  test('a move is saved, and a second reader sees the same order', () async {
    final store = InMemoryLibraryStore();
    final repository = FollowAreaRepository(store);
    await repository.load();
    for (final id in ['1', '2', '3']) {
      await repository.follow(_area(id: id));
    }

    await repository.move('douyu:3', 0);
    expect(repository.areas.map((a) => a.areaId), ['3', '2', '1']);

    final reopened = FollowAreaRepository(store);
    await reopened.load();
    expect(reopened.areas.map((a) => a.areaId), ['3', '2', '1']);
    expect(reopened.areas.map((a) => a.position), [0, 1, 2]);

    await repository.dispose();
    await reopened.dispose();
  });

  test('a record round-trips through the stored JSON', () async {
    final area = FollowArea(
      platform: 'huya',
      areaId: 'x',
      name: '星秀',
      followedAt: DateTime.utc(2026, 10, 21),
      position: 4,
    );
    final json = area.toJson();
    expect(FollowArea.fromJson(json), area);
    expect(json['platform'], 'huya');
  });
}
