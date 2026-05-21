import 'package:pure_live/player/core/live_room_volume_manager.dart';

enum LiveStatus { live, offline, replay, unknown, banned }

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

  dynamic data;

  dynamic danmakuData;

  /// 是否录播
  bool? isRecord = false;
  // 直播状态
  LiveStatus? liveStatus = LiveStatus.offline;

  /// EPG channel id
  String? epgId;

  /// 当前节目
  String? currentProgramme;

  /// 当前节目描述
  String? currentProgrammeDescription;

  // 添加未命名的默认构造函数
  LiveRoom({
    this.roomId,
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
    this.epgId,
    this.currentProgramme,
    this.currentProgrammeDescription,
  });

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
      liveStatus = LiveStatus.values.firstWhere((e) => e.index == json['liveStatus'], orElse: () => LiveStatus.unknown),
      status = json['status'] ?? false,
      notice = json['notice'] ?? '',
      introduction = json['introduction'] ?? '',
      isRecord = json['isRecord'] ?? false,
      epgId = json['epgId'] ?? '',
      currentProgramme = json['currentProgramme'] ?? '',
      currentProgrammeDescription = json['currentProgrammeDescription'] ?? '';

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
    'liveStatus': liveStatus?.index ?? LiveStatus.offline.index,
    'isRecord': isRecord,
    'status': status,
    'notice': notice,
    'introduction': introduction,
    'epgId': epgId,
    'currentProgramme': currentProgramme,
    'currentProgrammeDescription': currentProgrammeDescription,
  };

  /// 创建一个新的LiveRoom实例，并用提供的值更新指定字段
  LiveRoom copyWith({
    String? roomId,
    String? userId,
    String? link,
    String? title,
    String? nick,
    String? avatar,
    String? cover,
    String? area,
    String? watching,
    String? followers,
    String? platform,
    String? introduction,
    String? notice,
    bool? status,
    dynamic data,
    dynamic danmakuData,
    bool? isRecord,
    LiveStatus? liveStatus,
    String? epgId,
    String? currentProgramme,
    String? currentProgrammeDescription,
  }) {
    return LiveRoom(
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      link: link ?? this.link,
      title: title ?? this.title,
      nick: nick ?? this.nick,
      avatar: avatar ?? this.avatar,
      cover: cover ?? this.cover,
      area: area ?? this.area,
      watching: watching ?? this.watching,
      followers: followers ?? this.followers,
      platform: platform ?? this.platform,
      introduction: introduction ?? this.introduction,
      notice: notice ?? this.notice,
      status: status ?? this.status,
      isRecord: isRecord ?? this.isRecord,
      liveStatus: liveStatus ?? this.liveStatus,
      epgId: epgId ?? this.epgId,
      currentProgramme: currentProgramme ?? this.currentProgramme,
      currentProgrammeDescription: currentProgrammeDescription ?? this.currentProgrammeDescription,
    );
  }

  @override
  bool operator ==(covariant LiveRoom other) => platform == other.platform && roomId == other.roomId;

  @override
  int get hashCode => Object.hash(platform, roomId);

  @override
  String toString() {
    return 'LiveRoom{roomId: $roomId, userId: $userId, link: $link, title: $title, nick: $nick, avatar: $avatar, cover: $cover, area: $area, watching: $watching, followers: $followers, platform: $platform, introduction: $introduction, notice: $notice, status: $status, data: $data, danmakuData: $danmakuData, isRecord: $isRecord, liveStatus: $liveStatus}';
  }

  double getSavedVolume() {
    return LiveRoomVolumeManager.getRoomVolume(platform ?? 'UNKNOWN', roomId ?? '');
  }

  Future<void> saveCurrentVolume(double volume) async {
    await LiveRoomVolumeManager.saveRoomVolume(platform ?? 'UNKNOWN', roomId ?? '', volume);
  }
}
