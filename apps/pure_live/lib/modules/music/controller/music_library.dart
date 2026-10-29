import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;

/// The preference the module's collected songs are kept under.
const String kMusicFavouritesKey = 'music.favourites';

/// The preference the module's recently played songs are kept under.
const String kMusicRecentKey = 'music.recent';

/// How many songs the recent list keeps — lx-music's 试听 is a way back to
/// what was just on, not an archive.
const int kMusicRecentLimit = 100;

/// The identity saved rules, positions and lyric overrides use:
/// `sourceId:id`.
String musicTrackKey(audio.MusicTrack track) => '${track.sourceId}:${track.id}';

/// One song as the module stores it: enough to draw its row, resolve it again
/// and reopen its player without the search that found it.
Map<String, Object?> musicTrackToJson(audio.MusicTrack track) => {
  'id': track.id,
  'sourceId': track.sourceId,
  'title': track.title,
  'artist': track.artist,
  if (track.album.isNotEmpty) 'album': track.album,
  if (track.coverUri != null) 'cover': track.coverUri.toString(),
  if (track.duration != null) 'durationMs': track.duration!.inMilliseconds,
};

/// Reads a stored song; null when the entry is damaged.
audio.MusicTrack? musicTrackFromJson(Object? json) {
  if (json is! Map) return null;
  final id = json['id'];
  final title = json['title'];
  if (id is! String || id.isEmpty || title is! String) return null;
  final cover = json['cover'];
  final durationMs = (json['durationMs'] as num?)?.toInt();
  return audio.MusicTrack(
    id: id,
    sourceId: json['sourceId'] is String ? json['sourceId'] as String : '',
    title: title,
    artist: json['artist'] is String ? json['artist'] as String : '',
    album: json['album'] is String ? json['album'] as String : '',
    coverUri: cover is String ? Uri.tryParse(cover) : null,
    duration: durationMs == null ? null : Duration(milliseconds: durationMs),
  );
}

List<audio.MusicTrack> _readTracks(String key) {
  try {
    final raw = StoragePrefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    final json = jsonDecode(raw);
    if (json is! List) return const [];
    return [for (final entry in json) ?musicTrackFromJson(entry)];
  } on Object {
    return const [];
  }
}

Future<void> _writeTracks(String key, List<audio.MusicTrack> tracks) async {
  try {
    await StoragePrefs.setString(key, jsonEncode([for (final track in tracks) musicTrackToJson(track)]));
  } on Object {
    // A preference; a closed store loses it.
  }
}

/// The songs the viewer collected, newest first — the reference's 收藏.
final class MusicFavouritesController extends Notifier<List<audio.MusicTrack>> {
  @override
  List<audio.MusicTrack> build() => _readTracks(kMusicFavouritesKey);

  /// Whether [track] is collected.
  bool contains(audio.MusicTrack track) => state.contains(track);

  /// Collects [track], or takes it out again; returns whether it is now in.
  Future<bool> toggle(audio.MusicTrack track) async {
    final added = !state.contains(track);
    state = added
        ? [track, ...state]
        : [
            for (final entry in state)
              if (entry != track) entry,
          ];
    await _writeTracks(kMusicFavouritesKey, state);
    return added;
  }

  /// Replaces the whole collection — the sync bridge's overwrite path.
  Future<void> replaceAll(List<audio.MusicTrack> tracks) async {
    state = tracks;
    await _writeTracks(kMusicFavouritesKey, state);
  }

  /// Drops [track] from the collection.
  Future<void> remove(audio.MusicTrack track) async {
    state = [
      for (final entry in state)
        if (entry != track) entry,
    ];
    await _writeTracks(kMusicFavouritesKey, state);
  }
}

/// The module's collected songs.
final musicFavouritesProvider = NotifierProvider<MusicFavouritesController, List<audio.MusicTrack>>(
  MusicFavouritesController.new,
);

/// The songs the viewer played, newest first — the reference's 试听.
final class MusicRecentController extends Notifier<List<audio.MusicTrack>> {
  @override
  List<audio.MusicTrack> build() => _readTracks(kMusicRecentKey);

  /// Moves [track] to the front of the recent list.
  Future<void> record(audio.MusicTrack track) async {
    if (state.isNotEmpty && state.first == track) return;
    state = [
      track,
      for (final entry in state)
        if (entry != track) entry,
    ].take(kMusicRecentLimit).toList();
    await _writeTracks(kMusicRecentKey, state);
  }

  /// Drops one song from the recent list.
  Future<void> remove(audio.MusicTrack track) async {
    state = [
      for (final entry in state)
        if (entry != track) entry,
    ];
    await _writeTracks(kMusicRecentKey, state);
  }

  /// Replaces the whole list — the sync bridge's overwrite path.
  Future<void> replaceAll(List<audio.MusicTrack> tracks) async {
    state = tracks.take(kMusicRecentLimit).toList();
    await _writeTracks(kMusicRecentKey, state);
  }

  /// Drops every song.
  Future<void> clear() async {
    state = const [];
    await _writeTracks(kMusicRecentKey, state);
  }
}

/// The module's recently played songs.
final musicRecentProvider = NotifierProvider<MusicRecentController, List<audio.MusicTrack>>(MusicRecentController.new);
