import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/popular/popular_grid_controller.dart';

class PopularController extends GetxController with GetTickerProviderStateMixin {
  late TabController tabController;
  int index = 0;
  late List<Site> sites;
  bool _isTabControllerInitialized = false;

  @override
  void onInit() {
    super.onInit();

    _initTabController(isFirstLoad: true);

    ever(SettingsService.to.fav.hotAreasList, (_) {
      _initTabController(isFirstLoad: false);
    });
  }

  void initControllers(List<Site> sites) {
    for (Site site in sites) {
      final tag = site.id;

      if (!Get.isRegistered<BasePageScrollAndStateBone<LiveRoom>>(tag: tag)) {
        Get.lazyPut<BasePageScrollAndStateBone<LiveRoom>>(() {
          if (site.id == Sites.iptvSite) {
            return PopularLocalReactiveController(site);
          }

          if (site.id == Sites.kuaishouSite) {
            return PopularServerAllController(site);
          }

          if (site.id == Sites.douyuSite) {
            return PopularServerFixedController(site, fixedSize: 40);
          }
          if (site.id == Sites.huyaSite) {
            return PopularServerFixedController(site, fixedSize: 120);
          }
          if (site.id == Sites.douyinSite) {
            return PopularServerFixedController(site, fixedSize: 20);
          }
          return PopularServerRemoteController(site);
        }, tag: tag);
      }
    }
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

    initControllers(sites);
    if (isFirstLoad) {
      final preferPlatform = SettingsService.to.fav.preferPlatform.v;
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
        _loadDataAtIndex(index);
      });
    } else {
      _loadDataAtIndex(index);
    }
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
    if (sites.isEmpty || i >= sites.length) return;
    var siteId = sites[i].id;
    var gridController = Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: siteId);
    if (gridController.list.isEmpty) {
      gridController.loadData();
    }
  }
}
