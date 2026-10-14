import 'package:live_record_core/src/record_naming.dart';
import 'package:live_record_core/src/record_status.dart';

/// What must be known about a room in order to record it.
///
/// Immutable and persisted: it is the identity of the job, not its runtime state.
/// A stream address is deliberately absent — a signed live URL expires, and
/// storing one is both useless after a restart and a credential nobody should be
/// keeping in a task file.
final class RecordTarget {
  /// Creates a room target.
  const new({required this.platform, required this.roomId, required this.anchorName, this.roomTitle, this.watchUrl});

  /// Platform id (`douyin`, `bilibili`).
  final String platform;

  /// Room id, stable across a streamer's sessions.
  final String roomId;

  /// The anchor's own name, in whatever script the platform returns it.
  final String anchorName;

  /// Last known room title. Changes per session, and is only ever used for the
  /// display name, never for a path FFmpeg opens.
  final String? roomTitle;

  /// The room page address, when the host has one — what a notification deep-links
  /// to and what a status endpoint is asked about. Never a media URL.
  final String? watchUrl;

  /// JSON shape of this target.
  Map<String, Object?> toJson() => <String, Object?>{
    'platform': platform,
    'roomId': roomId,
    'anchorName': anchorName,
    if (roomTitle != null) 'roomTitle': roomTitle,
    if (watchUrl != null) 'watchUrl': watchUrl,
  };

  /// Reads [json]; null when the platform or room id is missing, which is a record
  /// that cannot be recorded and should be dropped rather than guessed at.
  static RecordTarget? fromJson(Map<String, Object?> json) {
    final platform = json['platform'] as String?;
    final roomId = json['roomId'] as String?;

    if (platform == null || roomId == null || roomId.isEmpty) {
      return null;
    }

    return RecordTarget(
      platform: platform,
      roomId: roomId,
      anchorName: (json['anchorName'] as String?) ?? roomId,
      roomTitle: json['roomTitle'] as String?,
      watchUrl: json['watchUrl'] as String?,
    );
  }

  @override
  String toString() => 'RecordTarget($platform/$roomId, $anchorName)';
}

/// One finished capture attempt whose segments still have to be joined.
///
/// A signed CDN ends a connection while the room stays live; the recorder
/// reconnects and joins the attempts only when the viewer-visible session ends.
/// That leaves windows of media on disk whose only proof is this record — which is
/// why it is persisted the moment an attempt ends, and why a power loss afterwards
/// still resolves into a complete file.
final class PendingAttempt {
  /// Creates an attempt record.
  const new({
    required this.directory,
    required this.prefix,
    required this.segments,
    required this.bytes,
    required this.mediaTime,
    this.damaged = false,
  });

  /// Directory the segments were written to.
  final String directory;

  /// Segment name prefix, as FFmpeg was handed it.
  final String prefix;

  /// How many segments the journal listed when the attempt ended.
  final int segments;

  /// Bytes on disk for this attempt.
  final int bytes;

  /// Media time the capture reported.
  final Duration mediaTime;

  /// The capture reported damaged packets.
  ///
  /// A join across a damaged attempt is refused rather than attempted: the
  /// segments are the only evidence of what happened in that window, and a merge
  /// that rewrites them into a corrupt container destroys both the recording and
  /// the reason it failed.
  final bool damaged;

  /// JSON shape.
  Map<String, Object?> toJson() => <String, Object?>{
    'directory': directory,
    'prefix': prefix,
    'segments': segments,
    'bytes': bytes,
    'mediaMs': mediaTime.inMilliseconds,
    if (damaged) 'damaged': true,
  };

  /// Reads [json]; null without a directory or a prefix.
  static PendingAttempt? fromJson(Map<String, Object?> json) {
    final directory = json['directory'] as String?;
    final prefix = json['prefix'] as String?;

    if (directory == null || directory.isEmpty || prefix == null || prefix.isEmpty) {
      return null;
    }

    return PendingAttempt(
      directory: directory,
      prefix: prefix,
      segments: (json['segments'] as num?)?.toInt() ?? 0,
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      mediaTime: Duration(milliseconds: (json['mediaMs'] as num?)?.toInt() ?? 0),
      damaged: json['damaged'] == true,
    );
  }

