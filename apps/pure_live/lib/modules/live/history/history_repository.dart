import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/app.dart';

/// How many watch records the history keeps; the oldest leave first.
const int kHistoryLimit = 500;

/// The rooms the viewer watched, newest first, capped at
/// [kHistoryLimit].
///
/// A watch record is the room as it was last seen plus the moment the
/// viewing ended; watching again moves the record to the top (it does not
/// duplicate). The entry's key is the room's identity — `platform:roomId`.
final class HistoryRepository {
  /// Serves the [store] (the `history` namespace).
  HistoryRepository(this.store);

  /// The history store: identity key → the room's JSON with
  /// `lastWatchedAt` beside it.
  final JsonStore store;

  /// Emits after every committed change.
  Stream<void> watch() => store.watch();

  /// The watched rooms, newest watch first.
  List<LiveRoom> list() => [for (final (room, _) in entries()) room];

  /// The watched rooms with their watch moments, newest watch first — the
  /// page groups them by day (the reference's history sections).
  List<(LiveRoom, DateTime)> entries() {
    final records = store.entries;
    final entries = records.entries.toList()..sort((a, b) => _watchedAt(b.value).compareTo(_watchedAt(a.value)));
    return [for (final entry in entries) (LiveRoom.fromJson(_jsonOf(entry.value)), _watchedAt(entry.value))];
  }

  /// Records a viewing of [room] that ended [at], trimming past [limit]:
  /// the stored entry moves to the top with the room as it was last seen
  /// and the new moment.
  Future<void> record(LiveRoom room, DateTime at, {int limit = kHistoryLimit}) {
    final key = room.ref.identityKey;
    final stored = store.get(key);
    final merged = stored == null ? room : LiveRoom.fromJson(_jsonOf(stored)).mergedWith(room);
    final json = {...merged.toJson(), 'lastWatchedAt': at.toIso8601String()};
    return store.put(key, json).then((_) => _trim(limit));
  }

  /// Replaces a stored record's room with a fresher read, keeping the
  /// moment it was watched (a refresh must not reorder the list).
  Future<void> updateRoom(LiveRoom room) async {
    final key = room.ref.identityKey;
    final stored = store.get(key);
    if (stored == null) return;
    final watchedAt = _watchedAt(stored);
    final merged = LiveRoom.fromJson(_jsonOf(stored)).mergedWith(room);
    await store.put(key, {...merged.toJson(), 'lastWatchedAt': watchedAt.toIso8601String()});
  }

  /// Replaces every stored record [rooms] carries with its fresher read,
  /// in one write: a refresh pass is one broadcast, not one per record.
  /// Watch moments stay, and records no longer stored are skipped.
  Future<void> updateAll(Iterable<LiveRoom> rooms) async {
    final updates = <String, Map<String, Object?>>{};
    for (final room in rooms) {
      final key = room.ref.identityKey;
      final stored = store.get(key);
      if (stored == null) continue;
      final watchedAt = _watchedAt(stored);
      final merged = LiveRoom.fromJson(_jsonOf(stored)).mergedWith(room);
      updates[key] = {...merged.toJson(), 'lastWatchedAt': watchedAt.toIso8601String()};
    }
    if (updates.isNotEmpty) await store.putAll(updates);
  }

  /// Drops the record behind [identityKey]; a room never watched is a
  /// no-op.
  Future<void> remove(String identityKey) => store.delete(identityKey);

  /// Drops the records of [shown] — what the page displayed when the user
  /// chose clear, moments included: an entry watched again since then has
  /// moved on, and the version the viewer was looking at is not theirs to
  /// delete (another window's RPC write lands between the render and the
  /// confirm).
  Future<void> clear(Iterable<(LiveRoom, DateTime)> shown) async {
    final stale = <String>[];
    for (final (room, watchedAt) in shown) {
      final key = room.ref.identityKey;
      final stored = store.get(key);
      if (stored == null) continue;
      if (_watchedAt(stored) != watchedAt) continue;
      stale.add(key);
    }
    if (stale.isNotEmpty) await store.deleteAll(stale);
  }

  /// Keeps the newest [limit] records; a cap of zero or less is the 不设上限
  /// choice and keeps them all, so nothing is deleted.
  Future<void> _trim(int limit) async {
    if (limit <= 0) return;
    final keys = store.entries.entries.toList()..sort((a, b) => _watchedAt(b.value).compareTo(_watchedAt(a.value)));
    final excess = keys.skip(limit).map((entry) => entry.key).toList();
    if (excess.isNotEmpty) await store.deleteAll(excess);
  }

