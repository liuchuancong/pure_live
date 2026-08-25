import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/popular/popular_grid_controller.dart';

class PopularController extends GetxController with GetTickerProviderStateMixin {
  late TabController tabController;
  int index = 0;
  late List<Site> sites;
  bool _isTabControllerInitialized = false;
  bool _isClosing = false;
  int _generation = 0;
  Timer? _settledTabLoadTimer;
  Timer? _adjacentWarmTimer;
  Timer? _audienceRefreshTimer;
  Worker? _hotAreasWorker;
  Worker? _audienceModeWorker;
  Worker? _audiencePlatformsWorker;

  @override
  void onInit() {
    super.onInit();

    _initTabController(isFirstLoad: true);

    _hotAreasWorker = debounce(SettingsService.to.fav.hotAreasList, (_) {
      if (_isClosing) return;
      _initTabController(isFirstLoad: false);
    }, time: const Duration(milliseconds: 150));
    _audienceModeWorker = ever(SettingsService.to.app.preferRealOnlineCounts, (_) => _scheduleAudienceRefresh());
    _audiencePlatformsWorker = ever(SettingsService.to.app.realOnlinePlatforms, (_) => _scheduleAudienceRefresh());
  }

  void initControllers(List<Site> sites) {
    for (final site in sites) {
      final tag = site.id;

      if (Get.isRegistered<BasePageScrollAndStateBone<LiveRoom>>(tag: tag)) {
        continue;
      }

      Get.lazyPut<BasePageScrollAndStateBone<LiveRoom>>(
        () {
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

          if (site.id == Sites.ccSite) {
            // CC's server order is heat-based. Fetch a larger stable candidate
            // window so real-online mode can rank by vision_visitor rather
            // than merely reordering each 20-card slice.
            return PopularServerFixedController(site, fixedSize: 100);
          }

          if (site.id == Sites.douyinSite) {
            return PopularServerFixedController(site, fixedSize: 20);
          }

          return PopularServerRemoteController(site);
        },
        tag: tag,
        fenix: true,
      );
    }
  }

  @override
  void onClose() {
    _isClosing = true;
    _generation++;

    _settledTabLoadTimer?.cancel();
    _adjacentWarmTimer?.cancel();
    _audienceRefreshTimer?.cancel();
    _hotAreasWorker?.dispose();
    _audienceModeWorker?.dispose();
    _audiencePlatformsWorker?.dispose();

    if (_isTabControllerInitialized) {
      tabController.removeListener(_handleTabChange);
      tabController.dispose();
      _isTabControllerInitialized = false;
    }

    super.onClose();
  }

  void _scheduleAudienceRefresh() {
    if (_isClosing) return;
    _audienceRefreshTimer?.cancel();
    _audienceRefreshTimer = Timer(const Duration(milliseconds: 160), () {
      if (_isClosing) return;
      unawaited(refreshCurrentData());
    });
  }

