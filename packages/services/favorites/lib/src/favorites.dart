// Module: lib/src/favorites.dart
// Purpose: Cross-domain favourites keyed by ContentRef, with the snapshot kept so a dead source still shows.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/services/favorites.md - "跨域收藏夹/分组,键 = ContentRef", the folder/entry shapes it sketches,
// and the rule that snapshot metadata (title/cover) is stored with the entry so the list stays visible after
// the source stops answering. "关注" is deliberately not here: that comes from a source, this is local.

import 'package:pure_live_platform/pure_live_platform.dart';

/// The id of the folder every unfiled favourite goes to. A value rather than a string the caller types, so a
/// rename of the display name cannot orphan entries.
const String defaultFolderId = 'favorites.default';

/// A user-arranged group of favourites.
final class FavoriteFolder {
  const FavoriteFolder({required this.id, required this.name, this.sortKey = 0});

  factory FavoriteFolder.fromJson(Map<String, Object?> json) => FavoriteFolder(
    id: _requireString(json, 'id', 'favorite_folder'),
    name: _requireString(json, 'name', 'favorite_folder'),
    sortKey: (json['sortKey'] as num?)?.toInt() ?? 0,
  );

  static const FavoriteFolder defaultFolder = FavoriteFolder(id: defaultFolderId, name: '默认');

  final String id;
  final String name;

  /// The manual ordering weight. "排序手动" is user data: the list may not decide the order by itself.
  final int sortKey;

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'name': name, 'sortKey': sortKey};

  @override
  bool operator ==(Object other) =>
      other is FavoriteFolder && other.id == id && other.name == name && other.sortKey == sortKey;

  @override
  int get hashCode => Object.hash(id, name, sortKey);

  @override
  String toString() => 'FavoriteFolder($id $name sort:$sortKey)';
}

/// One favourited item. The key is the whole [ref], not a bare id: the same content id on two sources is two
/// different things to watch.
final class FavoriteEntry {
  const FavoriteEntry({required this.ref, required this.folderId, required this.addedAt, required this.snapshot});

  factory FavoriteEntry.fromJson(Map<String, Object?> json) => FavoriteEntry(
    ref: ContentRef.fromJson(_asMap(json['ref'])),
    folderId: _requireString(json, 'folderId', 'favorite_entry'),
    addedAt: _parseUtc(json['addedAt']),
    snapshot: ContentSummary.fromJson(_asMap(json['snapshot'])),
  );

  final ContentRef ref;
  final String folderId;

  /// When the user added it. Re-adding refreshes the snapshot but not this stamp: an entry's age is the
  /// user's history, and rewriting it on every open would re-sort the list under them.
  final DateTime addedAt;

  /// The title/cover the platform saw when it was added, kept so the list renders without asking the source.
  final ContentSummary snapshot;

  FavoriteEntry inFolder(String id) => FavoriteEntry(ref: ref, folderId: id, addedAt: addedAt, snapshot: snapshot);

  FavoriteEntry withSnapshot(ContentSummary updated) =>
      FavoriteEntry(ref: ref, folderId: folderId, addedAt: addedAt, snapshot: updated);

  Map<String, Object?> toJson() => <String, Object?>{
    'ref': ref.toJson(),
    'folderId': folderId,
    'addedAt': _formatUtc(addedAt),
    'snapshot': snapshot.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is FavoriteEntry && other.ref == ref && other.folderId == folderId && other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(ref, folderId, addedAt);

  @override
  String toString() => 'FavoriteEntry(${ref.sourceId}/${ref.contentId} -> $folderId)';
}

/// Why a favourite operation was refused.
enum FavoriteFailure { folderNotFound, folderNotEmpty, notFavorite }

final class FavoriteException implements Exception {
  const FavoriteException(this.kind, this.detail);

  final FavoriteFailure kind;
  final String detail;

  @override
  String toString() => 'FavoriteException(${kind.name}: $detail)';
}

/// Where favourites live. Fine-grained on purpose: a key/value binding may rewrite one document, while a
/// database must not have to, so neither shape is smuggled into this interface.
abstract interface class FavoriteRepository {
  Future<List<FavoriteFolder>> folders();

  Future<void> upsertFolder(FavoriteFolder folder);

  Future<void> removeFolder(String folderId);

  Future<List<FavoriteEntry>> entries();

  Future<void> upsertEntry(FavoriteEntry entry);

  Future<void> removeEntry(ContentRef ref);
}

/// The favourites list, its folders and their order.
final class FavoritesService {
  FavoritesService({required FavoriteRepository repository, DateTime Function()? clock})
    : _repository = repository,
      _clock = clock ?? _utcNow;

  final FavoriteRepository _repository;
  final DateTime Function() _clock;

  /// Creates the default folder if it is missing. A binding that stores nothing on first run would otherwise
  /// make every `add` fail with "folder not found".
  Future<void> initialize() => _repository.upsertFolder(FavoriteFolder.defaultFolder);

