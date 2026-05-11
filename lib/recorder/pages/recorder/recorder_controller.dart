import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:get/get.dart';
import 'dart:developer' as developer;
import 'package:pure_live/core/sites.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/recorder/consts/recorder_keys.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/recorder/services/cache_service.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_command_builder.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_isolate_manager.dart';
import 'package:pure_live/recorder/services/ffmpeg_header_factory.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';
import 'package:pure_live/recorder/services/video_processor_service.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';

class RecorderController extends GetxService {
  final RecordSettingsController settings = Get.find<RecordSettingsController>();

  final tasks = <LiveRecordTask>[].obs;
  final Queue<LiveRecordTask> queue = Queue();
  final Map<String, FFmpegTaskExecutor> _executors = {};
  final Map<String, Timer> _pollTimers = {};
  final Set<String> _startingTasks = {};
  final Set<String> _runningTasks = {};

  int get runningCount => tasks
      .where(
        (e) =>
            e.status == RecordStatus.running ||
            e.status == RecordStatus.preparing ||
            e.status == RecordStatus.reconnecting,
      )
      .length;

  @override
  void onInit() {
    super.onInit();
    restoreAndAutoPoll();
  }

  // =========================================================
  // FFmpeg EVENT
  // =========================================================
  void _onFFmpegEvent(FFmpegEvent event) {
    final task = tasks.firstWhereOrNull((e) => e.taskId == event.taskId);
    if (task == null) return;

    switch (event.type) {
      case FFmpegEventType.started:
        task.status = RecordStatus.running;
        _runningTasks.add(task.taskId);
        break;
      case FFmpegEventType.startAck:
        break;
      case FFmpegEventType.progress:
        final d = event.data;
        task.recordedSeconds = (d['time'] ?? 0) ~/ 1000;
        task.fileSize = d['size'] ?? 0;
        task.fps = d['fps'] ?? 0;
        task.recordSpeed = d['speed'] ?? 0;
        task.bitrate = d['bitrate'] ?? 0;
        break;

      case FFmpegEventType.error:
        _onFail(task);
        break;

      case FFmpegEventType.complete:
        _onComplete(task);
        break;

      case FFmpegEventType.heartbeat:
        break;
    }

    updateTask(task);
  }

  // =========================================================
  // UPDATE
  // =========================================================
  void updateTask(LiveRecordTask task) {
    final i = tasks.indexWhere((e) => e.taskId == task.taskId);
    if (i == -1) return;

    List<LiveRecordTask> newList = List.from(tasks);
    newList[i] = task;
    tasks.value = newList;
    _persist(); //
  }

  // =========================================================
  // ADD TASK
  // =========================================================
  Future<void> addTask({required LiveRoom room}) async {
    if (tasks.any((e) => e.roomId == room.roomId && e.platform == room.platform)) return;

    final task = LiveRecordTask.fromRoom(room);
    tasks.insert(0, task);
    tasks.value = List.from(tasks);
    _persist();

    if (room.liveStatus == LiveStatus.live) {
      await startTask(task);
    } else {
      task.status = RecordStatus.waitingLive;
      updateTask(task);
      _startPolling(task);
    }
  }

  // =========================================================
  // START TASK (external)
  // =========================================================
  Future<void> startTask(LiveRecordTask task) async {
    task.retryCount = 0;
    await _startTask(task);
  }

  // =========================================================
  // FORCE START
  // =========================================================
  Future<void> forceStartTask(LiveRecordTask task) async {
    if (runningCount < settings.maxTaskCount.value) {
      await startTask(task);
      return;
    }

    final running = tasks.firstWhereOrNull((e) => e.taskId != task.taskId && e.status == RecordStatus.running);

    if (running == null) return;

    await stopTask(running);
    await startTask(task);
  }

  // =========================================================
  // INTERNAL START
  // =========================================================
  Future<void> _startTask(LiveRecordTask task) async {
    if (_startingTasks.contains(task.taskId)) return;

    _startingTasks.add(task.taskId);

    try {
      if (runningCount >= settings.maxTaskCount.value) {
        task.status = RecordStatus.queued;
        queue.add(task);
        updateTask(task);
        return;
      }

      _stopPolling(task.taskId);
      await _runTask(task);
    } finally {
      _startingTasks.remove(task.taskId);
    }
  }

