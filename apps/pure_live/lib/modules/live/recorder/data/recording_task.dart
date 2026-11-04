/// One recording task: a room the recorder is set to capture, with the
/// session it last ran.
///
/// The model is deliberately a plain immutable class: the engine drives it
/// through `recorder_engine.dart` (FFmpeg over the media_core recording
/// stack), and the surfaces read the facts it leaves behind. A task keeps
/// its room's identity as its id — `platform:roomId`, like a follow — so
/// re-recording a room updates its entry instead of piling up copies.
enum RecordingTaskState {
  /// The engine is capturing the room's stream.
  recording,

  /// The task is kept for a room that is not live yet: the live check in
  /// `recording_monitor.dart` starts it when the room goes live.
  waiting,

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
/// The platform id an IPTV recording is filed under.
///
/// It is also the second folder of a take (`<root>/<day>/iptv/<channel>/<take>/`),
/// which is what lets the live centre and the IPTV one each list their own
/// recordings out of the single tree the recorder writes. Both sides name it
/// through this constant so the two lists cannot drift apart by spelling.
const String kIptvRecordingPlatform = 'iptv';

/// The warning a take's row carries once its file is gone — deleted from the
/// player or from the library. The row keeps naming the folder, and this is how
/// the pages tell "saved, and the library shows it" from "saved, and nothing is
/// left to show".
const String kRecordingFileDeletedWarning = 'file-deleted';

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
    this.enabled = true,
    this.checkSeconds = 60,
    this.checkBackoff = true,
    this.maxCheckSeconds = 3600,
    this.anchorName = '',
    this.anchorAvatarUrl = '',
    this.coverUrl = '',
    this.endedAt,
    this.filePath,
    this.bytes = 0,
    this.durationMs = 0,
    this.errorText = '',
    this.scheduleEnabled = false,
    this.scheduleDays = const [1, 2, 3, 4, 5, 6, 7],
    this.scheduleStartMinutes = 1200,
    this.scheduleEndMinutes = 1440,
    this.stopAtWindowEnd = false,
    this.postProcessing = false,
    this.postProcessingProgress = -1,
    this.warning = '',
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
      enabled: map['enabled'] as bool? ?? true,
      checkSeconds: ((map['checkSeconds'] as num?)?.toInt() ?? 60).clamp(10, 300),
      checkBackoff: map['checkBackoff'] as bool? ?? true,
      maxCheckSeconds: ((map['maxCheckSeconds'] as num?)?.toInt() ?? 3600).clamp(60, 3600),
      anchorName: map['anchorName'] as String? ?? '',
      anchorAvatarUrl: map['anchorAvatarUrl'] as String? ?? '',
      coverUrl: map['coverUrl'] as String? ?? '',
      state: RecordingTaskState.fromJson(map['state']),
      startedAt: DateTime.tryParse(map['startedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      endedAt: DateTime.tryParse(map['endedAt'] as String? ?? ''),
      filePath: map['filePath'] as String?,
      bytes: (map['bytes'] as num?)?.toInt() ?? 0,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      errorText: map['errorText'] as String? ?? '',
      scheduleEnabled: map['scheduleEnabled'] as bool? ?? false,
      scheduleDays: _daysFromJson(map['scheduleDays']),
      scheduleStartMinutes: ((map['scheduleStart'] as num?)?.toInt() ?? 1200).clamp(0, 1439),
      scheduleEndMinutes: ((map['scheduleEnd'] as num?)?.toInt() ?? 1440).clamp(0, 1440),
      stopAtWindowEnd: map['stopAtWindowEnd'] as bool? ?? false,
      postProcessing: map['postProcessing'] as bool? ?? false,
      postProcessingProgress: (map['postProcessingProgress'] as num?)?.toDouble() ?? -1,
      warning: map['warning'] as String? ?? '',
    );
  }

