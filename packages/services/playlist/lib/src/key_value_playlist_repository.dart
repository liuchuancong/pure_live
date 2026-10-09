// Module: lib/src/key_value_playlist_repository.dart
// Purpose: Bind the playlist repository to one key/value document.
// Author: liuchuancong
// Created: 2026-10-09
//
// docs/content/playlist.md names settings_repository/backup as the eventual store; this is the key/value
// binding the composition root can build today, and the port is what keeps that swap from touching callers.

import 'package:pure_live_storage/pure_live_storage.dart';

import 'playlist.dart';

/// A [PlaylistRepository] held in one [KeyValueStore] key.
final class KeyValuePlaylistRepository implements PlaylistRepository {
  KeyValuePlaylistRepository(this.store, {this.namespace = 'playlists'});

  final KeyValueStore store;
  final String namespace;

  String get _key => namespace;

  @override
  Future<List<Playlist>> all() async {
    final raw = await store.read(_key);
    if (raw == null) {
      return const <Playlist>[];
    }
    // Not a list means somebody or something else wrote this key; rebuilding the document from an "empty"
    // read would delete the user's playlists on the next save, so refuse instead.
    if (raw is! List) {
      throw FormatException('the $namespace document is a ${raw.runtimeType}, not a list', raw);
    }
    return <Playlist>[
      for (final item in raw)
        if (item is Map) Playlist.fromJson(Map<String, Object?>.from(item)),
    ];
  }

  @override
  Future<void> upsert(Playlist playlist) async {
    final next = <Playlist>[
      for (final existing in await all())
        if (existing.id != playlist.id) existing,
      playlist,
    ];
    await _write(next);
  }

  @override
  Future<void> remove(String id) async {
    final next = (await all()).where((playlist) => playlist.id != id).toList(growable: false);
    await _write(next);
  }

  Future<void> _write(List<Playlist> playlists) =>
      store.write(_key, playlists.map((playlist) => playlist.toJson()).toList(growable: false));
}