  // =========================================================
  // RUN TASK
  // =========================================================
  Future<void> _runTask(LiveRecordTask task) async {
    // 1. 设置状态为准备中
    task.status = RecordStatus.preparing;
    updateTask(task);

    try {
      // 2. 解析流地址、获取保存目录和 Header
      final url = await StreamResolverService.to.resolveStream(
        roomId: task.roomId,
        platform: task.platform,
        preferredQuality: settings.defaultQuality.value,
      );

      final dir = await CacheService.to.getRoomDir(platform: task.platform, nick: task.nick);

      final headers = await FFmpegHeaderFactory.build(platform: task.platform);

      // 3. 构建录制命令
      final cmd = FFmpegCommandBuilder.buildRecordCommand(
        headers: headers,
        url: url,
        outputDir: dir.path,
        segmentTime: settings.segmentTime.value,
        preferBestStream: settings.preferBestStream.value,
        rwTimeout: settings.rwTimeout.value,
        threadQueueSize: settings.threadQueueSize.value,
      );

      // 4. 更新任务信息
      task.outputDir = dir.path;
      _runningTasks.add(task.taskId);

      // --- 关键优化：每个任务创建独立的执行器 ---
      // 如果已存在旧的执行器（如重连情况），先销毁它
      _executors[task.taskId]?.dispose();

      // 创建新的执行器实例
      final executor = FFmpegTaskExecutor(taskId: task.taskId);

      // 监听该任务独立的事件流
      executor.stream.listen((event) => _onFFmpegEvent(event));

      // 存入 Map 管理
      _executors[task.taskId] = executor;

      // 启动该任务独占的 Isolate
      await executor.run(cmd);
    } catch (e) {
      developer.log("运行录制任务失败: $e");
      _onFail(task);
    }
  }

  // =========================================================
  // STOP TASK
  // =========================================================
  Future<void> stopTask(LiveRecordTask task) async {
    queue.remove(task);
    _stopPolling(task.taskId);

    final executor = _executors[task.taskId];
    if (executor != null) {
      await executor.forceKill();
      _executors.remove(task.taskId);
      developer.log("等待底层资源释放...");
      await Future.delayed(const Duration(seconds: 2));
      developer.log("[${task.taskId}] 环境已安全，开始合并处理...");
      unawaited(_processVideo(task));
    }

    _runningTasks.remove(task.taskId);
    task.status = RecordStatus.stopped;
    updateTask(task);
    _next();
  }

  // In _onComplete or _onFail
  void _cleanupExecutor(String taskId) {
    _executors[taskId]?.dispose();
    _executors.remove(taskId);
  }

  // =========================================================
  // COMPLETE
  // =========================================================
  Future<void> _onComplete(LiveRecordTask task) async {
    _cleanupExecutor(task.taskId); // Cleanup the isolate
    task.status = RecordStatus.processing;
    updateTask(task);
    _runningTasks.remove(task.taskId);
    _next();
    unawaited(_processVideo(task));
  }

  // =========================================================
  // FAIL
  // =========================================================
  Future<void> _onFail(LiveRecordTask task) async {
    task.retryCount++;

    if (task.retryCount >= settings.maxRetryCount.value) {
      task.status = RecordStatus.waitingLive;
      updateTask(task);
      _startPolling(task);
      _next();
      return;
    }

    task.status = RecordStatus.reconnecting;
    updateTask(task);

    await Future.delayed(Duration(seconds: settings.retryDelay.value));

    await _runTask(task);
  }

  // =========================================================
  // PROCESS VIDEO
  // =========================================================
  Future<void> _processVideo(LiveRecordTask task) async {
    if (task.outputDir == null) return;
    final dir = Directory(task.outputDir!);
    if (!dir.existsSync()) return;

    task.status = RecordStatus.processing;
    updateTask(task);

    await VideoProcessorService.to.convertToMp4(
      task: task,
      tsDir: Directory(task.outputDir!),
      onFinish: (ok, _) {
        task.status = ok ? RecordStatus.completed : RecordStatus.failed;
        updateTask(task);
        _deleteTsFiles(dir);
      },
    );
  }

