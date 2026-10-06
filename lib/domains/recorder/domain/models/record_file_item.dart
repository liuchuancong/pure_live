class RecordFileItem {
  final String id;

  final String nick;

  final String platform;

  final String title;

  final String path;

  final String cover;

  final int size;

  final int duration;

  final DateTime createTime;

  final String fileName;

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