  @override
  String toString() => 'PendingAttempt($prefix, $segments segments, $bytes B${damaged ? ', damaged' : ''})';
}

/// One recording job: the room, where its files are, and what is still owed.
///
/// Mutable by design and owned by the orchestrator, which updates it in place and
/// persists it after every change that a crash would otherwise lose. What is
/// persisted is exactly what a later launch needs to finish the job: the identity,
/// the paths, the pending attempts, and the display name that has not been applied
/// yet. What is never persisted is a signed media URL.
final class RecordTask {
  /// Creates a task.
  new({
    required this.taskId,
    required this.target,
    required this.paths,
    required this.createdAt,
    this.status = RecordStatus.queued,
    this.roomState = RoomState.unknown,
    this.stage = ArtifactStage.nothing,
    this.sawLive = false,
    this.pendingAttempts = const <PendingAttempt>[],
    this.mergedFile,
    this.publishedFile,
    this.desiredFile,
    this.recordedFor = Duration.zero,
    this.bytesWritten = 0,
    this.segments = 0,
    this.failureReason,
    this.failureCount = 0,
    this.startedAt,
  });

  /// A task for [target], named by [paths], created at [now].
  factory forTarget({required RecordTarget target, required RecordPaths paths, required DateTime now}) {
    return RecordTask(taskId: paths.taskId, target: target, paths: paths, createdAt: now);
  }

  /// ASCII capture identifier, and the prefix every file FFmpeg writes carries.
  final String taskId;

  /// The room being recorded.
  final RecordTarget target;

  /// Where its files go and what they are called.
  final RecordPaths paths;

  /// When the task was created.
  final DateTime createdAt;

  /// Where the task is.
  RecordStatus status;

  /// What was concluded about the room.
  RoomState roomState;

  /// What the files on disk still owe.
  ArtifactStage stage;

  /// Whether this session has been seen live.
  ///
  /// The bit that turns a second non-live answer into [RoomState.ended] instead of
  /// [RoomState.waiting], and the reason a 关播 notification fires exactly once and
  /// a room that has never started is silent. Persisted, because a restart must not
  /// forget that a broadcast happened.
  bool sawLive;

  /// Attempts whose segments are not joined yet.
  List<PendingAttempt> pendingAttempts;

  /// The joined file, under its capture name.
  String? mergedFile;

  /// The joined file, after the display rename.
  String? publishedFile;

  /// The display name still to be applied, when a rename has not run or failed.
  String? desiredFile;

  /// Total media time across the attempts recorded so far.
  Duration recordedFor;

  /// Bytes on disk for this task.
  int bytesWritten;

  /// Segments the journals have listed across all attempts.
  int segments;

  /// Why the task last failed, when it did.
  String? failureReason;

  /// How many consecutive failures the current room has produced.
  int failureCount;

  /// When the current capture started, or null between attempts.
  DateTime? startedAt;

  /// Whether the room has been seen live at all.
  bool get everLive => sawLive;

  /// Whether anything is still owed to the files: a join, or a name.
  bool get hasOutstandingWork =>
      pendingAttempts.isNotEmpty || (mergedFile != null && publishedFile == null) || desiredFile != null;

  /// Whether this task occupies a capture slot or a process.
  bool get isBusy => statusIsBusy(status);

  /// Media time and bytes still waiting to be joined.
  ({Duration mediaTime, int bytes, int segments}) get pendingTotals {
    var media = Duration.zero;
    var total = 0;
    var count = 0;

    for (final attempt in pendingAttempts) {
      media += attempt.mediaTime;
      total += attempt.bytes;
      count += attempt.segments;
    }

    return (mediaTime: media, bytes: total, segments: count);
  }

