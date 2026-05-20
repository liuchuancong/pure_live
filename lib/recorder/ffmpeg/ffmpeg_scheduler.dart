import 'dart:async';
import 'dart:developer';
import 'dart:collection';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';

class FFmpegScheduler {
  FFmpegScheduler._internal();

  static final FFmpegScheduler instance = FFmpegScheduler._internal();
  DateTime _lastStartTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// 最大并发
  int get maxConcurrentTasks {
    if (Get.isRegistered<RecordSettingsController>()) {
      return Get.find<RecordSettingsController>().maxTaskCount.value;
    }
    log('Warning: RecordSettingsController not found, using fallback 1', name: 'FFmpegScheduler');
    return 1;
  }

  /// 等待队列
  final Queue<_SchedulerTask> _taskQueue = Queue();

  /// 运行中的任务
  final Map<String, _RunningTask> _runningTasks = {};

  /// 防止重复调度
  bool _isScheduling = false;

  /// 添加任务
  void enqueue({required String taskId, required Future<void> Function(TaskCancelToken token) taskRunner}) {
    /// 已运行
    if (_runningTasks.containsKey(taskId)) {
      log('Task already running: $taskId', name: 'FFmpegScheduler');
      return;
    }

    /// 已在队列
    if (_taskQueue.any((e) => e.taskId == taskId)) {
      log('Task already queued: $taskId', name: 'FFmpegScheduler');
      return;
    }

    _taskQueue.add(_SchedulerTask(taskId: taskId, taskRunner: taskRunner));

    log('Task enqueued: $taskId', name: 'FFmpegScheduler');

    _scheduleNext();
  }

  /// 取消任务
  /// 调用 cancel token
  Future<void> cancel(String taskId) async {
    _taskQueue.removeWhere((e) => e.taskId == taskId);

    final runningTask = _runningTasks[taskId];

    if (runningTask != null) {
      if (runningTask.cancelToken.isCancelled) {
        log('Task $taskId is already being cancelled, ignoring duplicate call.', name: 'FFmpegScheduler');
        return;
      }

      log('Signalling cancel to task: $taskId', name: 'FFmpegScheduler');

      try {
        await runningTask.cancelToken.cancel();
      } catch (e) {
        log('Cancel task error: $e', name: 'FFmpegScheduler');
      }
    }

    _scheduleNext();
  }

  /// 清空所有
  Future<void> clearAll() async {
    _taskQueue.clear();

    final tasks = _runningTasks.values.toList();

    _runningTasks.clear();

    for (final task in tasks) {
      try {
        await task.cancelToken.cancel();
      } catch (e) {
        log('Clear task error: $e', name: 'FFmpegScheduler');
      }
    }
  }

  /// 调度核心
  void _scheduleNext() {
    if (_isScheduling) return;

    _isScheduling = true;

    try {
      while (_runningTasks.length < maxConcurrentTasks && _taskQueue.isNotEmpty) {
        final now = DateTime.now();
        final diff = now.difference(_lastStartTime);

        if (diff.inSeconds < 5) {
          Future.delayed(Duration(seconds: 5 - diff.inSeconds), () {
            _isScheduling = false;
            _scheduleNext();
          });
          return;
        }

        final task = _taskQueue.removeFirst();

        _lastStartTime = DateTime.now();

        _runTask(task);
      }
    } finally {
      _isScheduling = false;
    }
  }

  /// 执行任务
  void _runTask(_SchedulerTask task) {
    final cancelToken = TaskCancelToken();

    final future = task.taskRunner(cancelToken).whenComplete(() {
      _runningTasks.remove(task.taskId);
      _scheduleNext();
    });

    _runningTasks[task.taskId] = _RunningTask(taskId: task.taskId, future: future, cancelToken: cancelToken);
  }

  /// 是否运行中
  bool isRunning(String taskId) {
    return _runningTasks.containsKey(taskId);
  }

  /// 是否排队中
  bool isQueued(String taskId) {
    return _taskQueue.any((e) => e.taskId == taskId);
  }

  /// 当前运行数
  int get runningCount => _runningTasks.length;

  /// 当前排队数
  int get queuedCount => _taskQueue.length;

  /// 当前全部任务数
  int get totalCount => runningCount + queuedCount;

  /// 当前运行任务
  List<String> get runningTaskIds {
    return _runningTasks.keys.toList();
  }

  /// 当前排队任务
  List<String> get queuedTaskIds {
    return _taskQueue.map((e) => e.taskId).toList();
  }
}

/// 队列任务
class _SchedulerTask {
  final String taskId;

  final Future<void> Function(TaskCancelToken token) taskRunner;

  const _SchedulerTask({required this.taskId, required this.taskRunner});
}

/// 运行中的任务
class _RunningTask {
  final String taskId;

  final Future<void> future;

  final TaskCancelToken cancelToken;

  const _RunningTask({required this.taskId, required this.future, required this.cancelToken});
}

/// 取消令牌
///
/// 用于真正终止 ffmpeg
///
/// 示例:
///
/// token.onCancel = () {
///   session.cancel();
/// };
///
class TaskCancelToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  FutureOr<void> Function()? onCancel;

  Future<void> cancel() async {
    if (_isCancelled) return;

    _isCancelled = true;

    try {
      await onCancel?.call();
    } catch (e) {
      log('Cancel token error: $e', name: 'FFmpegScheduler');
    }
  }
}
