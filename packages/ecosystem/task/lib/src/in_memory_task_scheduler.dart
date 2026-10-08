// Module: lib/src/in_memory_task_scheduler.dart
// Purpose: The bounded, priority-ordered, de-duplicating task scheduler that runs in one isolate.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-contracts.md section 16 and docs/architecture/platform-infrastructure.md
// section 7.3: one scheduler for every ecosystem, priorities that mean the same thing everywhere, and
// tasks sharing a live deduplicationKey collapsed into one run. Cancellation is a terminal state of its own
// (platform-models.md section 20 invariant 9), never folded into failure.

import 'dart:async';

import 'package:pure_live_platform/pure_live_platform.dart';

import 'cancellation.dart';
import 'task.dart';
import 'task_scheduler.dart';

/// An InMemory [TaskScheduler]: priority queue, a concurrency cap and a bounded record of finished work.
final class InMemoryTaskScheduler implements TaskScheduler {
  InMemoryTaskScheduler({this.maxConcurrent = 3, int finishedLimit = 64, DateTime Function()? clock})
    : _finishedLimit = finishedLimit,
      _clock = clock ?? _utcNow;

  /// How many tasks may run at once. The queue keeps the rest pending, ordered by priority.
  final int maxConcurrent;

  final int _finishedLimit;
  final DateTime Function() _clock;

  final Map<TaskId, _Entry> _entries = <TaskId, _Entry>{};
  final List<_Entry> _queue = <_Entry>[];
  final Set<_Entry> _paused = <_Entry>{};
  final Set<_Entry> _running = <_Entry>{};
  final List<TaskId> _finished = <TaskId>[];
  final StreamController<TaskStatus> _updates = StreamController<TaskStatus>.broadcast();

  @override
  Stream<TaskStatus> get updates => _updates.stream;

  @override
  Future<TaskHandle> submit(Task task) async {
    final id = task.descriptor.id;
    final known = _entries[id];
    if (known != null) {
      return known.handle;
    }

    final key = task.descriptor.deduplicationKey;
    if (key != null) {
      for (final entry in _liveEntries()) {
        if (entry.task.descriptor.deduplicationKey == key) {
          return entry.handle;
        }
      }
    }

    final entry = _Entry(
      task: task,
      token: CancellationToken(label: id),
    );
    entry.context = TaskContext(
      descriptor: task.descriptor,
      cancelToken: entry.token,
      onProgress: (progress) => _reportProgress(entry, progress),
    );
    // The handle reads its own entry rather than the scheduler's index, so an evicted record still reports
    // the state it really reached instead of a default.
    entry.handle = TaskHandle(
      descriptor: task.descriptor,
      statusOf: () => entry.status,
      result: entry.completer.future,
    );
    _entries[id] = entry;
    _queue.add(entry);
    _setStatus(entry, TaskState.pending);
    _pump();
    return entry.handle;
  }

  @override
  Future<void> cancel(TaskId id) async {
    final entry = _entries[id];
    // A record the scheduler already dropped finished on its own; an unknown id is not an error the caller
    // can act on, so both are a no-op.
    if (entry == null || entry.isTerminal) {
      return;
    }

    if (_running.contains(entry)) {
      entry.token.cancel();
      try {
        await entry.task.cancel();
      } catch (_) {
        // A failing cancel hook must not hide the cancellation; _execute settles the terminal state.
      }
      return;
    }

    _queue.remove(entry);
    _paused.remove(entry);
    final error = _cancelledError(id);
    _setStatus(entry, TaskState.cancelled, error: error);
    _retain(id);
    entry.complete(TaskResult.failure(error));
  }

  @override
  Future<bool> pause(TaskId id) async {
    final entry = _entries[id];
    if (entry == null || _running.contains(entry) || !_queue.remove(entry)) {
      return false;
    }
    _paused.add(entry);
    _setStatus(entry, TaskState.paused);
    return true;
  }

  @override
  Future<bool> resume(TaskId id) async {
    final entry = _entries[id];
    if (entry == null || !_paused.remove(entry)) {
      return false;
    }
    _queue.add(entry);
    _setStatus(entry, TaskState.pending);
    _pump();
    return true;
  }

  @override
  TaskHandle? find(TaskId id) => _entries[id]?.handle;

  @override
  List<TaskHandle> running() => _running.map((entry) => entry.handle).toList(growable: false);

  @override
  List<TaskHandle> pending() => _queue.map((entry) => entry.handle).toList(growable: false);

