import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/browse/sites_providers.dart';
import 'package:pure_live/features/settings/playback/player_tuning.dart' show playerProxyProvider;
import 'package:pure_live/modules/live/favorites/data/follow_repository.dart';
import 'package:pure_live/modules/live/multiview/multiview_controller.dart';
import 'package:pure_live/modules/live/multiview/multiview_playback.dart';

/// The wall's playback owner, argued over an in-memory store and an empty
/// site registry: the saved wall's ask on arrival (the yes opens every
/// pane, the no blanks the wall without opening one while it walks the
/// slots clear), the wall a viewer builds by hand (it opens without an
/// ask), and what a visit leaves behind when the viewer walks away.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageStores stores;
  late MultiviewRepository repository;
  late ProviderContainer container;
  final emissions = <MultiviewPlaybackState>[];

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
    emissions.clear();
    repository = MultiviewRepository(await stores.openStore('multiview'));
    container = ProviderContainer(
      overrides: [
        multiviewRepositoryProvider.overrideWith((ref) async => repository),
        followRepositoryProvider.overrideWith((ref) async => FollowRepository(await stores.openStore('follows'))),
        sitesProvider.overrideWith((ref) => LiveSiteRegistry(const [])),
        playerProxyProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);
    container.listen(multiviewPlaybackProvider, (_, next) => emissions.add(next));
    await container.read(multiviewRepositoryProvider.future);
    await container.read(followRepositoryProvider.future);
    await pumpEventQueue();
  });

  tearDown(() => stores.close());

  test('a saved wall asks once on arrival, and the yes opens every saved pane', () async {
    await repository.save(layout: MultiviewLayout.quad, slots: ['douyu:1', 'huya:2', null, null]);
    await pumpEventQueue();

    final playback = container.read(multiviewPlaybackProvider.notifier)..setActive(active: true);
    await pumpEventQueue();

    expect(container.read(multiviewPlaybackProvider).pendingRestore, isTrue);
    expect(container.read(multiviewPlaybackProvider).panes, isEmpty);

    playback.acceptRestoreWall();
    await pumpEventQueue();

    final state = container.read(multiviewPlaybackProvider);
    expect(state.pendingRestore, isFalse);
    expect(state.active, isTrue);
    // The registry holds no sites, so the panes land failed — but they exist.
    expect(state.panes.keys.toSet(), {0, 1});
    expect(state.panes[0]!.stage, MultiviewPaneStage.failed);
    expect(state.panes[0]!.error, contains('douyu'));
    // The first slot owns the wall's sound.
    expect(state.selected, 0);
    expect(state.panes[0]!.audible, isTrue);
    expect(state.panes[1]!.audible, isFalse);
  });

  test('the no blanks the wall, and not one pane opens while it walks the slots clear', () async {
    await repository.save(layout: MultiviewLayout.quad, slots: ['douyu:1', 'huya:2', 'douyu:3', 'huya:4']);
    await pumpEventQueue();

    final playback = container.read(multiviewPlaybackProvider.notifier)..setActive(active: true);
    await pumpEventQueue();
    expect(container.read(multiviewPlaybackProvider).pendingRestore, isTrue);
    emissions.clear();

    await playback.declineRestoreWall();
    await pumpEventQueue();

    expect(container.read(multiviewProvider).slots, everyElement(isNull));
    expect(container.read(multiviewPlaybackProvider).panes, isEmpty);
    for (final state in emissions) {
      expect(state.panes, isEmpty, reason: 'a pane opened while the decline walked the slots clear');
    }
  });

  test('a wall built by hand this visit opens without an ask', () async {
    container.read(multiviewPlaybackProvider.notifier).setActive(active: true);
    await pumpEventQueue();
    expect(container.read(multiviewPlaybackProvider).pendingRestore, isFalse);

    await container.read(multiviewProvider.notifier).assign(1, _room('douyu', '9'));
    await pumpEventQueue();

    final state = container.read(multiviewPlaybackProvider);
    expect(state.pendingRestore, isFalse);
    expect(state.panes.keys.toSet(), {1});
    expect(state.selected, 1);
  });

  test('leaving releases every pane, and a return asks for the wall again', () async {
    await repository.save(layout: MultiviewLayout.quad, slots: ['douyu:1', null, null, null]);
    await pumpEventQueue();
    final playback = container.read(multiviewPlaybackProvider.notifier)..setActive(active: true);

    await pumpEventQueue();
    playback.acceptRestoreWall();
    await pumpEventQueue();
    expect(container.read(multiviewPlaybackProvider).panes.keys.toSet(), {0});

    playback.setActive(active: false);
    await pumpEventQueue();
    final away = container.read(multiviewPlaybackProvider);
    expect(away.active, isFalse);
    expect(away.panes, isEmpty);

    playback.setActive(active: true);
    await pumpEventQueue();
    expect(container.read(multiviewPlaybackProvider).pendingRestore, isTrue); // a visit's ask, again
    expect(container.read(multiviewPlaybackProvider).panes, isEmpty);
  });
}

LiveRoom _room(String platform, String id) => LiveRoom.normalized(
  platform: platform,
  roomId: id,
  content: RoomContent.of(title: 'Room $id'),
);
