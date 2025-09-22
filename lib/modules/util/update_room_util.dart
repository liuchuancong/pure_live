import 'dart:io';

import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/plugins/extension/string_extension.dart';

import '../../common/models/live_room.dart';
import '../../common/services/settings_service.dart';
import '../../core/sites.dart';

class UpdateRoomUtil {
  /// 判断网络是否连接
  static Future<bool> testNetwork() async {
    // 通过请求 百度 判断网络是否连接
    var testCount = 2;
    var isOk = false;
    for (var i = 0; i < testCount; i++) {
      try {
        await HttpClient.instance.get("http://suggestion.baidu.com/su?wd=pqn&cb=suggestion");
        isOk = true;
        break;
      } catch (e) {
        CoreLog.w("$e");
        await HttpClient.resetHttpClient();
        sleep(const Duration(milliseconds: 200));
      }
    }
    return isOk;
  }

  ///  更新房间
  static Future<bool> updateRoomList(List<LiveRoom> roomList, SettingsService settings) async {
    var isTestNetworkOk = await testNetwork();
    if (!isTestNetworkOk) {
      return isTestNetworkOk;
    }
    // 过滤非法数据
    roomList = roomList.where((room) => !room.roomId.isNullOrEmpty && !room.platform.isNullOrEmpty).toList();

    // 已经更新的数据
    List<LiveRoom> updatedRoomList = [];

    // 批量更新
    var tmp = Sites.supportSites.where((site) => site.liveSite.isSupportBatchUpdateLiveStatus()).map((site) => MapEntry(site.liveSite, <LiveRoom>[])).toList();
    var batchUpdateSiteMap = Map.fromEntries(tmp);
    var unBatchUpdateRooms = roomList;
    bool hasError = false;
    if (batchUpdateSiteMap.isNotEmpty) {
      unBatchUpdateRooms = <LiveRoom>[];
      // 没有批量更新列表
      for (final room in roomList) {
        if (room.roomId == "") {
          continue;
        }
        var liveSite = Sites.of(room.platform!).liveSite;
        if (liveSite.isSupportBatchUpdateLiveStatus()) {
          batchUpdateSiteMap[liveSite]!.add(room);
        } else {
          unBatchUpdateRooms.add(room);
        }
      }

      // 批量更新
      List<Future<List<LiveRoom>>> futures = [];
      batchUpdateSiteMap.forEach((liveSite, list) {
        futures.add(liveSite.getLiveRoomDetailList(list: list));
      });
      try {
        for (var i = 0; i < futures.length; i++) {
          final rooms = await futures[i];
          // for (var room in rooms) {
          //   settings.updateRoom(room);
          // }
          updatedRoomList.addAll(rooms);
        }
      } catch (e) {
        CoreLog.error(e);
        hasError = true;
      }
    }

    List<Future<LiveRoom>> futures = [];
    for (final room in unBatchUpdateRooms) {
      if (room.roomId == "") {
        continue;
      }
      futures.add(Sites.of(room.platform!).liveSite.getRoomDetail(detail: room));
    }
    List<List<Future<LiveRoom>>> groupedList = [];

    // 每次循环处理四个元素
    for (int i = 0; i < futures.length; i += 3) {
      // 获取当前循环开始到下一个四个元素的位置（但不超过原列表长度）
      int end = i + 3;
      if (end > futures.length) {
        end = futures.length;
      }
      // 截取当前四个元素的子列表
      List<Future<LiveRoom>> subList = futures.sublist(i, end);
      // 将子列表添加到结果列表中
      groupedList.add(subList);
    }
    try {
      for (var i = 0; i < groupedList.length; i++) {
        final rooms = await Future.wait(groupedList[i]);
        // for (var room in rooms) {
        //   settings.updateRoom(room);
        // }
        updatedRoomList.addAll(rooms);
      }
    } catch (e) {
      CoreLog.error(e);
      hasError = true;
    }

    /// 重新计算更新录播标志
    // updatedRoomList
    // .where((room) => room.liveStatus == LiveStatus.live && room.recordWatching.isNotNullOrEmpty)
    // .forEach((room){
    //   var watching = readableCountStrToNum(room.watching);
    //   var recordWatching = readableCountStrToNum(room.recordWatching);
    //   if(watching <= recordWatching) {
    //     room.liveStatus = LiveStatus.replay;
    //   }
    // });

    settings.updateRooms(updatedRoomList);

    return hasError;
  }
}
