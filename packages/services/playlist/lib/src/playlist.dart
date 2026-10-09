// Module: lib/src/playlist.dart
// Purpose: The user's ordered playlists, with the snapshot stored so the list survives its sources.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/content/playlist.md - a Playlist is id + title + ordered entries + play policy, entries carry a
// ContentRef plus snapshot metadata, and a playlist may mix sources because each item resolves on its own.
// It also states the boundary this file keeps: a Playlist is a user asset, PlaybackQueue is session state.

import 'package:pure_live_platform/pure_live_platform.dart';

/// What the user asked the list to do. Stored, not obeyed: choosing the next item belongs to the playback
/// queue, which is session state (docs/content/playlist.md keeps the two apart on purpose).
enum PlaylistPlayMode { sequential, shuffle, singleLoop }

/// One row of a playlist.
final class PlaylistItem {
  const PlaylistItem({required this.ref, required this.snapshot});

  factory PlaylistItem.fromJson(Map<String, Object?> json) => PlaylistItem(
    ref: ContentRef.fromJson(_asMap(json['ref'])),
    snapshot: ContentSummary.fromJson(_asMap(json['snapshot'])),
  );

  final ContentRef ref;

  /// The title/cover captured when the row was added, so the list renders without asking any source.
  final ContentSummary snapshot;

  Map<String, Object?> toJson() => <String, Object?>{'ref': ref.toJson(), 'snapshot': snapshot.toJson()};

  @override
  bool operator ==(Object other) => other is PlaylistItem && other.ref == ref && other.snapshot.title == snapshot.title;

  @override
  int get hashCode => Object.hash(ref, snapshot.title);

  @override
  String toString() => 'PlaylistItem(${ref.sourceId}/${ref.contentId})';
}

/// A user-owned ordered list.
final class Playlist {
  const Playlist({
    required this.id,
    required this.title,
    this.items = const <PlaylistItem>[],
    this.playMode = PlaylistPlayMode.sequential,
  });

  factory Playlist.fromJson(Map<String, Object?> json) => Playlist(
    id: _requireString(json, 'id', 'playlist'),
    title: _requireString(json, 'title', 'playlist'),
    items: <PlaylistItem>[
      for (final item in (json['items'] as List? ?? const <Object?>[]))
        if (item is Map) PlaylistItem.fromJson(_asMap(item)),
    ],
    playMode: _playMode(json['playMode']),
  );

  final String id;
  final String title;

  /// Order is the meaning: a playlist is an ordered list, so the index is the identity of a row and the same
  /// content may legitimately appear twice (an M3U does exactly that).
  final List<PlaylistItem> items;
  final PlaylistPlayMode playMode;

  bool get isEmpty => items.isEmpty;

  Playlist withItems(List<PlaylistItem> next) =>
      Playlist(id: id, title: title, items: List<PlaylistItem>.unmodifiable(next), playMode: playMode);

  Playlist copyWith({String? title, PlaylistPlayMode? playMode}) =>
      Playlist(id: id, title: title ?? this.title, items: items, playMode: playMode ?? this.playMode);

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'playMode': playMode.name,
  };

  @override
  String toString() => 'Playlist($id $title ${items.length} items, ${playMode.name})';
}

/// Why a playlist operation was refused.
enum PlaylistFailure { notFound, indexOutOfRange, duplicateId }

final class PlaylistException implements Exception {
  const PlaylistException(this.kind, this.detail);

  final PlaylistFailure kind;
  final String detail;

  @override
  String toString() => 'PlaylistException(${kind.name}: $detail)';
}

/// Where playlists live. Whole-list granularity is honest here: the ordered list *is* the record, so a
/// per-item port would only hide the index maths the caller already has to do.
abstract interface class PlaylistRepository {
  Future<List<Playlist>> all();

  Future<void> upsert(Playlist playlist);

  Future<void> remove(String id);
}

/// The user's playlists: create, rename, order, and rows that keep their snapshot.
final class PlaylistsService {
  PlaylistsService({required PlaylistRepository repository}) : _repository = repository;

