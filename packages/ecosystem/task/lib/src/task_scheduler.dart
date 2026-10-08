// Module: lib/src/task_scheduler.dart
// Purpose: The scheduler contract and the read-only view a caller holds on a submitted task.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-contracts.md section 16. One scheduler for the whole platform, not one per
// ecosystem: Source refresh, repository update, EPG, plugin update, download, sync, backup, ticket refresh,
// cookie refresh and cache maintenance all submit through here so priorities and deduplication mean the
// same thing everywhere.

import 'dart:async';

import 'package:pure_live_platform/pure_live_platform.dart';

import 'task.dart';

/// A caller's view of one submitted task.
///
/// The handle reads its state through a closure rather than caching it, so a handle taken before a run and
/// one taken after always agree with the scheduler.
final class TaskHandle {
  TaskHandle({required this.descriptor, required TaskStatus Function() statusOf, required Future<TaskResult> result})
    : _statusOf = statusOf,
      result = result;

  final TaskDescriptor descriptor;
  final TaskStatus Function() _statusOf;

  /// Completes when the task reaches a terminal state. A cancelled task completes with a failure result
  /// whose code is `task.cancelled`, never with an exception, so awaiting it cannot crash a caller.
  final Future<TaskResult> result;

  TaskId get id => descriptor.id;

  TaskStatus get status => _statusOf();

  TaskState get state => status.state;

  double? get progress => status.progress;

  @override
  String toString() => 'TaskHandle($id ${state.name})';
}

/// The platform task scheduler.
abstract interface class TaskScheduler {
  /// Queues [task].
  ///
  /// Submitting the same id twice returns the existing handle, and a task whose live
  /// [TaskDescriptor.deduplicationKey] already has one pending or running returns that one instead: three
  /// "refresh TVBox A" requests must produce one run (platform-contracts.md section 16).
  Future<TaskHandle> submit(Task task);

  /// Cancels by id. A pending task never starts; a running one is signalled and given its cancel hook.
  Future<void> cancel(TaskId id);

  /// Holds a pending task back. Returns false for a task that is already running or finished, because
  /// pausing a running task needs cooperation the contract does not define yet.
  Future<bool> pause(TaskId id);

  /// Re-queues a held task. Returns false when [id] is not paused.
  Future<bool> resume(TaskId id);

  /// The handle for [id], including finished ones while they are still retained.
  TaskHandle? find(TaskId id);

  List<TaskHandle> running();

  List<TaskHandle> pending();

  /// Status changes for every task, so a progress UI and diagnostics share one feed.
  Stream<TaskStatus> get updates;
}