  /// The weekdays a stored schedule names; an empty or unreadable list is
  /// every day, which is what a schedule-less task means.
  static List<int> _daysFromJson(Object? raw) {
    if (raw is! List) return const [1, 2, 3, 4, 5, 6, 7];
    final days = <int>{
      for (final value in raw)
        if (value is num && value >= 1 && value <= 7) value.toInt(),
    }.toList()..sort();
    return days.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : days;
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

  /// The streamer's name as the room showed it when the subscription was
  /// saved, so the card names the anchor even when the room is in neither the
  /// follows nor the history store.
  final String anchorName;

  /// The streamer's avatar, cached with the same snapshot.
  final String anchorAvatarUrl;

  /// The room's cover, cached with the same snapshot.
  final String coverUrl;

  /// How often this room's live check runs, in seconds (10–300).
  ///
  /// The cadence belongs to the room: a room watched for one weekly show and
  /// a room watched all day should not share one interval.
  final int checkSeconds;

  /// Whether this room's failed checks back off exponentially.
  final bool checkBackoff;

  /// The ceiling the backoff may reach, in seconds (60–3600).
  final int maxCheckSeconds;

  /// Whether this room is still watched.
  ///
  /// The row is a subscription, not a session: it outlives every take, and
  /// this switch is what pauses or resumes the watching. A paused row keeps
  /// its last take's facts and its place in the list.
  final bool enabled;

  /// Where the task's last session left it.
  final RecordingTaskState state;

  /// When the last session started.
  final DateTime startedAt;

  /// When the last session ended; null while it still runs.
  final DateTime? endedAt;

  /// Where the last session's take landed: the joined MP4 once the
  /// post-recording join ran, otherwise the take's directory. Null until
  /// the engine writes something.
  final String? filePath;

  /// The last session's file size; the engine reports it as it records.
  final int bytes;

  /// Media time the last session captured, in milliseconds.
  ///
  /// This is the stream's own clock, not wall time: a source that stalled
  /// for a minute did not record a minute. The card reads it with [bytes]
  /// to show the take's length and its average write rate.
  final int durationMs;

  /// Why the last session failed ('' while it tells nothing). The engine
  /// writes the FFmpeg/backend's own words, trimmed to one paragraph.
  final String errorText;

  /// Whether the task only checks its room inside [scheduleDays] and
  /// [scheduleStartMinutes]–[scheduleEndMinutes].
  ///
  /// Off means the waiting task is checked at every tick, which is the
  /// original "record whenever live" behaviour.
  final bool scheduleEnabled;

  /// Weekdays the window applies to, Monday = 1 … Sunday = 7.
  ///
  /// All seven means every day. An empty list is read back as every day.
  final List<int> scheduleDays;

  /// Window start, minutes after midnight (0–1439).
  final int scheduleStartMinutes;

  /// Window end, minutes after midnight (0–1440).
  ///
  /// 1440 is 24:00, which a picker shows as 00:00 but keeps as the end of the
  /// same day rather than the start of an overnight one. A start later than
  /// the end is an overnight window (for example 22:00–02:00).
  final int scheduleEndMinutes;

  /// Whether a take still running at the window's end is stopped.
  ///
  /// Off keeps recording until the stream ends, which is the default: a
  /// window decides when to start, not when to cut a live take.
  final bool stopAtWindowEnd;

  /// Whether the take's post-processing (join, transcode, rename) is running.
  ///
  /// The capture is already saved when this becomes true. A card shows the
  /// take as "processing" until the join/rename finishes, so a viewer does not
  /// open a folder of segments and conclude the recording failed.
  final bool postProcessing;

  /// How far the post-processing run has got, 0–1, or -1 while indeterminate.
  ///
  /// A join reports output bytes against the segments' own size; a transcode
  /// reports FFmpeg's processed media time against the input's duration.
  final double postProcessingProgress;

  /// A stable warning code from the last post-processing run, or ''.
  ///
  /// Known values: `join-failed`, `transcode-failed`, `finalize-failed`,
  /// `stale`. The page maps them to the viewer's language; the files are kept
  /// in every case.
  final String warning;

  /// Whether the engine would be capturing this task right now.
  bool get isRunning => state == RecordingTaskState.recording;

  /// Whether the live check keeps this room watched: on, and with no session
  /// owning it. Every settled session keeps its row armed, so a room recorded
  /// once stays a subscription and is begun again the next time it goes live.
  bool get isArmed =>
      enabled &&
      !postProcessing &&
      (state == RecordingTaskState.waiting ||
          state == RecordingTaskState.stopped ||
          state == RecordingTaskState.failed);

  /// Whether only the live check can move this task forward.
  ///
  /// A waiting room is begun when it goes on air, and a scheduled task that has
  /// ended waits for its next window to re-arm it; with the live check switched
  /// off neither happens on its own, and the recorder page says so. Anything
  /// capturing, or finished without a schedule, is not waiting on the check.
  bool get needsLiveCheck => isArmed;

  /// The folder the take lives in, read back from [filePath] — which is the
  /// joined file once the post-recording steps wrote one, and the take's own
  /// directory before that. The string is carried as the recorder wrote it, so
  /// its separators say which style the path is, and the answer is text rather
  /// than a `dart:io` type: a task tells where its take is whether or not
  /// anything is here to read it.
  String get takeDirectory {
    final stored = (filePath ?? '').trim();
    if (stored.isEmpty) return '';
    // The row names the take's folder, or the one file the post-recording steps
    // wrote inside it — and that file is always `<name>.mp4`. Testing for an
    // extension rather than “does the tail contain a dot” is what keeps a take
    // whose own folder is named after a room like “3.5 万粉纪念” from being read
    // as a file and reported as its parent.
    if (!stored.toLowerCase().endsWith('.mp4')) return stored;
    final separator = stored.contains(r'\') ? r'\' : '/';
    final index = stored.lastIndexOf(separator);
    return index <= 0 ? stored : stored.substring(0, index);
  }

  /// The task as a storage JSON map.
  Map<String, Object?> toJson() => {
    'id': id,
    'platform': platform,
    'roomId': roomId,
    'roomTitle': roomTitle,
    'quality': quality,
    'enabled': enabled,
    'checkSeconds': checkSeconds,
    'checkBackoff': checkBackoff,
    'maxCheckSeconds': maxCheckSeconds,
    'anchorName': anchorName,
    'anchorAvatarUrl': anchorAvatarUrl,
    'coverUrl': coverUrl,
    'state': state.toJson(),
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt?.toUtc().toIso8601String(),
    'filePath': filePath,
    'bytes': bytes,
    'durationMs': durationMs,
    'errorText': errorText,
    'scheduleEnabled': scheduleEnabled,
    'scheduleDays': scheduleDays,
    'scheduleStart': scheduleStartMinutes,
    'scheduleEnd': scheduleEndMinutes,
    'stopAtWindowEnd': stopAtWindowEnd,
    'postProcessing': postProcessing,
    'postProcessingProgress': postProcessingProgress,
    'warning': warning,
  };

  /// Copies the task with the given fields replaced.
  RecordingTask copyWith({
    String? id,
    String? platform,
    String? roomId,
    String? roomTitle,
    String? quality,
    bool? enabled,
    int? checkSeconds,
    bool? checkBackoff,
    int? maxCheckSeconds,
    String? anchorName,
    String? anchorAvatarUrl,
    String? coverUrl,
    RecordingTaskState? state,
    DateTime? startedAt,
    DateTime? endedAt,
    String? filePath,
    int? bytes,
    int? durationMs,
    String? errorText,
    bool? scheduleEnabled,
    List<int>? scheduleDays,
    int? scheduleStartMinutes,
    int? scheduleEndMinutes,
    bool? stopAtWindowEnd,
    bool? postProcessing,
    double? postProcessingProgress,
    String? warning,
  }) {
    return RecordingTask(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      roomId: roomId ?? this.roomId,
      roomTitle: roomTitle ?? this.roomTitle,
      quality: quality ?? this.quality,
      enabled: enabled ?? this.enabled,
      checkSeconds: checkSeconds ?? this.checkSeconds,
      checkBackoff: checkBackoff ?? this.checkBackoff,
      maxCheckSeconds: maxCheckSeconds ?? this.maxCheckSeconds,
      anchorName: anchorName ?? this.anchorName,
      anchorAvatarUrl: anchorAvatarUrl ?? this.anchorAvatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      state: state ?? this.state,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      filePath: filePath ?? this.filePath,
      bytes: bytes ?? this.bytes,
      durationMs: durationMs ?? this.durationMs,
      errorText: errorText ?? this.errorText,
      scheduleEnabled: scheduleEnabled ?? this.scheduleEnabled,
      scheduleDays: scheduleDays == null ? this.scheduleDays : List.unmodifiable(scheduleDays),
      scheduleStartMinutes: scheduleStartMinutes ?? this.scheduleStartMinutes,
      scheduleEndMinutes: scheduleEndMinutes ?? this.scheduleEndMinutes,
      stopAtWindowEnd: stopAtWindowEnd ?? this.stopAtWindowEnd,
      postProcessing: postProcessing ?? this.postProcessing,
      postProcessingProgress: postProcessingProgress ?? this.postProcessingProgress,
      warning: warning ?? this.warning,
    );
  }
}
