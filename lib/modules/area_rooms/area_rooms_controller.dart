import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/base/base_controller.dart';

class AreaRoomsController extends BasePageController<LiveRoom> {
  final Site site;
  final LiveArea subCategory;
  final settings = Get.find<SettingsService>();
  AreaRoomsController({required this.site, required this.subCategory});

  @override
  Future<List<LiveRoom>> getData(int page, int pageSize) async {
    var result = await site.liveSite.getCategoryRooms(subCategory, page: page);
    for (var element in result.items) {
      element.area = subCategory.areaName;
    }
    return result.items;
  }
}
