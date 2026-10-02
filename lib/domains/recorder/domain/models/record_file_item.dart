class RecordFileItem {
  /// 唯一ID
  final String id;

  /// 主播
  final String nick;

  /// 平台
  final String platform;

  /// 标题
  final String title;

  /// 文件路径
  final String path;

  /// 封面
  final String cover;

  /// 文件大小
  final int size;

  /// 视频时长（秒）
  final int duration;

  /// 创建时间
  final DateTime createTime;

  /// 文件名
  final String fileName;

  /// 录制日期
  final String date;

  RecordFileItem({
    required this.id,
    required this.nick,
    required this.platform,
    required this.title,
    required this.path,
    required this.cover,
    required this.size,
    required this.duration,
    required this.createTime,
    required this.fileName,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "nick": nick,
    "platform": platform,
    "title": title,
    "path": path,
    "cover": cover,
    "size": size,
    "duration": duration,
    "createTime": createTime.toIso8601String(),
    "fileName": fileName,
    "date": date,
  };

  factory RecordFileItem.fromJson(Map<String, dynamic> json) {
    return RecordFileItem(
      id: json["id"],
      nick: json["nick"],
      platform: json["platform"],
      title: json["title"],
      path: json["path"],
      cover: json["cover"],
      size: json["size"],
      duration: json["duration"],
      createTime: DateTime.parse(json["createTime"]),
      fileName: json["fileName"],
      date: json["date"],
    );
  }
}