  /// Cancels everything still live and closes the status feed. A host tearing a scheduler down calls this.
  Future<void> dispose() async {
    for (final entry in _liveEntries().toList(growable: false)) {
      await cancel(entry.task.descriptor.id);
    }
    _entries.clear();
    _queue.clear();
    _paused.clear();
    _running.clear();
    _finished.clear();
    await _updates.close();
  }

  List<_Entry> _liveEntries() => <_Entry>[..._queue, ..._paused, ..._running];

  void _pump() {
    while (_running.length < maxConcurrent && _queue.isNotEmpty) {
      final next = _takeNext();
      _running.add(next);
      _setStatus(next, TaskState.running, startedAt: _clock());
      unawaited(_execute(next));
    }
  }

  /// Highest priority first, insertion order inside one priority.
  _Entry _takeNext() {
    var bestIndex = 0;
    for (var index = 1; index < _queue.length; index++) {
      final candidate = _queue[index];
      final best = _queue[bestIndex];
      if (candidate.task.descriptor.priority.index < best.task.descriptor.priority.index) {
        bestIndex = index;
      }
    }
    return _queue.removeAt(bestIndex);
  }

  Future<void> _execute(_Entry entry) async {
    final id = entry.task.descriptor.id;
    var result = TaskResult.failure(_failedError(id, 'never ran'));

    try {
      result = await entry.task.run(entry.context);
      if (entry.token.isCancelled) {
        result = TaskResult.failure(_cancelledError(id));
      }
    } on TaskCancelledException catch (error) {
      result = TaskResult.failure(_cancelledError(id, error.reason));
    } catch (error) {
      result = entry.token.isCancelled
          ? TaskResult.failure(_cancelledError(id, '$error'))
          : TaskResult.failure(_failedError(id, '$error'));
    } finally {
      _running.remove(entry);
      // A task that returns a failure result without throwing is a failure too: the state a caller reads
      // must not depend on whether the task chose an exception or a return value.
      final state = entry.token.isCancelled
          ? TaskState.cancelled
          : (result.success ? TaskState.completed : TaskState.failed);
      _setStatus(entry, state, completedAt: _clock(), error: result.error);
      _retain(id);
      entry.complete(result);
      _pump();
    }
  }

  void _reportProgress(_Entry entry, double progress) {
    if (!_running.contains(entry) || entry.isTerminal) {
      return;
    }
    _setStatus(entry, TaskState.running, progress: progress);
  }

  void _setStatus(
    _Entry entry,
    TaskState state, {
    double? progress,
    DateTime? startedAt,
    DateTime? completedAt,
    PlatformErrorInfo? error,
  }) {
    final previous = entry.status;
    entry.status = TaskStatus(
      taskId: entry.task.descriptor.id,
      state: state,
      progress: progress ?? previous.progress,
      startedAt: startedAt ?? previous.startedAt,
      completedAt: completedAt ?? previous.completedAt,
      error: error ?? previous.error,
    );
    if (!_updates.isClosed) {
      _updates.add(entry.status);
    }
  }

  /// Finished work stays findable through the scheduler only up to a bound: a scheduler that ran for a week
  /// must not keep every Task object it ever ran.
  void _retain(TaskId id) {
    _finished.add(id);
    while (_finished.length > _finishedLimit) {
      _entries.remove(_finished.removeAt(0));
    }
  }

  static PlatformErrorInfo _cancelledError(TaskId id, [String? reason]) => PlatformErrorInfo(
    code: PlatformErrorCodes.taskCancelled,
    message: reason ?? 'task $id was cancelled',
    category: PlatformErrorCategory.task,
    recoverable: true,
  );

  static PlatformErrorInfo _failedError(TaskId id, String reason) => PlatformErrorInfo(
    code: PlatformErrorCodes.taskFailed,
    message: 'task $id failed: $reason',
    category: PlatformErrorCategory.task,
    retryable: true,
  );

  static DateTime _utcNow() => DateTime.now().toUtc();
}

/// One queued task with the pieces the scheduler mutates.
class _Entry {
  _Entry({required this.task, required this.token})
    : status = TaskStatus(taskId: task.descriptor.id, state: TaskState.pending);

  final Task task;
  final CancellationToken token;
  final Completer<TaskResult> completer = Completer<TaskResult>();

  TaskStatus status;

  late final TaskContext context;
  late final TaskHandle handle;

  bool get isTerminal => status.isTerminal;

  void complete(TaskResult result) {
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }
}
