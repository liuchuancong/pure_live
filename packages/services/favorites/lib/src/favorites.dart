// Module: lib/src/favorites.dart
// Purpose: Cross-domain favourites keyed by ContentRef, with the snapshot kept so a dead source still shows.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/services/favorites.md - "跨域收藏夹/分组,键 = ContentRef", the folder/entry shapes it sketches,
// and the rule that snapshot metadata (title/cover) is stored with the entry so the list stays visible after
// the source stops answering. "关注" is deliberately not here: that comes from a source, this is local.

import 'dart:async';

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
    _announce();
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
    _announce();
    return entry;
  }

  Future<void> remove(ContentRef ref) async {
    if (await _find(ref) == null) {
      throw FavoriteException(FavoriteFailure.notFavorite, '${ref.sourceId}/${ref.contentId} is not a favourite');
    }
    await _repository.removeEntry(ref);
    _announce();
  }

  Future<FavoriteEntry> move(ContentRef ref, String folderId) async {
    final entry = await _find(ref);
    if (entry == null) {
      throw FavoriteException(FavoriteFailure.notFavorite, '${ref.sourceId}/${ref.contentId} is not a favourite');
    }
    final folder = await _requireFolder(folderId);
    final moved = entry.inFolder(folder.id);
    await _repository.upsertEntry(moved);
    _announce();
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

  /// Whether [ref] is on the list, without building the list.
  Future<bool> isFavorite(ContentRef ref) async => await _find(ref) != null;

  /// How many favourites each folder holds, empty folders included: a folder list that shows counts needs the
  /// zeros too, or an empty folder looks like a missing one.
  Future<Map<String, int>> folderCounts() async {
    final counts = <String, int>{for (final folder in await _repository.folders()) folder.id: 0};
    for (final entry in await _repository.entries()) {
      counts[entry.folderId] = (counts[entry.folderId] ?? 0) + 1;
    }
    return Map<String, int>.unmodifiable(counts);
  }

  /// Entries whose **stored snapshot** mentions [query] in title, subtitle or description.
  ///
  /// A filter over the snapshots rather than a search at the source: the list is browsable with the network
  /// down, which is the property that made the snapshot the record in the first place.
  Future<List<FavoriteEntry>> matching(String query, {String? folderId, int? limit}) async {
    final found = await list(folderId: folderId);
    final needle = query.trim().toLowerCase();
    final hits = needle.isEmpty
        ? found
        : <FavoriteEntry>[
            for (final entry in found)
              if (_mentions(entry.snapshot, needle)) entry,
          ];
    return limit == null || limit >= hits.length
        ? hits
        : List<FavoriteEntry>.unmodifiable(hits.take(limit < 0 ? 0 : limit));
  }

  /// Moves several entries, reading the list once and reporting what it refused.
  ///
  /// A bulk call that threw on the first bad ref would leave the user believing the batch had been applied.
  Future<BulkFolderChange> moveAll(Iterable<ContentRef> refs, String folderId) async {
    final folder = await _requireFolder(folderId);
    final entries = await _repository.entries();
    final moved = <ContentRef>[];
    final refused = <ContentRef>[];
    for (final ref in refs) {
      final found = _firstEntryFor(entries, ref);
      if (found == null) {
        refused.add(ref);
        continue;
      }
      await _repository.upsertEntry(found.inFolder(folder.id));
      moved.add(ref);
    }
    _announce();
    return BulkFolderChange(moved: moved, refused: refused);
  }

  Future<BulkRemoval> removeAll(Iterable<ContentRef> refs) async {
    final entries = await _repository.entries();
    final removed = <ContentRef>[];
    final refused = <ContentRef>[];
    for (final ref in refs) {
      if (_firstEntryFor(entries, ref) == null) {
        refused.add(ref);
        continue;
      }
      await _repository.removeEntry(ref);
      removed.add(ref);
    }
    _announce();
    return BulkRemoval(removed: removed, refused: refused);
  }

  /// Re-asks a source for each stored snapshot, through [lookup], and reports the four outcomes separately.
  ///
  /// Bounded by [limit]: the unbounded version runs one request per favourite against whatever the user saved
  /// over a year. A null answer is **missing**, not an error to swallow - a video that is gone keeps its old
  /// snapshot and shows up in [SnapshotRefresh.missing] so the caller can mark it rather than drop the row.
  Future<SnapshotRefresh> refreshSnapshots(
    Future<ContentSummary?> Function(ContentRef ref) lookup, {
    int limit = 100,
    String? folderId,
  }) async {
    final targets = List<FavoriteEntry>.unmodifiable((await list(folderId: folderId)).take(limit < 1 ? 0 : limit));
    var refreshed = 0;
    var unchanged = 0;
    final missing = <ContentRef>[];
    final failed = <ContentRef>[];
    for (final entry in targets) {
      final ContentSummary? fresh;
      try {
        fresh = await lookup(entry.ref);
      } on Object {
        failed.add(entry.ref);
        continue;
      }
      if (fresh == null) {
        missing.add(entry.ref);
        continue;
      }
      if (fresh.title == entry.snapshot.title &&
          fresh.subtitle == entry.snapshot.subtitle &&
          fresh.cover == entry.snapshot.cover) {
        unchanged++;
        continue;
      }
      await _repository.upsertEntry(entry.withSnapshot(fresh));
      refreshed++;
    }
    if (refreshed > 0) {
      _announce();
    }
    return SnapshotRefresh(
      considered: targets.length,
      refreshed: refreshed,
      unchanged: unchanged,
      missing: missing,
      failed: failed,
    );
  }

  /// Emits after any mutation this service performs, so a list screen listens instead of re-reading on every
  /// rebuild. Broadcast: a second screen must not steal the first one's events.
  Stream<void> get changes {
    final out = _changes ??= StreamController<void>.broadcast();
    return out.stream;
  }

  /// Closes [changes]. The service keeps working after this; it just stops announcing.
  Future<void> dispose() async {
    final out = _changes;
    _changes = null;
    if (out != null && !out.isClosed) {
      await out.close();
    }
  }

  StreamController<void>? _changes;

  void _announce() {
    final out = _changes;
    if (out != null && !out.isClosed) {
      out.add(null);
    }
  }

  static bool _mentions(ContentSummary snapshot, String needle) {
    if (snapshot.title.toLowerCase().contains(needle)) {
      return true;
    }
    final subtitle = snapshot.subtitle;
    if (subtitle != null && subtitle.toLowerCase().contains(needle)) {
      return true;
    }
    final description = snapshot.description;
    return description != null && description.toLowerCase().contains(needle);
  }

  static FavoriteEntry? _firstEntryFor(List<FavoriteEntry> entries, ContentRef ref) {
    for (final entry in entries) {
      if (entry.ref == ref) {
        return entry;
      }
    }
    return null;
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

/// What a bulk move did: the rows it moved and the refs it refused because they were not favourites.
final class BulkFolderChange {
  const BulkFolderChange({required this.moved, required this.refused});

  final List<ContentRef> moved;
  final List<ContentRef> refused;

  bool get isClean => refused.isEmpty;

  int get requestedCount => moved.length + refused.length;

  @override
  String toString() => 'BulkFolderChange(${moved.length} moved, ${refused.length} refused)';
}

/// What a bulk removal did.
final class BulkRemoval {
  const BulkRemoval({required this.removed, required this.refused});

  final List<ContentRef> removed;
  final List<ContentRef> refused;

  bool get isClean => refused.isEmpty;

  @override
  String toString() => 'BulkRemoval(${removed.length} removed, ${refused.length} refused)';
}

/// What a snapshot refresh found, in the four categories that need handling different from each other.
final class SnapshotRefresh {
  const SnapshotRefresh({
    required this.considered,
    required this.refreshed,
    required this.unchanged,
    required this.missing,
    required this.failed,
  });

  final int considered;
  final int refreshed;
  final int unchanged;

  /// The source answered "I do not have this anymore".
  final List<ContentRef> missing;

  /// The lookup threw. The old snapshot stays - that is the whole point of storing one.
  final List<ContentRef> failed;

  int get untouched => missing.length + failed.length;

  @override
  String toString() =>
      'SnapshotRefresh($considered considered, $refreshed refreshed, $unchanged unchanged, '
      '${missing.length} missing, ${failed.length} failed)';
}
