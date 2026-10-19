import 'dart:async';

import 'package:live_library/src/model/library_room.dart';
import 'package:live_library/src/store/library_store.dart';
import 'package:live_sites/live_sites.dart';

/// The followed rooms, their groups and their ordering.
///
/// Every mutation persists through the [LibraryStore] and publishes on
/// [changes]; a change from another writer (a second window) also
/// triggers a reload, so two windows stay in step. The room snapshot
/// inside a record is replaced by [replaceRoom] after refreshes — the
/// user's note, groups and position are never touched by that path.
final class FollowRepository {
  /// A repository over [store].
  new(this.store);

  /// The persistence seam.
  final LibraryStore store;

  final _changes = StreamController<void>.broadcast();
  List<LibraryRoom> _rooms = const [];
  List<FollowGroup> _groups = const [];
  bool _loaded = false;
  StreamSubscription<void>? _external;

  /// Emits after every committed mutation (local or external).
  Stream<void> get changes => _changes.stream;

  /// Whether [load] has run.
  bool get isLoaded => _loaded;

  /// The followed rooms, ordered by position.
  List<LibraryRoom> get rooms => List.unmodifiable(_rooms);

  /// The follow groups, ordered by position.
  List<FollowGroup> get groups => List.unmodifiable(_groups);

  /// Loads from the store and starts watching external changes
  /// (idempotent).
  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    _rooms = await store.loadRooms();
    _groups = await store.loadGroups();
    _external ??= store.changes.listen((_) => unawaited(_reload()));
  }

  /// Replaces the whole follow list with [rooms] and the whole group list
  /// with [groups] — the follows-backup restore door (the reference writes
  /// the two keys in one document). One commit, so the follow page sees the
  /// new state as a single change rather than a flicker of un-follows.
  Future<void> replaceAll({required List<LibraryRoom> rooms, required List<FollowGroup> groups}) async {
    _rooms = rooms;
    _groups = groups;
    await _commitRooms();
    await _commitGroups();
  }

  /// Whether [room] is followed (by identity).
  bool isFollowed(LiveRoom room) => _rooms.any((record) => record.identity == room.identityKey);

  /// The record of [room], when followed.
  LibraryRoom? recordOf(LiveRoom room) => _rooms.where((record) => record.identity == room.identityKey).firstOrNull;

  /// Follows [room] (a no-op when already followed).
  Future<void> follow(LiveRoom room, {String? note, List<String> groupIds = const []}) async {
    if (isFollowed(room)) {
      return;
    }
    final position = _rooms.isEmpty ? 0 : _rooms.map((r) => r.position).reduce((a, b) => a > b ? a : b) + 1;
    _rooms = [
      ..._rooms,
      LibraryRoom(room: room, followedAt: DateTime.now(), position: position, note: note, groupIds: groupIds),
    ];
    await _commitRooms();
  }

  /// Unfollows [room] (a no-op when absent).
  Future<void> unfollow(LiveRoom room) async {
    final next = [
      for (final record in _rooms)
        if (record.identity != room.identityKey) record,
    ];
    if (next.length == _rooms.length) {
      return;
    }
    _rooms = next;
    await _commitRooms();
  }

  /// Replaces the snapshot of [room] after a refresh, keeping the user's
  /// metadata untouched.
  Future<void> replaceRoom(LiveRoom room) async {
    var changed = false;
    _rooms = [
      for (final record in _rooms)
        if (record.identity == room.identityKey)
          () {
            changed = true;
            return record.copyWith(room: record.room.mergedWith(room));
          }()
        else
          record,
    ];
    if (changed) {
      await _commitRooms();
    }
  }

  /// Sets the user's [note] on [room].
  Future<void> setNote(LiveRoom room, String? note) => _updateRecord(room, (record) => record.copyWith(note: note));

  /// Replaces [room]'s follow groups.
  Future<void> setGroups(LiveRoom room, List<String> groupIds) =>
      _updateRecord(room, (record) => record.copyWith(groupIds: groupIds));

  /// Moves [room] to [position], rewriting the order of the whole list.
  Future<void> reorder(LiveRoom room, int position) async {
    final ordered = [..._rooms]..sort((a, b) => a.position.compareTo(b.position));
    final index = ordered.indexWhere((record) => record.identity == room.identityKey);
    if (index < 0) {
      return;
    }
    final moved = ordered.removeAt(index);
    ordered.insert(position.clamp(0, ordered.length), moved);
    _rooms = [for (final (index, record) in ordered.indexed) record.copyWith(position: index)];
    await _commitRooms();
  }

  /// Creates a group and returns its id.
  Future<String> createGroup(String name) async {
    final id = 'g${DateTime.now().microsecondsSinceEpoch}';
    final position = _groups.isEmpty ? 0 : _groups.map((g) => g.position).reduce((a, b) => a > b ? a : b) + 1;
    _groups = [..._groups, FollowGroup(id: id, name: name, position: position)];
    await _commitGroups();
    return id;
  }

  /// Renames a group.
  Future<void> renameGroup(String id, String name) async {
    _groups = [
      for (final group in _groups)
        if (group.id == id) group.copyWith(name: name) else group,
    ];
    await _commitGroups();
  }

  /// Moves the group [id] to [targetIndex] in the position order, rewriting
  /// every position — the tag manager's drag handle and pin-to-top both
  /// address this.
  Future<void> reorderGroup(String id, int targetIndex) async {
    final ordered = [..._groups]..sort((a, b) => a.position.compareTo(b.position));
    final index = ordered.indexWhere((group) => group.id == id);
    if (index < 0) {
      return;
    }
    final moved = ordered.removeAt(index);
    ordered.insert(targetIndex.clamp(0, ordered.length - 1), moved);
    _groups = [for (final (position, group) in ordered.indexed) group.copyWith(position: position)];
    await _commitGroups();
  }

  /// Deletes a group; its members keep their records but lose the id.
  Future<void> deleteGroup(String id) async {
    final nextGroups = [
      for (final group in _groups)
        if (group.id != id) group,
    ];
    if (nextGroups.length == _groups.length) {
      return;
    }
    _groups = nextGroups;
    _rooms = [
      for (final record in _rooms)
        if (record.groupIds.contains(id))
          record.copyWith(
            groupIds: [
              for (final groupId in record.groupIds)
                if (groupId != id) groupId,
            ],
          )
        else
          record,
    ];
    await _commitGroups();
    await _commitRooms();
  }

  /// Releases the repository (stops watching external changes).
  Future<void> dispose() async {
    await _external?.cancel();
    _external = null;
    await _changes.close();
  }

  Future<void> _updateRecord(LiveRoom room, LibraryRoom Function(LibraryRoom) transform) async {
    var changed = false;
    _rooms = [
      for (final record in _rooms)
        if (record.identity == room.identityKey)
          () {
            changed = true;
            return transform(record);
          }()
        else
          record,
    ];
    if (changed) {
      await _commitRooms();
    }
  }

  Future<void> _commitRooms() async {
    await store.saveRooms(_rooms);
    _changes.add(null);
  }

  Future<void> _commitGroups() async {
    await store.saveGroups(_groups);
    _changes.add(null);
  }

  Future<void> _reload() async {
    _rooms = await store.loadRooms();
    _groups = await store.loadGroups();
    _changes.add(null);
  }
}
