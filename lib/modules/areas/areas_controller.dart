import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';

class AreasController extends GetxController with GetTickerProviderStateMixin {
  final SettingsService settings = Get.find<SettingsService>();

  late TabController tabController;
  int index = 0;
  late List<dynamic> sites;
  bool _isTabControllerInitialized = false;

  @override
  void onInit() {
    super.onInit();

    _initTabController(isFirstLoad: true);

    ever(settings.hotAreasList, (_) {
      _initTabController(isFirstLoad: false);
    });
  }

  @override
  void onClose() {
    if (_isTabControllerInitialized) {
      tabController.removeListener(_handleTabChange);
      tabController.dispose();
    }
    super.onClose();
  }

  void _initTabController({required bool isFirstLoad}) {
    if (_isTabControllerInitialized) {
      tabController.removeListener(_handleTabChange);
      tabController.dispose();
    }

    sites = Sites().availableSites();
    if (sites.isEmpty) {
      _isTabControllerInitialized = false;
      return;
    }

    for (var site in sites) {
      if (!Get.isRegistered<AreasListController>(tag: site.id)) {
        Get.lazyPut(() => AreasListController(site), tag: site.id);
      }
    }

    if (isFirstLoad) {
      final preferPlatform = settings.preferPlatform.value;
      final pIndex = sites.indexWhere((e) => e.id == preferPlatform);
      index = pIndex == -1 ? 0 : pIndex;
    } else {
      if (index >= sites.length) {
        index = 0;
      }
    }

    tabController = TabController(length: sites.length, vsync: this, initialIndex: index);

    tabController.addListener(_handleTabChange);
    _isTabControllerInitialized = true;

    if (isFirstLoad && index > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        tabController.animateTo(index);
        _loadCurrentTabData(index);
      });
    } else {
      _loadCurrentTabData(index);
    }
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
    if (sites.isEmpty || i >= sites.length) return;
    var siteId = sites[i].id;
    var listController = Get.find<AreasListController>(tag: siteId);
    if (listController.list.isEmpty) {
      listController.loadData();
    }
  }
}
