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
  final showBackToBottom = false.obs;

  bool? _lastIsDesktop;
  bool? _pendingIsDesktop;
  int _layoutVersion = 0;
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
    // Content changes the scroll extent without a scroll event; re-evaluate
    // the jump buttons once the new list has been laid out.
    ever<List<T>>(list, (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isClosed) _syncScrollFlags();
    }));
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

  /// Async pagers expose their current operation, including connectivity and
  /// re-paging, so layout commits cannot change its dimensions mid-response.
  /// Synchronous local projections have no operation to await.
  Future<void>? get activePageOperation => null;

  void checkAndNotifyLayoutChange(bool isDesktop) {
    if (isClosed || (_pendingIsDesktop ?? _lastIsDesktop) == isDesktop) return;
    final version = ++_layoutVersion;
    _layoutRefreshTimer?.cancel();
    _pendingIsDesktop = isDesktop == _lastIsDesktop ? null : isDesktop;
    if (_pendingIsDesktop == null) return;

    // Keep the existing breakpoint debounce, but defer the state transition
    // itself as well as the refresh. Crossing back cancels the whole intent.
    _layoutRefreshTimer = Timer(const Duration(milliseconds: 120), () => unawaited(_commitLayout(version)));
  }

  Future<void> _commitLayout(int version) async {
    while (!isClosed && version == _layoutVersion) {
      final active = activePageOperation;
      if (active == null) break;
      await active;
    }
    if (isClosed || version != _layoutVersion) return;
    final isDesktop = _pendingIsDesktop;
    if (isDesktop == null) return;
    _pendingIsDesktop = null;
    final previousSize = pageSize.value;
    _lastIsDesktop = isDesktop;

    if (isDesktop) {
      pageSize.value = SettingsService.to.page.defaultPageSize.v;
      final int currentFirstItemIndex = (currentPage - 1) * previousSize;
      currentPage = (currentFirstItemIndex ~/ pageSize.value) + 1;
    } else {
      pageSize.value = 20;
      currentPage = 1;
    }

    await refreshData();
  }

  bool get usesDesktopPagination => _lastIsDesktop ?? Get.width > 680 && !PlatformUtils.isMobile;

  void _scrollListener() {
    _syncScrollFlags();
  }

  void _syncScrollFlags() {
    if (!scrollController.hasClients) {
      // Empty and error states have no scroll view: nothing to jump through.
      if (showBackToTop.value) showBackToTop.value = false;
      if (showBackToBottom.value) showBackToBottom.value = false;
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
    _layoutVersion++;
    _pendingIsDesktop = null;
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

  /// Default retry retains the legacy refresh behavior. Native-cursor pagers
  /// can resume the failed action without restarting already consumed pages.
  Future<void> retryData() => refreshData();
  String get retryActionLabel => i18n('retry');
  bool get showInlineError => false;
  String? get pageNotice => null;
  Future<void> refreshData();
  Future<void> goToPage(int page);
  void setPageSize(int? newSize);
}
