import 'package:pure_live/common/index.dart';

class AreaServerAllController extends ServerAllPageController<LiveRoom> {
  final Site site;
  final LiveArea subCategory;
  AreaServerAllController(this.site, this.subCategory);

  @override
  Future<List<LiveRoom>> fetchAllServerData() async {
    try {
      final result = await site.liveSite.getCategoryRooms(subCategory, page: currentPage);
      for (var element in result) {
        element.area = subCategory.areaName;
      }
      return result;
    } catch (e) {
      if (e.toString().contains("-352") ||
          (e.toString().contains("NoSuchMethodError") && e.toString().contains("'[]'"))) {
        notLogin.value = true;
        return [];
      }
      rethrow;
    }
  }
}

class AreaServerFixedController extends ServerFixedPageController<LiveRoom> {
  final Site site;
  final LiveArea subCategory;

  AreaServerFixedController(this.site, this.subCategory, {required int fixedSize})
    : super(fixedServerPageSize: fixedSize);

  @override
  Future<List<LiveRoom>> fetchFixedNetworkData(int bigPage, int fixedSize) async {
    try {
      final result = await site.liveSite.getCategoryRooms(subCategory, page: bigPage);
      for (var element in result) {
        element.area = subCategory.areaName;
      }
      return result;
    } catch (e) {
      if (e.toString().contains("-352") ||
          (e.toString().contains("NoSuchMethodError") && e.toString().contains("'[]'"))) {
        notLogin.value = true;
        return [];
      }
      rethrow;
    }
  }
}

class AreaServerRemoteController extends ServerRemotePageController<LiveRoom> {
  final Site site;
  final LiveArea subCategory;
  AreaServerRemoteController(this.site, this.subCategory);

  @override
  Future<List<LiveRoom>> fetchNetworkData(int page, int pageSize) async {
    try {
      final result = await site.liveSite.getCategoryRooms(subCategory, page: page);
      for (var element in result) {
        element.area = subCategory.areaName;
      }
      return result;
    } catch (e) {
      if (e.toString().contains("-352") ||
          (e.toString().contains("NoSuchMethodError") && e.toString().contains("'[]'"))) {
        notLogin.value = true;
        return [];
      }
      rethrow;
    }
  }
}
