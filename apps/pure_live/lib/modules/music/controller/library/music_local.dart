import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:path/path.dart' as p;

import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;
import 'package:pure_live/modules/music/controller/music_downloads.dart' show musicDownloadsProvider;

/// The preference the local-music folders are kept under.
const String kMusicLocalRootsKey = 'music.local.roots';

/// What the local view holds: the folder the app downloads into, the folders the
/// viewer added, the files they yielded, whether a scan is running and the last
/// failure.
typedef MusicLocalState = ({
  String downloadRoot,
  List<String> roots,
  List<audio.MusicTrack> tracks,
  bool loading,
  String? error,
});

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

/// The files the queue has settled, as one stable string. The queue republishes
/// on every progress tick, so a listener on the list itself would rescan the
/// library a dozen times a minute; what decides whether the library has anything
/// new to read is this set — a download landing adds a path, a file deleted from
/// the queue takes one away.
String _settledPaths(List<audio.MusicDownloadTask> tasks) {
  final paths = [
    for (final task in tasks)
      if (task.status == audio.MusicDownloadStatus.completed || task.status == audio.MusicDownloadStatus.skipped)
        task.outputPath,
  ]..sort();
  return paths.join('|');
}

/// The device's own music: the folder the app downloads into, the folders the
/// viewer added, and the files they hold.
///
/// The scan is the engine's [audio.LocalMusicSource], so the local files are
/// ordinary songs in the queue — mixed with streamed ones, with the sidecar
/// `.lrc` read by the same lyric pipeline.
///
/// The download folder is a root whether or not anyone added it: a song the
/// viewer downloaded is a file on their device, and until now it sat outside the
/// library until they pointed at the same folder by hand. It is not a choice, so
/// it is not stored in [kMusicLocalRootsKey] and offers no way to be dropped —
/// and moving the download folder in settings moves the root with it, because
/// this reads it from the storage layout rather than remembering a path.
final class MusicLocalController extends Notifier<MusicLocalState> {
  int _generation = 0;

  @override
  MusicLocalState build() {
    final downloadRoot = ref.watch(appPathsProvider).music.path;
    final roots = _readRoots();
    ref.listen(musicDownloadsProvider, (previous, next) {
      if (_settledPaths(previous ?? const []) == _settledPaths(next)) return;
      // The current state, not the roots captured here: a folder added after
      // this build belongs to the next scan.
      unawaited(_scan(state.downloadRoot, state.roots));
    });
    final folders = _folders(downloadRoot, roots);
    // Deferred: the scan writes state, and build has not returned yet.
    if (folders.isNotEmpty) unawaited(Future<void>.microtask(() => _scan(downloadRoot, roots)));
    return (
      downloadRoot: downloadRoot,
      roots: roots,
      tracks: const <audio.MusicTrack>[],
      loading: folders.isNotEmpty,
      error: null,
    );
  }

  /// Adds a folder to the library and scans it.
  Future<void> addRoot(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty || state.roots.contains(normalized)) return;
    final roots = [...state.roots, normalized];
    state = (downloadRoot: state.downloadRoot, roots: roots, tracks: state.tracks, loading: true, error: null);
    await _writeRoots(roots);
    await _scan(state.downloadRoot, roots);
  }

  /// Drops a folder and rescans what is left.
  Future<void> removeRoot(String path) async {
    final roots = [
      for (final root in state.roots)
        if (root != path) root,
    ];
    state = (downloadRoot: state.downloadRoot, roots: roots, tracks: state.tracks, loading: true, error: null);
    await _writeRoots(roots);
    await _scan(state.downloadRoot, roots);
  }

  /// Scans the current folders again.
  Future<void> rescan() => _scan(state.downloadRoot, state.roots);

  /// The folders a scan reads: the download folder first, then what the viewer
  /// added. One place named twice — the download folder added by hand, or a
  /// parent of it — is read once, because the same file arriving under two root
  /// paths is two rows for one song.
  static List<String> _folders(String downloadRoot, List<String> roots) {
    final out = <String, String>{};
    for (final path in [downloadRoot, ...roots]) {
      final trimmed = path.trim();
      if (trimmed.isEmpty) continue;
      out.putIfAbsent(p.canonicalize(trimmed), () => trimmed);
    }
    return out.values.toList();
  }

  Future<void> _scan(String downloadRoot, List<String> roots) async {
    final generation = ++_generation;
    final folders = _folders(downloadRoot, roots);
    if (folders.isEmpty) {
      if (!ref.mounted) return;
      state = (downloadRoot: downloadRoot, roots: roots, tracks: const [], loading: false, error: null);
      return;
    }
    state = (downloadRoot: downloadRoot, roots: roots, tracks: state.tracks, loading: true, error: null);
    try {
      final found = await audio.LocalMusicSource(roots: folders).listTracks();
      if (!ref.mounted || generation != _generation) return;
      // One file, one row: a root nested inside another yields the same path
      // twice, and a list that counts a song twice tells the viewer nothing new.
      final tracks = <audio.MusicTrack>[];
      final seen = <String>{};
      for (final track in found) {
        final path = track.localPath;
        if (path != null && !seen.add(p.canonicalize(path))) continue;
        tracks.add(track);
      }
      state = (downloadRoot: downloadRoot, roots: roots, tracks: tracks, loading: false, error: null);
    } on Object catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = (downloadRoot: downloadRoot, roots: roots, tracks: state.tracks, loading: false, error: '$failure');
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
