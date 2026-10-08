import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/domains/live/data/favorite_room_controller.dart';

class FavoriteAreasController extends GetxController {
  final tabSiteIndex = 0.obs;
  String selectedSiteId = Sites.allSite;

  // Read the persisted observable inside the page's Obx instead of retaining
  // the list object that happened to exist when this route was opened.
  List<LiveArea> get favoriteAreas => FavoriteRoomController.to.favoriteAreas.v;

  void selectSite(int index, String siteId) {
    selectedSiteId = siteId;
    tabSiteIndex.value = index;
  }
}
