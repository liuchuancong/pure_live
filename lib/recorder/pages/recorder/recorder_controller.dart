import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:get/get.dart';
import 'dart:developer' as developer;
import 'package:pure_live/core/sites.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pure_live/common/utils/toast_util.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/recorder/consts/recorder_keys.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_manager.dart';
import 'package:pure_live/recorder/services/cache_service.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_scheduler.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_command_builder.dart';
import 'package:pure_live/recorder/services/ffmpeg_header_factory.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';
import 'package:pure_live/recorder/services/video_processor_service.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';

class RecorderController extends GetxService {
  static RecorderController get to => Get.find<RecorderController>();

  final RecordSettingsController settings = Get.find<RecordSettingsController>();

  final FFmpegManager ffmpeg = FFmpegManager.to;

  final FFmpegScheduler scheduler = FFmpegScheduler.instance;

  final RxList<LiveRecordTask> tasks = <LiveRecordTask>[].obs;

  final Map<String, Timer> _pollTimers = {};

  final Map<String, Timer> _retryTimers = {};

  final Set<String> _startingTasks = {};
  // 用于阻塞 _runTask 直到整个流程（录制+处理）结束
  final Map<String, Completer<void>> _lifecycleCompleters = {};

  late final Timer _resourceMonitor;

  int get runningCount => scheduler.runningCount;

  int get queuedCount => scheduler.queuedCount;

  late final StreamSubscription _videoProcessSub;
  @override
  void onInit() {
    super.onInit();

    _initResourceMonitor();

    _initVideoProcessorListener();

    _initFFmpegListener();

    restoreAndAutoPoll();
  }

  void _initResourceMonitor() {
    _resourceMonitor = Timer.periodic(const Duration(seconds: 30), (_) => _checkResources());
  }

  void _initVideoProcessorListener() {
    _videoProcessSub = VideoProcessorService.to.stream.listen((event) {
      final task = tasks.firstWhereOrNull((e) => e.taskId == event.taskId);
      if (task == null) return;
      switch (event.type) {
        case VideoProcessEventType.started:
          task.status = RecordStatus.processing;
          break;
        case VideoProcessEventType.progress:
          break;
        case VideoProcessEventType.completed:
          task.status = RecordStatus.completed;
          break;
        case VideoProcessEventType.failed:
          task.status = RecordStatus.failed;
          break;
      }

      updateTask(task);
    });
  }

  void _initFFmpegListener() {
    ffmpeg.stream.listen(_onFFmpegEvent);
  }

  void _onFFmpegEvent(FFmpegEvent event) {
    final task = tasks.firstWhereOrNull((e) => e.taskId == event.taskId);
    if (task == null) return;
    switch (event.type) {
      case FFmpegEventType.started:
        task.status = RecordStatus.running;
        break;

      case FFmpegEventType.progress:
        final d = event.data;

        task.recordedSeconds = (d['time'] ?? 0) ~/ 1000;

        task.fileSize = d['size'] ?? 0;

        task.bitrate = d['bitrate'] ?? 0.0;

        task.recordSpeed = d['speed'] ?? 0.0;

        task.fps = d['fps'] ?? 0.0;
        break;

      case FFmpegEventType.error:
        _onFail(task);
        break;

      case FFmpegEventType.complete:
        _onComplete(task);
        break;

      default:
        break;
    }

    updateTask(task);
  }

  void updateTask(LiveRecordTask task) {
    final index = tasks.indexWhere((e) => e.taskId == task.taskId);

    if (index == -1) return;

    tasks[index] = task;

    tasks.value = [...tasks.value]
      ..sort((a, b) {
        return a.status.order.compareTo(b.status.order);
      });

    schedulePersist();
  }

  void schedulePersist() {
    _persist();
  }

  Future<void> addTask({required LiveRoom room}) async {
    if (tasks.any((e) => e.roomId == room.roomId && e.platform == room.platform)) {
      return;
    }
    final task = LiveRecordTask.fromRoom(room);
    tasks.insert(0, task);
    tasks.value = [...tasks.value]
      ..sort((a, b) {
        return a.status.order.compareTo(b.status.order);
      });
    schedulePersist();

    if (room.liveStatus == LiveStatus.live) {
      await startTask(task);
    } else {
      task.status = RecordStatus.waitingLive;
      updateTask(task);
      _startPolling(task);
    }
  }

  Future<void> startTask(LiveRecordTask task) async {
    task.retryCount = 0;

    await _startTask(task);
  }

  Future<void> forceStartTask(LiveRecordTask task) async {
    await startTask(task);
  }

