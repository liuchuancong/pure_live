import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';

/// How many watch records the history keeps; the oldest leave first.
const int kHistoryLimit = 500;

/// The rooms the viewer watched, newest first, capped at
/// [kHistoryLimit].
///
/// A watch record is the room as it was last seen plus the moment the
/// viewing ended; watching again moves the record to the top (it does not
/// duplicate). The entry's key is the room's identity — `platform:roomId`.
final class HistoryRepository {
  /// Serves the [box] (opened as `history` over the storage manager, its
  /// values the rooms' JSON as plain objects).
  HistoryRepository(this.box);

  /// The history box: identity key → the room's JSON with
  /// `lastWatchedAt` beside it.
  final HiveStorageRepository<Object> box;

  /// Emits after every committed change.
  Stream<void> watch() => box.watch();

  /// The watched rooms, newest watch first.
  List<LiveRoom> list() {
    final records = box.getAllEntries();
    final entries = records.entries.toList()
      ..sort((a, b) => _watchedAt(b.value).compareTo(_watchedAt(a.value)));
    return [for (final entry in entries) LiveRoom.fromJson(_jsonOf(entry.value))];
  }

  /// Records a viewing of [room] that ended [at]: the stored entry moves
  /// to the top with the room as it was last seen and the new moment.
  Future<void> record(LiveRoom room, DateTime at) {
    final key = room.ref.identityKey;
    final stored = box.get(key);
    final merged = stored == null ? room : LiveRoom.fromJson(_jsonOf(stored)).mergedWith(room);
    final json = {...merged.toJson(), 'lastWatchedAt': at.toIso8601String()};
    return box.save(key, json).then((_) => _trim());
  }

  /// Drops the record behind [identityKey]; a room never watched is a
  /// no-op.
  Future<void> remove(String identityKey) => box.delete(identityKey);

  /// Drops every record.
  Future<void> clear() async {
    await box.deleteAll(box.getAllKeys());
  }

  /// Keeps the newest [kHistoryLimit] records.
  Future<void> _trim() async {
    final keys = box
        .getAllEntries()
        .entries
        .toList()
      ..sort((a, b) => _watchedAt(b.value).compareTo(_watchedAt(a.value)));
    final excess = keys.skip(kHistoryLimit).map((entry) => entry.key).toList();
    if (excess.isNotEmpty) await box.deleteAll(excess);
  }

  /// The entry's watch moment; entries without one (from a future writer)
  /// sort oldest.
  static DateTime _watchedAt(Object value) =>
      DateTime.tryParse(_jsonOf(value)['lastWatchedAt'] as String? ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  /// The storage value as the JSON the room serializer reads.
  static Map<String, Object?> _jsonOf(Object value) =>
      value is Map<String, Object?> ? value : Map<String, Object?>.from(value as Map);
}

/// The history repository (one box, one process).
final historyRepositoryProvider = FutureProvider<HistoryRepository>((ref) async {
  final box = await StorageBoxManager().keyed<Object>('history');
  return HistoryRepository(HiveStorageRepository(box: box));
});

/// What the history page holds: the watched rooms and whether the
/// repository has opened yet.
typedef HistoryState = ({bool ready, List<LiveRoom> rooms});

/// Mirrors the history repository into the widget tree, like the follows
/// controller beside it.
final class HistoryController extends Notifier<HistoryState> {
  StreamSubscription<void>? _subscription;

  @override
  HistoryState build() {
    ref.watch(historyRepositoryProvider).whenData((repository) {
      _subscription ??= repository.watch().listen((_) => _refresh(repository));
      _refresh(repository);
    });
    ref.onDispose(() => unawaited(_subscription?.cancel() ?? Future<void>.value()));
    return (ready: false, rooms: const []);
  }

  void _refresh(HistoryRepository repository) {
    state = (ready: true, rooms: repository.list());
  }

  /// Records a viewing of [room] ending now.
  Future<void> record(LiveRoom room) async {
    final repository = ref.read(historyRepositoryProvider).value;
    if (repository == null) return;
    await repository.record(room, DateTime.now().toUtc());
  }

  /// Drops one record.
  Future<void> remove(String identityKey) async {
    final repository = ref.read(historyRepositoryProvider).value;
    if (repository == null) return;
    await repository.remove(identityKey);
  }

  /// Drops every record.
  Future<void> clear() async {
    final repository = ref.read(historyRepositoryProvider).value;
    if (repository == null) return;
    await repository.clear();
  }
}

/// The history page's state.
final historyProvider = NotifierProvider<HistoryController, HistoryState>(HistoryController.new);
