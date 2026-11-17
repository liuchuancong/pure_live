import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;
import 'package:pure_live/modules/music/controller/library/music_download_settings.dart'
    show musicDownloadSettingsProvider;
import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceListProvider, resolveWithToggle;
import 'package:pure_live/modules/music/controller/playback/music_playback.dart' show musicQualityOf;
import 'package:pure_live/modules/music/controller/playback/music_playback_settings.dart'
    show musicPlaybackSettingsProvider;
import 'package:pure_live/modules/music/controller/sources/music_source_failure.dart' show noteMusicSourceSilence;

/// The preference the download queue is kept under.
const String kMusicDownloadsKey = 'music.downloads';

/// What an attempt to download a song did.
enum MusicDownloadStart {
  /// A new task joined the queue.
  queued,

  /// The same song, rendition and container is already queued.
  duplicate,

  /// The song has no downloadable source (a local file, or a source this
  /// build does not execute).
  unsupported,

  /// Resolving the song failed; the result's error says why.
  failed,
}

/// The result of asking for a download.
typedef MusicDownloadResult = ({MusicDownloadStart outcome, String? error});

/// The module's download queue: the engine's queue, its tasks kept for the
/// next run, and the post-processing choices the settings carry.
///
/// The queue itself owns transfer, resume and retry; this is the app's seam —
/// it resolves a song through the module's source, applies the viewer's tag
/// and lyric choices, and stores the task list so a restart shows what was
/// queued instead of an empty page.
final class MusicDownloadsController extends Notifier<List<audio.MusicDownloadTask>> {
  late final audio.MusicDownloadQueue _queue;
  StreamSubscription<audio.MusicDownloadTask>? _updates;
  Timer? _persistTimer;

  @override
  List<audio.MusicDownloadTask> build() {
    _queue = audio.MusicDownloadQueue(maxConcurrent: ref.read(musicDownloadSettingsProvider).downloadMaxConcurrent);
    final stored = _readTasks();
    if (stored.isNotEmpty) _queue.restore(stored);
    _updates = _queue.updates.listen((_) {
      if (!ref.mounted) return;
      state = _queue.tasks;
      _persistSoon();
    });
    ref.listen(musicDownloadSettingsProvider.select((settings) => settings.downloadMaxConcurrent), (_, concurrent) {
      unawaited(_queue.setMaxConcurrent(concurrent));
    });
    ref.onDispose(() {
      // The last tick's state lands too: a shutdown inside the persist
      // window must not leave the next run reading stale statuses.
      _persistTimer?.cancel();
      unawaited(_persist());
      unawaited(_updates?.cancel() ?? Future<void>.value());
      unawaited(_queue.dispose());
    });
    return _queue.tasks;
  }

  /// Adds [track] to the queue; [listName] groups it when the viewer asked
  /// for one folder per list. [batchKeys] lets a bulk caller catch two
  /// identical songs inside one concurrent batch: the set carries the keys
  /// already claimed by this call, since the queue only sees a task after
  /// its own resolve finishes.
  Future<MusicDownloadResult> download(audio.MusicTrack track, {String? listName, Set<String>? batchKeys}) async {
    if (track.isLocal) {
      return (outcome: MusicDownloadStart.unsupported, error: null);
    }
    final settings = ref.read(musicDownloadSettingsProvider);
    audio.MusicSource? source;
    for (final candidate in ref.read(musicSourceListProvider)) {
      if (candidate.id == track.sourceId) source = candidate;
    }
    if (source == null) {
      return (outcome: MusicDownloadStart.unsupported, error: null);
    }
    final activeSource = source;
    final quality = musicQualityOf(ref.read(musicPlaybackSettingsProvider).quality);
    final directory = ref.read(appPathsProvider).music.path;
    try {
      final resolved = await resolveWithToggle(
        ref,
        track,
        quality: quality,
        allowAutoToggle: settings.downloadUseOtherSource,
      );
      audio.MusicLyricPayload? lyric;
      if (settings.downloadEmbedLyric || settings.downloadWriteLyric) {
        try {
          lyric = await activeSource.resolveLyric(track);
        } on Object catch (error, stackTrace) {
          // A song without a lyric still downloads; whether the platform
          // answered at all is the part worth keeping.
          noteMusicSourceSilence('${activeSource.id} download lyric', error, stackTrace);
        }
      }
      final request = audio.MusicDownloadRequest.forTrack(
        track: track,
        source: resolved,
        directory: directory,
        pattern: settings.downloadPattern,
        format: settings.downloadType.format,
        quality: quality,
        listName: listName,
        subdirectory: settings.downloadGroupByList ? listName : null,
        coverUrl: track.coverUri?.toString(),
        lyric: lyric,
        embedCover: settings.downloadEmbedCover,
        embedLyric: settings.downloadEmbedLyric,
        writeLyricFile: settings.downloadWriteLyric,
        skipExisting: settings.downloadSkipExisting,
        includeTranslation: settings.downloadIncludeTranslation,
        includeRomanization: settings.downloadIncludeRomanization,
      );
      final existing = _queue.pending.where((task) => task.request.dedupeKey == request.dedupeKey).firstOrNull;
      if (existing != null || (batchKeys != null && !batchKeys.add(request.dedupeKey))) {
        return (outcome: MusicDownloadStart.duplicate, error: null);
      }
      _queue.enqueue(
        request,
        resolve: () async {
          final fresh = await resolveWithToggle(
            ref,
            track,
            quality: quality,
            allowAutoToggle: settings.downloadUseOtherSource,
          );
          return audio.MusicDownloadRequest.forTrack(
            track: track,
            source: fresh,
            directory: directory,
            pattern: settings.downloadPattern,
            format: settings.downloadType.format,
            quality: quality,
            listName: listName,
            subdirectory: settings.downloadGroupByList ? listName : null,
            coverUrl: track.coverUri?.toString(),
            lyric: lyric,
            embedCover: settings.downloadEmbedCover,
            embedLyric: settings.downloadEmbedLyric,
            writeLyricFile: settings.downloadWriteLyric,
            skipExisting: settings.downloadSkipExisting,
            includeTranslation: settings.downloadIncludeTranslation,
            includeRomanization: settings.downloadIncludeRomanization,
          );
        },
      );
      return (outcome: MusicDownloadStart.queued, error: null);
    } on Object catch (failure) {
      appLog.forCategory('music.download').warning('download enqueue failed', fields: {'error': '$failure'});
      return (outcome: MusicDownloadStart.failed, error: '$failure');
    }
  }

