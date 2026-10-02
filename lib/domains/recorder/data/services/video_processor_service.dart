import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_manager.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/domains/recorder/domain/models/live_record_task.dart';
import 'package:pure_live/domains/recorder/data/services/cache_service.dart';
import 'package:pure_live/domains/recorder/data/services/recording_segment_clock.dart';

class VideoProcessorService extends GetxService {
  VideoProcessorService._internal() : _ffmpeg = FFmpegManager.to, _completionTimeoutOverride = null;

  @visibleForTesting
  VideoProcessorService.forTesting({required this._ffmpeg, Duration? completionTimeout})
    : _completionTimeoutOverride = completionTimeout;

  static final VideoProcessorService _instance = VideoProcessorService._internal();
  static VideoProcessorService get to => _instance;

  final FFmpegManager _ffmpeg;
  final Duration? _completionTimeoutOverride;
  final StreamController<VideoProcessEvent> _controller = StreamController<VideoProcessEvent>.broadcast();
  final Map<String, _MergeOperation> _operations = {};

  Stream<VideoProcessEvent> get stream => _controller.stream;

  bool isProcessing(String taskId) => _operations.containsKey(taskId);

  Future<void> cancel(String taskId) async {
    final operation = _operations[taskId];
    if (operation == null || operation.commitStarted) return;
    operation.cancelled = true;
    await _stopNative(operation);
  }

  Future<void> _stopNative(_MergeOperation operation) async {
    final id = operation.nativeTaskId;
    if (id == null || operation.nativeEnded || !_ffmpeg.isRunning(id)) return;
    final existing = operation.stopRequest;
    if (existing != null) return existing;
    // Publish ownership before invoking native code: stop may synchronously
    // emit startAck/terminal events and re-enter this path. A completed stop
    // acknowledgement is not a completed writer, so retain it until disposal.
    final stopped = Completer<void>();
    operation.stopRequest = stopped.future;
    try {
      await _ffmpeg.stop(id);
    } catch (error, stackTrace) {
      log('Video merge stop request failed', error: error, stackTrace: stackTrace);
    } finally {
      stopped.complete();
    }
  }

