import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/lan_sync/application/lan_sync_providers.dart'
    show favoritePayload, lanSyncRuntimeProvider;
import 'package:pure_live/modules/live/favorites/alerts/live_alert_events.dart' show liveAlertObserver;

/// The stored rooms the viewer follows, one entry per room identity.
///
/// A follow keeps the room as it was last seen (a card can show without a
/// round trip); a refresh merges what it learned into the stored copy
/// through `LiveRoom.mergedWith`, so a stale title never erases a fresh
/// one. The entry's key is the room's identity — `platform:roomId` — and
/// the entry's value is the room's storage JSON.
final class FollowRepository {
  /// Serves the [store] (the `follows` namespace).
  FollowRepository(this.store);

  /// The follows store: identity key → the room's JSON.
  final JsonStore store;

  /// Emits after every committed change.
  Stream<void> watch() => store.watch();

  /// The followed rooms, in storage order (insertion).
  List<LiveRoom> list() => [for (final value in store.values) LiveRoom.fromJson(_jsonOf(value))];

  /// Whether the room behind [identityKey] is followed.
  bool contains(String identityKey) => store.contains(identityKey);

  /// Follows [room]: an existing entry for its identity is replaced whole.
  Future<void> add(LiveRoom room) => store.put(room.ref.identityKey, room.toJson());

  /// Merges what a refresh learned into the stored entry, keeping the
  /// stored copy when the refresh carries nothing new. A room never
  /// followed is stored as given.
  Future<void> merge(LiveRoom incoming) {
    final key = incoming.ref.identityKey;
    final stored = store.get(key);
    final merged = stored == null ? incoming : LiveRoom.fromJson(_jsonOf(stored)).mergedWith(incoming);
    return store.put(key, merged.toJson());
  }

  /// Merges every room of [incoming] into the stored copies in one write:
  /// a whole refresh pass is one broadcast and one re-sort, not one per
  /// card arriving.
  Future<void> mergeAll(Iterable<LiveRoom> incoming) async {
    final updates = <String, Map<String, Object?>>{};
    for (final room in incoming) {
      final key = room.ref.identityKey;
      final stored = store.get(key);
      final merged = stored == null ? room : LiveRoom.fromJson(_jsonOf(stored)).mergedWith(room);
      updates[key] = merged.toJson();
    }
    if (updates.isNotEmpty) await store.putAll(updates);
  }

  /// Marks the stored entries behind [identityKeys] with an explicit
  /// unknown broadcast state: an ask that could not see the room must not
  /// leave a stale "live" badge standing for hours.
  Future<void> markUnknown(Iterable<String> identityKeys) async {
    final updates = <String, Map<String, Object?>>{};
    for (final key in identityKeys) {
      final stored = store.get(key);
      if (stored == null) continue;
      final room = LiveRoom.fromJson(_jsonOf(stored));
      if (room.broadcast.liveStatus == LiveStatus.unknown) continue;
      updates[key] = room
          .rebuild((b) => b..broadcast.replace(room.broadcast.rebuild((bb) => bb..liveStatus = LiveStatus.unknown)))
          .toJson();
    }
    if (updates.isNotEmpty) await store.putAll(updates);
  }

  /// Unfollows the room behind [identityKey]; a room never followed is a
  /// no-op.
  Future<void> remove(String identityKey) => store.delete(identityKey);

  /// The storage value as the JSON the room serializer reads.
  static Map<String, Object?> _jsonOf(Object? value) =>
      value is Map<String, Object?> ? value : Map<String, Object?>.from(value! as Map);
}

/// How long a namespace may take to open before the wait is declared: the
/// open is normally a few milliseconds. A failure surfaces as the future's
/// error instead of hanging the page forever.
const Duration _storeOpenTimeout = Duration(seconds: 8);

/// The follows repository (one namespace, one process).
final followRepositoryProvider = FutureProvider<FollowRepository>((ref) async {
  final store = await StorageStores.instance.openStore('follows').timeout(_storeOpenTimeout);
  return FollowRepository(store);
});

