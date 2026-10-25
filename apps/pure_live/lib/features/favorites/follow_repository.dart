import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;

/// The stored rooms the viewer follows, one entry per room identity.
///
/// A follow keeps the room as it was last seen (a card can show without a
/// round trip); a refresh merges what it learned into the stored copy
/// through `LiveRoom.mergedWith`, so a stale title never erases a fresh
/// one. The entry's key is the room's identity — `platform:roomId` — and
/// the entry's value is the room's storage JSON.
final class FollowRepository {
  /// Serves the [box] (opened as `follows` over the storage manager, its
  /// values the rooms' JSON as plain objects).
  FollowRepository(this.box);

  /// The follows box: identity key → the room's JSON.
  final HiveStorageRepository<Object> box;

  /// Emits after every committed change.
  Stream<void> watch() => box.watch();

  /// The followed rooms, in storage order (insertion).
  List<LiveRoom> list() => [for (final value in box.getAll()) LiveRoom.fromJson(_jsonOf(value))];

  /// Whether the room behind [identityKey] is followed.
  bool contains(String identityKey) => box.contains(identityKey);

  /// Follows [room]: an existing entry for its identity is replaced whole.
  Future<void> add(LiveRoom room) => box.save(room.ref.identityKey, room.toJson());

  /// Merges what a refresh learned into the stored entry, keeping the
  /// stored copy when the refresh carries nothing new. A room never
  /// followed is stored as given.
  Future<void> merge(LiveRoom incoming) {
    final key = incoming.ref.identityKey;
    final stored = box.get(key);
    final merged = stored == null ? incoming : LiveRoom.fromJson(_jsonOf(stored)).mergedWith(incoming);
    return box.save(key, merged.toJson());
  }

  /// Unfollows the room behind [identityKey]; a room never followed is a
  /// no-op.
  Future<void> remove(String identityKey) => box.delete(identityKey);

  /// The storage value as the JSON the room serializer reads; Hive hands
  /// back the map it stored with dynamic keys.
  static Map<String, Object?> _jsonOf(Object value) =>
      value is Map<String, Object?> ? value : Map<String, Object?>.from(value as Map);
}

/// How long a box may take to open before the wait is declared: the open
/// is normally a few milliseconds. The one slow case is real — another
/// app instance still holds the box's file lock (hive_ce locks are
/// exclusive across processes), and waiting forever there is exactly the
/// silent skeleton the viewer would never understand.
const Duration _boxOpenTimeout = Duration(seconds: 8);

/// Opens a keyed box with [_boxOpenTimeout]; a timeout or a failure
/// surfaces as the future's error instead of hanging the page forever.
Future<KeyedBox<Object, String>> _openKeyedBox(String name) =>
    StorageBoxManager().keyed<Object>(name).timeout(_boxOpenTimeout);

/// The follows repository (one box, one process).
final followRepositoryProvider = FutureProvider<FollowRepository>((ref) async {
  final box = await _openKeyedBox('follows');
  return FollowRepository(HiveStorageRepository(box: box));
});

/// What the favorites page holds: the followed rooms, whether the
/// repository has opened yet, and what went wrong when it never did.
typedef FollowsState = ({bool ready, List<LiveRoom> rooms, String? error});

/// Mirrors the follows repository into the widget tree: it lists once the
/// repository opens and follows its watch stream, so every change from any
/// surface (the page, a room's follow button) lands at once.
final class FollowsController extends Notifier<FollowsState> {
  StreamSubscription<void>? _subscription;

  @override
  FollowsState build() {
    ref.onDispose(() => unawaited(_subscription?.cancel() ?? Future<void>.value()));
    final repository = ref.watch(followRepositoryProvider);
    // Every state the open can be in lands here: loading keeps the page's
    // skeleton, an error (a locked box from a second instance, a broken
    // store) reaches the page as words with a retry, and data mirrors.
    switch (repository) {
      case AsyncData(:final value):
        _subscription ??= value.watch().listen((_) => _refresh(value));
        _refresh(value);
        return state;
      case AsyncError(:final error):
        _subscription = null;
        return (ready: false, rooms: const [], error: error.toString());
      default:
        return (ready: false, rooms: const [], error: null);
    }
  }

