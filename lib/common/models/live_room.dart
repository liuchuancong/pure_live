enum LiveStatus { live, offline, replay, unknown }

enum Platforms { huya, bilibili, douyu, douyin, unknown }

class LiveRoom {
  String? roomId;
  String? userId = '';
  String? link = '';
  String? title = '';
  String? nick = '';
  String? avatar = '';
  String? cover = '';
  String? area = '';
  String? watching = '';
  String? followers = '';
  String? platform = 'UNKNOWN';

  /// 介绍
  String? introduction;

  /// 公告
  String? notice;

  /// 状态
  bool? status;

  /// 附加信息
  dynamic data;

  /// 弹幕附加信息
  dynamic danmakuData;

  /// 是否录播
  bool? isRecord = false;
  // 直播状态
  LiveStatus? liveStatus = LiveStatus.offline;

  /// 录播观看人数
  String? recordWatching = '';

  LiveRoom(
      {this.roomId,
      this.userId,
      this.link,
      this.title = '',
      this.nick = '',
      this.avatar = '',
      this.cover = '',
      this.area,
      this.watching = '0',
      this.followers = '0',
      this.platform,
      this.liveStatus,
      this.data,
      this.danmakuData,
      this.isRecord = false,
      this.status = false,
      this.notice,
      this.introduction,
      this.recordWatching});

  LiveRoom.fromJson(Map<String, dynamic> json)
      : roomId = json['roomId'] ?? '',
        userId = json['userId'] ?? '',
        title = json['title'] ?? '',
        link = json['link'] ?? '',
        nick = json['nick'] ?? '',
        avatar = json['avatar'] ?? '',
        cover = json['cover'] ?? '',
        area = json['area'] ?? '',
        watching = json['watching'] ?? '',
        followers = json['followers'] ?? '',
        platform = json['platform'] ?? '',
        liveStatus = LiveStatus.values[json['liveStatus'] ?? 1],
        status = json['status'] ?? false,
        notice = json['notice'] ?? '',
        introduction = json['introduction'] ?? '',
        recordWatching = json['recordWatching'] ?? "",
        isRecord = json['isRecord'] ?? false;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'roomId': roomId,
        'userId': userId,
        'title': title,
        'nick': nick,
        'avatar': avatar,
        'cover': cover,
        'area': area,
        'watching': watching,
        'followers': followers,
        'platform': platform,
        'liveStatus': liveStatus?.index ?? 1,
        'isRecord': isRecord,
        'status': status,
        'notice': notice,
        'recordWatching': recordWatching,
        'introduction': introduction,
        'link': link,
      };

  @override
  bool operator ==(covariant LiveRoom other) => platform == other.platform && roomId == other.roomId;

  @override
  int get hashCode => int.parse(roomId!);
}
