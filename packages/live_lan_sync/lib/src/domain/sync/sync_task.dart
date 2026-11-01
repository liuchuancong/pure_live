import 'dart:convert' show jsonDecode, jsonEncode;

/// One synchronization run between two devices.
///
/// A task is a persisted fact, not a UI object: it survives restarts and is
/// restored from the store, never from past events (spec §17). Its progress
/// counters are updated as stages complete, and its status follows the
/// stage machine in spec §10.3.
final class SyncTask {
  /// A sync task between this device and [peerDeviceId].
  const new({
    required this.taskId,
    required this.peerDeviceId,
    required this.scopes,
    required this.status,
    this.direction = SyncDirection.push,
    this.stage = SyncTaskStage.planning,
    this.totalChanges = 0,
    this.completedChanges = 0,
    this.totalBytes = 0,
    this.transferredBytes = 0,
    this.startedAt,
    this.completedAt,
    this.error,
  });

  /// Restores a task persisted through [toJson].
  factory fromJson(Map<String, Object?> json) => SyncTask(
    taskId: json['taskId']! as String,
    peerDeviceId: json['peerDeviceId']! as String,
    direction: SyncDirection.values.byName(json['direction']! as String),
    scopes: {...(json['scopes']! as List<Object?>).cast<String>()},
    status: SyncTaskStatus.values.byName(json['status']! as String),
    stage: switch (json['stage']) {
      final String stage => SyncTaskStage.values.byName(stage),
      _ => SyncTaskStage.planning,
    },
    totalChanges: (json['totalChanges']! as num).toInt(),
    completedChanges: (json['completedChanges']! as num).toInt(),
    totalBytes: (json['totalBytes']! as num).toInt(),
    transferredBytes: (json['transferredBytes']! as num).toInt(),
    startedAt: switch (json['startedAt']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    completedAt: switch (json['completedAt']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    error: switch (json['error']) {
      final String value => value,
      _ => null,
    },
  );

  /// Restores a task from [encode].
  factory decode(String raw) => SyncTask.fromJson(jsonDecode(raw)! as Map<String, Object?>);

  /// The unique id of this run.
  final String taskId;

  /// The device syncing with this one.
  final String peerDeviceId;

  /// Which way data flows.
  final SyncDirection direction;

  /// The scopes the task covers.
  final Set<String> scopes;

  /// The task's outcome state.
  final SyncTaskStatus status;

  /// The fine-grained stage within the status, when the task is running.
  final SyncTaskStage stage;

  /// How many changes the exchange plans to move.
  final int totalChanges;

  /// How many changes have been applied and confirmed.
  final int completedChanges;

  /// How many file bytes the exchange plans to move.
  final int totalBytes;

  /// How many file bytes have been transferred and verified.
  final int transferredBytes;

  /// When the task started.
  final DateTime? startedAt;

  /// When the task reached a terminal status.
  final DateTime? completedAt;

  /// The failure description, present when [status] is [SyncTaskStatus.failed]
  /// or [SyncTaskStatus.partiallyCompleted]. Never carries secrets or full
  /// payloads.
  final String? error;

  /// Whether the task is still doing or awaiting work.
  bool get isActive =>
      status == SyncTaskStatus.pending || status == SyncTaskStatus.paused || _runningStatuses.contains(status);

  /// Overall progress in 0.0..1.0, combining changes and bytes by their own
  /// totals; a task with no planned work reports 0.
  double get progress {
    final changeFraction = totalChanges == 0 ? 0.0 : completedChanges / totalChanges;
    final byteFraction = totalBytes == 0 ? 0.0 : transferredBytes / totalBytes;
    if (totalChanges == 0 && totalBytes == 0) return 0;
    if (totalBytes == 0) return changeFraction;
    if (totalChanges == 0) return byteFraction;
    return (changeFraction + byteFraction) / 2;
  }

  /// A copy with the running fields of a live exchange updated.
  SyncTask progressed({
    SyncTaskStatus? status,
    SyncTaskStage? stage,
    int? completedChanges,
    int? transferredBytes,
    int? totalChanges,
    int? totalBytes,
  }) => SyncTask(
    taskId: taskId,
    peerDeviceId: peerDeviceId,
    direction: direction,
    scopes: scopes,
    status: status ?? this.status,
    stage: stage ?? this.stage,
    totalChanges: totalChanges ?? this.totalChanges,
    completedChanges: completedChanges ?? this.completedChanges,
    totalBytes: totalBytes ?? this.totalBytes,
    transferredBytes: transferredBytes ?? this.transferredBytes,
    startedAt: startedAt,
    completedAt: completedAt,
    error: error,
  );

  /// A copy marked terminal with [status] at [at].
  SyncTask finished({required SyncTaskStatus status, required DateTime at, String? error}) => SyncTask(
    taskId: taskId,
    peerDeviceId: peerDeviceId,
    direction: direction,
    scopes: scopes,
    status: status,
    stage: SyncTaskStage.idle,
    totalChanges: totalChanges,
    completedChanges: completedChanges,
    totalBytes: totalBytes,
    transferredBytes: transferredBytes,
    startedAt: startedAt,
    completedAt: at,
    error: error ?? this.error,
  );

  /// The JSON form persisted in the host's store.
  Map<String, Object?> toJson() => <String, Object?>{
    'taskId': taskId,
    'peerDeviceId': peerDeviceId,
    'direction': direction.name,
    'scopes': scopes.toList(),
    'status': status.name,
    'stage': stage.name,
    'totalChanges': totalChanges,
    'completedChanges': completedChanges,
    'totalBytes': totalBytes,
    'transferredBytes': transferredBytes,
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'error': error,
  };

  /// The JSON-encoded form, for stores that persist whole strings.
  String encode() => jsonEncode(toJson());

  static const Set<SyncTaskStatus> _runningStatuses = {
    SyncTaskStatus.discovering,
    SyncTaskStatus.connecting,
    SyncTaskStatus.authenticating,
    SyncTaskStatus.negotiating,
    SyncTaskStatus.planning,
    SyncTaskStatus.transferring,
    SyncTaskStatus.applying,
    SyncTaskStatus.resolvingConflicts,
  };

  @override
  String toString() => 'SyncTask($taskId, $peerDeviceId, ${direction.name}/${status.name})';
}

/// Which way a task moves data.
enum SyncDirection {
  /// This device sends; the peer only applies.
  push,

  /// This device receives; the peer only sends.
  pull,

  /// Both ends send and apply.
  bidirectional,
}

/// The outcome state of a task.
enum SyncTaskStatus {
  /// Created but not yet scheduled.
  pending,

  /// Looking for the peer (manual address or mDNS).
  discovering,

  /// Opening a transport session.
  connecting,

  /// Verifying the peer's identity.
  authenticating,

  /// Agreeing on protocol and schema versions.
  negotiating,

  /// Comparing manifests and computing the plan.
  planning,

  /// Moving changes and files.
  transferring,

  /// Applying received changes through the adapters.
  applying,

  /// Settling detected concurrent modifications.
  resolvingConflicts,

  /// Every planned change and byte confirmed.
  completed,

  /// Finished with some parts failed; [SyncTask.error] says what.
  partiallyCompleted,

  /// Failed; retryable per the error's category.
  failed,

  /// Cancelled by the user or the host.
  cancelled,

  /// Paused and resumable; partial progress is kept.
  paused,
}

/// The fine-grained stage within a running task, for progress reporting.
enum SyncTaskStage {
  /// Not running.
  idle,

  /// Finding the peer.
  discovery,

  /// Opening the session.
  connection,

  /// Identity verification.
  authentication,

  /// Version and schema negotiation.
  negotiation,

  /// Manifest comparison and plan computation.
  planning,

  /// Change batches in flight.
  changes,

  /// File transfers in flight.
  files,

  /// Applying received changes.
  application,

  /// Conflict resolution.
  conflicts,

  /// Cursor confirmation.
  confirmation,
}
