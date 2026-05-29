import 'package:pure_live/common/index.dart';

class FavoriteAreasController extends GetxController with GetTickerProviderStateMixin {
  late TabController tabSiteController;

  var tabSiteIndex = 0.obs;
  var favoriteAreas = [].obs;
  @override
  void onInit() {
    tabSiteController = TabController(length: Sites().availableSites().length + 1, vsync: this);
    tabSiteController.addListener(() {
      tabSiteIndex.value = tabSiteController.index;
    });
    favoriteAreas.value = SettingsService.to.fav.favoriteAreas.v;
    super.onInit();
  }
}
