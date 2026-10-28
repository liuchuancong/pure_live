import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;

/// The preference the local-music folders are kept under.
const String kMusicLocalRootsKey = 'music.local.roots';

/// What the local view holds: the folders, the files they yielded, whether a
/// scan is running and the last failure.
typedef MusicLocalState = ({List<String> roots, List<audio.MusicTrack> tracks, bool loading, String? error});

List<String> _readRoots() {
  try {
    final raw = StoragePrefs.getString(kMusicLocalRootsKey);
    if (raw == null || raw.isEmpty) return const [];
    final json = jsonDecode(raw);
    if (json is! List) return const [];
    return [
      for (final entry in json)
        if (entry is String && entry.trim().isNotEmpty) entry,
    ];
  } on Object {
    return const [];
  }
}

Future<void> _writeRoots(List<String> roots) async {
  try {
    await StoragePrefs.setString(kMusicLocalRootsKey, jsonEncode(roots));
  } on Object {
    // A preference; a closed store loses it.
  }
}

/// The device's own music: the folders the viewer added, scanned into tracks.
///
/// The scan is the engine's [audio.LocalMusicSource], so the local files are
/// ordinary songs in the queue — mixed with streamed ones, with the sidecar
/// `.lrc` read by the same lyric pipeline.
final class MusicLocalController extends Notifier<MusicLocalState> {
  int _generation = 0;

  @override
  MusicLocalState build() {
    final roots = _readRoots();
    // Deferred: the scan writes state, and build has not returned yet.
    if (roots.isNotEmpty) unawaited(Future<void>.microtask(() => _scan(roots)));
    return (roots: roots, tracks: const <audio.MusicTrack>[], loading: roots.isNotEmpty, error: null);
  }

  /// Adds a folder to the library and scans it.
  Future<void> addRoot(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty || state.roots.contains(normalized)) return;
    final roots = [...state.roots, normalized];
    state = (roots: roots, tracks: state.tracks, loading: true, error: null);
    await _writeRoots(roots);
    await _scan(roots);
  }

  /// Drops a folder and rescans what is left.
  Future<void> removeRoot(String path) async {
    final roots = [
      for (final root in state.roots)
        if (root != path) root,
    ];
    state = (roots: roots, tracks: state.tracks, loading: true, error: null);
    await _writeRoots(roots);
    await _scan(roots);
  }

  /// Scans the current folders again.
  Future<void> rescan() => _scan(state.roots);

  Future<void> _scan(List<String> roots) async {
    final generation = ++_generation;
    if (roots.isEmpty) {
      if (!ref.mounted) return;
      state = (roots: const [], tracks: const [], loading: false, error: null);
      return;
    }
    state = (roots: roots, tracks: state.tracks, loading: true, error: null);
    try {
      final tracks = await audio.LocalMusicSource(roots: roots).listTracks();
      if (!ref.mounted || generation != _generation) return;
      state = (roots: roots, tracks: tracks, loading: false, error: null);
    } on Object catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = (roots: roots, tracks: state.tracks, loading: false, error: '$failure');
    }
  }
}

/// The device's own music folders and tracks.
final musicLocalProvider = NotifierProvider<MusicLocalController, MusicLocalState>(MusicLocalController.new);

/// Reads a track's embedded cover; the roots are irrelevant because
/// [audio.LocalMusicSource.coverOf] opens the track's own file.
final audio.LocalMusicSource _coverSource = audio.LocalMusicSource(roots: const <String>[]);

/// A local file's embedded cover, read when a row asks for it.
///
/// Kept as a family so a song's cover is read once per session no matter how
/// often the list rebuilds, and skipped entirely for the streamed tracks that
/// carry a cover URI instead.
final FutureProviderFamily<Uint8List?, audio.MusicTrack> musicLocalCoverProvider =
    FutureProvider.family<Uint8List?, audio.MusicTrack>((ref, track) async {
      if (!track.isLocal) return null;
      try {
        return (await _coverSource.coverOf(track))?.bytes;
      } on Object {
        return null;
      }
    });
