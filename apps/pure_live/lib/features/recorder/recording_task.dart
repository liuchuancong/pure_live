/// One recording task: a room the recorder is set to capture, with the
/// session it last ran.
///
/// The model is deliberately a plain immutable class: the recording engine
/// itself arrives later with the player stack (media_core_recording_ffmpeg);
/// until then the repository stores these tasks and the surfaces read them.
/// A task keeps its room's identity as its id — `platform:roomId`, like a
/// follow — so re-recording a room updates its entry instead of piling up
/// copies.
enum RecordingTaskState {
  /// The engine is capturing the room's stream.
  recording,

  /// The last session ended and its file was saved.
  stopped,

  /// The last session ended in an error; nothing usable was kept.
  failed;

  /// The state stored in JSON: the enum's own name.
  String toJson() => name;

  /// Reads the state back; an unknown name (from a future writer) reads
  /// as [RecordingTaskState.stopped], the quietest guess.
  static RecordingTaskState fromJson(Object? value) =>
      RecordingTaskState.values.asNameMap()[value] ?? RecordingTaskState.stopped;
}

/// A room kept for recording and its last session's facts.
final class RecordingTask {
  /// Creates a task.
  const RecordingTask({
    required this.id,
    required this.platform,
    required this.roomId,
    required this.roomTitle,
    required this.state,
    required this.startedAt,
    this.quality = '',
    this.endedAt,
    this.filePath,
    this.bytes = 0,
  });

  /// Reads a task from its storage JSON; a map without a moment reads as
  /// the epoch, so a half-written entry still lists.
  factory RecordingTask.fromJson(Object? json) {
    final map = switch (json) {
      final Map<String, Object?> map => map,
      final Map<dynamic, dynamic> map => Map<String, Object?>.from(map),
      _ => const <String, Object?>{},
    };
    return RecordingTask(
      id: map['id'] as String? ?? '',
      platform: map['platform'] as String? ?? '',
      roomId: map['roomId'] as String? ?? '',
      roomTitle: map['roomTitle'] as String? ?? '',
      quality: map['quality'] as String? ?? '',
      state: RecordingTaskState.fromJson(map['state']),
      startedAt: DateTime.tryParse(map['startedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      endedAt: DateTime.tryParse(map['endedAt'] as String? ?? ''),
      filePath: map['filePath'] as String?,
      bytes: (map['bytes'] as num?)?.toInt() ?? 0,
    );
  }

  /// The task's identity: `platform:roomId`, the storage entry's key.
  final String id;

  /// The platform (site) id the room belongs to.
  final String platform;

  /// The room's id on its platform.
  final String roomId;

  /// The room title as it was when the task was last seen.
  final String roomTitle;

  /// The quality id the task asks the platform for ('' = the platform's
  /// best, the reference's default).
  final String quality;

  /// Where the task's last session left it.
  final RecordingTaskState state;

  /// When the last session started.
  final DateTime startedAt;

  /// When the last session ended; null while it still runs.
  final DateTime? endedAt;

  /// Where the last session's file landed; null until the engine writes
  /// one.
  final String? filePath;

  /// The last session's file size; the engine reports it as it records.
  final int bytes;

  /// Whether the engine would be capturing this task right now.
  bool get isRunning => state == RecordingTaskState.recording;

  /// The task as a storage JSON map.
  Map<String, Object?> toJson() => {
    'id': id,
    'platform': platform,
    'roomId': roomId,
    'roomTitle': roomTitle,
    'quality': quality,
    'state': state.toJson(),
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt?.toUtc().toIso8601String(),
    'filePath': filePath,
    'bytes': bytes,
  };

  /// Copies the task with the given fields replaced.
  RecordingTask copyWith({
    String? id,
    String? platform,
    String? roomId,
    String? roomTitle,
    String? quality,
    RecordingTaskState? state,
    DateTime? startedAt,
    DateTime? endedAt,
    String? filePath,
    int? bytes,
  }) {
    return RecordingTask(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      roomId: roomId ?? this.roomId,
      roomTitle: roomTitle ?? this.roomTitle,
      quality: quality ?? this.quality,
      state: state ?? this.state,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      filePath: filePath ?? this.filePath,
      bytes: bytes ?? this.bytes,
    );
  }
}