/// What the favorites page holds: the followed rooms, whether the
/// repository has opened yet, and what went wrong when it never did.
typedef FollowsState = ({bool ready, List<LiveRoom> rooms, String? error});

/// Mirrors the follows repository into the widget tree: it lists once the
/// repository opens and follows its watch stream, so every change from any
/// surface (the page, a room's follow button) lands at once — including a
/// change another window committed.
class FollowsController extends Notifier<FollowsState> {
  StreamSubscription<void>? _subscription;

  /// When a room's last refresh ask failed, per identity: the room sits
  /// the cooldown out of later passes (the reference's 5-minute skip), so
  /// a platform that is down is not hammered by every check.
  final Map<String, DateTime> _refreshFailedAt = {};

  /// How long a room whose ask just failed is skipped by passes that
  /// honour the cooldown.
  static const Duration _refreshCooldown = Duration(minutes: 5);

  @override
  FollowsState build() {
    ref.onDispose(() => unawaited(_subscription?.cancel() ?? Future<void>.value()));
    final repository = ref.watch(followRepositoryProvider);
    // Every state the open can be in lands here: loading keeps the page's
    // skeleton, an error (a failed database open, a broken store) reaches
    // the page as words with a retry, and data mirrors.
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
    await _recordSyncFavorite(room.ref.identityKey, favoritePayload(room));
  }

  /// Unfollows the room behind [identityKey].
  Future<void> remove(String identityKey) async {
    final repository = ref.read(followRepositoryProvider).value;
    if (repository == null) return;
    await repository.remove(identityKey);
    await _recordSyncDelete(identityKey);
  }

  /// Hands a local favorite edit to the sync runtime's log, when the
  /// feature is on and its runtime is up; any failure stays silent — the
  /// follow itself already succeeded, and the next edit re-records.
  Future<void> _recordSyncFavorite(String identityKey, Map<String, Object?> payload) async {
    try {
      final runtime = await ref.read(lanSyncRuntimeProvider.future);
      await runtime?.recordFavoriteUpsert(identityKey, payload);
      runtime?.scheduleAutoSync();
    } on Object {
      // The sync log is secondary to the follow; a missed entry is repaired
      // by the next edit of the same favorite.
    }
  }

