import 'package:pure_live/common/index.dart';

class HotAreasController extends GetxController {
  final sites = <Site>[].obs;

  @override
  void onInit() {
    final savedIds = SettingsService.to.fav.hotAreasList.v;
    final supported = Sites.supportSites;

    List<String> orderIds = List.from(savedIds);
    for (var site in supported) {
      if (!orderIds.contains(site.id)) {
        orderIds.add(site.id);
      }
    }

    for (var id in orderIds) {
      final siteElement = supported.firstWhereOrNull((element) => element.id == id);
      if (siteElement != null) {
        sites.add(siteElement);
      }
    }
    super.onInit();
  }

  Color get themeColor => HexColor(SettingsService.to.theme.themeColorSwitch.v);

  bool isSiteVisible(String id) {
    return SettingsService.to.fav.hotAreasList.v.contains(id);
  }

  void onChanged(String id, bool value) {
    List<String> currentList = List.from(SettingsService.to.fav.hotAreasList.v);
    if (value) {
      if (!currentList.contains(id)) {
        currentList.add(id);
      }
    } else {
      currentList.remove(id);
    }

    List<Site> sortedSites = [];
    for (var item in sites) {
      if (currentList.contains(item.id)) {
        sortedSites.add(item);
      }
    }
    for (var item in sites) {
      if (!currentList.contains(item.id)) {
        sortedSites.add(item);
      }
    }

    sites.assignAll(sortedSites);
    SettingsService.to.fav.hotAreasList.v = currentList;
  }

  void onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = sites.removeAt(oldIndex);
    sites.insert(newIndex, item);

    final currentSavedIds = SettingsService.to.fav.hotAreasList.v;
    List<String> newOrderSavedIds = [];
    for (var site in sites) {
      if (currentSavedIds.contains(site.id)) {
        newOrderSavedIds.add(site.id);
      }
    }
    SettingsService.to.fav.hotAreasList.v = newOrderSavedIds;
  }
}
