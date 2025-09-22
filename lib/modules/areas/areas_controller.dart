import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';

class AreasController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late TabController tabController;
  int index = 0;
  final isCustomSite = false.obs;

  AreasController() {
    final preferPlatform = Get.find<SettingsService>().preferPlatform.value;
    final pIndex =
        Sites().availableSites().indexWhere((e) => e.id == preferPlatform);
    tabController = TabController(
      initialIndex: pIndex == -1 ? 0 : pIndex,
      length: Sites().availableSites().length,
      vsync: this,
    );
    index = pIndex == -1 ? 0 : pIndex;
    tabController.animation?.addListener(() {
      var currentIndex = (tabController.animation?.value ?? 0).round();
      if (index == currentIndex) {
        return;
      }
      index = currentIndex;
      var controller = Get.find<AreasListController>(
          tag: Sites().availableSites()[index].id);
      isCustomSite.value = controller.site.id == 'custom';
      if (controller.list.isEmpty) {
        controller.loadData();
      }
    });
  }

  @override
  void onInit() async {
    List<Future> futures = [];
    var availableSites = Sites().availableSites();
    for (var i = 0; i < availableSites.length; i++) {
      var site = availableSites[i];
      futures.add(Future(() async {
        Get.put(AreasListController(site), tag: site.id);
        var controller = Get.find<AreasListController>(tag: site.id);
        if (controller.list.isEmpty && index == i) {
          controller.loadData();
        }
      }));
    }
    await Future.wait(futures);

    super.onInit();
  }
}