  Future<bool> convertToMp4({
    required LiveRecordTask task,
    bool deleteSourceTs = true,
    bool allowLegacySegments = false,
    String? directoryPath,
    String? filePrefix,
  }) async {
    final taskId = task.taskId;
    if (_operations.containsKey(taskId)) return false;
    final operation = _MergeOperation();
    _operations[taskId] = operation;

    StreamSubscription<FFmpegEvent>? subscription;
    File? listFile;
    File? partialFile;
    File? clockJournal;
    Future<void>? execution;
    CacheService? directoryOwner;
    String? protectedDirectory;

    Future<void> cleanup() async {
      await subscription?.cancel();
      for (final file in [listFile, partialFile]) {
        if (file == null) continue;
        try {
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // Never delete the source segments on failed/cancelled finalization.
        }
      }
      if (protectedDirectory != null) directoryOwner?.releaseDirectory(protectedDirectory);
      if (identical(_operations[taskId], operation)) _operations.remove(taskId);
    }

    try {
      final resolvedDirectoryPath = directoryPath?.trim().isNotEmpty == true
          ? directoryPath!.trim()
          : (task.outputDir?.trim() ?? '');
      final resolvedFilePrefix = filePrefix?.trim().isNotEmpty == true ? filePrefix!.trim() : task.recordingFilePrefix;
      if (resolvedDirectoryPath.isEmpty) {
        _emitFailed(taskId, i18n('video_dir_not_exist'));
        return false;
      }

      // The capture can log packet damage yet return zero on manual stop.
      // Stream-copy remux does not decode that bitstream and can also return
      // zero. Preserve the exact attempt instead of committing/deleting it.
      // Check persisted provenance here as well as in controller flows, so
      // interrupted recovery and direct conversion obey the same contract.
      if (task.pendingAttempts.any(
        (attempt) =>
            p.equals(p.absolute(attempt.directoryPath), p.absolute(resolvedDirectoryPath)) &&
            attempt.filePrefix == resolvedFilePrefix &&
            attempt.inputIntegrityError,
      )) {
        _emitFailed(taskId, i18n('recorder_input_integrity_failed'));
        return false;
      }

      // Own a separate cache lease: the recorder's outer lifecycle may finish
      // before a native writer acknowledges timeout cancellation.
      if (Get.isRegistered<CacheService>()) {
        directoryOwner = CacheService.to;
        protectedDirectory = resolvedDirectoryPath;
        directoryOwner.protectDirectory(resolvedDirectoryPath);
      }

      final tsDirectory = Directory(resolvedDirectoryPath);
      if (!await tsDirectory.exists()) {
        _emitFailed(taskId, i18n('video_dir_not_exist'));
        return false;
      }
      if (operation.cancelled) return false;

      final legacySegments = <File>[];
      await for (final entity in tsDirectory.list(followLinks: false)) {
        if (entity is! File || p.extension(entity.path).toLowerCase() != '.ts') continue;
        try {
          // An empty clock-v1 tail is still evidence of an unfinished attempt.
          // Keep it in the snapshot so journal validation cannot silently drop it.
          if (await entity.length() <= 0 && !entity.path.toLowerCase().endsWith(RecordingSegmentClock.segmentSuffix)) {
            continue;
          }
          legacySegments.add(entity);
        } on FileSystemException {
          // Segment rotation can race with the directory snapshot.
        }
      }
      // Schema-v1 recordings used strftime names without an attempt prefix.
      // Prefer the exact v2 attempt, but retain a recovery path for an
      // interrupted recording created by an older installed version.
      final segments = selectAttemptSegments(
        candidates: legacySegments,
        filePrefix: resolvedFilePrefix,
        allowLegacySegments: allowLegacySegments,
      );
      segments.sort((left, right) => p.basename(left.path).compareTo(p.basename(right.path)));
      if (segments.isEmpty) {
        _emitFailed(taskId, i18n('video_ts_empty'));
        return false;
      }
      final journal = File(p.join(tsDirectory.path, RecordingSegmentClock.journalName(resolvedFilePrefix)));
      final usesClock =
          segments.any((file) => file.path.toLowerCase().endsWith(RecordingSegmentClock.segmentSuffix)) ||
          await journal.exists();
      String manifest;
      // Retry storms after a streamer's broadcast ends can leave zero-byte
      // or half-flushed segments behind; they must not sink the whole merge.
      // Dropping them keeps the recorded material playable.
      final validSegments = <File>[];
      for (final segment in segments) {
        try {
          if (await segment.length() > 0) validSegments.add(segment);
        } on FileSystemException {
          // Vanished after the snapshot: FFmpeg reports it if it matters.
        }
      }

      if (validSegments.isEmpty) {
        log('Merge skipped for $taskId: every segment is empty');
        _emitFailed(taskId, i18n('recorder_no_valid_segments'));
        return false;
      }

      if (usesClock) {
        try {
          // A missing/partial/foreign journal and a mixed old/new TS snapshot
          // all fail before native IO. Never infer a duration or drop a tail.
          for (final segment in validSegments) {
            if (await segment.length() <= 0) throw const FormatException('Recording clock empty segment');
          }
          final clock = await RecordingSegmentClock.read(journal, prefix: resolvedFilePrefix, segments: validSegments);
          manifest = clock.toConcatManifest();
          clockJournal = journal;
        } on FileSystemException {
          _emitFailed(taskId, i18n('recorder_segment_clock_failed'));
          return false;
        } on FormatException catch (error) {
          log('Recording clock validation failed for $taskId: ${error.message}');
          _emitFailed(taskId, i18n('recorder_segment_clock_failed'));
          return false;
        }
      } else {
        // Legacy timestamps already contain per-child normalization. Applying
        // the new zero-inpoint contract would shift those old recordings again.
        manifest = buildConcatManifest(validSegments.map((segment) => p.absolute(segment.path)));
      }
      var inputBytes = 0;
      for (final segment in validSegments) {
        try {
          inputBytes += await segment.length();
        } on FileSystemException {
          // FFmpeg will report the concrete input error if a segment vanishes
          // after the stable snapshot.
        }
      }
      if (operation.cancelled) return false;

      log('$taskId: ${i18n("video_ts_total", args: {"count": validSegments.length.toString()})}');
      _emit(VideoProcessEvent(taskId: taskId, type: VideoProcessEventType.started));

      listFile = File(p.join(tsDirectory.path, '.$resolvedFilePrefix.ffconcat'));
      await listFile.writeAsString(manifest, flush: true);
      if (operation.cancelled) return false;

      final outputFile = await _uniqueOutputFile(tsDirectory, resolvedFilePrefix);
      partialFile = File('${outputFile.path}.partial');
      if (await partialFile.exists()) await partialFile.delete();
      if (operation.cancelled) return false;

      final ffmpegTaskId = 'merge_${taskId}_$resolvedFilePrefix';
      operation.nativeTaskId = ffmpegTaskId;
      final terminalEvent = Completer<FFmpegEvent>();
      subscription = _ffmpeg.stream.listen((event) {
        if (event.taskId != ffmpegTaskId) return;
        switch (event.type) {
          case FFmpegEventType.startAck:
            // Initialization can finish after cancel/timeout. Keep this
            // listener until native teardown so a late start is also stopped.
            if (operation.cancelled) unawaited(_stopNative(operation));
            break;
          case FFmpegEventType.progress:
            if (operation.cancelled || operation.commitStarted) break;
            final progress = mergeProgress(
              elapsedMilliseconds: (event.data['time'] as num?) ?? 0,
              recordedSeconds: task.recordedSeconds,
              outputBytes: (event.data['size'] as num?) ?? 0,
              inputBytes: inputBytes,
            );
            if (progress > operation.progress) operation.progress = progress;
            _emit(
              VideoProcessEvent(taskId: taskId, type: VideoProcessEventType.progress, progress: operation.progress),
            );
            break;
          case FFmpegEventType.complete:
          case FFmpegEventType.error:
            if (!terminalEvent.isCompleted) terminalEvent.complete(event);
            break;
          default:
            break;
        }
      });

      final arguments = <String>[
        '-y',
        '-hide_banner',
        '-loglevel',
        'warning',
        // Fail on demux/mux errors before atomic MP4 commit/source deletion.
        // FFmpegService also latches error diagnostics: some native versions
        // return zero even with -xerror. Neither check is full codec decoding.
        '-xerror',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        listFile.path,
        '-map',
        '0:v?',
        '-map',
        '0:a?',
        '-c',
        'copy',
        '-movflags',
        '+faststart',
        '-f',
        'mp4',
        partialFile.path,
      ];

      execution = _ffmpeg.start(taskId: ffmpegTaskId, arguments: arguments).whenComplete(() {
        operation.nativeEnded = true;
      });
      // start() resolves after executeAsync finishes, not when startAck fires.
      // The deadline covers that Future AND the terminal event, not just a
      // terminal event that is normally already buffered after start returns.
      final event = await execution
          .then((_) => terminalEvent.future)
          .timeout(
            _completionTimeoutOverride ?? mergeTimeout(inputBytes: inputBytes, recordedSeconds: task.recordedSeconds),
          );
      if (operation.cancelled ||
          event.type != FFmpegEventType.complete ||
          !await partialFile.exists() ||
          await partialFile.length() <= 0) {
        _emitFailed(taskId, i18n('video_ffmpeg_failed'));
        return false;
      }

      // File inspection above yields to cancellation. The rename is the
      // commit point; recheck immediately before it, then finish atomically.
      if (operation.cancelled) return false;
      operation.commitStarted = true;
      await partialFile.rename(outputFile.path);
      partialFile = null;
      if (deleteSourceTs) {
        final removedAllSegments = await _deleteFiles(segments, taskId);
        // Retain metadata too if a locked TS remains, enabling exact recovery.
        if (clockJournal != null && removedAllSegments) {
          await _deleteFiles([clockJournal], taskId);
        }
      }

      _emit(
        VideoProcessEvent(
          taskId: taskId,
          type: VideoProcessEventType.completed,
          progress: 1,
          outputPath: outputFile.path,
        ),
      );
      return true;
    } on TimeoutException {
      operation.cancelled = true;
      _emitFailed(taskId, i18n('video_ffmpeg_failed'));
      return false;
    } catch (error, stackTrace) {
      log('Video merge failed for $taskId: $error', stackTrace: stackTrace);
      _emitFailed(taskId, error.toString());
      return false;
    } finally {
      if (execution != null && !operation.nativeEnded) {
        operation.cancelled = true;
        await _stopNative(operation);
      }
      if (execution != null && !operation.nativeEnded) {
        // A timed-out stop is not a stopped writer. Retain its file ownership,
        // listener and task exclusion until the actual execution settles. The
        // caller receives failure promptly; retries do not race the old writer.
        unawaited(
          execution
              .then<void>(
                (_) {},
                onError: (Object error, StackTrace stack) {
                  log('Cancelled video merge settled with an error', error: error, stackTrace: stack);
                },
              )
              .whenComplete(cleanup),
        );
      } else {
        await cleanup();
      }
    }
  }

