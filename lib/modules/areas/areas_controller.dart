import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';

class AreasController extends GetxController with GetTickerProviderStateMixin {
  late TabController tabController;

  int index = 0;

  List<dynamic> sites = [];

  bool _isTabControllerInitialized = false;

  @override
  void onInit() {
    super.onInit();

    _initTabController(isFirstLoad: true);

    ever(SettingsService.to.fav.hotAreasList, (_) => _refreshTabs());
  }

  @override
  void onClose() {
    if (_isTabControllerInitialized) {
      tabController.removeListener(_handleTabChange);
      tabController.dispose();
    }

    super.onClose();
  }

  void _refreshTabs() {
    final newSites = Sites().availableSites();

    final changed =
        sites.length != newSites.length ||
        !List.generate(sites.length, (i) => sites[i].id == newSites[i].id).every((e) => e);

    if (!changed) {
      return;
    }

    _initTabController(isFirstLoad: false);
  }

  AreasListController _ensureListController(dynamic site) {
    final tag = site.id;

    if (!Get.isRegistered<AreasListController>(tag: tag)) {
      Get.lazyPut(() => AreasListController(site), tag: tag, fenix: true);
    }

    return Get.find<AreasListController>(tag: tag);
  }

  void _initTabController({required bool isFirstLoad}) {
    final newSites = Sites().availableSites();

    if (newSites.isEmpty) {
      if (_isTabControllerInitialized) {
        tabController.removeListener(_handleTabChange);
        tabController.dispose();
        _isTabControllerInitialized = false;
      }

      sites = [];
      index = 0;
      return;
    }

    sites = newSites;

    for (final site in sites) {
      _ensureListController(site);
    }

    if (isFirstLoad) {
      final preferPlatform = SettingsService.to.fav.preferPlatform.v;

      final pIndex = sites.indexWhere((e) => e.id == preferPlatform);

      index = pIndex == -1 ? 0 : pIndex;
    } else {
      if (index >= sites.length) {
        index = 0;
      }
    }

    if (_isTabControllerInitialized) {
      tabController.removeListener(_handleTabChange);
      tabController.dispose();
    }

    tabController = TabController(length: sites.length, vsync: this, initialIndex: index);

    tabController.addListener(_handleTabChange);

    _isTabControllerInitialized = true;

    _loadCurrentTabData(index);
  }

  void _handleTabChange() {
    if (tabController.indexIsChanging) {
      return;
    }

    if (index != tabController.index) {
      index = tabController.index;
      _loadCurrentTabData(index);
    }
  }

  void _loadCurrentTabData(int i) {
    if (sites.isEmpty || i < 0 || i >= sites.length) {
      return;
    }

    final site = sites[i];

    final listController = _ensureListController(site);

    if (listController.list.isEmpty) {
      listController.loadData();
    }
  }
}
