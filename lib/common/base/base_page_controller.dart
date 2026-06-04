import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/base/base_controller.dart';
import 'package:pure_live/common/global/platform_utils.dart';

abstract class BasePageController<T> extends BaseController {
  final ScrollController scrollController = ScrollController();
  final EasyRefreshController easyRefreshController = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );

  int currentPage = 1;
  int pageSize = 30;
  var canLoadMore = false.obs;
  var list = <T>[].obs;
  var totalCount = Rxn<int>();
  var showBackToTop = false.obs;
  var showBackToBottom = true.obs;
  final Map<int, List<T>> _pageCache = {};

  BasePageController() {
    scrollController.addListener(() {
      if (!scrollController.hasClients) return;
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
    });
  }

  @override
  void onClose() {
    scrollController.dispose();
    easyRefreshController.dispose();
    _pageCache.clear(); // 释放缓存
    super.onClose();
  }

  Future<List<T>> getData(int page, int pageSize);

  /// 💡 桌面端/通用：跳转到指定页（集成缓存读取、边界拦截）
  Future<void> goToPage(int page) async {
    if (loadding || page < 1) return;

    // 如果尝试往后翻页，但已经明确没有更多数据了，直接拦截
    if (page > currentPage && !canLoadMore.value && !_pageCache.containsKey(page)) return;

    currentPage = page;
    await loadData();
  }

  /// 下拉刷新（彻底清空本地所有缓存，重新去接口拉取第一页）
  Future refreshData() async {
    currentPage = 1;
    _pageCache.clear(); // 刷新时必须清空缓存
    await loadData();
  }

  /// 加载数据核心逻辑
  Future loadData() async {
    if (loadding) return;

    final bool isDesktop = PlatformUtils.isDesktop;
    final bool isNetworkSafe = await checkNetworkBeforeRequest();
    if (!isNetworkSafe) {
      if (!isDesktop) {
        easyRefreshController.finishRefresh(IndicatorResult.fail);
        easyRefreshController.finishLoad(IndicatorResult.fail);
      }
      return;
    }

    // 💡 优先检测：如果本地缓存过这一页的数据，直接读取缓存，不再发网络请求
    if (_pageCache.containsKey(currentPage)) {
      final cachedData = _pageCache[currentPage]!;
      list.assignAll(cachedData);

      // 判断当前页缓存后面是否还有数据（如果下一页有缓存，或者当前页满页，则认为还有下一页）
      canLoadMore.value = _pageCache.containsKey(currentPage + 1) || cachedData.length >= pageSize;
      pageEmpty.value = list.isEmpty;

      if (scrollController.hasClients) {
        scrollController.jumpTo(0);
      }
      return;
    }

    try {
      loadding = true;
      pageError.value = false;
      pageEmpty.value = false;
      notLogin.value = false;

      if (currentPage == 1 && list.isEmpty) {
        pageLoadding.value = true;
      }

      final result = await getData(currentPage, pageSize);
      final bool hasMore = result.length >= pageSize;
      canLoadMore.value = hasMore;
      _pageCache[currentPage] = result;
      list.assignAll(result);
      pageEmpty.value = list.isEmpty;

      if (scrollController.hasClients) {
        scrollController.jumpTo(0);
      }
      if (!isDesktop) {
        if (currentPage == 1) {
          if (easyRefreshController.controlFinishRefresh) {
            easyRefreshController.finishRefresh(IndicatorResult.success);
          }
          easyRefreshController.resetFooter();
        } else {
          if (easyRefreshController.controlFinishLoad) {
            easyRefreshController.finishLoad(hasMore ? IndicatorResult.success : IndicatorResult.noMore);
          }
        }
      }
    } catch (e) {
      handleError(e, showPageError: currentPage == 1 && list.isEmpty);
      if (!isDesktop) {
        if (currentPage == 1) {
          if (easyRefreshController.controlFinishRefresh) {
            easyRefreshController.finishRefresh(IndicatorResult.fail);
          }
        } else {
          if (easyRefreshController.controlFinishLoad) {
            easyRefreshController.finishLoad(IndicatorResult.fail);
          }
        }
      }
    } finally {
      loadding = false;
      pageLoadding.value = false;
    }
  }

  void scrollToBottom() {
    if (!scrollController.hasClients) return;
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
    );
  }

  void scrollToTopOrRefresh() {
    if (!scrollController.hasClients) return;
    if (scrollController.offset > 0) {
      scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.linear);
    } else {
      if (PlatformUtils.isDesktop) {
        refreshData();
      } else {
        easyRefreshController.callRefresh();
      }
    }
  }
}