  Future<File> _uniqueOutputFile(Directory directory, String prefix) async {
    var candidate = File(p.join(directory.path, '$prefix.mp4'));
    var suffix = 1;
    while (await candidate.exists() || await File('${candidate.path}.partial').exists()) {
      candidate = File(p.join(directory.path, '$prefix-$suffix.mp4'));
      suffix++;
    }
    return candidate;
  }

  static String _escapeConcatPath(String value) => value.replaceAll('\\', '/').replaceAll("'", r"'\''");

  /// Keeps retries isolated: an attempt may merge only its own prefixed TS
  /// files. Legacy strftime segments are admitted solely during explicit
  /// process-crash migration, never as a fallback for a fresh failed attempt.
  static List<File> selectAttemptSegments({
    required Iterable<File> candidates,
    required String filePrefix,
    bool allowLegacySegments = false,
  }) {
    final all = candidates.toList(growable: false);
    final matcher = RegExp('^${RegExp.escape(filePrefix)}_\\d{6,}(?:\\.clock-v1)?\\.ts\$', caseSensitive: false);
    final matching = all.where((file) => matcher.hasMatch(p.basename(file.path))).toList(growable: false);
    if (matching.isNotEmpty) return matching;
    // Explicit strftime migration must not borrow another clock-v1 attempt.
    return allowLegacySegments
        ? all.where((file) => !file.path.toLowerCase().endsWith(RecordingSegmentClock.segmentSuffix)).toList()
        : const <File>[];
  }

