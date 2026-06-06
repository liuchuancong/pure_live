import 'dart:async';
import 'package:pure_live/common/index.dart';

abstract class ServerRemotePageController<T> extends BasePageScrollAndStateBone<T> {
  final Map<int, List<T>> _pageCache = {};
  int _virtualNetworkPage = 1;

  ServerRemotePageController() : super();

  Future<List<T>> fetchNetworkData(int page, int pageSize);

  @override
  Future<void> refreshData() async {
    currentPage = 1;
    _virtualNetworkPage = 1;
    _pageCache.clear();
    await loadData();
  }

  @override
  Future<void> goToPage(int page) async {
    if (loadding || page < 1) return;
    if (page > currentPage && !canLoadMore.value && !_pageCache.containsKey(page)) return;
    currentPage = page;
    await loadData();
  }

  @override
  void setPageSize(int? newSize) {
    if (newSize == null || pageSize.value == newSize) return;

    final int previousSize = pageSize.value;
    final int currentFirstItemIndex = (currentPage - 1) * previousSize;

    List<T> allHistoryItems = [];
    final sortedKeys = _pageCache.keys.toList()..sort();
    for (var key in sortedKeys) {
      allHistoryItems.addAll(_pageCache[key]!);
    }

    pageSize.value = newSize;
    currentPage = (currentFirstItemIndex ~/ newSize) + 1;

    _pageCache.clear();

    _adaptiveRebuildAndFetchMore(allHistoryItems);
  }

  Future<void> _adaptiveRebuildAndFetchMore(List<T> historyPool) async {
    if (loadding) return;

    final int targetTotalItemsNeeded = currentPage * pageSize.value;

    if (historyPool.length < targetTotalItemsNeeded && canLoadMore.value) {
      final bool isNetworkSafe = await checkNetworkBeforeRequest();
      if (!isNetworkSafe) {
        finishRefreshControllers(IndicatorResult.fail);
        return;
      }

      try {
        loadding = true;
        while (historyPool.length < targetTotalItemsNeeded) {
          final int missingCount = targetTotalItemsNeeded - historyPool.length;
          final result = await fetchNetworkData(_virtualNetworkPage, missingCount);

          if (result.isEmpty) break;

          historyPool.addAll(result);
          _virtualNetworkPage++;
        }
      } catch (e) {
        handleError(e, showPageError: list.isEmpty);
      } finally {
        loadding = false;
      }
    }

    int chunkIndex = 1;
    for (int i = 0; i < historyPool.length; i += pageSize.value) {
      int end = i + pageSize.value;
      if (end > historyPool.length) end = historyPool.length;
      _pageCache[chunkIndex] = historyPool.sublist(i, end);
      chunkIndex++;
    }

    final cachedData = _pageCache[currentPage] ?? [];
    list.assignAll(cachedData);
    canLoadMore.value = cachedData.length >= pageSize.value;
    pageEmpty.value = list.isEmpty;

    finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);
    update();
  }

  @override
  Future<void> loadData() async {
    if (loadding) return;
    totalCount.value = null;

    if (_pageCache.containsKey(currentPage)) {
      final cachedData = _pageCache[currentPage]!;
      list.assignAll(cachedData);
      canLoadMore.value = cachedData.length >= pageSize.value;
      pageEmpty.value = list.isEmpty;
      finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);
      scrollToTopImmediate();
      return;
    }

    final bool isNetworkSafe = await checkNetworkBeforeRequest();
    if (!isNetworkSafe) {
      finishRefreshControllers(IndicatorResult.fail);
      return;
    }

    final int previousPageSnapshot = currentPage;
    try {
      loadding = true;
      pageError.value = false;
      pageEmpty.value = false;
      notLogin.value = false;
      if (list.isEmpty) pageLoadding.value = true;

      List<T> combinedResult = [];

      while (combinedResult.length < pageSize.value) {
        final int neededCount = pageSize.value - combinedResult.length;
        final result = await fetchNetworkData(_virtualNetworkPage, neededCount);
        if (result.isEmpty) break;
        combinedResult.addAll(result);
        _virtualNetworkPage++;
      }

      if (combinedResult.isEmpty && currentPage > 1) {
        canLoadMore.value = false;
        finishRefreshControllers(IndicatorResult.noMore);
        return;
      }

      canLoadMore.value = combinedResult.length >= pageSize.value;
      _pageCache[currentPage] = combinedResult;
      list.assignAll(combinedResult);
      pageEmpty.value = list.isEmpty;

      finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);
      scrollToTopImmediate();
    } catch (e) {
      currentPage = previousPageSnapshot;
      handleError(e, showPageError: list.isEmpty);
      finishRefreshControllers(IndicatorResult.fail);
    } finally {
      loadding = false;
      pageLoadding.value = false;
    }
  }
}