  Future<void> _recordSyncDelete(String identityKey) async {
    try {
      final runtime = await ref.read(lanSyncRuntimeProvider.future);
      await runtime?.recordFavoriteDelete(identityKey);
      runtime?.scheduleAutoSync();
    } on Object {
      // Same as above.
    }
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
        (b) => b
          ..local.tagIds.replace([
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
  /// and is not counted as a failure; a failed ask is. [quiet] marks a pass
  /// the user started and is watching, so live alerts only update what they
  /// saw instead of posting; [bypassCooldown] lets the viewer's own pass
  /// ignore the failure cooldown the background passes honour.
  ///
  /// A room whose last ask failed sits the cooldown out — a platform that
  /// is down must not be hammered by every pass. A failed ask marks the
  /// stored copy unknown, so a stale "live" badge never survives an hour
  /// of failures. The whole pass lands as one write, and one slow ask
  /// holds up its slot, not everyone behind it.
  Future<int> refreshRooms(
    Iterable<LiveRoom> rooms, {
    void Function(int done, int total)? onProgress,
    bool quiet = false,
    bool bypassCooldown = false,
  }) async {
    final repository = ref.read(followRepositoryProvider).value;
    if (repository == null) return 0;
    final now = DateTime.now();
    final queue = [
      for (final room in rooms)
        if (bypassCooldown ||
            !(now.difference(_refreshFailedAt[room.ref.identityKey] ?? DateTime(0)) < _refreshCooldown))
          room,
    ];
    if (queue.isEmpty) return 0;
    final sites = ref.read(sitesProvider);
    final fresh = <LiveRoom>[];
    final failedKeys = <String>[];
    var failed = 0;
    var done = 0;
    var next = 0;
    onProgress?.call(done, queue.length);
    // A worker pool, not batched waits: one slow platform occupies its
    // slot while the others keep asking (the reference's own shape).
    Future<void> worker() async {
      while (next < queue.length) {
        final room = queue[next++];
        try {
          final provider = sites.getById(room.ref.platform)?.capability<LiveRoomProvider>();
          if (provider != null) {
            final answer = await provider.getRoom(room.ref.roomId);
            await answer.match<Future<void>>(
              (_) async {
                failed++;
                failedKeys.add(room.ref.identityKey);
                _refreshFailedAt[room.ref.identityKey] = DateTime.now();
              },
              (detail) async {
                _refreshFailedAt.remove(room.ref.identityKey);
                // A platform may answer under another id for the same
                // room; the merge must land on the follow's identity, or
                // it would grow a second entry and leave the card stale.
                fresh.add(
                  detail.ref == room.ref ? detail : detail.rebuild((b) => b..ref.replace(room.ref)),
                );
              },
            );
          }
        } on Object {
          failed++;
          failedKeys.add(room.ref.identityKey);
          _refreshFailedAt[room.ref.identityKey] = DateTime.now();
        } finally {
          onProgress?.call(++done, queue.length);
        }
      }
    }

    final concurrency = ref.read(maxConcurrentRefreshProvider).clamp(1, 20);
    await Future.wait(<Future<void>>[for (var i = 0; i < concurrency; i++) worker()]);
    if (fresh.isNotEmpty) {
      await repository.mergeAll(fresh);
      liveAlertObserver?.call(fresh, quiet: quiet);
    }
    if (failedKeys.isNotEmpty) await repository.markUnknown(failedKeys);
    return failed;
  }

  /// Fetches [rooms] as they are now, merges the answers in one write and
  /// answers the fresh states (a failed ask and a platform without the
  /// capability are left out). The live-alert check and the recorder's
  /// waiting checks share this path; a caller that wants a failure count
  /// uses [refreshRooms]. Failures sit out the cooldown like the page's
  /// pass, but a failure here marks nothing — an alert check must not
  /// read a transient miss as a broadcast ending.
  Future<List<LiveRoom>> fetchLiveStates(Iterable<LiveRoom> rooms) async {
    final repository = ref.read(followRepositoryProvider).value;
    if (repository == null) return const [];
    final now = DateTime.now();
    final queue = [
      for (final room in rooms)
        if (!(now.difference(_refreshFailedAt[room.ref.identityKey] ?? DateTime(0)) < _refreshCooldown)) room,
    ];
    if (queue.isEmpty) return const [];
    final sites = ref.read(sitesProvider);
    final fresh = <LiveRoom>[];
    var next = 0;
    Future<void> worker() async {
      while (next < queue.length) {
        final room = queue[next++];
        try {
          final provider = sites.getById(room.ref.platform)?.capability<LiveRoomProvider>();
          if (provider == null) continue;
          final answer = await provider.getRoom(room.ref.roomId);
          await answer.match<Future<void>>((_) async {
            _refreshFailedAt[room.ref.identityKey] = DateTime.now();
          }, (detail) async {
            _refreshFailedAt.remove(room.ref.identityKey);
            fresh.add(detail.ref == room.ref ? detail : detail.rebuild((b) => b..ref.replace(room.ref)));
          });
        } on Object {
          _refreshFailedAt[room.ref.identityKey] = DateTime.now();
        }
      }
    }

    final concurrency = ref.read(maxConcurrentRefreshProvider).clamp(1, 20);
    await Future.wait(<Future<void>>[for (var i = 0; i < concurrency; i++) worker()]);
    if (fresh.isNotEmpty) await repository.mergeAll(fresh);
    return fresh;
  }
}

/// The favorites page's state.
final followsProvider = NotifierProvider<FollowsController, FollowsState>(FollowsController.new);
