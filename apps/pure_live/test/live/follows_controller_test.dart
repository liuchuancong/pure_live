import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right;
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/browse/sites_providers.dart' show sitesProvider;
import 'package:pure_live/modules/live/favorites/alerts/live_alert_events.dart' show liveAlertObserver;
import 'package:pure_live/modules/live/favorites/data/follow_repository.dart';

/// The follows controller over the in-memory store and a fake site: the
/// refresh pass — what merges, what a failure marks, who sits the cooldown
/// out — is the machinery every page and the alert watcher share, so it is
/// the part worth arguing.
void main() {
  late StorageStores stores;
  late JsonStore store;
  late FollowRepository repository;
  late ProviderContainer container;

  /// The fake registry's current sites; the provider override reads it.
  var currentSites = const <LiveSite>[];

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
    store = await stores.openStore('follows');
    repository = FollowRepository(store);
    container = ProviderContainer(
      overrides: [
        followRepositoryProvider.overrideWith((ref) async => repository),
        sitesProvider.overrideWith((ref) => LiveSiteRegistry(currentSites)),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() => stores.close());

  LiveRoom roomOf(String platform, String id, {LiveStatus? status, String? title}) => LiveRoom.normalized(
    platform: platform,
    roomId: id,
    content: RoomContent.of(title: title ?? 'Room $id'),
  ).rebuild((b) => b..broadcast.liveStatus = status);

  /// The repository loaded, the controller mounted and settled.
  Future<void> ready() async {
    await container.read(followRepositoryProvider.future);
    container.read(followsProvider);
    await pumpEventQueue();
  }

  /// Installs (or replaces) the fake registry: a site per id, the room
  /// provider only when [servesRooms] holds, answering [answerFor] per
  /// room id.
  void installSites({
    required Map<String, Future<Either<LiveSiteError, LiveRoom>> Function(String roomId)> answerFor,
    bool servesRooms = true,
  }) {
    currentSites = [
      for (final entry in answerFor.entries)
        _FakeSite(entry.key, roomProvider: servesRooms ? _FakeRoomProvider(entry.value) : null),
    ];
    container.invalidate(sitesProvider);
  }

  test('the controller mirrors the store and follows changes from anywhere', () async {
    await ready();
    expect(container.read(followsProvider).ready, isTrue);
    expect(container.read(followsProvider).rooms, isEmpty);
    await repository.add(roomOf('douyu', '1', status: LiveStatus.live));
    await pumpEventQueue();
    expect(container.read(followsProvider).rooms.single.identityKey, 'douyu:1');
  });

  test('a refresh pass merges the fresh answers and reports no failures', () async {
    await repository.add(roomOf('douyu', '1', status: LiveStatus.offline));
    await ready();
    installSites(
      answerFor: {
        'douyu': (roomId) async => Right(roomOf('douyu', roomId, status: LiveStatus.live, title: 'Now Live')),
      },
    );

    final failed = await container.read(followsProvider.notifier).refreshRooms([roomOf('douyu', '1')]);
    await pumpEventQueue();
    expect(failed, 0);
    final stored = repository.list().single;
    expect(stored.content.title, 'Now Live');
    expect(stored.broadcast.liveStatus, LiveStatus.live);
  });

  test('a platform answering under another id still lands on the follow', () async {
    await repository.add(roomOf('douyu', '1', status: LiveStatus.offline));
    await ready();
    installSites(
      answerFor: {
        // The detail names room 999: the merge must not grow a second entry
        // for it — the follow's own identity is where the answer lands.
        'douyu': (roomId) async => Right(roomOf('douyu', '999', status: LiveStatus.live, title: 'Moved')),
      },
    );

    final failed = await container.read(followsProvider.notifier).refreshRooms([roomOf('douyu', '1')]);
    await pumpEventQueue();
    expect(failed, 0);
    expect([for (final room in repository.list()) room.identityKey], ['douyu:1']);
    expect(repository.list().single.content.title, 'Moved');
  });

  test('a failed ask marks the stored copy unknown and sits the cooldown out', () async {
    await repository.add(roomOf('douyu', '1', status: LiveStatus.live));
    await ready();
    final room = roomOf('douyu', '1', status: LiveStatus.live);
    installSites(
      answerFor: {'douyu': (roomId) async => const Left(LiveSiteError.notFound(siteId: 'douyu', message: 'gone'))},
    );
    final notifier = container.read(followsProvider.notifier);

    expect(await notifier.refreshRooms([room]), 1);
    await pumpEventQueue();
    expect(repository.list().single.broadcast.liveStatus, LiveStatus.unknown);

    // The background pass skips the room that just failed: no ask, no new
    // failures, the stored copy untouched.
    expect(await notifier.refreshRooms([room]), 0);
    expect(await notifier.refreshRooms([room]), 0);

    // The viewer's own pass ignores the cooldown and asks again; a success
    // both clears the cooldown and restores what the platform says.
    installSites(
      answerFor: {'douyu': (roomId) async => Right(roomOf('douyu', roomId, status: LiveStatus.live, title: 'Back'))},
    );
    expect(await notifier.refreshRooms([room], bypassCooldown: true), 0);
    await pumpEventQueue();
    final stored = repository.list().single;
    expect(stored.broadcast.liveStatus, LiveStatus.live);
    expect(stored.content.title, 'Back');
  });

  test('the progress callback counts the queue from zero to full', () async {
    await ready();
    installSites(
      answerFor: {
        'douyu': (roomId) async => Right(roomOf('douyu', roomId, status: LiveStatus.live)),
        'huya': (roomId) async => const Left(LiveSiteError.notFound(siteId: 'huya', message: 'down')),
      },
    );
    final rooms = [roomOf('douyu', '1'), roomOf('douyu', '2'), roomOf('huya', '3')];
    final steps = <int>[];
    await container
        .read(followsProvider.notifier)
        .refreshRooms(
          rooms,
          onProgress: (done, total) {
            expect(total, 3);
            steps.add(done);
          },
        );
    // Every room reports exactly once, the count only ever climbs, and the
    // last step is the whole queue.
    expect(steps.first, 0);
    expect(steps.last, 3);
    expect(steps.toSet().length, steps.length);
  });

  test('the live-alert observer hears a pass, quiet or loud', () async {
    await repository.add(roomOf('douyu', '1', status: LiveStatus.offline));
    await ready();
    installSites(
      answerFor: {'douyu': (roomId) async => Right(roomOf('douyu', roomId, status: LiveStatus.live, title: 'On Air'))},
    );
    final notifier = container.read(followsProvider.notifier);
    final heard = <(List<LiveRoom>, bool)>[];
    liveAlertObserver = (rooms, {required quiet}) => heard.add((rooms, quiet));
    addTearDown(() => liveAlertObserver = null);

    await notifier.refreshRooms([roomOf('douyu', '1', status: LiveStatus.offline)]);
    await notifier.refreshRooms([roomOf('douyu', '1', status: LiveStatus.offline)], quiet: true);
    await pumpEventQueue();
    expect(heard.length, 2);
    expect(heard[0].$2, isFalse);
    expect(heard[1].$2, isTrue);
    expect(heard[0].$1.single.content.title, 'On Air');
  });

  test('a platform without the room capability is skipped, not failed', () async {
    await repository.add(roomOf('ghost', '1', status: LiveStatus.offline));
    await ready();
    installSites(
      answerFor: {'ghost': (roomId) async => Right(roomOf('ghost', roomId, status: LiveStatus.live))},
      servesRooms: false,
    );

    final failed = await container.read(followsProvider.notifier).refreshRooms([roomOf('ghost', '1')]);
    await pumpEventQueue();
    expect(failed, 0);
    // The stored copy keeps what it had: no capability learns nothing, and
    // nothing marks it unknown.
    expect(repository.list().single.broadcast.liveStatus, LiveStatus.offline);
  });

  test('fetchLiveStates answers the fresh rooms and marks nothing on a miss', () async {
    await repository.add(roomOf('douyu', '1', status: LiveStatus.offline));
    await repository.add(roomOf('huya', '2', status: LiveStatus.offline));
    await ready();
    installSites(
      answerFor: {
        'douyu': (roomId) async => Right(roomOf('douyu', roomId, status: LiveStatus.live, title: 'Fetch Live')),
        'huya': (roomId) async => const Left(LiveSiteError.notFound(siteId: 'huya', message: 'miss')),
      },
    );

    final fresh = await container.read(followsProvider.notifier).fetchLiveStates(repository.list());
    await pumpEventQueue();
    // Only the answer that came back; the miss is not in it.
    expect(fresh.single.identityKey, 'douyu:1');
    expect(fresh.single.content.title, 'Fetch Live');
    // The stored copy is untouched — an alert check must not read a
    // transient miss as a broadcast ending.
    expect(
      repository.list().firstWhere((room) => room.identityKey == 'huya:2').broadcast.liveStatus,
      LiveStatus.offline,
    );

    // The miss sits the cooldown out: a second pass asks douyu again and
    // leaves huya alone.
    await container.read(followsProvider.notifier).fetchLiveStates(repository.list());
    expect(
      repository.list().firstWhere((room) => room.identityKey == 'huya:2').broadcast.liveStatus,
      LiveStatus.offline,
    );
    expect(fresh.single.broadcast.liveStatus, LiveStatus.live);
  });

  test('setTags rewrites one follow, stripTag cleans every follow', () async {
    await repository.add(roomOf('douyu', '1', status: LiveStatus.live));
    await repository.add(roomOf('huya', '2', status: LiveStatus.live, title: 'Other'));
    await ready();
    final notifier = container.read(followsProvider.notifier);

    await notifier.setTags('douyu:1', ['t1', 't2']);
    await pumpEventQueue();
    expect(repository.list().firstWhere((room) => room.identityKey == 'douyu:1').local.tagIds, ['t1', 't2']);
    // A room no longer followed is a no-op.
    await notifier.setTags('ghost:9', ['t1']);

    await notifier.stripTag('t1');
    await pumpEventQueue();
    expect(repository.list().firstWhere((room) => room.identityKey == 'douyu:1').local.tagIds, ['t2']);
    expect(repository.list().firstWhere((room) => room.identityKey == 'huya:2').local.tagIds, isEmpty);
  });
}

/// A room provider that answers from a table, counting its asks.
final class _FakeRoomProvider implements LiveRoomProvider {
  _FakeRoomProvider(this.answer);

  final Future<Either<LiveSiteError, LiveRoom>> Function(String roomId) answer;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) => answer(roomId);

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async =>
      const Left(LiveSiteError.notFound(siteId: 'fake', message: 'unused'));
}

/// The smallest site: identity, a ready status, and the capabilities the
/// test handed it.
final class _FakeSite implements LiveSite {
  _FakeSite(this.id, {this.roomProvider});

  final String id;
  final _FakeRoomProvider? roomProvider;

  @override
  LiveSiteManifest get manifest => LiveSiteManifest(id: id, name: {'en': id}, version: '1', contractVersion: '1');

  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  @override
  T? capability<T extends LiveSiteCapability>() => roomProvider is T ? roomProvider! as T : null;

  @override
  Future<void> initialize(LiveSiteContext context) async {}

  @override
  Future<void> dispose() async {}
}
