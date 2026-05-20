import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/popular/popular_grid_controller.dart';

class PopularController extends GetxController with GetSingleTickerProviderStateMixin {
  late TabController tabController;
  int index = 0;
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
      Get.lazyPut(() => PopularGridController(site), tag: site.id);
    }

    if (index > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        tabController.animateTo(index);
        _loadDataAtIndex(index);
      });
    } else {
      _loadDataAtIndex(0);
    }

    tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!tabController.indexIsChanging) {
      if (index != tabController.index) {
        index = tabController.index;
        _loadDataAtIndex(index);
      }
    }
  }

  void _loadDataAtIndex(int i) {
    var siteId = sites[i].id;
    var controller = Get.find<PopularGridController>(tag: siteId);
    if (controller.list.isEmpty) {
      controller.loadData();
    }
  }

  @override
  void onClose() {
    tabController.removeListener(_handleTabChange);
    tabController.dispose();
    super.onClose();
  }
}
