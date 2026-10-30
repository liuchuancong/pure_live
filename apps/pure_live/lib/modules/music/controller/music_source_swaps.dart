import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_library.dart'
    show musicTrackFromJson, musicTrackKey, musicTrackToJson;

/// The preference the manual source swaps are kept under.
const String kMusicSourceSwapsKey = 'music.source.swaps';

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

  /// Remembers [to] as the way to play [from].
  Future<void> set(audio.MusicTrack from, audio.MusicTrack to) async {
    state = {...state, musicTrackKey(from): to};
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
