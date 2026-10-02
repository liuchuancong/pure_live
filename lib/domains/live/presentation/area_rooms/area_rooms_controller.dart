import 'package:pure_live/core/index.dart';
import 'package:pure_live/shared/platforms/live_directory.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';

String areaRoomsControllerTag(Site site, LiveArea area) => site.liveSite is LiveSiteDirectoryPager
    ? '${site.id}_${area.areaType}_${area.areaId}'
    : '${site.id}_${area.areaId}';

class AreaServerAllController extends ServerAllPageController<LiveRoom> {
  final Site site;
  final LiveArea subCategory;
  AreaServerAllController(this.site, this.subCategory);

  @override
  Future<List<LiveRoom>> fetchAllServerData() async {
    if (isClosed) return [];
    try {
      final result = await site.liveSite.getCategoryRooms(subCategory, page: currentPage);
      if (isClosed) return [];
      for (var element in result) {
        element.area = subCategory.areaName;
      }
      return result;
    } catch (e) {
      if (isClosed) return [];
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
    if (isClosed) return [];
    try {
      final result = await site.liveSite.getCategoryRooms(
        subCategory,
        page: bigPage,
        // Preserve older adapters' default contract; TwitCasting must fetch
        // the full bounded window once before this controller slices it.
        pageSize: site.id == Sites.twitcastingSite ? fixedSize : 30,
      );
      if (isClosed) return [];
      for (var element in result) {
        element.area = subCategory.areaName;
      }
      return result;
    } catch (e) {
      if (isClosed) return [];
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
    if (isClosed) return [];
    try {
      final result = await site.liveSite.getCategoryRooms(subCategory, page: page);
      if (isClosed) return [];
      for (var element in result) {
        element.area = subCategory.areaName;
      }
      return result;
    } catch (e) {
      if (isClosed) return [];
      if (e.toString().contains("-352") ||
          (e.toString().contains("NoSuchMethodError") && e.toString().contains("'[]'"))) {
        notLogin.value = true;
        return [];
      }
      rethrow;
    }
  }
}
