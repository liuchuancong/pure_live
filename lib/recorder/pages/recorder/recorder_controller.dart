import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:get/get.dart';
import 'dart:developer' as developer;
import 'package:pure_live/common/index.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/recorder/consts/recorder_keys.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/recorder/services/cache_service.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/services/ffmpeg_service.dart';
import 'package:pure_live/recorder/services/ffmpeg_header_factory.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';
import 'package:pure_live/recorder/services/video_processor_service.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';

class RecorderController extends GetxService {
  final RecordSettingsController settings = Get.find<RecordSettingsController>();

  /// 所有任务
  final tasks = <LiveRecordTask>[].obs;

  /// 排队队列
  final Queue<LiveRecordTask> queue = Queue();

  /// 轮询器
  final Map<String, Timer> _pollTimers = {};

  /// 防止重复启动
  final Set<String> _startingTasks = {};

  /// 轮询失败次数（指数退避）
  final Map<String, int> _pollRetryCount = {};

  /// 当前占用录制槽位数量
  int get runningTasks => tasks.where((e) {
    return e.status == RecordStatus.running ||
        e.status == RecordStatus.preparing ||
        e.status == RecordStatus.reconnecting;
  }).length;
  @override
  onInit() {
    restoreAndAutoPoll();
    super.onInit();
  }

  // =========================================================
  // 更新任务
  // =========================================================

  void updateTask(LiveRecordTask task) {
    final index = tasks.indexWhere((e) => e.taskId == task.taskId);

    if (index == -1) {
      return;
    }

    tasks[index] = task;

    tasks.assignAll(List<LiveRecordTask>.from(tasks));

    _persist();
  }

  // =========================================================
  // 添加任务
  // =========================================================

  Future<void> addTask({required LiveRoom room}) async {
    final exists = tasks.any((e) => e.roomId == room.roomId && e.platform == room.platform);

    if (exists) {
      return;
    }

    final task = LiveRecordTask.fromRoom(room);

    tasks.insert(0, task);

    tasks.assignAll(List<LiveRecordTask>.from(tasks));

    /// 已开播
    if (room.liveStatus == LiveStatus.live) {
      await startTask(task);

      return;
    }

    /// 未开播
    task.status = RecordStatus.waitingLive;

    updateTask(task);

    _startPolling(task);
  }

  // =========================================================
  // 删除任务
  // =========================================================

  Future<void> removeTask(LiveRecordTask task) async {
    await stopTask(task);

    queue.remove(task);

    _stopPolling(task.taskId);

    tasks.removeWhere((e) => e.taskId == task.taskId);

    tasks.assignAll(List<LiveRecordTask>.from(tasks));

    await _persist();
  }

  // =========================================================
  // 彻底取消直播间监控
  // =========================================================

  Future<void> unRecorder(LiveRecordTask task) async {
    developer.log('unRecorder => ${task.taskId}');

    try {
      /// 停止轮询
      _stopPolling(task.taskId);

      /// 是否正在录制
      final isRecording = [
        RecordStatus.running,
        RecordStatus.preparing,
        RecordStatus.reconnecting,
      ].contains(task.status);

      if (isRecording) {
        /// 停止 ffmpeg
        await FFmpegService.to.stopRecord(task.taskId);

        /// 等待 session 释放
        await _waitSessionRelease(task.taskId);

        /// 有录制内容 -> 自动合并
        if (task.outputDir != null && task.recordedSeconds > 0) {
          task.status = RecordStatus.processing;

          updateTask(task);

          await _processVideo(task);
        }
      }

      /// 队列移除
      queue.remove(task);

      /// 删除任务
      tasks.removeWhere((e) => e.taskId == task.taskId);

      tasks.assignAll(List<LiveRecordTask>.from(tasks));

      /// 删除持久化
      await _persist();

      developer.log('unRecorder success => ${task.taskId}');
    } catch (e, s) {
      developer.log('unRecorder error', error: e, stackTrace: s);
    }
  }

  // =========================================================
  // 外部启动
  // =========================================================

  Future<void> startTask(LiveRecordTask task) async {
    developer.log('startTask => ${task.taskId}, status=${task.status}');

    task.retryCount = 0;

    await _startTask(task);
  }

  // =========================================================
  // 内部启动
  // =========================================================
  Future<void> forceStartTask(LiveRecordTask task) async {
    /// 有空闲
    if (runningTasks < settings.maxTaskCount.value) {
      await startTask(task);
      return;
    }

    /// 找一个正在运行的任务
    final running = tasks.firstWhereOrNull(
      (e) =>
          e.taskId != task.taskId &&
          [RecordStatus.running, RecordStatus.preparing, RecordStatus.reconnecting].contains(e.status),
    );

    if (running == null) {
      return;
    }

    /// 弹窗确认
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('录制数量已满'),
        content: Text(
          '当前已达到最大录制数量。\n\n'
          '将停止录制：\n'
          '${running.nick}\n\n'
          '是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(Get.context!).pop(false);
            },
            child: const Text('取消'),
          ),

