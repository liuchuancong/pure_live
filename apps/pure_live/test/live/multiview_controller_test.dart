import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/live/multiview/multiview_controller.dart';

/// The wall's data layer, argued over an in-memory store: what opens, what
/// persists, what a mutation lands as — the page's spinner, its dock and
/// its wall all read from these answers.
void main() {
  late StorageStores stores;
  late JsonStore store;
  late MultiviewRepository repository;
  late ProviderContainer container;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    store = await stores.openStore('multiview');
    repository = MultiviewRepository(store);
    container = ProviderContainer(overrides: [multiviewRepositoryProvider.overrideWith((ref) async => repository)]);
    addTearDown(container.dispose);
  });

  tearDown(() => stores.close());

  LiveRoom room(String platform, String id) => LiveRoom.normalized(
    platform: platform,
    roomId: id,
    content: RoomContent.of(title: 'Room $id'),
  );

  /// The controller's state once the store has opened and settled.
  Future<MultiviewState> wall() async {
    await container.read(multiviewRepositoryProvider.future);
    container.read(multiviewProvider);
    await pumpEventQueue();
    final state = container.read(multiviewProvider);
    return state;
  }

  test('an empty store opens the default wall: quad, every slot empty, ready', () async {
    final state = await wall();
    expect(state.ready, isTrue);
    expect(state.error, isNull);
    expect(state.layout, MultiviewLayout.quad);
    expect(state.slots, List<String?>.filled(4, null));
  });

  test('load reads back a saved wall', () async {
    await repository.save(layout: MultiviewLayout.focus, slots: ['douyu:1', null, 'huya:2', 'douyu:3']);
    final state = repository.load();
    expect(state.layout, MultiviewLayout.focus);
    expect(state.slots, ['douyu:1', null, 'huya:2', 'douyu:3']);
  });

  test('a legacy int layout maps, and a document that lost its shape falls back', () async {
    expect(MultiviewRepository.jsonOf({'layout': 2, 'slots': <String?>[]})?['layout'], 2);
    await store.put('current', {
      'layout': 1,
      'slots': ['douyu:1'],
    });
    expect(repository.load().layout, MultiviewLayout.single);
    await store.put('current', 'this is not json {');
    final state = repository.load();
    expect(state.layout, MultiviewLayout.quad);
    expect(state.slots, List<String?>.filled(4, null));
  });

  test('slots are cut or padded to the layout, and non-identity entries read empty', () async {
    await store.put('current', {
      'layout': 'strip',
      'slots': ['douyu:1', 42, '', 'huya:2', 'douyu:3'],
    });
    final state = repository.load();
    expect(state.layout, MultiviewLayout.strip);
    expect(state.slots, ['douyu:1', null, null, 'huya:2']);
    await store.put('current', {
      'layout': 'quad',
      'slots': ['douyu:1'],
    });
    expect(repository.load().slots, ['douyu:1', null, null, null]);
  });

  test('the controller mirrors the store and follows changes made from anywhere', () async {
    expect((await wall()).layout, MultiviewLayout.quad);
    await repository.save(layout: MultiviewLayout.dual, slots: ['douyu:1', null]);
    await pumpEventQueue();
    final state = container.read(multiviewProvider);
    expect(state.layout, MultiviewLayout.dual);
    expect(state.slots, ['douyu:1', null]);
  });

  test('assign puts the room in its slot, clear empties it, swap exchanges them', () async {
    await container.read(multiviewRepositoryProvider.future);
    final controller = container.read(multiviewProvider.notifier);
    await controller.assign(0, room('douyu', '1'));
    await controller.assign(2, room('huya', '2'));
    await pumpEventQueue();
    expect(container.read(multiviewProvider).slots, ['douyu:1', null, 'huya:2', null]);

    await controller.swapSlots(0, 2);
    await pumpEventQueue();
    expect(container.read(multiviewProvider).slots, ['huya:2', null, 'douyu:1', null]);

    await controller.clearSlot(2);
    await pumpEventQueue();
    expect(container.read(multiviewProvider).slots, ['huya:2', null, null, null]);

    // The no-ops: a swap with itself, an out-of-range index, clearing an
    // empty slot — none of them may write the store.
    final before = store.get('current');
    await controller.swapSlots(1, 1);
    await controller.swapSlots(0, 9);
    await controller.assign(-1, room('douyu', '3'));
    await controller.clearSlot(3);
    await pumpEventQueue();
    expect(store.get('current'), before);
  });

  test('a layout change keeps the first slots and gives up the rest', () async {
    await container.read(multiviewRepositoryProvider.future);
    final controller = container.read(multiviewProvider.notifier);
    await controller.assign(0, room('douyu', '1'));
    await controller.assign(1, room('huya', '2'));
    await controller.assign(3, room('douyu', '3'));
    await pumpEventQueue();

    await controller.setLayout(MultiviewLayout.dual);
    await pumpEventQueue();
    final state = container.read(multiviewProvider);
    expect(state.layout, MultiviewLayout.dual);
    expect(state.slots, ['douyu:1', 'huya:2']);

    await controller.setLayout(MultiviewLayout.strip);
    await pumpEventQueue();
    expect(container.read(multiviewProvider).slots, ['douyu:1', 'huya:2', null, null]);
  });

  test('a wall-failure retry rebuilds only the repository and stays writable', () async {
    await container.read(multiviewRepositoryProvider.future);
    await container.read(multiviewProvider.notifier).assign(0, room('douyu', '1'));
    await pumpEventQueue();

    // A fresh repository over the same store stands in for the retry: the
    // controller re-subscribes and later writes still land.
    final replacement = MultiviewRepository(store);
    container
      ..updateOverrides([multiviewRepositoryProvider.overrideWith((ref) async => replacement)])
      ..invalidate(multiviewRepositoryProvider);
    await pumpEventQueue();
    expect(container.read(multiviewProvider).slots, ['douyu:1', null, null, null]);

    await container.read(multiviewProvider.notifier).assign(1, room('huya', '2'));
    await pumpEventQueue();
    expect(container.read(multiviewProvider).slots, ['douyu:1', 'huya:2', null, null]);
  });
}
