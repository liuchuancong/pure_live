// Module: lib/src/task.dart
// Purpose: The unit of scheduled work and the context handed to it while it runs.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-contracts.md section 16 and docs/architecture/platform-infrastructure.md
// section 7.3. The scheduler runs Source refreshes, repository updates, EPG updates, plugin updates,
// downloads, sync, backup, ticket refreshes, cookie refreshes and cache maintenance through this one shape,
// which is why the task itself stays opaque to the scheduler: it only ever sees a descriptor and a run.

import 'package:pure_live_platform/pure_live_platform.dart';

import 'cancellation.dart';

/// What a running task is told about its own execution.
final class TaskContext {
  TaskContext({required this.descriptor, required this.cancelToken, void Function(double progress)? onProgress})
    : _onProgress = onProgress;

  final TaskDescriptor descriptor;
  final CancellationToken cancelToken;

  final void Function(double progress)? _onProgress;

  bool get isCancelled => cancelToken.isCancelled;

  /// Reports progress in 0..1. Out of range values are clamped rather than rejected: a task that
  /// overshoots by rounding must not break the progress bar.
  void reportProgress(double value) {
    _onProgress?.call(value.clamp(0.0, 1.0).toDouble());
  }

  /// Convenience for the loop that has no progress worth naming.
  void throwIfCancelled() => cancelToken.throwIfCancelled();
}

/// One unit of scheduled work.
abstract interface class Task {
  /// Identity, priority and the deduplication key the scheduler reads before it queues anything.
  TaskDescriptor get descriptor;

  /// Does the work. Returning normally means success; throwing means failure unless the task was
  /// cancelled, in which case the scheduler records `cancelled` instead of `failed`.
  Future<TaskResult> run(TaskContext context);

  /// Cooperative stop, called after [TaskContext.cancelToken] has been signalled.
  ///
  /// The token alone cannot interrupt an `await`, so a task that holds a resource (a socket, a file, a
  /// running script) releases it here. The scheduler waits for this before it treats the task as finished.
  Future<void> cancel();
}