  static String buildConcatManifest(Iterable<String> paths) {
    final manifest = StringBuffer('ffconcat version 1.0\n');
    for (final path in paths) {
      manifest.writeln("file '${_escapeConcatPath(path)}'");
    }
    return manifest.toString();
  }

  /// Copy-remux statistics can carry an AV_NOPTS-like timestamp. Prefer
  /// actual output-byte progress; use media time only within a plausible
  /// duration. Only the successful file commit emits 100 percent.
  @visibleForTesting
  static double mergeProgress({
    required num elapsedMilliseconds,
    required int recordedSeconds,
    required num outputBytes,
    required int inputBytes,
  }) {
    double progress = 0;
    if (inputBytes > 0 && outputBytes.isFinite && outputBytes > 0 && outputBytes <= inputBytes * 2) {
      progress = outputBytes / inputBytes;
    } else if (recordedSeconds > 0 &&
        elapsedMilliseconds.isFinite &&
        elapsedMilliseconds > 0 &&
        elapsedMilliseconds <= recordedSeconds * 1000 + 15000) {
      progress = elapsedMilliseconds / (recordedSeconds * 1000);
    }
    return progress.clamp(0.0, 0.99).toDouble();
  }

  /// Copy-remux speed varies substantially with external storage, encryption
  /// and file count. A fixed five-second timeout marked healthy long recordings
  /// as failed and cancelled their MP4 finalization. Keep a conservative floor
  /// and scale with both media size and duration while retaining a hard cap.
  @visibleForTesting
  static Duration mergeTimeout({required int inputBytes, required int recordedSeconds}) {
    const bytesPerSecondFloor = 8 * 1024 * 1024;
    final bySize = (inputBytes.clamp(0, 1 << 62) / bytesPerSecondFloor).ceil() + 20;
    final byDuration = (recordedSeconds.clamp(0, 86400 * 30) / 20).ceil() + 20;
    final timeoutSeconds = [
      30,
      bySize,
      byDuration,
    ].reduce((left, right) => left > right ? left : right).clamp(30, 3600).toInt();
    return Duration(seconds: timeoutSeconds);
  }

  Future<bool> _deleteFiles(List<File> files, String taskId) async {
    log('$taskId: ${i18n("video_delete_temp_files")}');
    var removedAll = true;
    for (final file in files) {
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Output is already committed; a locked segment can be cleaned later.
        removedAll = false;
      }
    }
    return removedAll;
  }

  void _emit(VideoProcessEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  void _emitFailed(String taskId, String message) {
    _emit(VideoProcessEvent(taskId: taskId, type: VideoProcessEventType.failed, error: message));
  }

  @override
  void onClose() {
    for (final operation in _operations.values) {
      operation.cancelled = true;
      unawaited(_stopNative(operation));
    }
    _controller.close();
    super.onClose();
  }
}

class _MergeOperation {
  bool cancelled = false;
  bool commitStarted = false;
  bool nativeEnded = false;
  double progress = 0;
  String? nativeTaskId;
  Future<void>? stopRequest;
}

class VideoProcessEvent {
  final String taskId;
  final VideoProcessEventType type;
  final double progress;
  final String? outputPath;
  final String? error;

  const VideoProcessEvent({required this.taskId, required this.type, this.progress = 0, this.outputPath, this.error});
}

enum VideoProcessEventType { started, progress, completed, failed }
