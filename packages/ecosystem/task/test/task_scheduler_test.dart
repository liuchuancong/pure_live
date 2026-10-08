// Module: test/task_scheduler_test.dart
// Purpose: Verify the scheduler contract: priority order, de-duplication, cancellation, bounds and status.
// Author: liuchuancong
// Created: 2026-10-08
import 'dart:async';

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_task/pure_live_task.dart';
import 'package:test/test.dart';

/// Appends its id to [order] so a test can read the sequence work actually started in.
class _QuickTask implements Task {
  _QuickTask(this.descriptor, this.order);

  @override
  final TaskDescriptor descriptor;
  final List<TaskId> order;

  @override
  Future<TaskResult> run(TaskContext context) async {
    order.add(descriptor.id);
    return TaskResult.ok(descriptor.id);
  }

  @override
  Future<void> cancel() async {}
}

/// Holds a slot until it is released, and stops early when cancelled.
class _GatedTask implements Task {
  _GatedTask(this.descriptor, this.order);

  @override
  final TaskDescriptor descriptor;
  final List<TaskId> order;
  int cancelCalls = 0;
  final Completer<void> release = Completer<void>();

  /// Lets the task finish. Idempotent because a cancellation completes the same gate.
  void openGate() {
    if (!release.isCompleted) {
      release.complete();
    }
  }

  @override
  Future<TaskResult> run(TaskContext context) async {
    order.add(descriptor.id);
    context.cancelToken.onCancel(openGate);
    await release.future;
    context.throwIfCancelled();
    return TaskResult.ok(descriptor.id);
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }
}

class _ThrowingTask implements Task {
  _ThrowingTask(this.descriptor);

  @override
  final TaskDescriptor descriptor;

  @override
  Future<TaskResult> run(TaskContext context) async => throw StateError('page moved');

  @override
  Future<void> cancel() async {}
}

class _ReportingTask implements Task {
  _ReportingTask(this.descriptor);

  @override
  final TaskDescriptor descriptor;

  @override
  Future<TaskResult> run(TaskContext context) async {
    // 1.5 is out of range on purpose: a task that overshoots by rounding must not break the progress bar.
    context.reportProgress(0.5);
    context.reportProgress(1.5);
    return TaskResult.ok();
  }

  @override
  Future<void> cancel() async {}
}

