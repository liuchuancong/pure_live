import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:get/get.dart';
import 'dart:developer' as developer;
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/recorder/consts/recorder_keys.dart';
import 'package:pure_live/recorder/consts/recorder_config.dart';
import 'package:pure_live/recorder/services/cache_service.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/services/ffmpeg_service.dart';
import 'package:pure_live/recorder/services/ffmpeg_header_factory.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';
import 'package:pure_live/recorder/services/video_processor_service.dart';
import 'package:pure_live/recorder/pages/record_history/record_history_service.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';

class RecorderController extends GetxService {
  final RecordSettingsController settings = Get.find<RecordSettingsController>();

  final tasks = <LiveRecordTask>[].obs;
  final Queue<LiveRecordTask> queue = Queue();
  final Map<String, Timer> _pollTimers = {};
  final Set<String> _startingTasks = {};

  int get runningTasks => tasks.where((e) => e.status == RecordStatus.running).length;

  @override
  void onInit() {
    super.onInit();
    restoreAndAutoPoll();
  }

  // =========================
  // 🔥 关键：统一更新入口（核心修复）
  // =========================
  void updateTask(LiveRecordTask task) {
    final index = tasks.indexWhere((e) => e.taskId == task.taskId);
    if (index == -1) return;

    tasks[index] = task; // 替换对象
    tasks.assignAll(List<LiveRecordTask>.from(tasks));
  }

  // =========================
  // 执行任务
  // =========================
  Future<void> _runTask(LiveRecordTask task) async {
    try {
      task.status = RecordStatus.preparing;
      updateTask(task);

      final url = await StreamResolverService.to.resolveStream(
        roomId: task.roomId,
        platform: task.platform,
        preferredQuality: RecorderConfig.defaultQuality,
      );

      final dir = await CacheService.to.getRoomDir(platform: task.platform, nick: task.nick);

      task.outputDir = dir.path;
      task.retryCount = 0;
      task.status = RecordStatus.running;
      updateTask(task);

      final headers = await FFmpegHeaderFactory.build(platform: task.platform);
      developer.log(headers.toString());
      task.selectedQuality = settings.defaultQuality.value;

      await FFmpegService.to.startRecord(
        taskId: task.taskId,
        url: url,
        outputDir: dir.path,
        headers: headers,
        segmentTime: settings.segmentTime.value,

        onProgress: (record) {
          task.recordedSeconds = record.recordedSeconds;
          task.fileSize = record.fileSize;
          task.recordSpeed = record.speed;
          task.bitrate = record.bitrate;
          task.fps = record.fps;
          task.lastUpdate = DateTime.now();
          updateTask(task);
        },

        onError: (err) async {
          final session = FFmpegService.to.getSession(task.taskId);
          if (session?.manualStop ?? false) return;
          await _onFail(task);
        },

        onComplete: () async {
          final session = FFmpegService.to.getSession(task.taskId);
          if (session?.manualStop ?? false) return;
          await _onComplete(task);
        },
      );
    } catch (_) {
      if (task.status != RecordStatus.stopped) {
        await _onFail(task);
      }
    }
  }

  // =========================
  // 失败处理
  // =========================
  Future<void> _onFail(LiveRecordTask task) async {
    await FFmpegService.to.stopRecord(task.taskId);

    task.retryCount++;

    if (task.retryCount >= settings.maxRetryCount.value) {
      task.status = RecordStatus.idle;
      updateTask(task);
      _startPolling(task);
      _next();
      return;
    }

    task.status = RecordStatus.reconnecting;
    updateTask(task);

    await Future.delayed(Duration(seconds: settings.retryDelay.value));

    if (task.status == RecordStatus.stopped) return;

    try {
      StreamResolverService.to.invalidate(task.roomId);
      await _runTask(task);
    } catch (_) {
      _startPolling(task);
    }
  }

  // =========================
  // 添加任务
  // =========================
  Future<void> addTask({required LiveRoom room}) async {
    final exists = tasks.any((e) => e.roomId == room.roomId && e.platform == room.platform);

    if (exists) return;

    final task = LiveRecordTask.fromRoom(room);

    tasks.insert(0, task);
    tasks.assignAll(List<LiveRecordTask>.from(tasks));

    if (room.liveStatus == LiveStatus.live) {
      await _startTask(task);
    } else {
      _startPolling(task);
    }
  }

  // =========================
  // 删除任务
  // =========================
  Future<void> removeTask(LiveRecordTask task) async {
    await stopTask(task);
    queue.remove(task);
    tasks.remove(task);
    tasks.assignAll(List<LiveRecordTask>.from(tasks));
  }

