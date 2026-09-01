import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/recorder/services/recorder_diagnostics.dart';

class LiveRecordTask {
  /// =========================
  /// 基础信息
  /// =========================

  final String taskId;

  final String roomId;

  final String platform;

  String title;

  String nick;

  String avatar;

  String cover;

  LiveStatus liveStatus;

  String watching;

  String followers;

  bool isRecord;

  /// =========================
  /// 当前录制信息
  /// =========================

  String? currentUrl;

  String? selectedLine;

  String? selectedQuality;

  /// Stable retry cursor. Unlike [currentUrl], these values contain no signed
  /// stream data and can safely survive process restarts.
  String? selectedQualityId;

  int? selectedLineIndex;

  /// 输出目录
  String? outputDir;

  /// Completed native input attempts whose MPEG-TS segments still need to be
  /// remuxed. A short-lived CDN can deliberately end one HTTP transport while
  /// the room remains live. Keeping those attempts here lets the recorder
  /// reconnect first and perform the comparatively slow MP4 finalization only
  /// when the user-visible recording session actually stops.
  final List<PendingRecordingAttempt> pendingAttempts;

  /// =========================
  /// 实时录制状态
  /// =========================

  /// 已录制秒数
  int recordedSeconds;

  /// 文件大小 bytes
  int fileSize;

  /// ffmpeg speed
  double recordSpeed;

  /// bitrate
  double bitrate;

  /// fps
  double fps;

  /// 当前frame
  int lastFrame;

  /// watchdog
  DateTime? lastUpdate;

  /// =========================
  /// 状态控制
  /// =========================

  RecordStatus status;

  bool autoReconnect;

  int retryCount;

  DateTime createTime;

  /// Start of the user-visible recording session. A signed CDN can rotate
  /// through several native FFmpeg attempts, but the recording center must
  /// keep showing the original session start instead of the latest retry.
  DateTime? recordingStartedAt;

  DateTime get displayStartTime => recordingStartedAt ?? createTime;

  DateTime? lastFailTime;

  /// Sanitized user-visible failure from the most recent attempt.
  String? lastError;

  /// Stable stage id: room, stream, ffmpeg, merge, scheduler or status.
  String? lastErrorStage;

  bool wasStoppedByUser;

  LiveRecordTask({
    required this.taskId,
    required this.roomId,
    required this.platform,
    required this.title,
    required this.nick,
    required this.avatar,
    required this.cover,
    required this.createTime,
    this.recordingStartedAt,

    this.liveStatus = LiveStatus.unknown,
    this.watching = "0",
    this.followers = "0",
    this.isRecord = false,

    this.currentUrl,
    this.selectedLine,
    this.selectedQuality,
    this.selectedQualityId,
    this.selectedLineIndex,
    this.outputDir,
    List<PendingRecordingAttempt> pendingAttempts = const <PendingRecordingAttempt>[],

    /// 实时信息
    this.recordedSeconds = 0,
    this.fileSize = 0,
    this.recordSpeed = 0,
    this.bitrate = 0,
    this.fps = 0,
    this.lastFrame = 0,
    this.lastUpdate,

    /// 状态
    this.status = RecordStatus.waitingLive,
    this.autoReconnect = true,
    this.retryCount = 0,
    this.wasStoppedByUser = false,
    this.lastFailTime,
    this.lastError,
    this.lastErrorStage,
  }) : pendingAttempts = List<PendingRecordingAttempt>.of(pendingAttempts);

  /// =========================
  /// 从房间创建
  /// =========================

  factory LiveRecordTask.fromRoom(LiveRoom room) {
    final roomId = room.roomId ?? "";

    final platform = room.platform ?? "";

    return LiveRecordTask(
      taskId: "${platform}_$roomId",

      roomId: roomId,

      platform: platform,

      title: room.title ?? "",

      nick: room.nick ?? "",

      avatar: room.avatar ?? "",

      cover: room.cover ?? "",

      watching: room.watching ?? "0",

      followers: room.followers ?? "0",

      liveStatus: room.liveStatus ?? LiveStatus.unknown,

      isRecord: room.isRecord ?? false,

      createTime: DateTime.now(),
      wasStoppedByUser: false,
    );
  }

  /// =========================
  /// 更新房间信息
  /// =========================

  void updateFromRoom(LiveRoom room) {
    title = room.title ?? title;

    nick = room.nick ?? nick;

    avatar = room.avatar ?? avatar;

    cover = room.cover ?? cover;

    watching = room.watching ?? watching;

    followers = room.followers ?? followers;

    liveStatus = room.liveStatus ?? liveStatus;

    isRecord = room.isRecord ?? isRecord;
  }

  /// =========================
  /// watchdog
  /// =========================

  bool get isStalled {
    if (lastUpdate == null) return false;

    return DateTime.now().difference(lastUpdate!).inSeconds > 30;
  }

