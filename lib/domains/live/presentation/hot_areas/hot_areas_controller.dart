import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/domains/live/data/favorite_room_controller.dart';

class HotAreasController extends GetxController {
  final sites = <Site>[].obs;

  @override
  void onInit() {
    final savedIds = FavoriteRoomController.to.hotAreasList.v;
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

  Color get themeColor => SettingsService.to.theme.themeColor;

  bool isSiteVisible(String id) {
    return FavoriteRoomController.to.hotAreasList.v.contains(id);
  }

  void onChanged(String id, bool value) {
    List<String> currentList = List.from(FavoriteRoomController.to.hotAreasList.v);
    if (value) {
      if (!currentList.contains(id)) {
        currentList.add(id);
      }
    } else {
      if (!currentList.contains(id)) return;
      if (currentList.length <= 1) {
        ToastUtil.show(i18n('at_least_one_platform_required'));
        return;
      }
      currentList.remove(id);
    }

    final currentPreference = FavoriteRoomController.to.preferPlatform.v;
    if (currentList.isNotEmpty && !currentList.contains(currentPreference)) {
      FavoriteRoomController.to.preferPlatform.v = currentList.first;
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
    FavoriteRoomController.to.hotAreasList.v = currentList;
  }

  void onReorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= sites.length) return;
    final currentSavedIds = List<String>.from(FavoriteRoomController.to.hotAreasList.v);
    if (currentSavedIds.length <= 1 || !currentSavedIds.contains(sites[oldIndex].id)) return;
    if (newIndex < 0) return;
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = sites.removeAt(oldIndex);
    sites.insert(newIndex.clamp(0, sites.length), item);

    final visibleIds = currentSavedIds.toSet();
    final visibleSites = sites.where((site) => visibleIds.contains(site.id)).toList(growable: false);
    final hiddenSites = sites.where((site) => !visibleIds.contains(site.id)).toList(growable: false);
    sites.assignAll([...visibleSites, ...hiddenSites]);
    final newOrderSavedIds = visibleSites.map((site) => site.id).toList(growable: false);
    FavoriteRoomController.to.hotAreasList.v = newOrderSavedIds;
  }
}