  static const int insertAtEnd = -1;

  final PlaylistRepository _repository;

  Future<List<Playlist>> list() => _repository.all();

  Future<Playlist> get(String id) async => _require(id);

  Future<Playlist> create(String id, String title) async {
    if (await _repository.all().then((all) => all.any((playlist) => playlist.id == id))) {
      throw PlaylistException(PlaylistFailure.duplicateId, 'a playlist named $id already exists');
    }
    final playlist = Playlist(id: id, title: title);
    await _repository.upsert(playlist);
    return playlist;
  }

  Future<Playlist> rename(String id, String title) async {
    final updated = (await _require(id)).copyWith(title: title);
    await _repository.upsert(updated);
    return updated;
  }

  Future<Playlist> setPlayMode(String id, PlaylistPlayMode mode) async {
    final updated = (await _require(id)).copyWith(playMode: mode);
    await _repository.upsert(updated);
    return updated;
  }

  /// Appends (or inserts before [index]) one row with the metadata the caller has on screen.
  ///
  /// A repeated ref is allowed and stays a separate row: this is a queue the user ordered, not a set.
  Future<Playlist> addItem(String id, PlaylistItem item, {int index = insertAtEnd}) async {
    final playlist = await _require(id);
    final items = List<PlaylistItem>.of(playlist.items);
    final target = index == insertAtEnd ? items.length : _checkRange(index, items.length, allowEnd: true);
    items.insert(target, item);
    return _store(playlist.withItems(items));
  }

  Future<Playlist> removeItem(String id, int index) async {
    final playlist = await _require(id);
    final items = List<PlaylistItem>.of(playlist.items);
    items.removeAt(_checkRange(index, items.length));
    return _store(playlist.withItems(items));
  }

  /// Moves the row at [from] so it lands where [to] currently is. Both indices are read against the list
  /// **before** the move, which is what a drag handle reports; the gap the removed row leaves is adjusted
  /// here rather than left for every caller to remember.
  Future<Playlist> moveItem(String id, int from, int to) async {
    final playlist = await _require(id);
    final items = List<PlaylistItem>.of(playlist.items);
    final source = _checkRange(from, items.length);
    final target = _checkRange(to, items.length, allowEnd: true);
    final moved = items.removeAt(source);
    items.insert(source < target ? target - 1 : target, moved);
    return _store(playlist.withItems(items));
  }

  Future<Playlist> clear(String id) async => _store((await _require(id)).withItems(const <PlaylistItem>[]));

  Future<void> delete(String id) async {
    await _require(id);
    await _repository.remove(id);
  }

  /// The first row for [ref], or null. A search rather than a key: the same content can occupy two rows, so
  /// the index of the one the user means is not derivable from the ref alone.
  Future<int?> indexOfFirst(String id, ContentRef ref) async {
    final items = (await _require(id)).items;
    for (var index = 0; index < items.length; index++) {
      if (items[index].ref == ref) {
        return index;
      }
    }
    return null;
  }

  Future<Playlist> _store(Playlist playlist) async {
    await _repository.upsert(playlist);
    return playlist;
  }

  Future<Playlist> _require(String id) async {
    for (final playlist in await _repository.all()) {
      if (playlist.id == id) {
        return playlist;
      }
    }
    throw PlaylistException(PlaylistFailure.notFound, 'no playlist named $id');
  }

  int _checkRange(int index, int length, {bool allowEnd = false}) {
    final upper = allowEnd ? length : length - 1;
    if (index < 0 || index > upper) {
      throw PlaylistException(PlaylistFailure.indexOutOfRange, 'index $index is outside a list of $length rows');
    }
    return index;
  }
}

PlaylistPlayMode _playMode(Object? raw) => raw is String
    ? PlaylistPlayMode.values.firstWhere((mode) => mode.name == raw, orElse: () => PlaylistPlayMode.sequential)
    : PlaylistPlayMode.sequential;

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
