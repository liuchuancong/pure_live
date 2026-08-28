import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pure_live/common/index.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_manager.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';

class VideoProcessorService extends GetxService {
  VideoProcessorService._internal();

  static final VideoProcessorService _instance = VideoProcessorService._internal();
  static VideoProcessorService get to => _instance;

  final FFmpegManager _ffmpeg = FFmpegManager.to;
  final StreamController<VideoProcessEvent> _controller = StreamController<VideoProcessEvent>.broadcast();
  final Set<String> _processingTasks = <String>{};
  final Set<String> _cancelledTasks = <String>{};
  final Map<String, String> _ffmpegTaskIds = <String, String>{};

  Stream<VideoProcessEvent> get stream => _controller.stream;

  bool isProcessing(String taskId) => _processingTasks.contains(taskId);

  Future<void> cancel(String taskId) async {
    if (!_processingTasks.contains(taskId)) return;
    _cancelledTasks.add(taskId);
    final ffmpegTaskId = _ffmpegTaskIds[taskId];
    if (ffmpegTaskId != null) await _ffmpeg.stop(ffmpegTaskId);
  }

  Future<bool> convertToMp4({
    required LiveRecordTask task,
    bool deleteSourceTs = true,
    bool allowLegacySegments = false,
  }) async {
    final taskId = task.taskId;
    if (!_processingTasks.add(taskId)) return false;

    StreamSubscription<FFmpegEvent>? subscription;
    File? listFile;
    File? partialFile;
    try {
      final directoryPath = task.outputDir?.trim() ?? '';
      if (directoryPath.isEmpty) {
        _emitFailed(taskId, i18n('video_dir_not_exist'));
        return false;
      }

      final tsDirectory = Directory(directoryPath);
      if (!await tsDirectory.exists()) {
        _emitFailed(taskId, i18n('video_dir_not_exist'));
        return false;
      }

      final legacySegments = <File>[];
      await for (final entity in tsDirectory.list(followLinks: false)) {
        if (entity is! File || p.extension(entity.path).toLowerCase() != '.ts') continue;
        try {
          if (await entity.length() <= 0) continue;
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
        filePrefix: task.recordingFilePrefix,
        allowLegacySegments: allowLegacySegments,
      );
      segments.sort((left, right) => p.basename(left.path).compareTo(p.basename(right.path)));
      if (segments.isEmpty) {
        _emitFailed(taskId, i18n('video_ts_empty'));
        return false;
      }
      var inputBytes = 0;
      for (final segment in segments) {
        try {
          inputBytes += await segment.length();
        } on FileSystemException {
          // FFmpeg will report the concrete input error if a segment vanishes
          // after the stable snapshot.
        }
      }

      log('$taskId: ${i18n("video_ts_total", args: {"count": segments.length.toString()})}');
      _emit(VideoProcessEvent(taskId: taskId, type: VideoProcessEventType.started));

      listFile = File(p.join(tsDirectory.path, '.${task.recordingFilePrefix}.ffconcat'));
      await listFile.writeAsString(
        buildConcatManifest(segments.map((segment) => p.absolute(segment.path))),
        flush: true,
      );

      final outputFile = await _uniqueOutputFile(tsDirectory, task.recordingFilePrefix);
      partialFile = File('${outputFile.path}.partial');
      if (await partialFile.exists()) await partialFile.delete();

      final ffmpegTaskId = 'merge_${taskId}_${task.recordingFilePrefix}';
      _ffmpegTaskIds[taskId] = ffmpegTaskId;
      final terminalEvent = Completer<FFmpegEvent>();
      subscription = _ffmpeg.stream.listen((event) {
        if (event.taskId != ffmpegTaskId) return;
        switch (event.type) {
          case FFmpegEventType.progress:
            final elapsed = (event.data['time'] as num?)?.toDouble() ?? 0;
            final total = task.recordedSeconds <= 0 ? 1.0 : task.recordedSeconds * 1000.0;
            _emit(
              VideoProcessEvent(
                taskId: taskId,
                type: VideoProcessEventType.progress,
                progress: (elapsed / total).clamp(0.0, 1.0),
              ),
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

      await _ffmpeg.start(taskId: ffmpegTaskId, arguments: arguments);
      final event = await terminalEvent.future.timeout(
        mergeTimeout(inputBytes: inputBytes, recordedSeconds: task.recordedSeconds),
      );
      if (_cancelledTasks.contains(taskId) ||
          event.type != FFmpegEventType.complete ||
          !await partialFile.exists() ||
          await partialFile.length() <= 0) {
        _emitFailed(taskId, i18n('video_ffmpeg_failed'));
        return false;
      }

      await partialFile.rename(outputFile.path);
      partialFile = null;
      if (deleteSourceTs) await _deleteFiles(segments, taskId);

      _emit(VideoProcessEvent(taskId: taskId, type: VideoProcessEventType.completed, outputPath: outputFile.path));
      return true;
    } on TimeoutException {
      _emitFailed(taskId, i18n('video_ffmpeg_failed'));
      return false;
    } catch (error, stackTrace) {
      log('Video merge failed for $taskId: $error', stackTrace: stackTrace);
      _emitFailed(taskId, error.toString());
      return false;
    } finally {
      await subscription?.cancel();
      if (listFile != null) {
        try {
          if (await listFile.exists()) await listFile.delete();
        } on FileSystemException {
          // Best-effort temporary manifest cleanup.
        }
      }
      if (partialFile != null) {
        try {
          if (await partialFile.exists()) await partialFile.delete();
        } on FileSystemException {
          // Preserve the original TS segments when partial cleanup fails.
        }
      }
      _processingTasks.remove(taskId);
      _cancelledTasks.remove(taskId);
      _ffmpegTaskIds.remove(taskId);
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
    final prefix = '${filePrefix}_';
    final matching = all.where((file) => p.basename(file.path).startsWith(prefix)).toList(growable: false);
    return matching.isNotEmpty ? matching : (allowLegacySegments ? all : const <File>[]);
  }

  static String buildConcatManifest(Iterable<String> paths) {
    final manifest = StringBuffer('ffconcat version 1.0\n');
    for (final path in paths) {
      manifest.writeln("file '${_escapeConcatPath(path)}'");
    }
    return manifest.toString();
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

  Future<void> _deleteFiles(List<File> files, String taskId) async {
    log('$taskId: ${i18n("video_delete_temp_files")}');
    for (final file in files) {
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Output is already committed; a locked segment can be cleaned later.
      }
    }
  }

  void _emit(VideoProcessEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  void _emitFailed(String taskId, String message) {
    _emit(VideoProcessEvent(taskId: taskId, type: VideoProcessEventType.failed, error: message));
  }

  @override
  void onClose() {
    _controller.close();
    super.onClose();
  }
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
