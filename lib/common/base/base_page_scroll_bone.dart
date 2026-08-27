import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/base/base_controller.dart';
import 'package:pure_live/common/global/platform_utils.dart';

abstract class BasePageScrollAndStateBone<T> extends BaseController {
  final ScrollController _ownedScrollController = createPureLiveScrollController();
  ScrollController? _boundScrollController;

  /// Scroll position used by paging buttons and visibility flags.
  ///
  /// A tabbed view can bind one dedicated controller for its active tab. This
  /// keeps every PageView child on a unique ScrollController while preserving
  /// the shared paging actions.
  ScrollController get scrollController => _boundScrollController ?? _ownedScrollController;
  final EasyRefreshController easyRefreshController = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );

  int currentPage = 1;
  final pageSize = 20.obs;
  final canLoadMore = false.obs;
  final list = <T>[].obs;
  final totalCount = Rxn<int>();

  final showBackToTop = false.obs;
  final showBackToBottom = true.obs;

  bool? _lastIsDesktop;
  Timer? _layoutRefreshTimer;

  BasePageScrollAndStateBone() {
    // Controllers are created from an already mounted route, so Get.width is
    // available here.  Establishing the initial paging mode before the first
    // frame prevents BasePageView from starting a second network refresh from
    // inside build while the controller's initial request is still running.
    final initialIsDesktop = Get.width > 680 && !PlatformUtils.isMobile;
    _lastIsDesktop = initialIsDesktop;
    pageSize.value = initialIsDesktop && Get.isRegistered<SettingsService>()
        ? SettingsService.to.page.defaultPageSize.v
        : 20;
    _ownedScrollController.addListener(_scrollListener);
  }

  void bindActiveScrollController(ScrollController? externalController) {
    if (isClosed) return;
    final previous = scrollController;
    if (identical(previous, externalController) ||
        (externalController == null && identical(previous, _ownedScrollController))) {
      return;
    }
    previous.removeListener(_scrollListener);
    _boundScrollController = externalController;
    scrollController.addListener(_scrollListener);
    _syncScrollFlags();
  }

  void checkAndNotifyLayoutChange(bool isDesktop) {
    if (_lastIsDesktop == isDesktop) return;
    final previousIsDesktop = _lastIsDesktop;
    _lastIsDesktop = isDesktop;

    if (isDesktop) {
      pageSize.value = SettingsService.to.page.defaultPageSize.v;
      final int currentFirstItemIndex = (currentPage - 1) * 20;
      currentPage = (currentFirstItemIndex ~/ pageSize.value) + 1;
    } else {
      pageSize.value = 20;
      currentPage = 1;
    }

    // The first layout observation only configures paging.  A real breakpoint
    // transition is coalesced and refreshed after layout settles, rather than
    // mutating the data source during a widget build.
    if (previousIsDesktop == null) return;
    _layoutRefreshTimer?.cancel();
    _layoutRefreshTimer = Timer(const Duration(milliseconds: 120), () => unawaited(refreshData()));
  }

  bool get usesDesktopPagination => _lastIsDesktop ?? Get.width > 680 && !PlatformUtils.isMobile;

  void _scrollListener() {
    _syncScrollFlags();
  }

  void _syncScrollFlags() {
    if (!scrollController.hasClients) {
      if (showBackToTop.value) showBackToTop.value = false;
      if (!showBackToBottom.value) showBackToBottom.value = true;
      return;
    }
    final offset = scrollController.offset;
    final position = scrollController.position;
    final maxScroll = position.maxScrollExtent;

    if (offset > 400 && !showBackToTop.value) {
      showBackToTop.value = true;
    } else if (offset <= 400 && showBackToTop.value) {
      showBackToTop.value = false;
    }

    if (position.atEdge && offset > 0) {
      showBackToBottom.value = false;
    } else {
      if (maxScroll - offset > 400) {
        if (!showBackToBottom.value) showBackToBottom.value = true;
      } else {
        if (showBackToBottom.value) showBackToBottom.value = false;
      }
    }
  }

  @override
  void onClose() {
    _layoutRefreshTimer?.cancel();
    scrollController.removeListener(_scrollListener);
    _boundScrollController = null;
    _ownedScrollController.dispose();
    easyRefreshController.dispose();
    super.onClose();
  }

  void scrollToTopImmediate() {
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
  }

  void finishRefreshControllers(IndicatorResult result) {
    if (usesDesktopPagination) return;
    easyRefreshController.finishRefresh(
      result == IndicatorResult.fail ? IndicatorResult.fail : IndicatorResult.success,
    );
    easyRefreshController.finishLoad(result);
  }

  void scrollToBottom() {
    if (!scrollController.hasClients) return;
    final distance = (scrollController.position.maxScrollExtent - scrollController.offset).abs();
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: _scrollAnimationDuration(distance),
      curve: Curves.easeOutCubic,
    );
  }

  void scrollToTopOrRefresh() {
    if (!scrollController.hasClients) return;
    if (scrollController.offset > 0) {
      scrollController.animateTo(
        0,
        duration: _scrollAnimationDuration(scrollController.offset),
        curve: Curves.easeOutCubic,
      );
    } else {
      if (_lastIsDesktop ?? Get.width > 680 && !PlatformUtils.isMobile) {
        refreshData();
      } else {
        easyRefreshController.callRefresh();
      }
    }
  }

  Duration _scrollAnimationDuration(double distance) {
    return Duration(milliseconds: (180 + distance / 8).round().clamp(220, 520));
  }

  Future<void> loadMoreData() async {
    if (loadding.value) return;
    if (usesDesktopPagination) {
      await goToPage(currentPage + 1);
    } else {
      currentPage++;
      await loadData();
    }
  }

  Future<void> loadData();
  Future<void> refreshData();
  Future<void> goToPage(int page);
  void setPageSize(int? newSize);
}
