import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom, LiveRoomRefIdentity;
import 'package:live_storage/live_storage.dart';

/// The pane counts the wall offers: one, two side by side, two by two,
/// two columns by three rows, and three by three (the reference's
/// 1×1, 1×2, 2×2, 2×3 and 3×3 walls).
const List<int> kMultiviewLayouts = [1, 2, 4, 6, 9];

/// The layout a wall that never stored one starts with (the reference's
/// default arrangement).
const int _defaultLayout = 4;

/// The key the wall document sits under (the box holds exactly this one
/// entry).
const String _documentKey = 'current';

/// The wall's arrangement: the layout's pane count and, per slot, the
/// identity of the room it holds — `platform:roomId`, like a follow — or
/// null while the slot is empty.
typedef MultiviewState = ({bool ready, int layout, List<String?> slots});

/// The multiview store (the reference's last-arrangement meta entry): one
/// box holding one JSON map — the layout and the slots — so a revisit
/// opens the same wall. The video tiles themselves arrive later with the
/// player stack (`media_core_multiview`); until then the wall and its
/// pane picker arrange rooms, and the store keeps the arrangement between
/// visits.
final class MultiviewRepository {
  /// Serves the [box] (opened as `multiview` over the storage manager,
  /// its one value the wall's JSON as a plain object).
  MultiviewRepository(this.box);

  /// The multiview box: the wall document under its one key.
  final HiveStorageRepository<Object> box;

  /// Emits after every committed change.
  Stream<void> watch() => box.watch();

  /// The wall as it was last stored; a box without one starts a four-slot
  /// wall with every slot empty, and a document that lost its shape
  /// (an unknown layout, entries that are not room identities) keeps
  /// what still reads.
  MultiviewState load() {
    final stored = box.get(_documentKey);
    if (stored == null) {
      return (ready: true, layout: _defaultLayout, slots: List<String?>.filled(_defaultLayout, null));
    }
    final json = stored is Map<String, Object?> ? stored : Map<String, Object?>.from(stored as Map);
    final rawLayout = json['layout'];
    final layout = rawLayout is int && kMultiviewLayouts.contains(rawLayout) ? rawLayout : _defaultLayout;
    return (ready: true, layout: layout, slots: _slotsOf(json['slots'], layout));
  }

  /// Stores [layout] and [slots] whole, replacing the wall document.
  Future<void> save({required int layout, required List<String?> slots}) =>
      box.save(_documentKey, {'layout': layout, 'slots': slots});

  /// The stored slots cut or padded to [count]; an entry that is not a
  /// room identity reads as an empty slot.
  static List<String?> _slotsOf(Object? raw, int count) {
    final stored = raw is List ? raw : const <Object?>[];
    return List<String?>.generate(count, (index) {
      if (index >= stored.length) return null;
      final entry = stored[index];
      return entry is String && entry.isNotEmpty ? entry : null;
    });
  }
}

/// The multiview repository (one box, one process).
final multiviewRepositoryProvider = FutureProvider<MultiviewRepository>((ref) async {
  final box = await StorageBoxManager().keyed<Object>('multiview');
  return MultiviewRepository(HiveStorageRepository(box: box));
});

/// Mirrors the multiview repository into the widget tree: it loads once
/// the repository opens and follows its watch stream, so every change
/// lands at once. Every mutation writes the whole wall document, so the
/// store is always the one truth — the pane picker, a later video stack
/// or another surface may change the wall from anywhere.
final class MultiviewController extends Notifier<MultiviewState> {
  StreamSubscription<void>? _subscription;

  @override
  MultiviewState build() {
    ref.watch(multiviewRepositoryProvider).whenData((repository) {
      _subscription ??= repository.watch().listen((_) => _refresh(repository));
      _refresh(repository);
    });
    ref.onDispose(() => unawaited(_subscription?.cancel() ?? Future<void>.value()));
    return (ready: false, layout: _defaultLayout, slots: List<String?>.filled(_defaultLayout, null));
  }

  void _refresh(MultiviewRepository repository) {
    state = repository.load();
  }

  /// The repository while the wall is loaded; null before it opens (the
  /// page waits for it, so a write never lands before the first read and
  /// wipes the stored wall with the empty default).
  MultiviewRepository? get _repository {
    final repository = ref.read(multiviewRepositoryProvider).value;
    if (repository == null || !state.ready) return null;
    return repository;
  }

  /// Changes the layout to [count] panes: the first slots keep their
  /// rooms, the ones beyond the new size give them up.
  Future<void> setLayout(int count) async {
    final repository = _repository;
    if (repository == null || !kMultiviewLayouts.contains(count)) return;
    final slots = [
      for (var index = 0; index < count; index++)
        if (index < state.slots.length) state.slots[index] else null,
    ];
    await repository.save(layout: count, slots: slots);
  }

  /// Puts [room] into slot [index], replacing whoever was there.
  Future<void> assign(int index, LiveRoom room) async {
    final repository = _repository;
    if (repository == null || index < 0 || index >= state.slots.length) return;
    final slots = [...state.slots];
    slots[index] = room.ref.identityKey;
    await repository.save(layout: state.layout, slots: slots);
  }

  /// Empties slot [index]; a slot never filled is a no-op.
  Future<void> clearSlot(int index) async {
    final repository = _repository;
    if (repository == null || index < 0 || index >= state.slots.length) return;
    if (state.slots[index] == null) return;
    final slots = [...state.slots];
    slots[index] = null;
    await repository.save(layout: state.layout, slots: slots);
  }

  /// Exchanges the rooms of slots [a] and [b]; an empty slot trades its
  /// emptiness (a move). Two empty slots, or an index out of the wall,
  /// are a no-op.
  Future<void> swapSlots(int a, int b) async {
    final repository = _repository;
    if (repository == null || a == b) return;
    if (a < 0 || b < 0 || a >= state.slots.length || b >= state.slots.length) return;
    final slots = [...state.slots];
    final held = slots[a];
    slots[a] = slots[b];
    slots[b] = held;
    await repository.save(layout: state.layout, slots: slots);
  }
}

/// The multiview wall's state.
final multiviewProvider = NotifierProvider<MultiviewController, MultiviewState>(MultiviewController.new);
