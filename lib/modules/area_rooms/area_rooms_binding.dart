import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/area_rooms/area_rooms_controller.dart';

class AreaRoomsBinding extends Binding {
  @override
  List<Bind> dependencies() {
    final Site site = Get.arguments[0];
    final LiveArea subCategory = Get.arguments[1];
    final String tag = "${site.id}_${subCategory.areaId}";

    return [
      Bind.lazyPut<BasePageScrollAndStateBone<LiveRoom>>(() {
        if (site.id == Sites.kuaishouSite) {
          return AreaServerAllController(site, subCategory);
        }
        if (site.id == Sites.douyuSite) {
          return AreaServerFixedController(site, subCategory, fixedSize: 40);
        }
        if (site.id == Sites.huyaSite) {
          return AreaServerFixedController(site, subCategory, fixedSize: 120);
        }
        return AreaServerRemoteController(site, subCategory);
      }, tag: tag),
    ];
  }
}
