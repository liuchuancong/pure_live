import 'dart:io';
import 'dart:async';
import 'dart:developer';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_manager.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';

class VideoProcessorService extends GetxService {
  VideoProcessorService._internal();

  static final VideoProcessorService _instance = VideoProcessorService._internal();

  static VideoProcessorService get to => _instance;

  final FFmpegManager _ffmpeg = FFmpegManager.to;

  final StreamController<VideoProcessEvent> _controller = StreamController<VideoProcessEvent>.broadcast();

  Stream<VideoProcessEvent> get stream => _controller.stream;

  final Map<String, StreamSubscription<FFmpegEvent>> _subscriptions = {};

  final Set<String> _processingTasks = {};

  bool isProcessing(String taskId) {
    return _processingTasks.contains(taskId);
  }

  Future<bool> convertToMp4({required LiveRecordTask task, bool deleteSourceTs = true}) async {
    final taskId = task.taskId;
    if (_processingTasks.contains(taskId)) {
      return false;
    }
    _processingTasks.add(taskId);
    try {
      final tsDir = Directory(task.outputDir ?? '');
      if (!tsDir.existsSync()) {
        _emitFailed(taskId, i18n("video_dir_not_exist"));
        return false;
      }
      final files = tsDir
          .listSync()
          .whereType<File>()
          .where((e) => e.path.endsWith('.ts') && e.lengthSync() > 0)
          .toList();

      files.sort((a, b) => a.path.compareTo(b.path));

      if (files.isEmpty) {
        _emitFailed(taskId, i18n("video_ts_empty"));
        return false;
      } else {
        log('$taskId： ${i18n("video_ts_total", args: {"count": files.length.toString()})}');
      }

      _controller.add(VideoProcessEvent(taskId: taskId, type: VideoProcessEventType.started));

      final listFile = File(p.join(tsDir.path, 'list.txt'));

      final buffer = StringBuffer();

      for (final f in files) {
        buffer.writeln("file '${f.path.replaceAll('\\', '/')}'");
      }

      await listFile.writeAsString(buffer.toString());

      final t = task.createTime;

      final date =
          '${t.year}'
          '${t.month.toString().padLeft(2, '0')}'
          '${t.day.toString().padLeft(2, '0')}_'
          '${t.hour.toString().padLeft(2, '0')}'
          '${t.minute.toString().padLeft(2, '0')}'
          '${t.second.toString().padLeft(2, '0')}';

      final outputPath = p.join(tsDir.path, '$date.mp4');

      final ffmpegTaskId = 'merge_$taskId';

      final command = [
        '-y',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        '"${listFile.path}"',
        '-c',
        'copy',
        '"$outputPath"',
      ].join(' ');

      final completer = Completer<bool>();

      await _subscriptions[ffmpegTaskId]?.cancel();

      _subscriptions[ffmpegTaskId] = _ffmpeg.stream.listen((event) async {
        if (event.taskId != ffmpegTaskId) {
          return;
        }

        switch (event.type) {
          case FFmpegEventType.progress:
            final data = event.data;
            final time = (data['time'] ?? 0).toDouble();
            final duration = task.recordedSeconds <= 0 ? 1 : task.recordedSeconds * 1000;
            final progress = (time / duration).clamp(0.0, 1.0);
            _controller.add(
              VideoProcessEvent(taskId: taskId, type: VideoProcessEventType.progress, progress: progress),
            );
            break;

          case FFmpegEventType.complete:
            _controller.add(
              VideoProcessEvent(taskId: taskId, type: VideoProcessEventType.completed, outputPath: outputPath),
            );

            if (deleteSourceTs) {
              _deleteTsFiles(tsDir, taskId);
            }

            await _subscriptions[ffmpegTaskId]?.cancel();

            _subscriptions.remove(ffmpegTaskId);

            if (!completer.isCompleted) {
              completer.complete(true);
            }

            break;

          case FFmpegEventType.error:
            _emitFailed(taskId, i18n("video_ffmpeg_failed"));

            await _subscriptions[ffmpegTaskId]?.cancel();

            _subscriptions.remove(ffmpegTaskId);

            if (!completer.isCompleted) {
              completer.complete(false);
            }

            break;

          default:
            break;
        }
      });

      await _ffmpeg.start(taskId: ffmpegTaskId, command: command);

      return await completer.future;
    } catch (e) {
      _emitFailed(taskId, e.toString());

      return false;
    } finally {
      _processingTasks.remove(taskId);
    }
  }

  void _deleteTsFiles(Directory dir, String taskId) {
    try {
      if (!dir.existsSync()) {
        return;
      }
      log('$taskId： ${i18n("video_delete_temp_files")}');
      for (final file in dir.listSync()) {
        if (file.path.endsWith('.ts') || file.path.endsWith('list.txt')) {
          file.deleteSync();
        }
      }
    } catch (_) {}
  }

  void _emitFailed(String taskId, String message) {
    _controller.add(VideoProcessEvent(taskId: taskId, type: VideoProcessEventType.failed, error: message));
  }

  @override
  void onClose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
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