  /// The entry's watch moment; entries without one (from a future writer)
  /// sort oldest.
  static DateTime _watchedAt(Object? value) =>
      DateTime.tryParse(_jsonOf(value)['lastWatchedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// The storage value as the JSON the room serializer reads.
  static Map<String, Object?> _jsonOf(Object? value) =>
      value is Map<String, Object?> ? value : Map<String, Object?>.from(value! as Map);
}

/// The history repository (one namespace, one process).
final historyRepositoryProvider = FutureProvider<HistoryRepository>((ref) async {
  final store = await StorageStores.instance.openStore('history');
  return HistoryRepository(store);
});

/// What the history page holds: the watched rooms with their watch
/// moments, whether the repository has opened yet, and the open failure.
typedef HistoryState = ({bool ready, List<(LiveRoom, DateTime)> records, String? error});

/// Mirrors the history repository into the widget tree, like the follows
/// controller beside it; a change committed in another window arrives over
/// the store's watch stream.
class HistoryController extends Notifier<HistoryState> {
  StreamSubscription<void>? _subscription;

  @override
  HistoryState build() {
    ref.watch(historyRepositoryProvider).whenData((repository) {
      _subscription ??= repository.watch().listen((_) => _refresh(repository));
      _refresh(repository);
    });
    ref.onDispose(() => unawaited(_subscription?.cancel() ?? Future<void>.value()));
    final repository = ref.watch(historyRepositoryProvider);
    switch (repository) {
      case AsyncData(:final value):
        _subscription ??= value.watch().listen((_) => _refresh(value));
        _refresh(value);
        return state;
      case AsyncError(:final error):
        _subscription = null;
        return (ready: false, records: const [], error: error.toString());
      default:
        return (ready: false, records: const [], error: null);
    }
  }

  void _refresh(HistoryRepository repository) {
    state = (ready: true, records: repository.entries(), error: null);
  }

  /// Records a viewing of [room] ending now, at the history cap the
  /// settings surface chose.
  Future<void> record(LiveRoom room) async {
    final repository = ref.read(historyRepositoryProvider).value;
    if (repository == null) return;
    await repository.record(room, DateTime.now().toUtc(), limit: ref.read(historyLimitProvider));
  }

  /// Re-reads [rooms] through each platform's refresh capability, keeping
  /// the watch moments; answers how many could not be refreshed. The pass
  /// runs a worker pool — one slow platform occupies its slot, not the
  /// whole list — and lands as one write.
  Future<int> refreshRooms(List<LiveRoom> rooms, {void Function(int done, int total)? onProgress}) async {
    final repository = ref.read(historyRepositoryProvider).value;
    if (repository == null) return rooms.length;
    final sites = ref.read(sitesProvider);
    final concurrency = ref.read(maxConcurrentRefreshProvider).clamp(1, 20);
    var failed = 0;
    var done = 0;
    var next = 0;
    final fresh = <LiveRoom>[];
    onProgress?.call(done, rooms.length);

    Future<void> worker() async {
      while (next < rooms.length) {
        final room = rooms[next++];
        try {
          final refresh = sites.getById(room.ref.platform)?.capability<LiveRoomRefresh>();
          if (refresh == null) {
            failed++;
            continue;
          }
          final answer = await refresh.getRoomForRefresh(roomId: room.ref.roomId);
          await answer.match(
            (_) async {
              failed++;
            },
            (updated) async {
              fresh.add(updated);
            },
          );
        } on Object {
          // One unreachable room must not abort the rest of the pass.
          failed++;
        } finally {
          onProgress?.call(++done, rooms.length);
        }
      }
    }

    await Future.wait(<Future<void>>[for (var i = 0; i < concurrency; i++) worker()]);
    if (fresh.isNotEmpty) await repository.updateAll(fresh);
    return failed;
  }

  /// Drops one record.
  Future<void> remove(String identityKey) async {
    final repository = ref.read(historyRepositoryProvider).value;
    if (repository == null) return;
    await repository.remove(identityKey);
  }

  /// Drops the records the page showed, moments included: a record watched
  /// again since the page rendered stays.
  Future<void> clear(Iterable<(LiveRoom, DateTime)> shown) async {
    final repository = ref.read(historyRepositoryProvider).value;
    if (repository == null) return;
    await repository.clear(shown);
  }
}

/// The history page's state.
final historyProvider = NotifierProvider<HistoryController, HistoryState>(HistoryController.new);
