class RecordHistory {
  final String taskId;
  final String roomId;
  final String platform;

  final String title;
  final String nick;

  final String filePath;
  final int fileSize;

  final DateTime createTime;

  RecordHistory({
    required this.taskId,
    required this.roomId,
    required this.platform,
    required this.title,
    required this.nick,
    required this.filePath,
    required this.fileSize,
    required this.createTime,
  });

  Map<String, dynamic> toJson() => {
    "taskId": taskId,
    "roomId": roomId,
    "platform": platform,
    "title": title,
    "nick": nick,
    "filePath": filePath,
    "fileSize": fileSize,
    "createTime": createTime.toIso8601String(),
  };

  factory RecordHistory.fromJson(Map<String, dynamic> json) {
    return RecordHistory(
      taskId: json["taskId"],
      roomId: json["roomId"],
      platform: json["platform"],
      title: json["title"],
      nick: json["nick"],
      filePath: json["filePath"],
      fileSize: json["fileSize"],
      createTime: DateTime.parse(json["createTime"]),
    );
  }
}