  void _refresh(FollowRepository repository) {
    state = (ready: true, rooms: repository.list(), error: null);
  }

  /// Follows [room] (or refreshes its stored copy).
  Future<void> add(LiveRoom room) async {
    final repository = ref.read(followRepositoryProvider).value;
    if (repository == null) return;
    await repository.add(room);
  }

  /// Unfollows the room behind [identityKey].
  Future<void> remove(String identityKey) async {
    final repository = ref.read(followRepositoryProvider).value;
    if (repository == null) return;
    await repository.remove(identityKey);
  }

  /// Replaces the local tag ids of the followed room behind [identityKey];
  /// a room no longer followed is a no-op.
  Future<void> setTags(String identityKey, List<String> tagIds) async {
    final repository = ref.read(followRepositoryProvider).value;
    final room = state.rooms.where((entry) => entry.ref.identityKey == identityKey).firstOrNull;
    if (repository == null || room == null) return;
    final updated = room.rebuild((b) => b..local.tagIds.replace(tagIds));
    await repository.add(updated);
  }

  /// Strips [tagId] from every followed room that carries it.
  Future<void> stripTag(String tagId) async {
    final repository = ref.read(followRepositoryProvider).value;
    if (repository == null) return;
    for (final room in state.rooms) {
      if (!room.local.tagIds.contains(tagId)) continue;
      final updated = room.rebuild(
        (b) => b..local.tagIds.replace([
          for (final id in room.local.tagIds)
            if (id != tagId) id,
        ]),
      );
      await repository.add(updated);
    }
  }

  /// Refreshes every followed room against its platform (the reference's
  /// `FollowRefresher`): the room provider asks each site for the room as
  /// it is now, and what comes back merges into the stored copy — a stale
  /// title or audience figure never erases a fresh one.
  ///
  /// A platform without the room capability (or a failed ask) keeps the
  /// stored copy: the refresh reports no error, it just learns nothing.
  /// This is the whole-list scope; the page calls [refreshRooms] with its
  /// visible slice.
  Future<void> refresh() async {
    await refreshRooms(state.rooms);
  }

  /// Refreshes [rooms] and answers how many asks failed; [onProgress] gets
  /// the number done and the total after every ask, so the page can show
  /// the bar. A platform without the room capability keeps its stored copy
  /// and is not counted as a failure; a failed ask is.
  Future<int> refreshRooms(Iterable<LiveRoom> rooms, {void Function(int done, int total)? onProgress}) async {
    final repository = ref.read(followRepositoryProvider).value;
    if (repository == null) return 0;
    final targets = rooms.toList(growable: false);
    final sites = ref.read(sitesProvider);
    var failed = 0;
    var done = 0;
    onProgress?.call(done, targets.length);
    // A handful of asks at a time keeps a full list from stampeding one
    // platform's endpoints.
    const batchSize = 4;
    for (var start = 0; start < targets.length; start += batchSize) {
      final batch = targets.sublist(start, (start + batchSize).clamp(0, targets.length));
      Future<void> refreshOne(LiveRoom room) async {
        try {
          final provider = sites.getById(room.ref.platform)?.capability<LiveRoomProvider>();
          if (provider == null) return;
          final answer = await provider.getRoom(room.ref.roomId);
          await answer.match<Future<void>>((_) async {
            failed++;
          }, repository.merge);
        } on Object {
          failed++;
        } finally {
          onProgress?.call(++done, targets.length);
        }
      }

      await Future.wait(<Future<void>>[for (final room in batch) refreshOne(room)]);
    }
    return failed;
  }
}

/// The favorites page's state.
final followsProvider = NotifierProvider<FollowsController, FollowsState>(FollowsController.new);
