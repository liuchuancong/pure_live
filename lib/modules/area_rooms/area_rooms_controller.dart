import 'package:pure_live/core/sites.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/base/base_controller.dart';

class AreaRoomsController extends BasePageController<LiveRoom> {
  final Site site;
  final LiveArea subCategory;

  AreaRoomsController({
    required this.site,
    required this.subCategory,
  });

  @override
  Future<List<LiveRoom>> getData(int page, int pageSize) async {
    var result = await site.liveSite.getCategoryRooms(subCategory, page: page);
    for (var element in result.items) {
      element.area = subCategory.areaName;
    }
    return result.items;
  }
}