  /// 删除指定目录下的所有 .ts 切片和临时配置文件
  void _deleteTsFiles(Directory dir) {
    try {
      if (!dir.existsSync()) return;

      // 1. 获取所有待删除文件
      final files = dir.listSync();

      for (final file in files) {
        final path = file.path;
        // 只删除 .ts 文件和 ffmpeg 的列表文件
        if (path.endsWith('.ts') || path.endsWith('list.txt')) {
          file.deleteSync();
        }
      }
      developer.log("清理完成：已删除 ${dir.path} 下的原始切片");
    } catch (e) {
      developer.log("清理文件失败: $e");
    }
  }

  // =========================================================
  // QUEUE NEXT
  // =========================================================
  void _next() {
    if (queue.isEmpty) return;
    if (runningCount >= settings.maxTaskCount.value) return;

    _startTask(queue.removeFirst());
  }

  // =========================================================
  // POLLING
  // =========================================================
  void _startPolling(LiveRecordTask task) {
    if (!settings.enablePolling.value) return;
    if (_pollTimers.containsKey(task.taskId)) return;

    task.status = RecordStatus.waitingLive;
    updateTask(task);

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

  void _stopPolling(String id) {
    _pollTimers[id]?.cancel();
    _pollTimers.remove(id);
  }

  // =========================================================
  // UNRECORDER
  // =========================================================
  Future<void> unRecorder(LiveRecordTask task) async {
    _stopPolling(task.taskId);
    queue.remove(task);

    final executor = _executors[task.taskId];
    if (executor != null) {
      // 1. 直接炸掉 Isolate 进程
      await executor.forceKill();
      _executors.remove(task.taskId);

      // 2. 核心：因为进程被杀，不会触发 complete 回调，所以这里手动调用
      developer.log("[$task.taskId] 进程已炸掉，开始手动触发合并...");
      _processVideo(task);
    }

    // 3. 从运行状态集合中移除
    _runningTasks.remove(task.taskId);

    // 4. 从任务列表中删除并持久化
    tasks.removeWhere((e) => e.taskId == task.taskId);
    tasks.value = List.from(tasks);
    await _persist();

    // 5. 检查是否可以启动队列中的下一个任务
    _next();
  }

  // =========================================================
  // PERSIST
  // =========================================================
  Future<void> _persist() async {
    try {
      final jsonStr = jsonEncode(tasks.map((e) => e.toJson()).toList());
      await HivePrefUtil.setString(RecorderKeys.recorderTasks, jsonStr);
    } catch (e) {
      developer.log("持久化失败: $e");
    }
  }

  // =========================================================
  // RESTORE 恢复任务并自动刷新状态
  // =========================================================
  Future<void> restoreAndAutoPoll() async {
    try {
      final raw = HivePrefUtil.getString(RecorderKeys.recorderTasks);
      if (raw == null || raw.isEmpty) return;

      final list = jsonDecode(raw) as List;
      final restored = list.map((e) => LiveRecordTask.fromJson(e)).toList();
      tasks.value = List<LiveRecordTask>.from(restored);
      developer.log('tasks: ${tasks.length}');
      if (settings.autoStartOnBoot.value) {
        for (final task in tasks) {
          unawaited(refreshTaskStatus(task));
        }
      }
    } catch (e) {
      tasks.clear();
    }
  }

  //刷新任务状态
  Future<void> refreshTaskStatus(LiveRecordTask task) async {
    try {
      final room = await Sites.of(task.platform).liveSite.getRoomDetail(roomId: task.roomId, platform: task.platform);
      task.updateFromRoom(room);

      if (room.liveStatus == LiveStatus.live) {
        task.status = RecordStatus.preparing;
        updateTask(task);
        await startTask(task);
      } else {
        task.status = RecordStatus.waitingLive;
        updateTask(task);
        _startPolling(task);
      }
    } catch (e) {
      task.status = RecordStatus.waitingLive;
      updateTask(task);
      _startPolling(task);
    }
  }

  // =========================================================
  // OPEN DIR
  // =========================================================
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
      await launchUrl(uri);
    }
  }

  @override
  void onClose() {
    for (var timer in _pollTimers.values) {
      timer.cancel();
    }
    _pollTimers.clear();
    super.onClose();
  }
}
