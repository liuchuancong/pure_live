import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/library/music_library.dart'
    show musicTrackFromJson, musicTrackKey, musicTrackToJson;

/// The preference the manual source swaps are kept under.
const String kMusicSourceSwapsKey = 'music.source.swaps';

/// How many remembered swaps the shelf keeps, newest first — the module's
/// other shelves cap at the same scale (dislikes 5000, lyric cache 200).
const int kMusicSourceSwapLimit = 200;

/// lx-music's manual 换源 cache: a replacement the viewer picked is remembered
/// per original track, so the next play of that track goes straight to the
/// swapped one instead of failing on its own platform again.
final class MusicSourceSwapsController extends Notifier<Map<String, audio.MusicTrack>> {
  @override
  Map<String, audio.MusicTrack> build() {
    final raw = _read();
    if (raw == null || raw.isEmpty) return const {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const {};
      return {
        for (final entry in json.entries)
          if (entry.value is Map) entry.key as String: ?musicTrackFromJson(entry.value),
      };
    } on Object {
      return const {};
    }
  }

  /// The replacement stored for [track], when one is.
  audio.MusicTrack? swappedOf(audio.MusicTrack track) => state[musicTrackKey(track)];

  /// Remembers [to] as the way to play [from]. The map is capped newest
  /// first like every other shelf of this module: a swap list that grew
  /// forever would be the one unbounded persisted collection.
  Future<void> set(audio.MusicTrack from, audio.MusicTrack to) async {
    final key = musicTrackKey(from);
    final next = {
      key: to,
      for (final entry in state.entries)
        if (entry.key != key) entry.key: entry.value,
    };
    if (next.length > kMusicSourceSwapLimit) {
      state = Map.fromEntries(next.entries.take(kMusicSourceSwapLimit));
    } else {
      state = next;
    }
    await _save();
  }

  /// Forgets every remembered swap — the cache page's clear button.
  Future<void> clear() async {
    state = const {};
    await _save();
  }

  Future<void> _save() async {
    try {
      await StoragePrefs.setString(
        kMusicSourceSwapsKey,
        jsonEncode({for (final entry in state.entries) entry.key: musicTrackToJson(entry.value)}),
      );
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  static String? _read() {
    try {
      return StoragePrefs.getString(kMusicSourceSwapsKey);
    } on Object {
      return null;
    }
  }
}

final musicSourceSwapsProvider = NotifierProvider<MusicSourceSwapsController, Map<String, audio.MusicTrack>>(
  MusicSourceSwapsController.new,
);
