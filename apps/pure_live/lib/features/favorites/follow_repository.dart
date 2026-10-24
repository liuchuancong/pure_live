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
    final merged =
        stored == null ? incoming : LiveRoom.fromJson(_jsonOf(stored)).mergedWith(incoming);
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

/// The follows repository (one box, one process).
final followRepositoryProvider = FutureProvider<FollowRepository>((ref) async {
  final box = await StorageBoxManager().keyed<Object>('follows');
  return FollowRepository(HiveStorageRepository(box: box));
});

/// What the favorites page holds: the followed rooms and whether the
/// repository has opened yet.
typedef FollowsState = ({bool ready, List<LiveRoom> rooms});

/// Mirrors the follows repository into the widget tree: it lists once the
/// repository opens and follows its watch stream, so every change from any
/// surface (the page, a room's follow button) lands at once.
final class FollowsController extends Notifier<FollowsState> {
  StreamSubscription<void>? _subscription;

  @override
  FollowsState build() {
    ref.watch(followRepositoryProvider).whenData((repository) {
      _subscription ??= repository.watch().listen((_) => _refresh(repository));
      _refresh(repository);
    });
    ref.onDispose(() => unawaited(_subscription?.cancel() ?? Future<void>.value()));
    return (ready: false, rooms: const []);
  }

  void _refresh(FollowRepository repository) {
    state = (ready: true, rooms: repository.list());
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

  /// Refreshes every followed room against its platform (the reference's
  /// `FollowRefresher`): the room provider asks each site for the room as
  /// it is now, and what comes back merges into the stored copy — a stale
  /// title or audience figure never erases a fresh one.
  ///
  /// A platform without the room capability (or a failed ask) keeps the
  /// stored copy: the refresh reports no error, it just learns nothing.
  Future<void> refresh() async {
    final repository = ref.read(followRepositoryProvider).value;
    if (repository == null) return;
    final rooms = repository.list();
    final sites = ref.read(sitesProvider);
    // A handful of asks at a time keeps a full list from stampeding one
    // platform's endpoints.
    const batchSize = 4;
    for (var start = 0; start < rooms.length; start += batchSize) {
      final batch = rooms.sublist(start, (start + batchSize).clamp(0, rooms.length));
      Future<void> refreshOne(LiveRoom room) {
        final provider = sites.getById(room.ref.platform)?.capability<LiveRoomProvider>();
        if (provider == null) return Future<void>.value();
        return provider.getRoom(room.ref.roomId).then((answer) => answer.match((_) {}, repository.merge));
      }

      await Future.wait(<Future<void>>[for (final room in batch) refreshOne(room)]);
    }
  }
}

/// The favorites page's state.
final followsProvider = NotifierProvider<FollowsController, FollowsState>(FollowsController.new);
