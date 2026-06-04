import 'package:pure_live/common/index.dart';

class AreaRoomsController extends BasePageController<LiveRoom> {
  final Site site;
  final LiveArea subCategory;

  AreaRoomsController({required this.site, required this.subCategory});

  @override
  Future<List<LiveRoom>> getData(int page, int pageSize) async {
    try {
      var result = await site.liveSite.getCategoryRooms(subCategory, page: page);
      for (var element in result.items) {
        element.area = subCategory.areaName;
      }
      return result.items;
    } catch (e) {
      debugPrint('Exception caught in area rooms controller fetch loop: $e');
      final errorStr = e.toString();
      if (errorStr.contains("-352") || (errorStr.contains("NoSuchMethodError") && errorStr.contains("'[]'"))) {
        throw Exception("loginRequired");
      }
      rethrow;
    }
  }
}
