import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_library.dart' show musicTrackKey;

/// The preference the viewer's 不喜欢 rules are kept under.
const String kMusicDislikesKey = 'music.dislikes';

/// How many rules the module keeps; the oldest falls off first.
const int kMusicDislikeLimit = 5000;

/// The reference's 不喜欢规则, reduced to what this module can honour: a song
/// that is disliked is skipped when the queue reaches it, every time, until
/// the rule is removed.
final class MusicDislikesController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    try {
      final raw = StoragePrefs.getString(kMusicDislikesKey);
      if (raw == null || raw.isEmpty) return const <String>{};
      final json = jsonDecode(raw);
      if (json is! List) return const <String>{};
      return <String>{
        for (final entry in json)
          if (entry is String && entry.isNotEmpty) entry,
      };
    } on Object {
      return const <String>{};
    }
  }

  /// Whether [track] is excluded from playback.
  bool contains(audio.MusicTrack track) => state.contains(musicTrackKey(track));

  /// Adds or removes [track]'s rule; the answer is the state after the call.
  Future<bool> toggle(audio.MusicTrack track) async {
    final key = musicTrackKey(track);
    final next = <String>{...state};
    final disliked = !next.remove(key);

    if (disliked) {
      next.add(key);

      while (next.length > kMusicDislikeLimit) {
        next.remove(next.first);
      }
    }

    state = next;
    await _save(next);

    return disliked;
  }

  /// Drops every rule.
  Future<void> clear() async {
    state = const <String>{};
    await _save(state);
  }

  Future<void> _save(Set<String> keys) async {
    try {
      await StoragePrefs.setString(kMusicDislikesKey, jsonEncode(keys.toList()));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The viewer's dislike rules.
final musicDislikesProvider = NotifierProvider<MusicDislikesController, Set<String>>(MusicDislikesController.new);
