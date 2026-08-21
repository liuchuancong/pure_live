import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/popular/popular_grid_controller.dart';

class PopularController extends GetxController with GetTickerProviderStateMixin {
  late TabController tabController;
  int index = 0;
  late List<Site> sites;
  bool _isTabControllerInitialized = false;
  Timer? _settledTabLoadTimer;
  Timer? _adjacentWarmTimer;
  Worker? _hotAreasWorker;

  @override
  void onInit() {
    super.onInit();

    _initTabController(isFirstLoad: true);

    _hotAreasWorker = ever(SettingsService.to.fav.hotAreasList, (_) {
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
          if (site.id == Sites.soopSite) {
            return PopularServerFixedController(site, fixedSize: 60);
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
    _settledTabLoadTimer?.cancel();
    _adjacentWarmTimer?.cancel();
    _hotAreasWorker?.dispose();
    if (_isTabControllerInitialized) {
      tabController.removeListener(_handleTabChange);
      tabController.dispose();
    }
    super.onClose();
  }

  void _initTabController({required bool isFirstLoad}) {
    _settledTabLoadTimer?.cancel();
    _adjacentWarmTimer?.cancel();
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

    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_loadDataAtIndex(index)));
  }

  void _handleTabChange() {
    if (tabController.indexIsChanging) return;

    // During a finger-driven TabBarView drag, TabController.index changes at
    // the half-way point while the page is still moving. Starting network work
    // and rebuilding the destination grid in that frame caused visible hitching.
    final animationValue = tabController.animation?.value ?? tabController.index.toDouble();
    if ((animationValue - tabController.index).abs() > 0.001) return;
    if (index == tabController.index) return;

    index = tabController.index;
    _settledTabLoadTimer?.cancel();
    _settledTabLoadTimer = Timer(const Duration(milliseconds: 80), () => unawaited(_loadDataAtIndex(index)));
  }

  Future<void> _loadDataAtIndex(int i) async {
    if (sites.isEmpty || i >= sites.length) return;
    var siteId = sites[i].id;
    var gridController = Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: siteId);
    if (gridController.list.isEmpty) {
      await gridController.loadData();
    }
    if (i != index || gridController.list.isEmpty) return;

    // Warm one neighbouring platform only after the visible grid is complete
    // and idle. This avoids a startup request storm while making the next
    // horizontal swipe land on an already stable snapshot.
    _adjacentWarmTimer?.cancel();
    _adjacentWarmTimer = Timer(const Duration(milliseconds: 700), () => _warmNextPlatform(i, gridController));
  }

  void _warmNextPlatform(int currentIndex, BasePageScrollAndStateBone<LiveRoom> current) {
    if (currentIndex != index || sites.length < 2) return;
    if (current.scrollController.hasClients && current.scrollController.position.isScrollingNotifier.value) {
      _adjacentWarmTimer?.cancel();
      _adjacentWarmTimer = Timer(const Duration(milliseconds: 450), () => _warmNextPlatform(currentIndex, current));
      return;
    }

    final nextIndex = currentIndex + 1 < sites.length ? currentIndex + 1 : currentIndex - 1;
    if (nextIndex < 0) return;
    final next = Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: sites[nextIndex].id);
    if (next.list.isEmpty) unawaited(next.loadData());
  }

  /// Refreshes only the visible platform after a real app foreground return.
  /// This avoids both stale live cards and a simultaneous request storm across
  /// every configured platform.
  Future<void> refreshCurrentData() async {
    if (sites.isEmpty || index < 0 || index >= sites.length) return;
    final siteId = sites[index].id;
    final gridController = Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: siteId);
    await gridController.refreshData();
  }
}