  /// A copy with the given fields replaced.
  RecordTask copyWith({
    RecordStatus? status,
    RoomState? roomState,
    ArtifactStage? stage,
    bool? sawLive,
    List<PendingAttempt>? pendingAttempts,
    String? mergedFile,
    String? publishedFile,
    String? desiredFile,
    Duration? recordedFor,
    int? bytesWritten,
    int? segments,
    String? failureReason,
    int? failureCount,
    DateTime? startedAt,
  }) {
    return RecordTask(
      taskId: taskId,
      target: target,
      paths: paths,
      createdAt: createdAt,
      status: status ?? this.status,
      roomState: roomState ?? this.roomState,
      stage: stage ?? this.stage,
      sawLive: sawLive ?? this.sawLive,
      pendingAttempts: pendingAttempts ?? this.pendingAttempts,
      mergedFile: mergedFile ?? this.mergedFile,
      publishedFile: publishedFile ?? this.publishedFile,
      desiredFile: desiredFile ?? this.desiredFile,
      recordedFor: recordedFor ?? this.recordedFor,
      bytesWritten: bytesWritten ?? this.bytesWritten,
      segments: segments ?? this.segments,
      failureReason: failureReason ?? this.failureReason,
      failureCount: failureCount ?? this.failureCount,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  /// The stored shape. Field names are stable: a task written by an earlier build
  /// must still load after an upgrade, so values are read tolerantly (numeric drift,
  /// absent optionals) rather than strictly.
  Map<String, Object?> toJson() => <String, Object?>{
    'taskId': taskId,
    'target': target.toJson(),
    'root': paths.rootDirectory,
    'platform': paths.platformSlug,
    'anchor': paths.anchorSlug,
    'day': paths.day,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'roomState': roomState.name,
    'stage': stage.name,
    'sawLive': sawLive,
    'pending': pendingAttempts.map((attempt) => attempt.toJson()).toList(),
    if (mergedFile != null) 'mergedFile': mergedFile,
    if (publishedFile != null) 'publishedFile': publishedFile,
    if (desiredFile != null) 'desiredFile': desiredFile,
    'recordedMs': recordedFor.inMilliseconds,
    'bytes': bytesWritten,
    'segments': segments,
    if (failureReason != null) 'failure': failureReason,
    'failures': failureCount,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
  };

  /// Reads a stored task. Null when the record cannot name a room or a directory:
  /// a task that cannot say where its files are cannot be recovered, and guessing
  /// a path is how one recording is written into another.
  static RecordTask? fromJson(Map<String, Object?> json) {
    final taskId = json['taskId'] as String?;
    final root = json['root'] as String?;
    final day = json['day'] as String?;

    if (taskId == null || taskId.isEmpty || root == null || day == null) {
      return null;
    }

    final target = RecordTarget.fromJson((json['target'] as Map<String, Object?>?) ?? const <String, Object?>{});

    if (target == null) {
      return null;
    }

    final paths = RecordPaths(
      rootDirectory: root,
      platformSlug: (json['platform'] as String?) ?? target.platform,
      anchorSlug: (json['anchor'] as String?) ?? target.roomId,
      day: day,
      taskId: taskId,
    );

    return RecordTask(
      taskId: taskId,
      target: target,
      paths: paths,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.utc(1970),
      status: _byName(RecordStatus.values, json['status'] as String?, RecordStatus.queued),
      roomState: _byName(RoomState.values, json['roomState'] as String?, RoomState.unknown),
      stage: _byName(ArtifactStage.values, json['stage'] as String?, ArtifactStage.nothing),
      sawLive: json['sawLive'] == true,
      pendingAttempts: _attempts(json['pending']),
      mergedFile: json['mergedFile'] as String?,
      publishedFile: json['publishedFile'] as String?,
      desiredFile: json['desiredFile'] as String?,
      recordedFor: Duration(milliseconds: (json['recordedMs'] as num?)?.toInt() ?? 0),
      bytesWritten: (json['bytes'] as num?)?.toInt() ?? 0,
      segments: (json['segments'] as num?)?.toInt() ?? 0,
      failureReason: json['failure'] as String?,
      failureCount: (json['failures'] as num?)?.toInt() ?? 0,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
    );
  }

  @override
  String toString() =>
      'RecordTask($taskId, ${target.anchorName}, ${status.name}/${roomState.name}/${stage.name}, '
      '${pendingAttempts.length} pending)';
}

List<PendingAttempt> _attempts(Object? value) {
  if (value is! List) {
    return const <PendingAttempt>[];
  }

  return value
      .whereType<Map<Object?, Object?>>()
      .map((entry) {
        return PendingAttempt.fromJson(entry.cast<String, Object?>());
      })
      .nonNulls
      .toList(growable: false);
}

T _byName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) {
    return fallback;
  }

  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }

  return fallback;
}
