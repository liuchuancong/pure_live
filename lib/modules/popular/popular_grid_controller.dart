import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/base/base_controller.dart';

class PopularGridController extends BasePageController<LiveRoom> {
  final Site site;
  final isNetworkError = false.obs;
  final isLoginRequiredError = false.obs;
  final settings = Get.find<SettingsService>();
  PopularGridController(this.site);

  @override
  Future<List<LiveRoom>> getData(int page, int pageSize) async {
    try {
      var result = await site.liveSite.getRecommendRooms(page: page, nick: '热门');
      isNetworkError.value = false;
      isLoginRequiredError.value = false;

      if (site.id == Sites.iptvSite && list.isNotEmpty) {
        return [];
      }
      return result.items;
    } catch (e) {
      debugPrint('Exception caught in grid controller fetch loop: $e');
      final errorStr = e.toString();
      if (errorStr.contains("NoSuchMethodError") && errorStr.contains("'[]'")) {
        isLoginRequiredError.value = true;
        isNetworkError.value = false;
      } else {
        isNetworkError.value = true;
        isLoginRequiredError.value = false;
      }
      return [];
    }
  }
}
