import 'dart:async';

import 'package:get/get.dart';
import 'package:pure_live/common/base/base_controller.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/modules/util/rx_util.dart';

import '../util/update_room_util.dart';

class HistoryController extends BasePageController<LiveRoom> {
  HistoryController();

  static HistoryController get instance => Get.find<HistoryController>();

  @override
  Future refreshData() async {
    CoreLog.d("HistoryController refreshData");
    final SettingsService settings = SettingsService.instance;
    await UpdateRoomUtil.updateRoomList(settings.historyRooms, settings);
    // if (result) {
    //   easyRefreshController.finishRefresh(IndicatorResult.success);
    //   easyRefreshController.resetFooter();
    // } else {
    //   easyRefreshController.finishRefresh(IndicatorResult.fail);
    // }
    // currentPage = 1;
    // // list.value = [];
    // await loadData();
    return await super.refreshData();
  }

  @override
  Future<List<LiveRoom>> getData(int page, int pageSize) async {
    CoreLog.d("HistoryController getData(int page = $page, int pageSize = $pageSize)");
    if (page > 1) {
      canLoadMore.updateValueNotEquate(false);
      return [];
    }
    final SettingsService settings = SettingsService.instance;
    final rooms = settings.historyRooms.toList().reversed.toList();
    canLoadMore.updateValueNotEquate(false);
    return rooms;
  }

  @override
  Future<void> onInit() async {
    // TODO: implement onInit
    super.onInit();
    await loadData();
  }
}
