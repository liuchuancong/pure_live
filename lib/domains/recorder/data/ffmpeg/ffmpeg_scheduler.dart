import 'dart:async';
import 'dart:developer';
import 'dart:collection';

import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/recorder/data/record_settings_controller.dart';

class FFmpegScheduler {
  FFmpegScheduler._internal() : _capacityOverride = null, minimumStartGap = const Duration(seconds: 5);

  @visibleForTesting
  FFmpegScheduler.forTesting({int capacity = 1, this.minimumStartGap = Duration.zero}) : _capacityOverride = capacity {
    if (capacity < 1 || minimumStartGap.isNegative) throw ArgumentError('Invalid scheduler limits');
  }

  final int? _capacityOverride;
  final Duration minimumStartGap;

  static final FFmpegScheduler instance = FFmpegScheduler._internal();
  DateTime _lastStartTime = DateTime.fromMillisecondsSinceEpoch(0);

  int get maxConcurrentTasks {
    final capacity = _capacityOverride;
    if (capacity != null) return capacity;
    if (Get.isRegistered<RecordSettingsController>()) {
      return Get.find<RecordSettingsController>().maxTaskCount.value;
    }
    log('Warning: RecordSettingsController not found, using fallback 1', name: 'FFmpegScheduler');
    return 1;
  }

  final Queue<_SchedulerTask> _taskQueue = Queue();

  final Map<String, _RunningTask> _runningTasks = {};

  bool _isScheduling = false;
  Timer? _scheduleTimer;

  void enqueue({required String taskId, required Future<void> Function(TaskCancelToken token) taskRunner}) {
    if (_runningTasks.containsKey(taskId)) {
      log('Task already running: $taskId', name: 'FFmpegScheduler');
      return;
    }

    if (_taskQueue.any((e) => e.taskId == taskId)) {
      log('Task already queued: $taskId', name: 'FFmpegScheduler');
      return;
    }

    _taskQueue.add(_SchedulerTask(taskId: taskId, taskRunner: taskRunner));

    log('Task enqueued: $taskId', name: 'FFmpegScheduler');

    _scheduleNext();
  }

  Future<void> cancel(String taskId) async {
    _taskQueue.removeWhere((e) => e.taskId == taskId);
    if (_taskQueue.isEmpty) {
      _scheduleTimer?.cancel();
      _scheduleTimer = null;
    }

    final runningTask = _runningTasks[taskId];

    if (runningTask != null) {
      if (runningTask.cancelToken.isCancelled) {
        log('Task $taskId is already being cancelled; waiting for its lifecycle fence.', name: 'FFmpegScheduler');
        try {
          await runningTask.future.timeout(const Duration(seconds: 20));
        } catch (e) {
          log('Wait for cancelled task error: $e', name: 'FFmpegScheduler');
        }
        return;
      }

      log('Signalling cancel to task: $taskId', name: 'FFmpegScheduler');

      try {
        await runningTask.cancelToken.cancel();
        await runningTask.future.timeout(const Duration(seconds: 20));
      } catch (e) {
        log('Cancel task error: $e', name: 'FFmpegScheduler');
      }
    }

    _scheduleNext();
  }

  /// Wait for the current running owner, not merely the bounded cancel request.
  /// Call after cancel when output/state mutation requires the native writer
  /// and its finalizer to have actually exited. A later task with the same ID
  /// does not extend the captured completion fence.
  Future<void> waitForTask(String taskId) => _runningTasks[taskId]?.future ?? Future<void>.value();

  Future<void> clearAll() async {
    _taskQueue.clear();
    _scheduleTimer?.cancel();
    _scheduleTimer = null;

    final tasks = _runningTasks.values.toList();

    for (final task in tasks) {
      try {
        await task.cancelToken.cancel();
        await task.future.timeout(const Duration(seconds: 20));
      } catch (e) {
        log('Clear task error: $e', name: 'FFmpegScheduler');
      }
    }
  }

  void _scheduleNext() {
    if (_isScheduling || _scheduleTimer?.isActive == true) return;

    _isScheduling = true;

    try {
      while (_runningTasks.length < maxConcurrentTasks && _taskQueue.isNotEmpty) {
        final now = DateTime.now();
        final diff = now.difference(_lastStartTime);

        if (diff < minimumStartGap) {
          _scheduleTimer = Timer(minimumStartGap - diff, () {
            _scheduleTimer = null;
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

  void _runTask(_SchedulerTask task) {
    final cancelToken = TaskCancelToken();
    final completion = Completer<void>();
    final running = _RunningTask(taskId: task.taskId, future: completion.future, cancelToken: cancelToken);
    // Establish ownership before invoking user code. A synchronous throw or
    // reentrant cancel must observe the same running task as async completion.
    _runningTasks[task.taskId] = running;
    unawaited(
      Future<void>(() async {
        try {
          if (!cancelToken.isCancelled) await task.taskRunner(cancelToken);
        } catch (error, stackTrace) {
          log('Uncaught scheduled task error: $error\n$stackTrace', name: 'FFmpegScheduler');
        } finally {
          if (identical(_runningTasks[task.taskId], running)) _runningTasks.remove(task.taskId);
          if (!completion.isCompleted) completion.complete();
          _scheduleNext();
        }
      }),
    );
  }

  bool isRunning(String taskId) {
    return _runningTasks.containsKey(taskId);
  }

  bool isQueued(String taskId) {
    return _taskQueue.any((e) => e.taskId == taskId);
  }

  int get runningCount => _runningTasks.length;

  int get queuedCount => _taskQueue.length;

  int get totalCount => runningCount + queuedCount;

  List<String> get runningTaskIds {
    return _runningTasks.keys.toList();
  }

  List<String> get queuedTaskIds {
    return _taskQueue.map((e) => e.taskId).toList();
  }
}

class _SchedulerTask {
  final String taskId;

  final Future<void> Function(TaskCancelToken token) taskRunner;

  const _SchedulerTask({required this.taskId, required this.taskRunner});
}

class _RunningTask {
  final String taskId;

  final Future<void> future;

  final TaskCancelToken cancelToken;

  const _RunningTask({required this.taskId, required this.future, required this.cancelToken});
}

/// token.onCancel = () {
///   session.cancel();
/// };
class TaskCancelToken {
  bool _isCancelled = false;
  bool _cancelCallbackInvoked = false;
  FutureOr<void> Function()? _onCancel;

  bool get isCancelled => _isCancelled;

  FutureOr<void> Function()? get onCancel => _onCancel;

  set onCancel(FutureOr<void> Function()? callback) {
    _onCancel = callback;
    if (_isCancelled && callback != null && !_cancelCallbackInvoked) {
      _cancelCallbackInvoked = true;
      unawaited(_invokeLateCancel(callback));
    }
  }

  Future<void> cancel() async {
    if (_isCancelled) return;

    _isCancelled = true;

    try {
      final callback = _onCancel;
      if (callback != null && !_cancelCallbackInvoked) {
        _cancelCallbackInvoked = true;
        await callback.call();
      }
    } catch (e) {
      log('Cancel token error: $e', name: 'FFmpegScheduler');
    }
  }

  Future<void> _invokeLateCancel(FutureOr<void> Function() callback) async {
    try {
      await callback();
    } catch (e) {
      log('Late cancel token callback error: $e', name: 'FFmpegScheduler');
    }
  }
}
