// Module: lib/src/key_value_favorite_repository.dart
// Purpose: Bind the favourite repository to one key/value document.
// Author: liuchuancong
// Created: 2026-10-09
//
// docs/services/favorites.md names Drift as the eventual store and puts favourites in the sync scope. This
// binding is the key/value one the composition root can build today; the repository interface is what keeps
// a later Drift binding from changing anything above it (the same division as KeyValuePermissionStore).

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_storage/pure_live_storage.dart';

import 'favorites.dart';

/// A [FavoriteRepository] held in two keys of a [KeyValueStore].
///
/// Rewriting both lists per operation is deliberate at this size: a folder rename touches every entry, and a
/// document that is read whole cannot leave the two halves disagreeing the way two separate writes can.
final class KeyValueFavoriteRepository implements FavoriteRepository {
  KeyValueFavoriteRepository(this.store, {this.namespace = 'favorites'});

  final KeyValueStore store;
  final String namespace;

  String get _foldersKey => '$namespace.folders';

  String get _entriesKey => '$namespace.entries';

  @override
  Future<List<FavoriteFolder>> folders() async {
    final raw = await _readList(_foldersKey);
    return <FavoriteFolder>[
      for (final item in raw)
        if (item is Map) FavoriteFolder.fromJson(Map<String, Object?>.from(item)),
    ];
  }

  @override
  Future<void> upsertFolder(FavoriteFolder folder) async {
    final current = await folders();
    final next = <FavoriteFolder>[
      for (final existing in current)
        if (existing.id != folder.id) existing,
      folder,
    ];
    await _writeFolders(next);
  }

  @override
  Future<void> removeFolder(String folderId) async {
    final current = await folders();
    await _writeFolders(current.where((folder) => folder.id != folderId).toList(growable: false));
  }

  @override
  Future<List<FavoriteEntry>> entries() async {
    final raw = await _readList(_entriesKey);
    return <FavoriteEntry>[
      for (final item in raw)
        if (item is Map) FavoriteEntry.fromJson(Map<String, Object?>.from(item)),
    ];
  }

  @override
  Future<void> upsertEntry(FavoriteEntry entry) async {
    final current = await entries();
    final next = <FavoriteEntry>[
      for (final existing in current)
        if (existing.ref != entry.ref) existing,
      entry,
    ];
    await _writeEntries(next);
  }

  @override
  Future<void> removeEntry(ContentRef ref) async {
    final current = await entries();
    await _writeEntries(current.where((entry) => entry.ref != ref).toList(growable: false));
  }

  /// A document that exists but is not a list is refused rather than read as empty: the next write rebuilds
  /// the whole document from what it read, so a silent "empty" here is how the rest of the user's favourites
  /// would disappear on the next add (the same rule FileKeyValueStore applies to its file).
  Future<List<Object?>> _readList(String key) async {
    final raw = await store.read(key);
    if (raw == null) {
      return const <Object?>[];
    }
    if (raw is! List) {
      throw FormatException('the $key document is a ${raw.runtimeType}, not a list', raw);
    }
    return raw;
  }

  Future<void> _writeFolders(List<FavoriteFolder> folders) =>
      store.write(_foldersKey, folders.map((folder) => folder.toJson()).toList(growable: false));

  Future<void> _writeEntries(List<FavoriteEntry> entries) =>
      store.write(_entriesKey, entries.map((entry) => entry.toJson()).toList(growable: false));
}
