import 'dart:async' show unawaited;
import 'dart:io' show Directory, File, FileSystemEntityType;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_recording_ffmpeg/media_core_recording_ffmpeg.dart' show FfmpegKitExecutor;
import 'package:path/path.dart' as p;

import 'package:pure_live/app/app.dart' show appPathsProvider;

/// How wide a kept cover is: enough for a list row's tile and a grid card,
/// small enough that a page of them decodes without a wait.
const int kRecordingCoverWidth = 320;

/// How far into the take the frame is taken. A live capture opens with the
/// room's own first seconds, which are often a black or a splash frame; five
/// seconds in is the same sample a file manager's preview takes.
const Duration _kCoverSeek = Duration(seconds: 5);

/// How many covers FFmpeg may cut at once. A library of two hundred takes would
/// otherwise start two hundred processes the moment the page opens.
const int _kCoverParallel = 2;

/// How long an unused cover is kept before the folder is swept.
const Duration _kCoverTtl = Duration(days: 30);

/// The covers cut from the takes on disk: file path → the JPEG holding its
/// frame.
///
/// A recording has no poster of its own — the library's tile is a generic video
/// glyph — so the frame is taken from the file itself with the recording
/// backend's own FFmpeg ([FfmpegKitExecutor] from `media_core_recording_ffmpeg`),
/// rather than opening a decoder or shelling out to a second binary. The kept
/// frame is keyed by the take's path *and* its last write, so a take that grew
/// (or was replaced under the same name) loses the stale picture, and a
/// re-joined MP4 is sampled again.
///
/// A take that cannot answer — a file FFmpeg will not open, a process that
/// failed, a path already tried in this run — keeps the row's placeholder and
/// is not asked again until the library is refreshed.
final class RecordingCovers extends Notifier<Map<String, String>> {
  final FfmpegKitExecutor _executor = FfmpegKitExecutor();

  /// Paths whose cover is cached, queued or running.
  final Set<String> _known = {};

  /// Paths tried and answered with nothing; asking again this run would only
  /// fail again.
  final Set<String> _failed = {};

  /// Paths waiting their turn behind [_kCoverParallel] processes.
  final List<String> _queue = [];

  int _running = 0;

  @override
  Map<String, String> build() {
    unawaited(_sweep());
    return const {};
  }

  /// The cover already cut for [filePath], or null while there is none.
  String? pathFor(String filePath) => state[filePath];

  /// Cuts and keeps the frame of [filePath], asking for it whenever a row shows
  /// the take. A repeat ask costs nothing; the first one queues a process.
  void request(String filePath) {
    if (filePath.isEmpty || _known.contains(filePath)) return;
    final file = File(filePath);
    final stamp = _stampOf(file);
    if (stamp == null) return;
    final kept = _coverFile(filePath, stamp);
    if (kept.existsSync()) {
      _known.add(filePath);
      state = {...state, filePath: kept.path};
      return;
    }
    _known.add(filePath);
    _queue.add(filePath);
    _drain();
  }

  /// Forgets what was tried, so a refreshed library asks its takes again — a
  /// file that has since been repaired or finished writing can answer now.
  void resetAttempts() {
    _known.removeAll(_failed);
    _failed.clear();
  }

  /// Starts queued captures while fewer than [_kCoverParallel] are running.
  void _drain() {
    while (_running < _kCoverParallel && _queue.isNotEmpty) {
      final filePath = _queue.removeAt(0);
      _running++;
      unawaited(
        _capture(filePath).whenComplete(() {
          _running--;
          _drain();
        }),
      );
    }
  }