  /// Queues every song in [tracks] that can be downloaded; returns how many
  /// new tasks joined.
  ///
  /// The resolves run a few at a time, not one by one: a two-hundred-song
  /// list shows its first rows while the first handful of sources are still
  /// being asked, where a serial loop made every row wait on every
  /// round-trip before it. The queue's own resolver runs only on retries,
  /// so the source of the first attempt is still fetched here — just six
  /// abreast instead of in single file.
  Future<int> downloadAll(Iterable<audio.MusicTrack> tracks, {String? listName}) async {
    const width = 6;
    var queued = 0;
    final list = tracks.toList();
    final batchKeys = <String>{};
    for (var start = 0; start < list.length; start += width) {
      final batch = [
        for (final track in list.skip(start).take(width)) download(track, listName: listName, batchKeys: batchKeys),
      ];
      final results = await Future.wait(batch);
      queued += results.where((result) => result.outcome == MusicDownloadStart.queued).length;
    }
    return queued;
  }

  Future<void> pause(String id) => _run(() => _queue.pause(id));

  Future<void> resume(String id) => _run(() => _queue.resume(id));

  Future<void> retry(String id) => _run(() => _queue.retry(id));

  Future<void> cancel(String id) => _run(() => _queue.cancel(id));

  Future<void> pauseAll() => _run(_queue.pauseAll);

  Future<void> resumeAll() => _run(_queue.resumeAll);

  /// Removes a task row; [deleteFile] also removes its bytes.
  Future<void> remove(String id, {bool deleteFile = false}) => _run(() => _queue.remove(id, deleteFile: deleteFile));

  Future<void> clearFinished() async {
    _queue.clearFinished();
    state = _queue.tasks;
    await _persist();
  }

  Future<void> _run(Future<void> Function() work) async {
    await work();
    if (!ref.mounted) return;
    state = _queue.tasks;
    await _persist();
  }

  void _persistSoon() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 500), () => unawaited(_persist()));
  }

  Future<void> _persist() async {
    try {
      await StoragePrefs.setString(kMusicDownloadsKey, jsonEncode([for (final task in _queue.tasks) task.toJson()]));
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  static List<audio.MusicDownloadTask> _readTasks() {
    try {
      final raw = StoragePrefs.getString(kMusicDownloadsKey);
      if (raw == null || raw.isEmpty) return const [];
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      return [
        for (final entry in json)
          if (entry is Map) audio.MusicDownloadTask.fromJson(entry.cast<String, Object?>()),
      ];
    } on Object {
      return const [];
    }
  }
}

/// The module's download queue.
final musicDownloadsProvider = NotifierProvider<MusicDownloadsController, List<audio.MusicDownloadTask>>(
  MusicDownloadsController.new,
);

/// How many tasks are still moving.
int musicDownloadsActive(List<audio.MusicDownloadTask> tasks) => tasks.where((task) => !task.isTerminal).length;
