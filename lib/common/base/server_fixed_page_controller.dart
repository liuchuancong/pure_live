import 'dart:async';
import 'package:pure_live/common/index.dart';

abstract class ServerFixedPageController<T> extends BasePageScrollAndStateBone<T> {
  final int fixedServerPageSize;
  final Map<int, List<T>> _bigPageCache = {};
  final Map<int, List<T>> _slicedSmallCache = {};

  ServerFixedPageController({required this.fixedServerPageSize}) : super();

  Future<List<T>> fetchFixedNetworkData(int bigPage, int fixedSize);

  @override
  Future<void> refreshData() async {
    _bigPageCache.clear();
    _slicedSmallCache.clear();
    await loadData();
  }

  @override
  Future<void> goToPage(int page) async {
    if (loadding || page < 1) return;
    currentPage = page;
    await loadData();
  }

  @override
  void setPageSize(int? newSize) {
    if (newSize == null || pageSize.value == newSize) return;
    final int currentFirstItemIndex = (currentPage - 1) * pageSize.value;
    pageSize.value = newSize;
    currentPage = (currentFirstItemIndex ~/ newSize) + 1;
    _slicedSmallCache.clear();
    loadData();
  }

  @override
  Future<void> loadData() async {
    if (loadding) return;
    totalCount.value = null;

    if (_slicedSmallCache.containsKey(currentPage)) {
      final cachedData = _slicedSmallCache[currentPage]!;
      list.assignAll(cachedData);
      // 缓存也有极少数可能装不满（比如末尾页修改了pageSize），认准：只要数量够 pageSize 就能继续点
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
    final int currentGlobalStart = (currentPage - 1) * pageSize.value;
    final int currentGlobalEnd = currentGlobalStart + pageSize.value;

    try {
      loadding = true;
      pageError.value = false;
      pageEmpty.value = false;
      notLogin.value = false;
      if (list.isEmpty) pageLoadding.value = true;

      List<T> combinedData = [];
      int currentFetchOffset = currentGlobalStart;

      while (currentFetchOffset < currentGlobalEnd) {
        final int serverBigPage = (currentFetchOffset ~/ fixedServerPageSize) + 1;
        List<T> bigPageData;

        if (_bigPageCache.containsKey(serverBigPage)) {
          bigPageData = _bigPageCache[serverBigPage]!;
        } else {
          bigPageData = await fetchFixedNetworkData(serverBigPage, fixedServerPageSize);
          _bigPageCache[serverBigPage] = bigPageData;
        }

        if (bigPageData.isEmpty) break;

        final int innerStart = currentFetchOffset % fixedServerPageSize;
        if (innerStart >= bigPageData.length) break;

        final int neededCount = currentGlobalEnd - currentFetchOffset;
        final int availableCount = bigPageData.length - innerStart;
        final int takeCount = neededCount < availableCount ? neededCount : availableCount;

        combinedData.addAll(bigPageData.sublist(innerStart, innerStart + takeCount));
        currentFetchOffset += takeCount;

        if (bigPageData.length < fixedServerPageSize) break;
      }

      if (combinedData.isEmpty && currentPage > 1) {
        canLoadMore.value = false;
        finishRefreshControllers(IndicatorResult.noMore);
        return;
      }
      canLoadMore.value = combinedData.length >= pageSize.value;

      _slicedSmallCache[currentPage] = combinedData;
      list.assignAll(combinedData);
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
