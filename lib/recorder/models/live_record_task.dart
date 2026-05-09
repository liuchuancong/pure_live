import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/recorder/models/record_status.dart';

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

  /// 输出目录
  String? outputDir;

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

  DateTime? lastFailTime;

  LiveRecordTask({
    required this.taskId,
    required this.roomId,
    required this.platform,
    required this.title,
    required this.nick,
    required this.avatar,
    required this.cover,
    required this.createTime,

    this.liveStatus = LiveStatus.unknown,
    this.watching = "0",
    this.followers = "0",
    this.isRecord = false,

    this.currentUrl,
    this.selectedLine,
    this.selectedQuality,
    this.outputDir,

    /// 实时信息
    this.recordedSeconds = 0,
    this.fileSize = 0,
    this.recordSpeed = 0,
    this.bitrate = 0,
    this.fps = 0,
    this.lastFrame = 0,
    this.lastUpdate,

    /// 状态
    this.status = RecordStatus.idle,
    this.autoReconnect = true,
    this.retryCount = 0,

    this.lastFailTime,
  });

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

  /// =========================
  /// json
  /// =========================

  Map<String, dynamic> toJson() => {
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

    "currentUrl": currentUrl,
    "selectedLine": selectedLine,
    "selectedQuality": selectedQuality,
    "outputDir": outputDir,

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
    "autoReconnect": autoReconnect,
    "retryCount": retryCount,

    "createTime": createTime.toIso8601String(),

    "lastFailTime": lastFailTime?.toIso8601String(),
  };

  factory LiveRecordTask.fromJson(Map<String, dynamic> json) {
    return LiveRecordTask(
      taskId: json["taskId"] ?? "",

      roomId: json["roomId"] ?? "",

      platform: json["platform"] ?? "",

      title: json["title"] ?? "",

      nick: json["nick"] ?? "",

      avatar: json["avatar"] ?? "",

      cover: json["cover"] ?? "",

      watching: json["watching"] ?? "0",

      followers: json["followers"] ?? "0",

      isRecord: json["isRecord"] ?? false,

      liveStatus: LiveStatus.values[json["liveStatus"] ?? 0],

      currentUrl: json["currentUrl"],

      selectedLine: json["selectedLine"],

      selectedQuality: json["selectedQuality"],

      outputDir: json["outputDir"],

      /// 实时录制
      recordedSeconds: json["recordedSeconds"] ?? 0,

      fileSize: json["fileSize"] ?? 0,

      recordSpeed: (json["recordSpeed"] ?? 0).toDouble(),

      bitrate: (json["bitrate"] ?? 0).toDouble(),

      fps: (json["fps"] ?? 0).toDouble(),

      lastFrame: json["lastFrame"] ?? 0,

      lastUpdate: json["lastUpdate"] != null ? DateTime.tryParse(json["lastUpdate"]) : null,

      /// 状态
      status: RecordStatus.values[json["status"] ?? 0],

      autoReconnect: json["autoReconnect"] ?? true,

      retryCount: json["retryCount"] ?? 0,

      createTime: DateTime.tryParse(json["createTime"] ?? "") ?? DateTime.now(),

      lastFailTime: json["lastFailTime"] != null ? DateTime.tryParse(json["lastFailTime"]) : null,
    );
  }
}