TaskDescriptor _descriptor(String id, {TaskPriority priority = TaskPriority.normal, String? dedupe}) {
  return TaskDescriptor(id: id, type: 'test.run', priority: priority, deduplicationKey: dedupe);
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late List<TaskId> order;
  late InMemoryTaskScheduler scheduler;

  setUp(() {
    order = <TaskId>[];
    scheduler = InMemoryTaskScheduler();
  });

  tearDown(() async {
    await scheduler.dispose();
  });

  group('running', () {
    test('test_submit_quickTask_reportsPendingRunningCompleted', () async {
      final seen = <TaskState>[];
      scheduler.updates.listen((status) => seen.add(status.state));

      final handle = await scheduler.submit(_QuickTask(_descriptor('a'), order));
      final result = await handle.result;
      // The broadcast feed delivers a status one turn later than the completer resolves.
      await settle();

      expect(result.success, isTrue);
      expect(result.value, 'a');
      expect(handle.state, TaskState.completed);
      expect(seen, <TaskState>[TaskState.pending, TaskState.running, TaskState.completed]);
      expect(order, <String>['a']);
    });

    test('test_submit_sameIdTwice_returnsTheSameHandleAndRunsOnce', () async {
      final first = await scheduler.submit(_QuickTask(_descriptor('a'), order));
      final second = await scheduler.submit(_QuickTask(_descriptor('a'), order));

      expect(identical(first, second), isTrue);
      await first.result;
      expect(order, <String>['a']);
    });

    test('test_submit_finishedLists_areEmptiedAfterwards', () async {
      final handle = await scheduler.submit(_QuickTask(_descriptor('a'), order));
      await handle.result;

      expect(scheduler.pending(), isEmpty);
      expect(scheduler.running(), isEmpty);
      expect(scheduler.find('a'), isNotNull);
      expect(scheduler.find('missing'), isNull);
    });

    test('test_submit_respectsMaxConcurrentAndDrains', () async {
      scheduler = InMemoryTaskScheduler(maxConcurrent: 2);
      final gates = <_GatedTask>[
        for (final id in <String>['a', 'b', 'c', 'd']) _GatedTask(_descriptor(id), order),
      ];
      final handles = <TaskHandle>[];
      for (final gate in gates) {
        handles.add(await scheduler.submit(gate));
      }

      expect(scheduler.running().length, 2, reason: 'only two slots exist');
      expect(order, <String>['a', 'b']);
      expect(scheduler.pending().map((handle) => handle.id), <String>['c', 'd']);

      gates[0].openGate();
      await handles[0].result;
      expect(order, <String>['a', 'b', 'c']);
      expect(scheduler.running().length, 2);

      for (final gate in gates.skip(1)) {
        gate.openGate();
      }
      await Future.wait(handles.map((handle) => handle.result));

      expect(order, <String>['a', 'b', 'c', 'd']);
      expect(scheduler.running(), isEmpty);
      expect(scheduler.pending(), isEmpty);
    });

    test('test_run_progressIsReportedAndOutOfRangeValuesAreClamped', () async {
      final statuses = <TaskStatus>[];
      final subscription = scheduler.updates.where((status) => status.taskId == 'a').listen(statuses.add);

      final handle = await scheduler.submit(_ReportingTask(_descriptor('a')));
      await handle.result;
      await settle();
      await subscription.cancel();

      expect(statuses.map((status) => status.progress).whereType<double>().toSet(), <double>{0.5, 1.0});
      expect(handle.progress, 1.0);
    });
  });

  group('priority', () {
    test('test_submit_ordersByPriorityThenInsertion', () async {
      // One slot, so the three quick tasks genuinely queue instead of starting as they are submitted.
      scheduler = InMemoryTaskScheduler(maxConcurrent: 1);
      final gate = _GatedTask(_descriptor('blocker'), order);
      final blocker = await scheduler.submit(gate);
      final low = await scheduler.submit(_QuickTask(_descriptor('low', priority: TaskPriority.low), order));
      final background = await scheduler.submit(
        _QuickTask(_descriptor('bg', priority: TaskPriority.background), order),
      );
      final critical = await scheduler.submit(_QuickTask(_descriptor('crit', priority: TaskPriority.critical), order));

      gate.openGate();
      await Future.wait(<Future<TaskResult>>[blocker.result, low.result, background.result, critical.result]);

      expect(order, <String>['blocker', 'crit', 'low', 'bg']);
    });
  });

  group('deduplication', () {
    test('test_submit_sameDeduplicationKey_reusesTheLiveTask', () async {
      final gate = _GatedTask(_descriptor('refresh-a', dedupe: 'source:tvbox_001'), order);
      final first = await scheduler.submit(gate);
      final duplicate = await scheduler.submit(_QuickTask(_descriptor('refresh-b', dedupe: 'source:tvbox_001'), order));

      expect(identical(first, duplicate), isTrue, reason: 'the second request must not start its own run');

      gate.openGate();
      await first.result;
      expect(order, <String>['refresh-a']);
      expect(scheduler.find('refresh-b'), isNull);
    });

    test('test_submit_afterTheKeyFinished_aNewTaskIsAccepted', () async {
      final first = await scheduler.submit(_QuickTask(_descriptor('run-1', dedupe: 'epg'), order));
      await first.result;

      final second = await scheduler.submit(_QuickTask(_descriptor('run-2', dedupe: 'epg'), order));
      await second.result;

      expect(order, <String>['run-1', 'run-2']);
    });

    test('test_submit_withoutADeduplicationKey_runsBoth', () async {
      final first = await scheduler.submit(_QuickTask(_descriptor('a'), order));
      final second = await scheduler.submit(_QuickTask(_descriptor('b'), order));
      await Future.wait(<Future<TaskResult>>[first.result, second.result]);

      expect(order, hasLength(2));
    });
  });

  group('cancellation', () {
    test('test_cancel_pendingTask_neverRunsAndCompletesWithCancelledCode', () async {
      scheduler = InMemoryTaskScheduler(maxConcurrent: 1);
      final gate = _GatedTask(_descriptor('blocker'), order);
      final blocker = await scheduler.submit(gate);
      final queued = await scheduler.submit(_QuickTask(_descriptor('queued'), order));

      expect(queued.state, TaskState.pending);
      await scheduler.cancel('queued');

      expect(queued.state, TaskState.cancelled);
      final result = await queued.result;
      expect(result.success, isFalse);
      expect(result.error?.code, PlatformErrorCodes.taskCancelled);
      expect(result.error?.recoverable, isTrue);
      expect(order, <String>['blocker']);

      gate.openGate();
      await blocker.result;
      expect(order, <String>['blocker']);
    });

    test('test_cancel_runningTask_isCancelledNotFailed', () async {
      final gate = _GatedTask(_descriptor('long'), order);
      final handle = await scheduler.submit(gate);
      await settle();

      await scheduler.cancel('long');
      final result = await handle.result;

      expect(handle.state, TaskState.cancelled);
      expect(result.error?.code, PlatformErrorCodes.taskCancelled);
      expect(gate.cancelCalls, 1, reason: 'the cooperative stop hook must be reached');
      expect(scheduler.running(), isEmpty);
    });

    test('test_cancel_unknownId_isANoOp', () async {
      await scheduler.cancel('never-submitted');
      expect(scheduler.pending(), isEmpty);
    });

    test('test_cancel_completedTask_leavesTheTerminalStateAlone', () async {
      final handle = await scheduler.submit(_QuickTask(_descriptor('a'), order));
      await handle.result;

      await scheduler.cancel('a');

      expect(handle.state, TaskState.completed);
    });
  });

  group('pause and resume', () {
    test('test_pause_pendingTask_holdsItAndResumeRequeues', () async {
      scheduler = InMemoryTaskScheduler(maxConcurrent: 1);
      final gate = _GatedTask(_descriptor('blocker'), order);
      final blocker = await scheduler.submit(gate);
      final held = await scheduler.submit(_QuickTask(_descriptor('held'), order));

      expect(await scheduler.pause('held'), isTrue);
      expect(held.state, TaskState.paused);
      expect(scheduler.pending(), isEmpty);

      gate.openGate();
      await blocker.result;
      expect(order, <String>['blocker'], reason: 'a paused task must not start on the freed slot');

      expect(await scheduler.resume('held'), isTrue);
      await held.result;
      expect(order, <String>['blocker', 'held']);
    });

    test('test_pause_runningTask_isRefused', () async {
      final gate = _GatedTask(_descriptor('long'), order);
      await scheduler.submit(gate);
      await settle();

      expect(await scheduler.pause('long'), isFalse);
      gate.openGate();
    });

    test('test_resume_withoutPause_isRefused', () async {
      final handle = await scheduler.submit(_QuickTask(_descriptor('a'), order));
      await handle.result;

      expect(await scheduler.resume('a'), isFalse);
      expect(await scheduler.resume('never'), isFalse);
    });
  });

  group('failure', () {
    test('test_run_throwingTask_isFailedAndTheQueueKeepsDraining', () async {
      final broken = await scheduler.submit(_ThrowingTask(_descriptor('broken')));
      final next = await scheduler.submit(_QuickTask(_descriptor('after'), order));
      final result = await broken.result;
      await next.result;

      expect(broken.state, TaskState.failed);
      expect(result.error?.code, PlatformErrorCodes.taskFailed);
      expect(result.error?.retryable, isTrue);
      expect(next.state, TaskState.completed);
      expect(order, <String>['after']);
    });

    test('test_run_returningFailureResult_isFailedToo', () async {
      // The state a caller reads must not depend on whether the task threw or returned a failure.
      final handle = await scheduler.submit(_FailingTask(_descriptor('soft')));
      await handle.result;

      expect(handle.state, TaskState.failed);
      expect(handle.status.error?.code, 'source.parse_failed');
    });
  });

  group('retention', () {
    test('test_finishedRecords_areBoundedButAStaleHandleStillReportsItsLastStatus', () async {
      scheduler = InMemoryTaskScheduler(finishedLimit: 2);
      final handles = <TaskHandle>[
        for (final id in <String>['a', 'b', 'c', 'd']) await scheduler.submit(_QuickTask(_descriptor(id), order)),
      ];
      await Future.wait(handles.map((handle) => handle.result));

      expect(scheduler.find('a'), isNull, reason: 'the oldest finished record is evicted');
      expect(scheduler.find('d'), isNotNull);
      // Eviction must not turn a completed task into an invented state.
      expect(handles.first.state, TaskState.completed);
      expect(handles.first.progress, isNull);
    });
  });
}

class _FailingTask implements Task {
  _FailingTask(this.descriptor);

  @override
  final TaskDescriptor descriptor;

  @override
  Future<TaskResult> run(TaskContext context) async {
    return TaskResult.failure(
      const PlatformErrorInfo(code: 'source.parse_failed', message: 'the repository changed shape'),
    );
  }

  @override
  Future<void> cancel() async {}
}