  Future<void> _startTask(LiveRecordTask task) async {
    if (_startingTasks.contains(task.taskId)) {
      ToastUtil.show("任务正在启动中，请稍候...");
      return;
    }

    if (scheduler.isRunning(task.taskId) || scheduler.isQueued(task.taskId)) {
      ToastUtil.show("任务已在队列或运行中");
      return;
    }

    _startingTasks.add(task.taskId);

    try {
      _stopPolling(task.taskId);

      task.status = RecordStatus.queued;
      updateTask(task);

      scheduler.enqueue(
        taskId: task.taskId,
        taskRunner: (token) async {
          await _runTask(task, token);
        },
      );
    } catch (e) {
      developer.log('启动任务异常: $e', name: 'RecorderController');
      ToastUtil.show("启动失败: ${e.toString()}");

      task.status = RecordStatus.failed;
      updateTask(task);
    } finally {
      _startingTasks.remove(task.taskId);
    }
  }

  Future<void> _runTask(LiveRecordTask task, TaskCancelToken token) async {
    task.status = RecordStatus.preparing;
    updateTask(task);
    final completer = Completer<void>();
    _lifecycleCompleters[task.taskId] = completer;

    try {
      final url = await StreamResolverService.to.resolveStream(
        roomId: task.roomId,
        platform: task.platform,
        preferredQuality: settings.defaultQuality.value,
      );

      final dir = await CacheService.to.getRoomDir(
        platform: task.platform,
        nick: task.nick,
        usePinyinForFolder: settings.usePinyinForFolder.value,
      );
      final headers = await FFmpegHeaderFactory.build(platform: task.platform);

      final cmd = FFmpegCommandBuilder.buildRecordCommand(
        headers: headers,
        url: url,
        outputDir: dir.path,
        segmentTime: settings.segmentTime.value,
        preferBestStream: settings.preferBestStream.value,
        rwTimeout: settings.rwTimeout.value,
        threadQueueSize: settings.threadQueueSize.value,
      );
      log('Running command: ${cmd.toString()}', name: 'RecorderController');
      task.outputDir = dir.path;
      updateTask(task);

      token.onCancel = () async {
        await ffmpeg.stop(task.taskId);
        // 确保取消时也能解锁
        if (!completer.isCompleted) completer.complete();
      };

      await ffmpeg.start(taskId: task.taskId, command: cmd);
      await completer.future;
    } on StreamException catch (e) {
      developer.log('解析失败: ${e.message}', name: 'RecorderController');
      ToastUtil.show("${task.nick}: ${e.message}");

      if (!e.retryable) {
        task.status = RecordStatus.waitingLive;
        updateTask(task);
        _startPolling(task);
        if (!completer.isCompleted) completer.complete();
        return;
      }
      rethrow;
    } catch (e, s) {
      developer.log('任务运行异常: $e', stackTrace: s, name: 'RecorderController');
      ToastUtil.show("${task.nick} 录制异常: ${e.toString()}");
      _onFail(task);
    } finally {
      _lifecycleCompleters.remove(task.taskId);
      if (!completer.isCompleted) completer.complete();
    }
  }

  Future<void> stopTask(LiveRecordTask task) async {
    _stopPolling(task.taskId);
    _retryTimers[task.taskId]?.cancel();
    _retryTimers.remove(task.taskId);
    await scheduler.cancel(task.taskId);
    if (task.status == RecordStatus.running || task.status == RecordStatus.preparing) {
      log('Stopping task: ${task.taskId}');
    }
  }

