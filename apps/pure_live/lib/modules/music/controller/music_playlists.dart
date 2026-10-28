import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_library.dart' show musicTrackFromJson, musicTrackToJson;
import 'package:pure_live/modules/music/controller/music_settings.dart' show musicSettingsProvider;

/// The preference the viewer's own playlists are kept under.
const String kMusicPlaylistsKey = 'music.playlists';

/// How many playlists the module keeps.
const int kMusicPlaylistLimit = 100;

/// One playlist the viewer made: a name and its songs, in order.
@immutable
final class MusicPlaylist {
  /// Creates a playlist.
  const MusicPlaylist({required this.id, required this.name, required this.tracks, required this.createdAt});

  /// Reads a stored playlist; null when the entry is damaged.
  static MusicPlaylist? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final createdAt = (json['createdAt'] as num?)?.toInt();
    if (id is! String || id.isEmpty || name is! String || createdAt == null) return null;
    final entries = json['tracks'];
    return MusicPlaylist(
      id: id,
      name: name,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      tracks: entries is List ? [for (final entry in entries) ?musicTrackFromJson(entry)] : const [],
    );
  }

  /// The playlist's id.
  final String id;

  /// The playlist's name.
  final String name;

  /// Its songs, in play order.
  final List<audio.MusicTrack> tracks;

  /// When it was made.
  final DateTime createdAt;

  /// The stored shape.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'tracks': [for (final track in tracks) musicTrackToJson(track)],
  };

  /// A copy with selected fields replaced.
  MusicPlaylist copyWith({String? name, List<audio.MusicTrack>? tracks}) =>
      MusicPlaylist(id: id, name: name ?? this.name, tracks: tracks ?? this.tracks, createdAt: createdAt);
}

/// The viewer's playlists — lx-music's 我的歌单.
///
/// A playlist is local: it stores enough of each song to draw its row and
/// resolve it again, so a list survives a search that found the song. A song
/// already in a list is not added twice; reordering is a move inside it.
final class MusicPlaylistsController extends Notifier<List<MusicPlaylist>> {
  @override
  List<MusicPlaylist> build() {
    final raw = _read();
    if (raw == null || raw.isEmpty) return const [];
    try {
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      return [for (final entry in json) ?MusicPlaylist.fromJson(entry)];
    } on Object {
      return const [];
    }
  }

  /// The playlist with [id], or null.
  MusicPlaylist? find(String id) {
    for (final playlist in state) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  /// Makes a playlist called [name]; null when the list is full.
  Future<MusicPlaylist?> create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || state.length >= kMusicPlaylistLimit) return null;
    final playlist = MusicPlaylist(
      id: 'pl_${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      tracks: const [],
      createdAt: DateTime.now(),
    );
    state = [...state, playlist];
    await _save();
    return playlist;
  }

  /// Renames a playlist.
  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = [
      for (final playlist in state)
        if (playlist.id == id) playlist.copyWith(name: trimmed) else playlist,
    ];
    await _save();
  }

  /// Deletes a playlist; its songs stay in the library and the queue.
  Future<void> delete(String id) async {
    state = [
      for (final playlist in state)
        if (playlist.id != id) playlist,
    ];
    await _save();
  }

  /// Adds [track] to the playlist; false when it is already there or the
  /// playlist is gone.
  Future<bool> addTrack(String id, audio.MusicTrack track) async {
    final playlist = find(id);
    if (playlist == null || playlist.tracks.contains(track)) return false;
    final tracks = ref.read(musicSettingsProvider).addToTop ? [track, ...playlist.tracks] : [...playlist.tracks, track];
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(tracks: tracks) else item,
    ];
    await _save();
    return true;
  }

  /// Drops [track] from the playlist.
  Future<void> removeTrack(String id, audio.MusicTrack track) async {
    state = [
      for (final playlist in state)
        if (playlist.id == id)
          playlist.copyWith(
            tracks: [
              for (final entry in playlist.tracks)
                if (entry != track) entry,
            ],
          )
        else
          playlist,
    ];
    await _save();
  }

  /// Moves a song inside the playlist.
  Future<void> moveTrack(String id, int from, int to) async {
    final playlist = find(id);
    if (playlist == null || from < 0 || from >= playlist.tracks.length) return;
    final tracks = [...playlist.tracks];
    final track = tracks.removeAt(from);
    tracks.insert(to.clamp(0, tracks.length), track);
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(tracks: tracks) else item,
    ];
    await _save();
  }

  /// Empties a playlist without deleting it.
  Future<void> clear(String id) async {
    state = [
      for (final playlist in state)
        if (playlist.id == id) playlist.copyWith(tracks: const []) else playlist,
    ];
    await _save();
  }

  static String? _read() {
    try {
      return StoragePrefs.getString(kMusicPlaylistsKey);
    } on Object {
      return null;
    }
  }

  Future<void> _save() async {
    try {
      await StoragePrefs.setString(kMusicPlaylistsKey, jsonEncode([for (final playlist in state) playlist.toJson()]));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The viewer's playlists.
final musicPlaylistsProvider = NotifierProvider<MusicPlaylistsController, List<MusicPlaylist>>(
  MusicPlaylistsController.new,
);
