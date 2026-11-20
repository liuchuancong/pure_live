import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right;
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/browse/sites_providers.dart' show sitesProvider;
import 'package:pure_live/modules/live/history/history_repository.dart';

/// The history controller over the in-memory store and a fake site: the
/// refresh pass — what merges with its moment kept, what counts as failed,
/// what the progress reports — is what the page's bar and toast read.
void main() {
  late StorageStores stores;
  late JsonStore store;
  late HistoryRepository repository;
  late ProviderContainer container;

  /// The fake registry's current sites; the provider override reads it.
  var currentSites = const <LiveSite>[];

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
    store = await stores.openStore('history');
    repository = HistoryRepository(store);
    container = ProviderContainer(
      overrides: [
        historyRepositoryProvider.overrideWith((ref) async => repository),
        sitesProvider.overrideWith((ref) => LiveSiteRegistry(currentSites)),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() => stores.close());

  LiveRoom roomOf(String platform, String id, {String? title}) => LiveRoom.normalized(
    platform: platform,
    roomId: id,
    content: RoomContent.of(title: title ?? 'Room $id'),
  );

  /// Installs (or replaces) the fake registry: a site per id, the refresh
  /// capability only when [servesRefresh] holds, answering [answerFor].
  void installSites({
    required Map<String, Future<Either<LiveSiteError, LiveRoom>> Function({required String roomId})> answerFor,
    Set<String> noRefreshFor = const <String>{},
  }) {
    currentSites = [
      for (final entry in answerFor.entries)
        _FakeSite(entry.key, refresh: noRefreshFor.contains(entry.key) ? null : _FakeRefresh(entry.value)),
    ];
    container.invalidate(sitesProvider);
  }

  test('the controller mirrors the store and follows changes from anywhere', () async {
    await container.read(historyRepositoryProvider.future);
    container.read(historyProvider);
    await pumpEventQueue();
    expect(container.read(historyProvider).ready, isTrue);
    expect(container.read(historyProvider).records, isEmpty);

    await repository.record(roomOf('douyu', '1'), DateTime.now().toUtc());
    await pumpEventQueue();
    expect(container.read(historyProvider).records.single.$1.identityKey, 'douyu:1');
  });

  test('a refresh pass takes the fresh reads and keeps the watch moments', () async {
    await repository.record(roomOf('douyu', '1', title: 'Old'), DateTime.now().toUtc());
    await repository.record(roomOf('huya', '2'), DateTime.now().toUtc().subtract(const Duration(days: 1)));
    // The controller mounts and settles before the pass, so the order it
    // holds is the order the store had.
    container.read(historyProvider);
    await pumpEventQueue();
    await container.read(historyRepositoryProvider.future);
    final orderBefore = [for (final (room, _) in container.read(historyProvider).records) room.identityKey];
    installSites(
      answerFor: {
        'douyu': ({required roomId}) async => Right(roomOf('douyu', roomId, title: 'Fresh One')),
        'huya': ({required roomId}) async => Right(roomOf('huya', roomId, title: 'Fresh Two')),
      },
    );

    final failed = await container.read(historyProvider.notifier).refreshRooms([
      roomOf('douyu', '1'),
      roomOf('huya', '2'),
    ]);
    await pumpEventQueue();
    expect(failed, 0);
    final records = container.read(historyProvider).records;
    // The order — and so the moments behind it — never moved.
    expect([for (final (room, _) in records) room.identityKey], orderBefore);
    expect(records[0].$1.content.title, 'Fresh One');
    expect(records[1].$1.content.title, 'Fresh Two');
  });

  test('a failed ask and a platform without the capability both count', () async {
    await repository.record(roomOf('douyu', '1'), DateTime.now().toUtc());
    await repository.record(roomOf('huya', '2'), DateTime.now().toUtc());
    await repository.record(roomOf('bigo', '3'), DateTime.now().toUtc());
    await pumpEventQueue();
    final steps = <int>[];
    installSites(
      answerFor: {
        'douyu': ({required roomId}) async => const Left(LiveSiteError.notFound(siteId: 'douyu', message: 'gone')),
        'huya': ({required roomId}) async => Right(roomOf('huya', roomId, title: 'Fresh Two')),
        'bigo': ({required roomId}) async => const Left(LiveSiteError.notFound(siteId: 'bigo', message: 'down')),
      },
      noRefreshFor: {'bigo'},
    );
    // The store's provider must have opened before the pass: the pass
    // answers rooms.length on a store still opening, every room a failure.
    await container.read(historyRepositoryProvider.future);
    container.read(historyProvider);
    await pumpEventQueue();
    final failed = await container
        .read(historyProvider.notifier)
        .refreshRooms(
          [roomOf('douyu', '1'), roomOf('huya', '2'), roomOf('bigo', '3')],
          onProgress: (done, total) {
            expect(total, 3);
            steps.add(done);
          },
        );
    // The miss and the capability-less platform are both failures; the one
    // answer that came back is not.
    expect(failed, 2);
    expect(steps.first, 0);
    expect(steps.last, 3);
    expect(steps.toSet().length, steps.length);
    // The fresh answer lands under its stored moment; the misses keep
    // their stored copies as they were.
    await pumpEventQueue();
    final records = container.read(historyProvider).records;
    expect(records[1].$1.identityKey, 'huya:2');
    expect(records[1].$1.content.title, 'Fresh Two');
  });
}

/// A refresh capability that answers from a table.
final class _FakeRefresh implements LiveRoomRefresh {
  _FakeRefresh(this.answer);

  final Future<Either<LiveSiteError, LiveRoom>> Function({required String roomId}) answer;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) => answer(roomId: roomId);

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) => answer(roomId: roomId);
}

/// The smallest site: identity, a ready status, and the capabilities the
/// test handed it.
final class _FakeSite implements LiveSite {
  _FakeSite(this.id, {this.refresh});

  final String id;
  final _FakeRefresh? refresh;

  @override
  LiveSiteManifest get manifest => LiveSiteManifest(id: id, name: {'en': id}, version: '1', contractVersion: '1');

  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  @override
  T? capability<T extends LiveSiteCapability>() => refresh is T ? refresh! as T : null;

  @override
  Future<void> initialize(LiveSiteContext context) async {}

  @override
  Future<void> dispose() async {}
}
