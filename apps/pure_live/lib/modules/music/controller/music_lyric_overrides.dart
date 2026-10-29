import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_library.dart' show musicTrackKey;

/// The preference the viewer's manual lyric associations are kept under.
const String kMusicLyricOverridesKey = 'music.lyric.overrides';

/// How many songs keep an associated lyric; the oldest falls off first.
const int kMusicLyricOverrideLimit = 200;

/// The reference's 关联歌词: a song pointed at a lyric the viewer chose,
/// instead of the one its source guessed.
///
/// The text is stored per track (`sourceId:id`), so the association survives a
/// restart; the engine is handed the parsed document when the track plays.
final class MusicLyricOverridesController extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    try {
      final raw = StoragePrefs.getString(kMusicLyricOverridesKey);
      if (raw == null || raw.isEmpty) return const <String, String>{};
      final json = jsonDecode(raw);
      if (json is! Map) return const <String, String>{};
      return <String, String>{
        for (final entry in json.entries)
          if (entry.key is String && entry.value is String) entry.key as String: entry.value as String,
      };
    } on Object {
      return const <String, String>{};
    }
  }

  /// Whether [track] has an associated lyric.
  bool contains(audio.MusicTrack track) => state.containsKey(musicTrackKey(track));

  /// [track]'s associated lyric text, when there is one.
  String? textFor(audio.MusicTrack track) => state[musicTrackKey(track)];

  /// Associates [text] with [track].
  Future<void> set(audio.MusicTrack track, String text) async {
    final key = musicTrackKey(track);
    final next = <String, String>{...state}
      ..remove(key)
      ..[key] = text;

    while (next.length > kMusicLyricOverrideLimit) {
      next.remove(next.keys.first);
    }

    state = next;
    await _save(next);
  }

  /// Drops [track]'s association.
  Future<void> remove(audio.MusicTrack track) async {
    final key = musicTrackKey(track);
    if (!state.containsKey(key)) return;
    final next = <String, String>{...state}..remove(key);
    state = next;
    await _save(next);
  }

  /// Drops every association.
  Future<void> clear() async {
    state = const <String, String>{};
    await _save(state);
  }

  Future<void> _save(Map<String, String> overrides) async {
    try {
      await StoragePrefs.setString(kMusicLyricOverridesKey, jsonEncode(overrides));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The viewer's associated lyrics.
final musicLyricOverridesProvider = NotifierProvider<MusicLyricOverridesController, Map<String, String>>(
  MusicLyricOverridesController.new,
);
