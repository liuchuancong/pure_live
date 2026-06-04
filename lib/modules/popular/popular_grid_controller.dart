import 'dart:async';
import 'package:pure_live/common/index.dart';

class PopularGridController extends BasePageController<LiveRoom> {
  final Site site;

  PopularGridController(this.site) : super();

  @override
  Future<List<LiveRoom>> getData(int page, int pageSize) async {
    try {
      var result = await site.liveSite.getRecommendRooms(page: page, nick: '热门');
      if (site.id == Sites.iptvSite && list.isNotEmpty) {
        return [];
      }
      return result.items;
    } catch (e) {
      debugPrint('Exception caught in grid controller fetch loop: $e');
      final errorStr = e.toString();
      if (errorStr.contains("NoSuchMethodError") && errorStr.contains("'[]'")) {
        throw Exception("loginRequired");
      }
      rethrow;
    }
  }
}