  // =========================
  // 停止任务
  // =========================
  Future<void> stopTask(LiveRecordTask task) async {
    _stopPolling(task.taskId);
    await FFmpegService.to.stopRecord(task.taskId);

    // 1. 如果有录制内容，进入异步处理流程
    if (task.outputDir != null && task.recordedSeconds > 0) {
      task.status = RecordStatus.processing; // 设为合成中
      updateTask(task);
      try {
        VideoProcessorService.to.convertToMp4(
          task: task,
          tsDir: Directory(task.outputDir!),
          onFinish: (success, finalPath) async {
            if (success) {
              task.status = RecordStatus.completed;
              await RecordHistoryService.to.addRecord(task: task, file: File(finalPath));
            } else {
              task.status = RecordStatus.failed;
            }
            updateTask(task);
            _persist();
          },
        );
      } catch (e) {
        task.status = RecordStatus.failed;
        updateTask(task);
      }
    } else {
      task.status = RecordStatus.stopped;
      updateTask(task);
    }
    _persist();
    _next();
  }

  // =========================
  // 持久化
  // =========================
  Future<void> _persist() async {
    final jsonStr = jsonEncode(tasks.map((e) => e.toJson()).toList());
    await HivePrefUtil.setString(RecorderKeys.recorderTasks, jsonStr);
  }

  // =========================
  // 启动任务
  // =========================
  Future<void> _startTask(LiveRecordTask task) async {
    if (_startingTasks.contains(task.taskId)) return;

    if (task.status == RecordStatus.running ||
        task.status == RecordStatus.preparing ||
        task.status == RecordStatus.reconnecting) {
      return;
    }

    if (runningTasks >= settings.maxTaskCount.value) {
      task.status = RecordStatus.queued;
      if (!queue.contains(task)) queue.add(task);

      updateTask(task);
      return;
    }

    _startingTasks.add(task.taskId);
    _stopPolling(task.taskId);

    try {
      await _runTask(task);
    } finally {
      _startingTasks.remove(task.taskId);
    }
  }

  // =========================
  // 轮询
  // =========================
  void _startPolling(LiveRecordTask task) {
    if (!settings.enablePolling.value) return;
    if (_pollTimers.containsKey(task.taskId)) return;

    task.status = RecordStatus.idle;
    updateTask(task);

    final interval = settings.liveCheckInterval.value;

    _pollTimers[task.taskId] = Timer.periodic(Duration(seconds: interval), (_) async {
      try {
        final room = await Sites.of(task.platform).liveSite.getRoomDetail(roomId: task.roomId, platform: task.platform);

        task.updateFromRoom(room);
        updateTask(task);

        if (room.liveStatus == LiveStatus.live) {
          _stopPolling(task.taskId);
          await _startTask(task);
        }
      } catch (_) {}
    });
  }

  void _stopPolling(String taskId) {
    _pollTimers[taskId]?.cancel();
    _pollTimers.remove(taskId);
  }

  // =========================
  // 外部启动
  // =========================
  Future<void> startTask(LiveRecordTask task) async {
    task.retryCount = 0;
    await _startTask(task);
  }

  // =========================
  // 完成
  // =========================
  Future<void> _onComplete(LiveRecordTask task) async {
    task.status = RecordStatus.processing;
    updateTask(task);
    _next();
    try {
      await VideoProcessorService.to.convertToMp4(
        task: task,
        tsDir: Directory(task.outputDir!),
        onFinish: (success, mp4Path) async {
          if (success) {
            task.status = RecordStatus.completed;
            await RecordHistoryService.to.addRecord(task: task, file: File(mp4Path));
          } else {
            task.status = RecordStatus.failed;
          }
          updateTask(task);
        },
      );
    } catch (_) {
      task.status = RecordStatus.failed;
      updateTask(task);
    }
  }

  // =========================
  // 队列
  // =========================
  void _next() {
    if (queue.isEmpty || runningTasks >= settings.maxTaskCount.value) return;
    final task = queue.removeFirst();
    _startTask(task);
  }

  // =========================
  // 恢复
  // =========================
  Future<void> restoreAndAutoPoll() async {
    final raw = HivePrefUtil.getString(RecorderKeys.recorderTasks);
    if (raw == null || raw.isEmpty) return;

    try {
      final list = jsonDecode(raw) as List;
      final restored = list.map((e) => LiveRecordTask.fromJson(e)).toList();

      for (var task in restored) {
        if (task.status == RecordStatus.running ||
            task.status == RecordStatus.reconnecting ||
            task.status == RecordStatus.preparing) {
          task.status = RecordStatus.stopped;
        }
      }

      tasks.assignAll(restored);
    } catch (_) {
      tasks.clear();
    }
  }
}
