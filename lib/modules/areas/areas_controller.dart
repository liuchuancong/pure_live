import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';

class AreasController extends GetxController with GetSingleTickerProviderStateMixin {
  late TabController tabController;
  int index = 0;
  final isCustomSite = false.obs;
  late List<dynamic> sites;

  @override
  void onInit() {
    super.onInit();
    sites = Sites().availableSites();

    final preferPlatform = Get.find<SettingsService>().preferPlatform.value;
    final pIndex = sites.indexWhere((e) => e.id == preferPlatform);
    index = pIndex == -1 ? 0 : pIndex;

    tabController = TabController(length: sites.length, vsync: this);

    for (var site in sites) {
      Get.lazyPut(() => AreasListController(site), tag: site.id);
    }

    if (index > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        tabController.animateTo(index);
        _loadCurrentTabData(index);
      });
    } else {
      _loadCurrentTabData(0);
    }

    tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!tabController.indexIsChanging) {
      if (index != tabController.index) {
        index = tabController.index;
        _loadCurrentTabData(index);
      }
    }
  }

  void _loadCurrentTabData(int i) {
    var siteId = sites[i].id;
    isCustomSite.value = siteId == 'custom';
    // 只有在真的需要时才去找 Controller 并触发 loadData
    var listController = Get.find<AreasListController>(tag: siteId);
    if (listController.list.isEmpty) {
      listController.loadData();
    }
  }

  @override
  void onClose() {
    tabController.removeListener(_handleTabChange);
    tabController.dispose();
    super.onClose();
  }
}
