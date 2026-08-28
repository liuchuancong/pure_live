import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';

class AreasController extends GetxController with GetTickerProviderStateMixin {
  late TabController tabController;

  int index = 0;

  List<dynamic> sites = [];

  bool _isTabControllerInitialized = false;
  Timer? _settledTabLoadTimer;
  Timer? _adjacentWarmTimer;
  Worker? _hotAreasWorker;

  @override
  void onInit() {
    super.onInit();

    _initTabController(isFirstLoad: true);

    _hotAreasWorker = ever(SettingsService.to.fav.hotAreasList, (_) => _refreshTabs());
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

  void _registerListController(dynamic site) {
    final tag = site.id;
    if (!Get.isRegistered<AreasListController>(tag: tag)) {
      Get.lazyPut(() => AreasListController(site), tag: tag, fenix: true);
    }
  }

  AreasListController _ensureListController(dynamic site) {
    _registerListController(site);
    return Get.find<AreasListController>(tag: site.id);
  }

  void _initTabController({required bool isFirstLoad}) {
    _settledTabLoadTimer?.cancel();
    _adjacentWarmTimer?.cancel();
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
      // Register all platforms without constructing their paging, refresh and
      // scroll controllers. Only the visible page and one idle neighbour are
      // materialized, keeping startup memory and listener count bounded.
      _registerListController(site);
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

    tabController = TabController(
      length: sites.length,
      vsync: this,
      initialIndex: index,
      animationDuration: pureLiveTabTransitionDuration,
    );

    tabController.addListener(_handleTabChange);

    _isTabControllerInitialized = true;

    unawaited(_loadCurrentTabData(index));
  }

  void _handleTabChange() {
    if (tabController.indexIsChanging) return;
    final animationValue = tabController.animation?.value ?? tabController.index.toDouble();
    if ((animationValue - tabController.index).abs() > 0.001) return;

    if (index != tabController.index) {
      index = tabController.index;
      _settledTabLoadTimer?.cancel();
      _settledTabLoadTimer = Timer(const Duration(milliseconds: 80), () => unawaited(_loadCurrentTabData(index)));
    }
  }

  Future<void> _loadCurrentTabData(int i) async {
    if (sites.isEmpty || i < 0 || i >= sites.length) {
      return;
    }

    final site = sites[i];

    final listController = _ensureListController(site);

    if (listController.list.isEmpty) {
      await listController.loadData();
    }
    if (i != index || listController.list.isEmpty) return;
    _adjacentWarmTimer?.cancel();
    _adjacentWarmTimer = Timer(const Duration(milliseconds: 800), () => _warmNextPlatform(i, listController));
  }

  void _warmNextPlatform(int currentIndex, AreasListController current) {
    if (currentIndex != index || sites.length < 2) return;
    if (current.scrollController.hasClients && current.scrollController.position.isScrollingNotifier.value) {
      _adjacentWarmTimer?.cancel();
      _adjacentWarmTimer = Timer(const Duration(milliseconds: 450), () => _warmNextPlatform(currentIndex, current));
      return;
    }
    final nextIndex = currentIndex + 1 < sites.length ? currentIndex + 1 : currentIndex - 1;
    if (nextIndex < 0) return;
    final next = _ensureListController(sites[nextIndex]);
    if (next.list.isEmpty) unawaited(next.loadData());
  }

  /// Revalidates the currently visible site's category catalogue when the app
  /// returns after being backgrounded, without fetching hidden platforms.
  Future<void> refreshCurrentData() async {
    if (sites.isEmpty || index < 0 || index >= sites.length) return;
    await _ensureListController(sites[index]).refreshData();
  }
}
