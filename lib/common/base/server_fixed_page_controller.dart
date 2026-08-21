import 'dart:async';

import 'package:pure_live/common/index.dart';

abstract class ServerFixedPageController<T> extends BasePageScrollAndStateBone<T> {
  final int fixedServerPageSize;
  final Map<int, List<T>> _bigPageCache = {};
  final Map<int, List<T>> _slicedSmallCache = {};
  Future<void>? _activeLoad;
  bool _refreshPending = false;

  ServerFixedPageController({required this.fixedServerPageSize}) : super();

  Future<List<T>> fetchFixedNetworkData(int bigPage, int fixedSize);

  @override
  Future<void> refreshData() async {
    _refreshPending = true;
    final active = _activeLoad;
    if (active != null) await active;
    if (!_refreshPending || isClosed) return;
    _refreshPending = false;
    _bigPageCache.clear();
    _slicedSmallCache.clear();
    currentPage = 1;
    await _startLoad(replaceMobileSnapshot: true);
  }

  @override
  Future<void> goToPage(int page) async {
    if (_activeLoad != null || page < 1) return;
    if (!usesDesktopPagination) return;
    currentPage = page;
    await loadData();
  }

  @override
  void setPageSize(int? newSize) {
    if (newSize == null || pageSize.value == newSize) return;
    if (!usesDesktopPagination) {
      pageSize.value = newSize;
      return;
    }
    final int currentFirstItemIndex = (currentPage - 1) * pageSize.value;
    pageSize.value = newSize;
    currentPage = (currentFirstItemIndex ~/ newSize) + 1;
    _slicedSmallCache.clear();
    loadData();
  }

  @override
  Future<void> loadData() async {
    final active = _activeLoad;
    if (active != null) return active;
    return _startLoad();
  }

  Future<void> _startLoad({bool replaceMobileSnapshot = false}) {
    final active = _activeLoad;
    if (active != null) return active;
    late final Future<void> operation;
    operation = _performLoad(replaceMobileSnapshot: replaceMobileSnapshot).whenComplete(() {
      if (identical(_activeLoad, operation)) _activeLoad = null;
    });
    _activeLoad = operation;
    return operation;
  }

  Future<void> _performLoad({required bool replaceMobileSnapshot}) async {
    totalCount.value = null;

    if (usesDesktopPagination && _slicedSmallCache.containsKey(currentPage)) {
      final cachedData = _slicedSmallCache[currentPage]!;
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

    final int currentGlobalStart = (currentPage - 1) * pageSize.value;
    final int currentGlobalEnd = currentGlobalStart + pageSize.value;

    try {
      loadding.value = true;
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

      if (usesDesktopPagination) {
        canLoadMore.value = combinedData.length >= pageSize.value;
        _slicedSmallCache[currentPage] = combinedData;
        list.assignAll(combinedData);
        pageEmpty.value = list.isEmpty;
        finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);
        scrollToTopImmediate();
      } else {
        canLoadMore.value = combinedData.length >= pageSize.value;
        if (replaceMobileSnapshot) {
          list.assignAll(combinedData);
        } else {
          list.addAll(combinedData);
        }
        pageEmpty.value = list.isEmpty;
        finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);
      }
    } catch (e) {
      currentPage = previousPageSnapshot;
      handleError(e, showPageError: list.isEmpty);
      finishRefreshControllers(IndicatorResult.fail);
    } finally {
      loadding.value = false;
      pageLoadding.value = false;
    }
  }
}