          FilledButton(
            onPressed: () {
              Navigator.of(Get.context!).pop(true);
            },
            child: const Text('继续'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    developer.log(
      'force stop => ${running.taskId}, '
      'force start => ${task.taskId}',
    );

    /// 停止旧任务
    await stopTask(running);

    /// 启动新任务
    await startTask(task);
  }

  Future<void> _startTask(LiveRecordTask task) async {
    /// 防止重复启动
    if (_startingTasks.contains(task.taskId)) {
      developer.log('task already starting => ${task.taskId}');
      return;
    }

    _startingTasks.add(task.taskId);

    try {
      /// 已运行
      if (task.status == RecordStatus.running ||
          task.status == RecordStatus.preparing ||
          task.status == RecordStatus.reconnecting) {
        developer.log('task already running => ${task.taskId}');

        return;
      }

      /// 正在处理视频
      if (task.status == RecordStatus.processing) {
        developer.log('task processing => ${task.taskId}');
      }

      /// 已在队列
      if (task.status == RecordStatus.queued) {
        developer.log('task already queued => ${task.taskId}');
        return;
      }

      /// 超过并发限制
      if (runningTasks >= settings.maxTaskCount.value) {
        task.status = RecordStatus.queued;

        if (!queue.contains(task)) {
          queue.add(task);
        }

        updateTask(task);

        developer.log('task queued => ${task.taskId}');

        return;
      }

      /// 停止轮询
      _stopPolling(task.taskId);

      /// 真正执行录制
      await _runTask(task);
    } catch (e, s) {
      developer.log('_startTask error', error: e, stackTrace: s);

      task.status = RecordStatus.failed;

      updateTask(task);
    } finally {
      _startingTasks.remove(task.taskId);
    }
  }

  // =========================================================
  // 真正执行录制
  // =========================================================

  Future<void> _runTask(LiveRecordTask task) async {
    try {
      developer.log('_runTask => ${task.taskId}');

      task.status = RecordStatus.preparing;

      updateTask(task);

      /// 解析流地址
      final url = await StreamResolverService.to.resolveStream(
        roomId: task.roomId,
        platform: task.platform,
        preferredQuality: settings.defaultQuality.value,
      );

      /// 创建目录
      final dir = await CacheService.to.getRoomDir(platform: task.platform, nick: task.nick);

      /// headers
      final headers = await FFmpegHeaderFactory.build(platform: task.platform);

      task.outputDir = dir.path;

      task.retryCount = 0;

      task.selectedQuality = settings.defaultQuality.value;

      task.status = RecordStatus.running;

      updateTask(task);

      /// 开始录制
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
          developer.log('ffmpeg error => $err');

          final session = FFmpegService.to.getSession(task.taskId);

          if (session?.manualStop ?? false) {
            return;
          }

          if (!settings.autoReconnect.value) {
            task.status = RecordStatus.failed;

            updateTask(task);

            _next();

            return;
          }

          await _onFail(task);
        },

        onComplete: () async {
          developer.log('ffmpeg complete => ${task.taskId}');
          final session = FFmpegService.to.getSession(task.taskId);
          if (session?.manualStop ?? false) {
            return;
          }

          await _onComplete(task);
        },
      );
    }
    /// Stream 异常
    on StreamException catch (e) {
      switch (e.type) {
        case StreamErrorType.notLive:
          developer.log('主播未开播 => ${task.roomId}');

          task.status = RecordStatus.waitingLive;

          updateTask(task);

          _startPolling(task);

          _next();

          return;

        case StreamErrorType.noQuality:
          developer.log('无可用清晰度 => ${task.roomId}');

          await _onFail(task);

          return;

        case StreamErrorType.cdnFailed:
          developer.log('cdn失败 => ${task.roomId}');

          await _onFail(task);

          return;

        case StreamErrorType.roomNotFound:
          developer.log('房间不存在 => ${task.roomId}');

          task.status = RecordStatus.failed;

          updateTask(task);

          _next();

          return;

        case StreamErrorType.networkError:
          developer.log('网络错误 => ${task.roomId}');

          await _onFail(task);

          return;

        case StreamErrorType.loginExpired:
          developer.log('登录失效 => ${task.roomId}');

          task.status = RecordStatus.failed;

          updateTask(task);

          _next();

          return;

        case StreamErrorType.banned:
          developer.log('房间封禁 => ${task.roomId}');

          task.status = RecordStatus.failed;

          updateTask(task);

          _next();

          return;

        case StreamErrorType.unknown:
          developer.log('未知错误 => ${task.roomId}');

          await _onFail(task);

          return;
      }
    }
    /// 未知异常
    catch (e, s) {
      developer.log('_runTask unknown error', error: e, stackTrace: s);

      if (task.status != RecordStatus.stopped) {
        await _onFail(task);
      }
    }
  }

  // =========================================================
  // 停止任务
  // =========================================================

  Future<void> stopTask(LiveRecordTask task) async {
    developer.log('stopTask => ${task.taskId}');

    try {
      queue.remove(task);

      _stopPolling(task.taskId);

      await FFmpegService.to.stopRecord(task.taskId);

      await _waitSessionRelease(task.taskId);

      /// 有录制内容
      if (task.outputDir != null && task.recordedSeconds > 0) {
        task.status = RecordStatus.processing;

        updateTask(task);

        _next();

        unawaited(_processVideo(task));
      } else {
        task.status = RecordStatus.stopped;

        updateTask(task);

        _next();
      }
    } catch (e, s) {
      developer.log('stopTask error', error: e, stackTrace: s);

      task.status = RecordStatus.failed;

      updateTask(task);
    }
  }

  // =========================================================
  // 录制完成
  // =========================================================

  Future<void> _onComplete(LiveRecordTask task) async {
    developer.log('_onComplete => ${task.taskId}');

    try {
      task.status = RecordStatus.processing;
      updateTask(task);
      _next();
      unawaited(_processVideo(task));
    } catch (e, s) {
      developer.log('_onComplete error', error: e, stackTrace: s);

      task.status = RecordStatus.failed;

      updateTask(task);
    }
  }

  // =========================================================
  // 视频处理
  // =========================================================

  Future<void> _processVideo(LiveRecordTask task) async {
    try {
      final outputDir = task.outputDir;
      if (outputDir == null) {
        task.status = RecordStatus.failed;
        updateTask(task);
        return;
      }
      await Future.delayed(Duration(seconds: 5));
      await VideoProcessorService.to.convertToMp4(
        task: task,
        tsDir: Directory(outputDir),

        onFinish: (success, mp4Path) async {
          try {
            if (success) {
              task.status = RecordStatus.completed;
            } else {
              task.status = RecordStatus.failed;
            }
            updateTask(task);
          } catch (e, s) {
            developer.log('_processVideo onFinish error', error: e, stackTrace: s);
            task.status = RecordStatus.failed;
            updateTask(task);
          }
        },
      );
    } catch (e, s) {
      developer.log('_processVideo error', error: e, stackTrace: s);

      task.status = RecordStatus.failed;

      updateTask(task);
    }
  }

  // =========================================================
  // 失败重连
  // =========================================================

  Future<void> _onFail(LiveRecordTask task) async {
    developer.log('_onFail => ${task.taskId}');

    try {
      await FFmpegService.to.stopRecord(task.taskId);

      await _waitSessionRelease(task.taskId);

      task.retryCount++;

      /// 超过最大重试
      if (task.retryCount >= settings.maxRetryCount.value) {
        developer.log('retry max => ${task.taskId}');

        task.status = RecordStatus.waitingLive;

        updateTask(task);

        _startPolling(task);

        _next();

        return;
      }

      task.status = RecordStatus.reconnecting;

      updateTask(task);

      await Future.delayed(Duration(seconds: settings.retryDelay.value));

      if (task.status == RecordStatus.stopped) {
        return;
      }

      StreamResolverService.to.invalidate(task.roomId);

      await _runTask(task);
    } catch (e, s) {
      developer.log('_onFail error', error: e, stackTrace: s);

      task.status = RecordStatus.waitingLive;

      updateTask(task);

      _startPolling(task);

      _next();
    }
  }

  // =========================================================
  // 等待 session 释放
  // =========================================================

  Future<void> _waitSessionRelease(String taskId) async {
    developer.log('wait session release => $taskId');

    const maxWait = 30;

    int count = 0;

    while (FFmpegService.to.getSession(taskId) != null && count < maxWait) {
      await Future.delayed(const Duration(milliseconds: 200));

      count++;
    }

    developer.log('session released => $taskId');
  }

  // =========================================================
  // 队列调度
  // =========================================================

  void _next() {
    if (queue.isEmpty) {
      return;
    }

    if (runningTasks >= settings.maxTaskCount.value) {
      return;
    }

    final task = queue.removeFirst();

    developer.log('_next => ${task.taskId}');

    _startTask(task);
  }

  // =========================================================
  // 轮询直播状态
  // =========================================================

  void _startPolling(LiveRecordTask task) {
    if (!settings.enablePolling.value) {
      return;
    }

    if (_pollTimers.containsKey(task.taskId)) {
      return;
    }

    developer.log('start polling => ${task.taskId}');

    task.status = RecordStatus.waitingLive;

    updateTask(task);

    int currentInterval = settings.liveCheckInterval.value;

    _pollTimers[task.taskId] = Timer.periodic(Duration(seconds: currentInterval), (_) async {
      try {
        final room = await Sites.of(task.platform).liveSite.getRoomDetail(roomId: task.roomId, platform: task.platform);

        task.updateFromRoom(room);

        updateTask(task);

        /// 成功恢复
        _pollRetryCount[task.taskId] = 0;

        if (room.liveStatus == LiveStatus.live) {
          developer.log('room live => ${task.roomId}');

          _stopPolling(task.taskId);

          await startTask(task);
        }
      } catch (e, s) {
        developer.log('_startPolling error', error: e, stackTrace: s);

        /// 指数退避
        if (settings.enableBackoff.value) {
          final retry = (_pollRetryCount[task.taskId] ?? 0) + 1;

          _pollRetryCount[task.taskId] = retry;

          currentInterval = (settings.liveCheckInterval.value * retry).clamp(
            settings.liveCheckInterval.value,
            settings.maxCheckInterval.value,
          );

          developer.log('poll backoff => ${task.taskId}, interval=$currentInterval');
        }
      }
    });
  }

  void _stopPolling(String taskId) {
    _pollTimers[taskId]?.cancel();

    _pollTimers.remove(taskId);

    _pollRetryCount.remove(taskId);
  }

  // =========================================================
  // 持久化
  // =========================================================

  Future<void> _persist() async {
    try {
      final jsonStr = jsonEncode(tasks.map((e) => e.toJson()).toList());

      await HivePrefUtil.setString(RecorderKeys.recorderTasks, jsonStr);
    } catch (e, s) {
      developer.log('_persist error', error: e, stackTrace: s);
    }
  }

  // =========================================================
  // 刷新任务状态
  // =========================================================

  // =========================================================
  // 刷新直播间状态
  // =========================================================

  Future<void> refreshTaskStatus(LiveRecordTask task) async {
    try {
      developer.log('refreshTaskStatus => ${task.taskId}');

      final room = await Sites.of(task.platform).liveSite.getRoomDetail(roomId: task.roomId, platform: task.platform);
      task.updateFromRoom(room);

      /// 正在直播
      if (room.liveStatus == LiveStatus.live) {
        developer.log('room is live => ${task.roomId}');
        task.status = RecordStatus.preparing;
        updateTask(task);
        await startTask(task);

        return;
      }

      /// 未开播
      developer.log('room not live => ${task.roomId}');

      task.status = RecordStatus.waitingLive;

      updateTask(task);

      /// 开始轮询
      if (settings.autoStartOnBoot.value) {
        _startPolling(task);
      }
    }
    /// 房间不存在
    on StreamException catch (e) {
      developer.log('refreshTaskStatus stream error => ${e.type}');

      switch (e.type) {
        case StreamErrorType.roomNotFound:
        case StreamErrorType.banned:
          task.status = RecordStatus.failed;
          break;

        case StreamErrorType.notLive:
          task.status = RecordStatus.waitingLive;

          if (settings.autoStartOnBoot.value) {
            _startPolling(task);
          }
          break;

        default:
          task.status = RecordStatus.failed;
          break;
      }

      updateTask(task);
    } catch (e, s) {
      developer.log('refreshTaskStatus error', error: e, stackTrace: s);

      /// 网络异常不要直接 failed
      task.status = RecordStatus.waitingLive;

      updateTask(task);

      if (settings.autoStartOnBoot.value) {
        _startPolling(task);
      }
    }
  }

  // =========================================================
  // 恢复任务
  // =========================================================
  Future<void> restoreAndAutoPoll() async {
    try {
      final raw = HivePrefUtil.getString(RecorderKeys.recorderTasks);

      if (raw == null || raw.isEmpty) {
        return;
      }

      final list = jsonDecode(raw) as List;

      final restored = list.map((e) => LiveRecordTask.fromJson(e)).toList();

      tasks.assignAll(restored);

      developer.log('restore tasks => ${restored.length}');

      /// 开机自动恢复
      if (!settings.autoStartOnBoot.value) {
        return;
      }

      /// 逐个刷新状态
      for (final task in tasks) {
        unawaited(refreshTaskStatus(task));
      }
    } catch (e, s) {
      developer.log('restoreAndAutoPoll error', error: e, stackTrace: s);

      tasks.clear();
    }
  }

  void openFileDir() async {
    final path = settings.recordSavePath.value;

    if (Platform.isWindows) {
      await Process.run('explorer', [path]);
      return;
    }

    if (Platform.isMacOS) {
      await Process.run('open', [path]);
      return;
    }

    if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
      return;
    }

    if (Platform.isAndroid) {
      final uri = Uri.parse('file://$path');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }
}
