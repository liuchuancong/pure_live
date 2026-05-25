import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/base/base_controller.dart';

class HotAreasController extends BaseController {
  final SettingsService settingsController = Get.find<SettingsService>();
  final sites = <Site>[].obs;

  @override
  void onInit() {
    final savedIds = settingsController.hotAreasList.value;
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

  Color get themeColor => HexColor(settingsController.themeColorSwitch.value);

  bool isSiteVisible(String id) {
    return settingsController.hotAreasList.value.contains(id);
  }

  void onChanged(String id, bool value) {
    List<String> currentList = List.from(settingsController.hotAreasList.value);
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
    settingsController.hotAreasList.value = currentList;
  }

  void onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = sites.removeAt(oldIndex);
    sites.insert(newIndex, item);

    final currentSavedIds = settingsController.hotAreasList.value;
    List<String> newOrderSavedIds = [];
    for (var site in sites) {
      if (currentSavedIds.contains(site.id)) {
        newOrderSavedIds.add(site.id);
      }
    }
    settingsController.hotAreasList.value = newOrderSavedIds;
  }
}