  Future<void> _onComplete(LiveRecordTask task) async {
    log('FFmpeg complete => $task.taskId');
    if (task.status == RecordStatus.stopped ||
        task.status == RecordStatus.failed ||
        task.status == RecordStatus.processing) {
      return;
    }

    if (task.outputDir != null && task.recordedSeconds > 0) {
      task.status = RecordStatus.processing;
      updateTask(task);
      try {
        await _processVideo(task);
      } catch (e) {
        task.status = RecordStatus.failed;
        updateTask(task);
      }
    } else {
      task.status = RecordStatus.stopped;
      updateTask(task);
      final completer = _lifecycleCompleters[task.taskId];
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<void> _onFail(LiveRecordTask task) async {
    final completer = _lifecycleCompleters[task.taskId];
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    if (task.status == RecordStatus.stopped) {
      return;
    }

    task.retryCount++;

    if (task.retryCount >= settings.maxRetryCount.value) {
      task.status = RecordStatus.waitingLive;

      updateTask(task);

      _startPolling(task);

      return;
    }

    task.status = RecordStatus.reconnecting;

    updateTask(task);

    _retryTimers[task.taskId]?.cancel();

    _retryTimers[task.taskId] = Timer(Duration(seconds: settings.retryDelay.value), () async {
      if (!tasks.any((e) => e.taskId == task.taskId)) {
        return;
      }

      if (task.status == RecordStatus.stopped) {
        return;
      }

      await _startTask(task);
    });
  }

  Future<void> _processVideo(LiveRecordTask task) async {
    try {
      if (task.outputDir == null) {
        return;
      }
      task.status = RecordStatus.processing;
      updateTask(task);
      await VideoProcessorService.to.convertToMp4(task: task);
      final settingsController = Get.find<RecordSettingsController>();
      await settingsController.refreshCacheSize();
    } catch (e) {
      developer.log("解析视频出错: $e");
    } finally {
      final completer = _lifecycleCompleters[task.taskId];
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    }
  }

  void _startPolling(LiveRecordTask task) {
    if (!settings.enablePolling.value) {
      return;
    }

    if (_pollTimers.containsKey(task.taskId)) {
      return;
    }

    _pollTimers[task.taskId] = Timer.periodic(Duration(seconds: settings.liveCheckInterval.value), (_) async {
      try {
        final room = await Sites.of(task.platform).liveSite.getRoomDetail(roomId: task.roomId, platform: task.platform);

        task.updateFromRoom(room);

        updateTask(task);

        if (room.liveStatus == LiveStatus.live) {
          _stopPolling(task.taskId);

          await startTask(task);
        }
      } catch (_) {}
    });
  }

  void _stopPolling(String taskId) {
    _pollTimers[taskId]?.cancel();

    _pollTimers.remove(taskId);
  }

  Future<void> _checkResources() async {
    try {
      final cacheMB = await CacheService.to.getCacheSize();
      final rssMB = ProcessInfo.currentRss / 1024 / 1024;
      final maxMemoryMB = (Platform.numberOfProcessors * 1024).toDouble();
      developer.log(
        'Cache: ${cacheMB.toStringAsFixed(2)} MB | '
        'Memory: ${rssMB.toStringAsFixed(2)} MB',
        name: 'RecorderController',
      );

      if (cacheMB > settings.maxCacheMB.value && settings.enableCacheLimit.value) {
        await CacheService.to.enforceLimit(maxMB: settings.maxCacheMB.value.toDouble());
      }

      if (rssMB > maxMemoryMB * 0.9) {
        developer.log('Memory usage too high', name: 'RecorderController');
      }
    } catch (e) {
      developer.log('_checkResources error: $e', name: 'RecorderController');
    }
  }

  Future<void> unRecorder(LiveRecordTask task) async {
    _stopPolling(task.taskId);

    _retryTimers[task.taskId]?.cancel();

    _retryTimers.remove(task.taskId);

    await scheduler.cancel(task.taskId);
    await Future.delayed(Duration(seconds: 1));
    final completer = _lifecycleCompleters[task.taskId];
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    tasks.removeWhere((e) => e.taskId == task.taskId);
    tasks.value = [...tasks.value]
      ..sort((a, b) {
        return a.status.order.compareTo(b.status.order);
      });
    schedulePersist();
  }

  Future<void> _persist() async {
    try {
      final json = jsonEncode(tasks.map((e) => e.toJson()).toList());
      await HivePrefUtil.setString(RecorderKeys.recorderTasks, json);
    } catch (_) {}
  }

  Future<void> restoreAndAutoPoll() async {
    try {
      final json = HivePrefUtil.getString(RecorderKeys.recorderTasks);

      if (json == null || json.isEmpty) {
        return;
      }

      final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();

      List<LiveRecordTask> recorderTasks = list.map((e) => LiveRecordTask.fromJson(e)).toList();
      recorderTasks.sort((a, b) => a.status.order.compareTo(b.status.order));
      tasks.value = recorderTasks;
      for (final task in tasks) {
        task.status = RecordStatus.stopped;
        updateTask(task);
      }
      if (settings.autoStartOnBoot.value) {
        for (final task in tasks) {
          await refreshTaskStatus(task);
        }
      }
    } catch (_) {
      tasks.clear();
    }
  }

  Future<void> refreshTaskStatus(LiveRecordTask task) async {
    try {
      final room = await Sites.of(task.platform).liveSite.getRoomDetail(roomId: task.roomId, platform: task.platform);
      task.updateFromRoom(room);
      updateTask(task);
      if (room.liveStatus == LiveStatus.live) {
        await startTask(task);
      } else {
        _startPolling(task);
      }
    } catch (_) {
      _startPolling(task);
    }
  }

  void openFileDir() async {
    final path = settings.recordSavePath.value;

    if (Platform.isWindows) {
      await Process.run('explorer', [path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    } else if (Platform.isAndroid) {
      final uri = Uri.parse('file://$path');

      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void onClose() {
    for (final t in _pollTimers.values) {
      t.cancel();
    }

    for (final t in _retryTimers.values) {
      t.cancel();
    }
    _resourceMonitor.cancel();
    _pollTimers.clear();

    _retryTimers.clear();
    _videoProcessSub.cancel();
    super.onClose();
  }
}