  /// Writes the frame of [filePath] and publishes it, retrying from the head of
  /// the file when the seek found nothing.
  Future<void> _capture(String filePath) async {
    final file = File(filePath);
    final stamp = _stampOf(file);
    if (stamp == null) {
      _failed.add(filePath);
      return;
    }
    final out = _coverFile(filePath, stamp);
    try {
      await _executor.initialize();
      final directory = out.parent;
      if (!directory.existsSync()) await directory.create(recursive: true);
      var written = await _run(filePath, out.path, seek: _kCoverSeek);
      // A take shorter than the seek answers with no frame at all; the head of
      // the file is the honest second sample.
      written = written || await _run(filePath, out.path, seek: Duration.zero);
      if (!written) {
        _failed.add(filePath);
        return;
      }
      state = {...state, filePath: out.path};
    } on Object {
      _failed.add(filePath);
    }
  }

  /// One FFmpeg run: a scaled still at [seek], null picture when it wrote
  /// nothing.
  Future<bool> _run(String filePath, String outPath, {required Duration seek}) async {
    final execution = await _executor.start(
      arguments: [
        '-hide_banner',
        '-loglevel',
        'error',
        '-y',
        '-ss',
        '${seek.inMilliseconds / 1000}',
        '-i',
        filePath,
        '-frames:v',
        '1',
        '-vf',
        'scale=$kRecordingCoverWidth:-2',
        '-q:v',
        '4',
        outPath,
      ],
    );
    await execution.exitCode;
    return File(outPath).existsSync() && File(outPath).lengthSync() > 0;
  }

  /// The kept cover's own path for [filePath] as it stood at [stamp].
  File _coverFile(String filePath, int stamp) {
    final name = '${_slug(p.basenameWithoutExtension(filePath))}-${_hash('$filePath|$stamp')}';
    return File(p.join(_folder().path, '$name.jpg'));
  }

  /// The folder the covers live in, created on first use.
  Directory _folder() {
    final directory = ref.read(appPathsProvider).recordingCovers;
    if (!directory.existsSync()) directory.createSync(recursive: true);
    return directory;
  }

  /// Drops covers older than [_kCoverTtl]: a take deleted from the library
  /// cannot say its own name, so its frame goes by age instead.
  Future<void> _sweep() async {
    try {
      final directory = ref.read(appPathsProvider).recordingCovers;
      if (!directory.existsSync()) return;
      final cut = DateTime.now().subtract(_kCoverTtl);
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || p.extension(entity.path).toLowerCase() != '.jpg') continue;
        final stamp = _stampOf(entity);
        if (stamp == null || DateTime.fromMillisecondsSinceEpoch(stamp).isAfter(cut)) continue;
        try {
          await entity.delete();
        } on Object {
          // A frame the OS still holds costs a little disk, not the page.
        }
      }
    } on Object {
      // A sweep that cannot start — the provider already gone, the folder on a
      // drive that is not mounted — leaves the cache one run bigger.
    }
  }

  /// The file's last write, or null when there is no file to stamp.
  int? _stampOf(File file) {
    try {
      final stat = file.statSync();
      return stat.type == FileSystemEntityType.notFound ? null : stat.modified.millisecondsSinceEpoch;
    } on Object {
      return null;
    }
  }
}

/// The recording library's covers, by take file path.
final recordingCoversProvider = NotifierProvider<RecordingCovers, Map<String, String>>(RecordingCovers.new);

/// A name a cover file can take from a take's own: letters and digits only,
/// short enough to keep the folder readable.
String _slug(String source) {
  final buffer = StringBuffer();
  for (final rune in source.runes) {
    final letter = (rune >= 0x61 && rune <= 0x7a) || (rune >= 0x41 && rune <= 0x5a) || (rune >= 0x30 && rune <= 0x39);
    if (letter || (rune == 0x2d || rune == 0x5f)) buffer.writeCharCode(rune);
    if (buffer.length >= 24) break;
  }
  final slug = buffer.toString();
  return slug.isEmpty ? 'take' : slug;
}

/// FNV-1a over [source], as the suffix that makes a slug name the exact file
/// and stamp it was cut from.
String _hash(String source) {
  var hash = 0x811c9dc5;
  for (final unit in source.codeUnits) {
    hash = (hash ^ unit) * 0x01000193 & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
