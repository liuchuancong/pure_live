import 'package:pure_live/core/index.dart';
import 'package:pure_live/modules/area_rooms/area_rooms_controller.dart';
import 'package:pure_live/core/base/live_directory_controller.dart';
import 'package:pure_live/core/interface/live_directory.dart';

class AreaRoomsBinding extends Binding {
  @override
  List<Bind> dependencies() {
    final Site site = Get.arguments[0];
    final LiveArea subCategory = Get.arguments[1];
    final String tag = areaRoomsControllerTag(site, subCategory);

    return [Bind.lazyPut<BasePageScrollAndStateBone<LiveRoom>>(() => createController(site, subCategory), tag: tag)];
  }

  static BasePageScrollAndStateBone<LiveRoom> createController(Site site, LiveArea subCategory) {
    final directory = site.liveSite;
    if (directory is LiveSiteDirectoryPager) {
      return LiveDirectoryController(directory: directory as LiveSiteDirectoryPager, category: subCategory);
    }
    if (directory is LiveSiteCategoryDirectoryProvider) {
      return LiveDirectoryController(
        directory: (directory as LiveSiteCategoryDirectoryProvider).categoryDirectory,
        category: subCategory,
      );
    }
    if (site.id == Sites.kuaishouSite) {
      return AreaServerAllController(site, subCategory);
    }
    if (site.id == Sites.douyuSite) {
      return AreaServerFixedController(site, subCategory, fixedSize: 40);
    }
    if (site.id == Sites.huyaSite) {
      return AreaServerFixedController(site, subCategory, fixedSize: 120);
    }
    if (site.id == Sites.soopSite) {
      return AreaServerFixedController(site, subCategory, fixedSize: 60);
    }
    if (site.id == Sites.twitcastingSite) {
      return AreaServerFixedController(site, subCategory, fixedSize: 60);
    }
    return AreaServerRemoteController(site, subCategory);
  }
}
