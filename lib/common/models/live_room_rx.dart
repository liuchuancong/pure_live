import 'package:get/get.dart';
import 'package:pure_live/plugins/extension/string_extension.dart';

import 'live_room.dart';

class LiveRoomRx {
  Rx<String?> roomId = ''.obs;
  Rx<String?> userId = ''.obs;
  Rx<String?> link = ''.obs;
  Rx<String?> title = ''.obs;
  Rx<String?> nick = ''.obs;
  Rx<String?> avatar = ''.obs;
  Rx<String?> cover = ''.obs;
  Rx<String?> area = ''.obs;
  Rx<String?> watching = ''.obs;
  Rx<String?> followers = ''.obs;
  Rx<String?> platform = 'UNKNOWN'.obs;

  LiveRoomRx();

  /// 介绍
  Rx<String?> introduction = ''.obs;

  /// 公告
  Rx<String?> notice = ''.obs;

  /// 状态
  Rx<bool?> status = false.obs;

  /// 附加信息
  dynamic data;

  /// 弹幕附加信息
  dynamic danmakuData;

  /// 是否录播
  Rx<bool?> isRecord = false.obs;

  // 直播状态
  Rx<LiveStatus?> liveStatus = LiveStatus.offline.obs;
  Rx<String?> recordWatching = ''.obs;

  /// 更新内部数据
  void updateByLiveRoom(LiveRoom liveRoom) {
    liveRoomToRx(liveRoom, this);
  }

  void liveRoomToRx(LiveRoom liveRoom, LiveRoomRx liveRoomRx) {
    liveRoomRx.roomId.value = liveRoom.roomId.appendTxt("");
    liveRoomRx.userId.value = liveRoom.userId.appendTxt("");
    liveRoomRx.link.value = liveRoom.link.appendTxt("");
    liveRoomRx.title.value = liveRoom.title.appendTxt("");
    liveRoomRx.nick.value = liveRoom.nick.appendTxt("");
    liveRoomRx.avatar.value = liveRoom.avatar.appendTxt("");
    liveRoomRx.cover.value = liveRoom.cover.appendTxt("");
    liveRoomRx.area.value = liveRoom.area.appendTxt("");
    liveRoomRx.watching.value = liveRoom.watching.appendTxt("");
    liveRoomRx.followers.value = liveRoom.followers.appendTxt("");
    liveRoomRx.platform.value = liveRoom.platform.appendTxt("");
    liveRoomRx.introduction.value = liveRoom.introduction.appendTxt("");
    liveRoomRx.notice.value = liveRoom.notice.appendTxt("");
    liveRoomRx.status.value = liveRoom.status ?? false;
    liveRoomRx.data = liveRoom.data;
    liveRoomRx.danmakuData = liveRoom.danmakuData;
    liveRoomRx.isRecord.value = liveRoom.isRecord ?? false;
    liveRoomRx.liveStatus.value = liveRoom.liveStatus ?? LiveStatus.offline;
    liveRoomRx.recordWatching.value = liveRoom.recordWatching ?? "";
  }

  /// 转换为 LiveRoom 对象 没有 rx
  LiveRoom toLiveRoom() {
    var liveRoom = LiveRoom();
    liveRoom
      ..roomId = roomId.value
      ..userId = userId.value
      ..link = link.value
      ..title = title.value
      ..nick = nick.value
      ..avatar = avatar.value
      ..cover = cover.value
      ..area = area.value
      ..watching = watching.value
      ..followers = followers.value
      ..platform = platform.value
      ..introduction = introduction.value
      ..notice = notice.value
      ..status = status.value
      ..data = data
      ..danmakuData = danmakuData
      ..isRecord = isRecord.value
      ..recordWatching = recordWatching.value
      ..liveStatus = liveStatus.value;
    return liveRoom;
  }
}