  void beginNewRecording({DateTime? now}) {
    final startedAt = now ?? DateTime.now();
    recordedSeconds = 0;
    fileSize = 0;
    recordingStartedAt = startedAt;
    // A previous interrupted/failing remux remains recoverable. Do not discard
    // its absolute directory merely because the user starts the room again.
    beginNewAttempt(now: startedAt);
  }

  void queuePendingAttempt({required String directoryPath, required String filePrefix}) {
    final directory = directoryPath.trim();
    final prefix = filePrefix.trim();
    if (directory.isEmpty || prefix.isEmpty) return;
    final duplicate = pendingAttempts.any(
      (attempt) => attempt.directoryPath == directory && attempt.filePrefix == prefix,
    );
    if (!duplicate) {
      pendingAttempts.add(PendingRecordingAttempt(directoryPath: directory, filePrefix: prefix));
    }
  }

  void removePendingAttempt(PendingRecordingAttempt attempt) {
    pendingAttempts.removeWhere(
      (candidate) => candidate.directoryPath == attempt.directoryPath && candidate.filePrefix == attempt.filePrefix,
    );
  }

  /// Starts one native FFmpeg attempt without discarding the aggregate
  /// duration/size of the user-initiated recording session. Live CDNs can end
  /// a response or expire a signed URL while the room is still online; those
  /// retries are file attempts, not new recordings from the user's point of
  /// view.
  void beginNewAttempt({DateTime? now}) {
    createTime = now ?? DateTime.now();
    recordSpeed = 0;
    bitrate = 0;
    fps = 0;
    lastFrame = 0;
    lastUpdate = null;
    currentUrl = null;
    selectedLine = null;
    selectedQuality = null;
  }

  void markFailure({required String stage, required Object error, DateTime? now}) {
    lastFailTime = now ?? DateTime.now();
    lastErrorStage = stage.trim().toLowerCase();
    final sanitized = RecorderDiagnostics.sanitize(error);
    lastError = sanitized.isEmpty ? null : sanitized;
  }

  void clearFailure() {
    lastError = null;
    lastErrorStage = null;
  }

  String get recordingFilePrefix {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${createTime.year}${two(createTime.month)}${two(createTime.day)}_'
        '${two(createTime.hour)}${two(createTime.minute)}${two(createTime.second)}_'
        '${createTime.millisecond.toString().padLeft(3, '0')}';
  }

  /// =========================
  /// json
  /// =========================

  Map<String, dynamic> toJson() => {
    "schemaVersion": 6,
    "taskId": taskId,
    "roomId": roomId,
    "platform": platform,

    "title": title,
    "nick": nick,
    "avatar": avatar,
    "cover": cover,

    "watching": watching,
    "followers": followers,

    "isRecord": isRecord,

    "liveStatus": liveStatus.index,
    "liveStatusName": liveStatus.name,

    // Signed CDN addresses expire quickly and can contain account/session
    // tokens. They are runtime-only and must not be written to local prefs.
    "selectedLine": selectedLine,
    "selectedQuality": selectedQuality,
    "selectedQualityId": selectedQualityId,
    "selectedLineIndex": selectedLineIndex,
    "outputDir": outputDir,
    "pendingAttempts": pendingAttempts.map((attempt) => attempt.toJson()).toList(growable: false),

    /// 实时信息
    "recordedSeconds": recordedSeconds,
    "fileSize": fileSize,
    "recordSpeed": recordSpeed,
    "bitrate": bitrate,
    "fps": fps,
    "lastFrame": lastFrame,
    "lastUpdate": lastUpdate?.toIso8601String(),

    /// 状态
    "status": status.index,
    "statusName": status.name,
    "autoReconnect": autoReconnect,
    "retryCount": retryCount,

    "createTime": createTime.toIso8601String(),
    "recordingStartedAt": recordingStartedAt?.toIso8601String(),

    "lastFailTime": lastFailTime?.toIso8601String(),
    "lastError": lastError,
    "lastErrorStage": lastErrorStage,
    "wasStoppedByUser": wasStoppedByUser,
  };

