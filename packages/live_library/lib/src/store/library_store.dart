import 'dart:async';

import 'package:live_library/src/model/library_room.dart';
import 'package:live_storage/live_storage.dart';

/// The persistence seam of the library.
///
/// The production implementation writes through the live_storage
/// preferences store; tests use [InMemoryLibraryStore].
abstract interface class LibraryStore {
  /// Loads the followed rooms (ordered by position).
  Future<List<LibraryRoom>> loadRooms();

  /// Loads the follow groups.
  Future<List<FollowGroup>> loadGroups();

  /// Loads the watch history (newest first).
  Future<List<WatchRecord>> loadHistory();

  /// Stores the followed rooms.
  Future<void> saveRooms(List<LibraryRoom> rooms);

  /// Stores the follow groups.
  Future<void> saveGroups(List<FollowGroup> groups);

  /// Stores the watch history.
  Future<void> saveHistory(List<WatchRecord> history);

  /// Emits whenever another writer changed the library (second window).
  Stream<void> get changes;
}

/// The keys the library owns in the preferences store.
abstract final class LibraryKeys {
  /// Followed rooms.
  static const String rooms = 'library.follows.v1';

  /// Follow groups.
  static const String groups = 'library.groups.v1';

  /// Watch history.
  static const String history = 'library.history.v1';
}

/// A [LibraryStore] over the live_storage preferences seam.
final class PreferencesLibraryStore implements LibraryStore {
  /// A store over [preferences].
  new(this.preferences);

  /// The preferences store (drift-backed in production).
  final PreferencesStore preferences;

  @override
  Stream<void> get changes => preferences.changes;

  @override
  Future<List<LibraryRoom>> loadRooms() => _load(LibraryKeys.rooms, LibraryRoom.fromJson);

  @override
  Future<List<FollowGroup>> loadGroups() => _load(LibraryKeys.groups, FollowGroup.fromJson);

  @override
  Future<List<WatchRecord>> loadHistory() => _load(LibraryKeys.history, WatchRecord.fromJson);

  @override
  Future<void> saveRooms(List<LibraryRoom> rooms) => _save(LibraryKeys.rooms, rooms, (room) => room.toJson());

  @override
  Future<void> saveGroups(List<FollowGroup> groups) => _save(LibraryKeys.groups, groups, (group) => group.toJson());

  @override
  Future<void> saveHistory(List<WatchRecord> history) =>
      _save(LibraryKeys.history, history, (record) => record.toJson());

  Future<List<T>> _load<T>(String key, T Function(Map<String, Object?>) fromJson) async {
    final raw = await preferences.read(key);
    if (raw is! List) {
      return const [];
    }
    final items = <T>[];
    for (final entry in raw) {
      if (entry is Map) {
        items.add(fromJson(entry.cast<String, Object?>()));
      }
    }
    return items;
  }

  Future<void> _save<T>(String key, List<T> items, Map<String, Object?> Function(T) toJson) =>
      preferences.write(key, [for (final item in items) toJson(item)]);
}

/// An in-memory [LibraryStore] for tests and previews.
final class InMemoryLibraryStore implements LibraryStore {
  /// An empty store.
  new();

  final _changes = StreamController<void>.broadcast();
  List<LibraryRoom> _rooms = const [];
  List<FollowGroup> _groups = const [];
  List<WatchRecord> _history = const [];

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<LibraryRoom>> loadRooms() async => _rooms;

  @override
  Future<List<FollowGroup>> loadGroups() async => _groups;

  @override
  Future<List<WatchRecord>> loadHistory() async => _history;

  @override
  Future<void> saveRooms(List<LibraryRoom> rooms) async {
    _rooms = List.unmodifiable(rooms);
    _changes.add(null);
  }

  @override
  Future<void> saveGroups(List<FollowGroup> groups) async {
    _groups = List.unmodifiable(groups);
    _changes.add(null);
  }

  @override
  Future<void> saveHistory(List<WatchRecord> history) async {
    _history = List.unmodifiable(history);
    _changes.add(null);
  }
}
