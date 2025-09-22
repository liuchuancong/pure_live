import 'dart:async';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/base/base_controller.dart';

class FavoriteGridController extends BasePageController<LiveRoom> {
  final int index;

  FavoriteGridController(this.index);

  @override
  Future refreshData() async {
    EasyThrottle.throttle('refresh-favorite', const Duration(milliseconds: 200), () async {
      await FavoriteController.instance.onRefresh();
      super.refreshData();
    });
  }

  @override
  Future<List<LiveRoom>> getData(int page, int pageSize) async {
    if(page > 1) {
      return [];
    }
    list = FavoriteController.instance.filterDataList[index];
    return list.value;
  }

}