  void _initTabController({required bool isFirstLoad}) {
    if (_isClosing) return;

    final generation = ++_generation;

    _settledTabLoadTimer?.cancel();
    _adjacentWarmTimer?.cancel();

    final newSites = Sites().availableSites();

    if (newSites.isEmpty) {
      if (_isTabControllerInitialized) {
        tabController.removeListener(_handleTabChange);
        tabController.dispose();
        _isTabControllerInitialized = false;
      }

      sites = newSites;
      index = 0;
      return;
    }

    final oldIndex = index;
    final oldSiteId = _isTabControllerInitialized && sites.isNotEmpty && index >= 0 && index < sites.length
        ? sites[index].id
        : null;

    sites = newSites;

    initControllers(sites);

    if (isFirstLoad) {
      final preferPlatform = SettingsService.to.fav.preferPlatform.v;
      final pIndex = sites.indexWhere((e) => e.id == preferPlatform);
      index = pIndex == -1 ? 0 : pIndex;
    } else if (oldSiteId != null) {
      final newIndex = sites.indexWhere((e) => e.id == oldSiteId);
      index = newIndex == -1 ? oldIndex.clamp(0, sites.length - 1) : newIndex;
    } else {
      index = oldIndex.clamp(0, sites.length - 1);
    }

    if (_isTabControllerInitialized) {
      tabController.removeListener(_handleTabChange);
      tabController.dispose();
      _isTabControllerInitialized = false;
    }

    tabController = TabController(length: sites.length, vsync: this, initialIndex: index);

    tabController.addListener(_handleTabChange);
    _isTabControllerInitialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isClosing || generation != _generation) return;
      unawaited(_loadDataAtIndex(index, generation: generation));
    });
  }

  void _handleTabChange() {
    if (_isClosing || !_isTabControllerInitialized) return;
    if (tabController.indexIsChanging) return;

    final animationValue = tabController.animation?.value ?? tabController.index.toDouble();

    if ((animationValue - tabController.index).abs() > 0.001) return;
    if (index == tabController.index) return;

    index = tabController.index;

    final generation = _generation;

    _settledTabLoadTimer?.cancel();
    _settledTabLoadTimer = Timer(const Duration(milliseconds: 80), () {
      if (_isClosing || generation != _generation) return;
      unawaited(_loadDataAtIndex(index, generation: generation));
    });
  }

  Future<void> _loadDataAtIndex(int i, {required int generation}) async {
    if (_isClosing || generation != _generation) return;
    if (sites.isEmpty || i < 0 || i >= sites.length) return;

    final siteId = sites[i].id;

    if (!Get.isRegistered<BasePageScrollAndStateBone<LiveRoom>>(tag: siteId)) {
      initControllers(sites);
    }

    if (!Get.isRegistered<BasePageScrollAndStateBone<LiveRoom>>(tag: siteId)) {
      return;
    }

    final gridController = Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: siteId);

    if (gridController.list.isEmpty) {
      await gridController.loadData();
    }

    if (_isClosing || generation != _generation) return;
    if (i != index || gridController.list.isEmpty) return;

    _adjacentWarmTimer?.cancel();
    _adjacentWarmTimer = Timer(const Duration(milliseconds: 700), () {
      if (_isClosing || generation != _generation) return;
      _warmNextPlatform(i, gridController, generation);
    });
  }

  void _warmNextPlatform(int currentIndex, BasePageScrollAndStateBone<LiveRoom> current, int generation) {
    if (_isClosing || generation != _generation) return;
    if (currentIndex != index || sites.length < 2) return;

    if (current.scrollController.hasClients && current.scrollController.position.isScrollingNotifier.value) {
      _adjacentWarmTimer?.cancel();
      _adjacentWarmTimer = Timer(const Duration(milliseconds: 450), () {
        if (_isClosing || generation != _generation) return;
        _warmNextPlatform(currentIndex, current, generation);
      });
      return;
    }

    final nextIndex = currentIndex + 1 < sites.length ? currentIndex + 1 : currentIndex - 1;

    if (nextIndex < 0) return;

    final siteId = sites[nextIndex].id;

    if (!Get.isRegistered<BasePageScrollAndStateBone<LiveRoom>>(tag: siteId)) {
      initControllers(sites);
    }

    if (!Get.isRegistered<BasePageScrollAndStateBone<LiveRoom>>(tag: siteId)) {
      return;
    }

    final next = Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: siteId);

    if (next.list.isEmpty) {
      unawaited(next.loadData());
    }
  }

  Future<void> refreshCurrentData() async {
    if (_isClosing) return;
    if (sites.isEmpty || index < 0 || index >= sites.length) return;

    final siteId = sites[index].id;

    if (!Get.isRegistered<BasePageScrollAndStateBone<LiveRoom>>(tag: siteId)) {
      initControllers(sites);
    }

    if (!Get.isRegistered<BasePageScrollAndStateBone<LiveRoom>>(tag: siteId)) {
      return;
    }

    final gridController = Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: siteId);

    await gridController.refreshData();
  }
}
