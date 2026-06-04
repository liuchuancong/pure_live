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
  final pageSize = 30.obs;
  final canLoadMore = false.obs;
  final list = <T>[].obs;
  final totalCount = Rxn<int>();

  final showBackToTop = false.obs;
  final showBackToBottom = true.obs;
  final Map<int, List<T>> _pageCache = {};

  List<T>? _rawAllData;

  BasePageController() {
    scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
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
  }

  @override
  void onClose() {
    scrollController.removeListener(_scrollListener);
    scrollController.dispose();
    easyRefreshController.dispose();
    _pageCache.clear();
    _rawAllData = null;
    super.onClose();
  }

  Future<List<T>> getData(int page, int pageSize);

  Future<void> refreshData() async {
    _pageCache.clear();
    _rawAllData = null;
    await loadData();
  }

  Future<void> loadMoreData() async {
    if (loadding || !canLoadMore.value) {
      _finishRefreshControllers(IndicatorResult.noMore);
      return;
    }
    currentPage++;
    await loadData();
  }

  Future<void> goToPage(int page) async {
    if (loadding || page < 1) return;
    if (page > currentPage && !canLoadMore.value && !_pageCache.containsKey(page)) return;

    currentPage = page;
    await loadData();
  }

  void setPageSize(int? newSize) {
    if (newSize == null || pageSize.value == newSize) return;

    final int currentFirstItemIndex = (currentPage - 1) * pageSize.value;
    final int targetPage = (currentFirstItemIndex ~/ newSize) + 1;

    pageSize.value = newSize;
    currentPage = targetPage;
    _pageCache.clear();
    loadData();
  }

  Future<void> loadData() async {
    if (loadding) return;

    if (_rawAllData != null) {
      _processLocalPaging();
      return;
    }

    if (_pageCache.containsKey(currentPage)) {
      final cachedData = _pageCache[currentPage]!;
      list.assignAll(cachedData);
      canLoadMore.value = _pageCache.containsKey(currentPage + 1) || cachedData.length >= pageSize.value;
      pageEmpty.value = list.isEmpty;
      _finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);
      _scrollToTopImmediate();
      return;
    }

    final bool isNetworkSafe = await checkNetworkBeforeRequest();
    if (!isNetworkSafe) {
      _finishRefreshControllers(IndicatorResult.fail);
      return;
    }

    try {
      loadding = true;
      pageError.value = false;
      pageEmpty.value = false;
      notLogin.value = false;

      if (list.isEmpty) {
        pageLoadding.value = true;
      }

      final result = await getData(currentPage, pageSize.value);

      if (result.length > pageSize.value && currentPage == 1) {
        _rawAllData = result;
        loadding = false;
        pageLoadding.value = false;
        _processLocalPaging();
        return;
      }

      final bool hasMore = result.length >= pageSize.value;
      canLoadMore.value = hasMore;
      _pageCache[currentPage] = result;
      list.assignAll(result);
      pageEmpty.value = list.isEmpty;

      _finishRefreshControllers(hasMore ? IndicatorResult.success : IndicatorResult.noMore);
      _scrollToTopImmediate();
    } catch (e) {
      handleError(e, showPageError: list.isEmpty);
      _finishRefreshControllers(IndicatorResult.fail);
    } finally {
      loadding = false;
      pageLoadding.value = false;
    }
  }

  void _processLocalPaging() {
    if (_rawAllData == null) return;

    final allItems = _rawAllData!;
    if (totalCount.value == null || totalCount.value == 0) {
      totalCount.value = allItems.length;
    }

    final int startIndex = (currentPage - 1) * pageSize.value;
    if (startIndex >= allItems.length) {
      list.clear();
      canLoadMore.value = false;
      pageEmpty.value = true;
      _finishRefreshControllers(IndicatorResult.noMore);
      return;
    }

    int endIndex = startIndex + pageSize.value;
    if (endIndex > allItems.length) {
      endIndex = allItems.length;
    }

    final pageItems = allItems.sublist(startIndex, endIndex);
    canLoadMore.value = endIndex < allItems.length;

    list.assignAll(pageItems);
    pageEmpty.value = list.isEmpty;

    _finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);
    _scrollToTopImmediate();
  }

  void _finishRefreshControllers(IndicatorResult result) {
    if (PlatformUtils.isDesktop) return;
    easyRefreshController.finishRefresh(
      result == IndicatorResult.fail ? IndicatorResult.fail : IndicatorResult.success,
    );
    easyRefreshController.finishLoad(result);
  }

  void _scrollToTopImmediate() {
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
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
