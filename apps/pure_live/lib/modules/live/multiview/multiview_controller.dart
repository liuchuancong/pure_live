import 'dart:async' show StreamSubscription, unawaited;
import 'dart:convert' show jsonDecode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom, LiveRoomRefIdentity;
import 'package:live_storage/live_storage.dart';

/// The arrangements of the wall: one pane, two side by side, two by two,
/// and the reference's focus layout (one large pane with a column of three
/// small ones). Six and nine streams are not offered: they cost more than
/// a wall is worth and the reference does not ship them either.
enum MultiviewLayout {
  /// One pane.
  single(1),

  /// Two side by side.
  dual(2),

  /// Two by two.
  quad(4),

  /// One large pane and three small ones beside it (or below it, when
  /// that leaves the large pane more room).
  focus(4),

  /// Four equal panes in a row — or in a column, when the wall is taller
  /// than it is wide.
  strip(4);

  MultiviewLayout(this.panes);

  /// Panes the layout holds.
  final int panes;
}

/// The layout a wall that never stored one starts with (the reference's
/// default arrangement).
const MultiviewLayout _defaultLayout = MultiviewLayout.quad;

/// The key the wall document sits under (the store holds exactly this one
/// entry).
const String _documentKey = 'current';

/// The wall's arrangement: the layout and, per slot, the identity of the
/// room it holds — `platform:roomId`, like a follow — or null while the
/// slot is empty. `error` carries what went wrong when the store never
/// opened, so the page can say so instead of spinning.
typedef MultiviewState = ({
  bool ready,
  MultiviewLayout layout,
  List<String?> slots,
  String? error,
});

/// The wall before it can be read: the default arrangement, every slot empty,
/// and whatever the open answered when it did not open.
MultiviewState pendingMultiview({String? error}) => (
  ready: false,
  layout: _defaultLayout,
  slots: List<String?>.filled(_defaultLayout.panes, null),
  error: error,
);
/// The multiview store (the reference's last-arrangement meta entry): one
/// store holding one JSON map — the layout and the slots — so a revisit
/// opens the same wall. The video tiles themselves arrive later with the
/// player stack (`media_core_multiview`); until then the wall and its
/// pane picker arrange rooms, and the store keeps the arrangement between
/// visits.
final class MultiviewRepository {
  /// Serves the [store] (the `multiview` namespace, its one value the
  /// wall's JSON as a plain object).
  MultiviewRepository(this.store);

  /// The multiview store: the wall document under its one key.
  final JsonStore store;

  /// Emits after every committed change.
  Stream<void> watch() => store.watch();

  /// The wall as it was last stored; a store without one starts a four-slot
  /// wall with every slot empty, and a document that lost its shape
  /// (an unknown layout, entries that are not room identities) keeps
  /// what still reads.
  MultiviewState load() {
    final stored = store.get(_documentKey);
    if (stored == null) {
      return (
        ready: true,
        layout: _defaultLayout,
        slots: List<String?>.filled(_defaultLayout.panes, null),
        error: null,
      );
    }
    final json = _jsonOf(stored);
    if (json == null) {
      // A document this build cannot read is an empty wall, not a broken
      // page: the layout and the slots both have honest defaults.
      return (
        ready: true,
        layout: _defaultLayout,
        slots: List<String?>.filled(_defaultLayout.panes, null),
        error: null,
      );
    }
    final layout = _layoutOf(json['layout']);
    return (ready: true, layout: layout, slots: _slotsOf(json['slots'], layout.panes), error: null);
  }

  /// The stored document as a map, however the store handed it over: a map
  /// of its own, any other map shape, or JSON text. Anything else is no
  /// document.
  static Map<String, Object?>? _jsonOf(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) return Map<String, Object?>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, Object?>.from(decoded);
      } on FormatException {
        // Not JSON either; the caller falls back to the default wall.
      }
    }
    return null;
  }

  /// Stores [layout] and [slots] whole, replacing the wall document.
  Future<void> save({required MultiviewLayout layout, required List<String?> slots}) =>
      store.put(_documentKey, {'layout': layout.name, 'slots': slots});

  /// The stored layout; the pane counts walls stored before the focus
  /// layout existed still read, and a value out of the enum is the
  /// default.
  static MultiviewLayout _layoutOf(Object? raw) {
    if (raw is String) {
      for (final layout in MultiviewLayout.values) {
        if (layout.name == raw) return layout;
      }
    }
    if (raw is int) {
      return switch (raw) {
        1 => MultiviewLayout.single,
        2 => MultiviewLayout.dual,
        _ => MultiviewLayout.quad,
      };
    }
    return _defaultLayout;
  }

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

/// How long a namespace may take to open before the wait is declared: the
/// open is normally a few milliseconds, and an undeclared one is a wall
/// that never arrives — the page would only ever show its spinner.
const Duration _storeOpenTimeout = Duration(seconds: 8);

/// The multiview repository (one namespace, one process).
final multiviewRepositoryProvider = FutureProvider<MultiviewRepository>((ref) async {
  final store = await StorageStores.instance.openStore('multiview').timeout(_storeOpenTimeout);
  return MultiviewRepository(store);
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
    ref.onDispose(() => unawaited(_subscription?.cancel() ?? Future<void>.value()));
    final repository = ref.watch(multiviewRepositoryProvider);
    // Every state the open can be in lands here: loading keeps the page's
    // spinner, an error (a failed database open, a store that never
    // answered) reaches the page as words with a retry, and data mirrors
    // the stored wall.
    switch (repository) {
      case AsyncData(:final value):
        _subscription ??= value.watch().listen((_) => _refresh(value));
        _refresh(value);
        return state;
      case AsyncError(:final error):
        _subscription = null;
        return pendingMultiview(error: error.toString());
      default:
        return pendingMultiview();
    }
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

  /// Changes the layout: the first slots keep their rooms, the ones beyond
  /// the new layout's size give them up.
  Future<void> setLayout(MultiviewLayout layout) async {
    final repository = _repository;
    if (repository == null) return;
    final slots = [
      for (var index = 0; index < layout.panes; index++)
        if (index < state.slots.length) state.slots[index] else null,
    ];
    await repository.save(layout: layout, slots: slots);
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
