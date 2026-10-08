// Module: lib/src/models/task/task_models.dart
// Purpose: The task vocabulary: what a task is, how it is prioritised and how its state is reported.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-models.md section 13 and docs/contracts/platform-contracts.md section 16.
// These are the serialisable halves. TaskContext and CancelToken are runtime objects and therefore belong
// to the scheduler package, and cancellation itself is media_core's type mapped at the wiring layer
// (platform-models.md section 2); docs/architecture/evolution.md forbids renaming these values later.

import '../../support/json.dart';
import '../error/platform_error_info.dart';
import '../identifiers.dart';

/// Where a task sits in the queue. Values follow platform-infrastructure.md section 7.3.
enum TaskPriority { critical, high, normal, low, background }

/// What the scheduler needs to know before it runs anything.
final class TaskDescriptor {
  const TaskDescriptor({
    required this.id,
    required this.type,
    this.priority = TaskPriority.normal,
    this.networkRequired = false,
    this.backgroundAllowed = true,
    this.deduplicationKey,
    this.metadata = const <String, Object?>{},
  });

  factory TaskDescriptor.fromJson(Map<String, Object?> json) => TaskDescriptor(
    id: requireString(json, 'id', 'task_descriptor'),
    type: requireString(json, 'type', 'task_descriptor'),
    priority: enumByName(TaskPriority.values, json['priority'] as String?) ?? TaskPriority.normal,
    networkRequired: json['networkRequired'] as bool? ?? false,
    backgroundAllowed: json['backgroundAllowed'] as bool? ?? true,
    deduplicationKey: json['deduplicationKey'] as String?,
    metadata: asObjectMap(json['metadata']),
  );

  final TaskId id;

  /// A namespaced kind, for example `source.refresh` or `ticket.refresh`; the scheduler never interprets it.
  final String type;
  final TaskPriority priority;

  /// Recorded so a metered or offline device can defer the task; the scheduler does not itself read the network.
  final bool networkRequired;

  /// False means the task must not start while the app is backgrounded.
  final bool backgroundAllowed;

  /// Tasks sharing a live key must not run at the same time (platform-contracts.md section 16), which is
  /// why three "refresh TVBox A" requests collapse into one run.
  final String? deduplicationKey;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'type': type,
    'priority': priority.name,
    if (networkRequired) 'networkRequired': true,
    if (!backgroundAllowed) 'backgroundAllowed': false,
    if (deduplicationKey != null) 'deduplicationKey': deduplicationKey,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  @override
  String toString() => 'TaskDescriptor($id ${priority.name})';

  /// Identity is the id alone; a progress update must not turn a task into a new key.
  @override
  bool operator ==(Object other) => other is TaskDescriptor && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Where a task is. `cancelled` is a terminal state of its own, never folded into `failed`
/// (platform-models.md section 20 invariant 9).
enum TaskState { pending, running, paused, completed, failed, cancelled }

/// A reported state change.
final class TaskStatus {
  const TaskStatus({
    required this.taskId,
    required this.state,
    this.progress,
    this.startedAt,
    this.completedAt,
    this.error,
    this.metadata = const <String, Object?>{},
  });

  factory TaskStatus.fromJson(Map<String, Object?> json) => TaskStatus(
    taskId: requireString(json, 'taskId', 'task_status'),
    state: enumByName(TaskState.values, json['state'] as String?) ?? TaskState.pending,
    progress: (json['progress'] as num?)?.toDouble(),
    startedAt: parseUtc(json['startedAt']),
    completedAt: parseUtc(json['completedAt']),
    error: json['error'] == null ? null : PlatformErrorInfo.fromJson(asObjectMap(json['error'])),
    metadata: asObjectMap(json['metadata']),
  );

  /// Carried so a broadcast of statuses can be attributed without the reader keeping its own index.
  final TaskId taskId;
  final TaskState state;

  /// Null means the task has no meaningful progress, which most of them do not.
  final double? progress;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final PlatformErrorInfo? error;
  final Map<String, Object?> metadata;

  bool get isTerminal => state == TaskState.completed || state == TaskState.failed || state == TaskState.cancelled;

  Map<String, Object?> toJson() => <String, Object?>{
    'taskId': taskId,
    'state': state.name,
    if (progress != null) 'progress': progress,
    if (startedAt != null) 'startedAt': formatUtc(startedAt),
    if (completedAt != null) 'completedAt': formatUtc(completedAt),
    if (error != null) 'error': error!.toJson(),
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  @override
  String toString() => 'TaskStatus($taskId ${state.name}${progress == null ? '' : ' ${(progress! * 100).round()}%'})';
}

/// What a run produced.
final class TaskResult {
  const TaskResult({required this.success, this.value, this.error, this.metadata = const <String, Object?>{}});

  factory TaskResult.fromJson(Map<String, Object?> json) => TaskResult(
    success: json['success'] as bool? ?? false,
    error: json['error'] == null ? null : PlatformErrorInfo.fromJson(asObjectMap(json['error'])),
    metadata: asObjectMap(json['metadata']),
  );

  /// Not serialised: a result value is whatever the task produced and belongs to the caller, not to storage.
  final Object? value;
  final bool success;
  final PlatformErrorInfo? error;
  final Map<String, Object?> metadata;

  static TaskResult ok([Object? value]) => TaskResult(success: true, value: value);

  static TaskResult failure(PlatformErrorInfo error) => TaskResult(success: false, value: null, error: error);

  Map<String, Object?> toJson() => <String, Object?>{
    'success': success,
    if (error != null) 'error': error!.toJson(),
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  @override
  String toString() => 'TaskResult(${success ? 'success' : 'failure'}${error == null ? '' : ' ${error!.code}'})';
}