  factory LiveRecordTask.fromJson(Map<String, dynamic> json) {
    final roomId = _string(json["roomId"]);
    final platform = _string(json["platform"]).toLowerCase();
    return LiveRecordTask(
      taskId: _string(json["taskId"], fallback: "${platform}_$roomId"),

      roomId: roomId,

      platform: platform,

      title: _string(json["title"]),

      nick: _string(json["nick"]),

      avatar: _string(json["avatar"]),

      cover: _string(json["cover"]),

      watching: _string(json["watching"], fallback: "0"),

      followers: _string(json["followers"], fallback: "0"),

      isRecord: _bool(json["isRecord"]),

      liveStatus: _enumValue(
        LiveStatus.values,
        name: json["liveStatusName"],
        index: json["liveStatus"],
        fallback: LiveStatus.unknown,
      ),

      // Discard schema-v1/v2 persisted signed URLs during migration.
      currentUrl: null,

      selectedLine: _nullableString(json["selectedLine"]),

      selectedQuality: _nullableString(json["selectedQuality"]),

      selectedQualityId: _nullableString(json["selectedQualityId"]),

      selectedLineIndex: _nullableInt(json["selectedLineIndex"]),

      outputDir: _nullableString(json["outputDir"]),

      pendingAttempts: _pendingAttempts(json["pendingAttempts"]),

      /// 实时录制
      recordedSeconds: _recordedSeconds(json["recordedSeconds"]),

      fileSize: _int(json["fileSize"]),

      recordSpeed: _double(json["recordSpeed"]),

      bitrate: _double(json["bitrate"]),

      fps: _double(json["fps"]),

      lastFrame: _int(json["lastFrame"]),

      lastUpdate: _date(json["lastUpdate"]),

      /// 状态
      status: _enumValue(
        RecordStatus.values,
        name: json["statusName"],
        index: json["status"],
        fallback: RecordStatus.stopped,
      ),

      autoReconnect: _bool(json["autoReconnect"], fallback: true),

      retryCount: _int(json["retryCount"]),

      createTime: _date(json["createTime"]) ?? DateTime.now(),

      recordingStartedAt: _date(json["recordingStartedAt"]),

      lastFailTime: _date(json["lastFailTime"]),
      lastError: _diagnostic(json["lastError"]),
      lastErrorStage: _stage(json["lastErrorStage"]),
      wasStoppedByUser: _bool(json["wasStoppedByUser"]),
    );
  }

  static String _string(dynamic value, {String fallback = ''}) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String? _diagnostic(dynamic value) {
    final sanitized = RecorderDiagnostics.sanitize(value);
    return sanitized.isEmpty ? null : sanitized;
  }

  static String? _stage(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized.startsWith('ffmpeg.')) return normalized;
    return const {
          'room',
          'quality',
          'stream',
          'network',
          'ffmpeg',
          'merge',
          'scheduler',
          'status',
          'recorder',
        }.contains(normalized)
        ? normalized
        : null;
  }

  static int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _recordedSeconds(dynamic value) {
    final seconds = _int(value);
    // Older builds could persist FFmpeg's INT32_MAX timestamp sentinel as an
    // elapsed duration.  No single local capture should retain a counter above
    // one year; reset corrupted telemetry while leaving the task itself intact.
    const maximumPersistedSeconds = 365 * 24 * 60 * 60;
    return seconds >= 0 && seconds <= maximumPersistedSeconds ? seconds : 0;
  }

  static int? _nullableInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _bool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return fallback;
  }

  static DateTime? _date(dynamic value) => DateTime.tryParse(value?.toString() ?? '');

  static List<PendingRecordingAttempt> _pendingAttempts(dynamic value) {
    if (value is! List) return const <PendingRecordingAttempt>[];
    final attempts = <PendingRecordingAttempt>[];
    final seen = <String>{};
    for (final item in value) {
      if (item is! Map) continue;
      final attempt = PendingRecordingAttempt.fromJson(Map<String, dynamic>.from(item));
      if (attempt == null) continue;
      final key = '${attempt.directoryPath}\u0000${attempt.filePrefix}';
      if (seen.add(key)) attempts.add(attempt);
    }
    return attempts;
  }

  static T _enumValue<T>(List<T> values, {dynamic name, dynamic index, required T fallback}) {
    final normalizedName = name?.toString().trim();
    if (normalizedName?.isNotEmpty == true) {
      for (final value in values) {
        if (value.toString().split('.').last == normalizedName) return value;
      }
    }
    final parsedIndex = index is num ? index.toInt() : int.tryParse(index?.toString() ?? '');
    if (parsedIndex != null && parsedIndex >= 0 && parsedIndex < values.length) {
      return values[parsedIndex];
    }
    return fallback;
  }
}

class PendingRecordingAttempt {
  const PendingRecordingAttempt({required this.directoryPath, required this.filePrefix});

  final String directoryPath;
  final String filePrefix;

  Map<String, String> toJson() => <String, String>{'directoryPath': directoryPath, 'filePrefix': filePrefix};

  static PendingRecordingAttempt? fromJson(Map<String, dynamic> json) {
    final directoryPath = json['directoryPath']?.toString().trim() ?? '';
    final filePrefix = json['filePrefix']?.toString().trim() ?? '';
    if (directoryPath.isEmpty || filePrefix.isEmpty) return null;
    return PendingRecordingAttempt(directoryPath: directoryPath, filePrefix: filePrefix);
  }
}