  /// Folders in the user's manual order, ties broken by name so the order is still total.
  Future<List<FavoriteFolder>> folders() async {
    final sorted = List<FavoriteFolder>.of(await _repository.folders());
    sorted.sort((a, b) {
      final byKey = a.sortKey.compareTo(b.sortKey);
      return byKey != 0 ? byKey : a.name.compareTo(b.name);
    });
    return sorted;
  }

  Future<FavoriteFolder> createFolder(String id, String name, {int sortKey = 0}) async {
    final folder = FavoriteFolder(id: id, name: name, sortKey: sortKey);
    await _repository.upsertFolder(folder);
    return folder;
  }

  Future<void> renameFolder(String id, String name) async {
    final folder = await _requireFolder(id);
    await _repository.upsertFolder(FavoriteFolder(id: folder.id, name: name, sortKey: folder.sortKey));
  }

  Future<void> reorderFolder(String id, int sortKey) async {
    final folder = await _requireFolder(id);
    await _repository.upsertFolder(FavoriteFolder(id: folder.id, name: folder.name, sortKey: sortKey));
  }

  /// Removing a folder that still holds favourites is refused rather than emptied: the user asked to delete a
  /// label, and both alternatives - deleting their favourites, or moving them somewhere they did not choose -
  /// touch data this layer has no authority over.
  Future<void> removeFolder(String id) async {
    await _requireFolder(id);
    final held = (await _repository.entries()).where((entry) => entry.folderId == id).toList(growable: false);
    if (held.isNotEmpty) {
      throw FavoriteException(
        FavoriteFailure.folderNotEmpty,
        'folder $id still holds ${held.length} favourites; move them first',
      );
    }
    await _repository.removeFolder(id);
  }

  /// Favourites [ref] with the metadata the caller has on screen. If it is already there, the snapshot is
  /// refreshed and the original `addedAt` is kept.
  Future<FavoriteEntry> add(ContentRef ref, ContentSummary snapshot, {String folderId = defaultFolderId}) async {
    final folder = await _requireFolder(folderId);
    final existing = await _find(ref);
    final entry = existing == null
        ? FavoriteEntry(ref: ref, folderId: folder.id, addedAt: _clock(), snapshot: snapshot)
        : existing.withSnapshot(snapshot);
    await _repository.upsertEntry(entry);
    return entry;
  }

  Future<void> remove(ContentRef ref) async {
    if (await _find(ref) == null) {
      throw FavoriteException(FavoriteFailure.notFavorite, '${ref.sourceId}/${ref.contentId} is not a favourite');
    }
    await _repository.removeEntry(ref);
  }

  Future<FavoriteEntry> move(ContentRef ref, String folderId) async {
    final entry = await _find(ref);
    if (entry == null) {
      throw FavoriteException(FavoriteFailure.notFavorite, '${ref.sourceId}/${ref.contentId} is not a favourite');
    }
    final folder = await _requireFolder(folderId);
    final moved = entry.inFolder(folder.id);
    await _repository.upsertEntry(moved);
    return moved;
  }

  /// The listing is built entirely from stored snapshots: nothing here asks a source, which is the point of
  /// "源失效仍可见".
  ///
  /// Newest first. The entry shape carries no manual ordering weight, so "手动" belongs to the folders and a
  /// per-entry order would be a model change, not a sort.
  Future<List<FavoriteEntry>> list({String? folderId, SourceId? sourceId, ContentKind? kind}) async {
    final entries = (await _repository.entries()).where((entry) {
      if (folderId != null && entry.folderId != folderId) {
        return false;
      }
      if (sourceId != null && entry.ref.sourceId != sourceId) {
        return false;
      }
      if (kind != null && entry.ref.kind != kind) {
        return false;
      }
      return true;
    }).toList();
    entries.sort((a, b) => -a.addedAt.compareTo(b.addedAt));
    return entries;
  }

  Future<FavoriteEntry?> _find(ContentRef ref) async {
    for (final entry in await _repository.entries()) {
      if (entry.ref == ref) {
        return entry;
      }
    }
    return null;
  }

  Future<FavoriteFolder> _requireFolder(String id) async {
    for (final folder in await _repository.folders()) {
      if (folder.id == id) {
        return folder;
      }
    }
    throw FavoriteException(FavoriteFailure.folderNotFound, 'no favourite folder named $id');
  }

  static DateTime _utcNow() => DateTime.now().toUtc();
}

// The platform package keeps its JSON helpers in src/support, so a service that stores its own records parses
// them here rather than widening a shared barrel for one package's benefit.

Map<String, Object?> _asMap(Object? raw) {
  if (raw is! Map) {
    throw FormatException('expected an object, got ${raw.runtimeType}', raw);
  }
  return Map<String, Object?>.from(raw);
}

String _requireString(Map<String, Object?> json, String field, String shape) {
  final value = json[field];
  if (value is! String || value.isEmpty) {
    throw FormatException('$shape is missing $field', json);
  }
  return value;
}

DateTime _parseUtc(Object? raw) {
  if (raw is! String) {
    throw FormatException('expected an ISO-8601 timestamp, got ${raw.runtimeType}', raw);
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('unreadable timestamp', raw);
  }
  return parsed.toUtc();
}

String _formatUtc(DateTime value) => value.toUtc().toIso8601String();
