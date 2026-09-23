import 'dart:async';

import 'package:pure_live/common/index.dart';

abstract class ServerRemotePageController<T> extends BasePageScrollAndStateBone<T> {
  final Map<int, List<T>> _pageCache = {};
  int _virtualNetworkPage = 1;
  Future<void>? _activeLoad;
  bool _refreshPending = false;
  int? _pendingPageSize;

  ServerRemotePageController() : super();

  Future<List<T>> fetchNetworkData(int page, int pageSize);

  @override
  Future<void>? get activePageOperation => _activeLoad;

  int? get maxPage {
    final total = totalCount.value;
    final size = pageSize.value;

    if (total == null || size < 1) {
      return null;
    }

    return (total / size).ceil();
  }

  bool get canGoNextPage {
    final max = maxPage;

    if (max != null) {
      return currentPage < max;
    }

    return canLoadMore.value;
  }

  @override
  Future<void> refreshData() async {
    if (isClosed) return;

    _refreshPending = true;

    while (_activeLoad != null && !isClosed) {
      await _activeLoad;
    }

    if (!_refreshPending || isClosed) return;

    _refreshPending = false;
    currentPage = 1;
    _virtualNetworkPage = 1;
    _pageCache.clear();

    await _startLoad(replaceMobileSnapshot: true);
  }

  @override
  Future<void> goToPage(int page) async {
    if (isClosed || _activeLoad != null || page < 1) return;
    if (!usesDesktopPagination) return;

    final max = maxPage;

    if (max != null && page > max) {
      page = max;
    }

    if (page == currentPage) {
      return;
    }

    // Already loaded: switch pages without another network request.
    final cachedData = _pageCache[page];

    if (cachedData != null) {
      currentPage = page;
      list.assignAll(cachedData);
      canLoadMore.value = max != null ? page < max : cachedData.length >= pageSize.value;
      pageEmpty.value = list.isEmpty;

      scrollToTopImmediate();
      update();
      return;
    }

    final previousPage = currentPage;
    currentPage = page;

    try {
      // Rebuild the requested page from all history already fetched.
      final historyPool = <T>[];
      final sortedKeys = _pageCache.keys.toList()..sort();

      for (final key in sortedKeys) {
        historyPool.addAll(_pageCache[key]!);
      }

      await _startLoad(rebuildHistory: historyPool);
    } catch (e) {
      if (isClosed) return;

      currentPage = previousPage;
      rethrow;
    }
  }

  @override
  void setPageSize(int? newSize) {
    if (isClosed || newSize == null || newSize < 1) return;

    // Keep request dimensions stable until its snapshot is committed. A later
    // selection replaces the pending intent, including selecting the old size.
    _pendingPageSize = newSize;
    unawaited(_applyPendingPageSize());
  }

  Future<void> _applyPendingPageSize() async {
    while (_activeLoad != null && !isClosed) {
      await _activeLoad;
    }

    if (isClosed) return;

    final newSize = _pendingPageSize;
    _pendingPageSize = null;

    if (newSize == null || pageSize.value == newSize) return;

    if (!usesDesktopPagination) {
      pageSize.value = newSize;
      return;
    }

    final int previousSize = pageSize.value;
    final int currentFirstItemIndex = (currentPage - 1) * previousSize;

    final allHistoryItems = <T>[];
    final sortedKeys = _pageCache.keys.toList()..sort();

    for (final key in sortedKeys) {
      allHistoryItems.addAll(_pageCache[key]!);
    }

    pageSize.value = newSize;
    currentPage = (currentFirstItemIndex ~/ newSize) + 1;

    final max = maxPage;
    if (max != null && currentPage > max) {
      currentPage = max;
    }

    _pageCache.clear();

    await _startLoad(rebuildHistory: allHistoryItems);
  }

  Future<void> _adaptiveRebuildAndFetchMore(List<T> historyPool) async {
    if (isClosed || loadding.value) return;

    final int targetTotalItemsNeeded = currentPage * pageSize.value;

    if (historyPool.length < targetTotalItemsNeeded && canLoadMore.value) {
      final bool isNetworkSafe = await checkNetworkBeforeRequest();

      if (isClosed) return;

      if (!isNetworkSafe) {
        finishRefreshControllers(IndicatorResult.fail);
        return;
      }

      try {
        loadding.value = true;

        final seen = historyPool.toSet();

        var requestCount = 0;
        var noProgressCount = 0;

        while (historyPool.length < targetTotalItemsNeeded && requestCount < 20 && noProgressCount < 2) {
          final int missingCount = targetTotalItemsNeeded - historyPool.length;

          final result = await fetchNetworkData(_virtualNetworkPage, missingCount);

          if (isClosed) return;

          requestCount++;

          if (result.isEmpty) {
            break;
          }

          final previousLength = historyPool.length;

          for (final item in result) {
            if (seen.add(item)) {
              historyPool.add(item);
            }

            if (historyPool.length >= targetTotalItemsNeeded) {
              break;
            }
          }

          noProgressCount = historyPool.length == previousLength ? noProgressCount + 1 : 0;

          _virtualNetworkPage++;
        }
      } catch (e) {
        if (isClosed) return;

        handleError(e, showPageError: list.isEmpty);
      } finally {
        if (!isClosed) {
          loadding.value = false;
        }
      }
    }

    _pageCache.clear();

    int chunkIndex = 1;

    for (int i = 0; i < historyPool.length; i += pageSize.value) {
      int end = i + pageSize.value;

      if (end > historyPool.length) {
        end = historyPool.length;
      }

      _pageCache[chunkIndex] = historyPool.sublist(i, end);
      chunkIndex++;
    }

    final cachedData = _pageCache[currentPage] ?? [];

    list.assignAll(cachedData);

    final max = maxPage;

    if (max != null) {
      canLoadMore.value = currentPage < max;
    } else {
      canLoadMore.value = cachedData.length >= pageSize.value;
    }

    pageEmpty.value = list.isEmpty;

    finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);

    scrollToTopImmediate();
    update();
  }

  @override
  Future<void> loadData() async {
    final active = _activeLoad;

    if (active != null) {
      return active;
    }

    if (isClosed) return;

    return _startLoad();
  }

  @override
  Future<void> loadMoreData() async {
    if (isClosed) return;

    final active = _activeLoad;

    if (active != null) {
      return active;
    }

    await super.loadMoreData();
  }

  Future<void> _startLoad({bool replaceMobileSnapshot = false, List<T>? rebuildHistory}) {
    final active = _activeLoad;

    if (active != null) {
      return active;
    }

    late final Future<void> operation;

    final work = rebuildHistory == null
        ? _performLoad(replaceMobileSnapshot: replaceMobileSnapshot)
        : _adaptiveRebuildAndFetchMore(rebuildHistory);

    operation = work.whenComplete(() {
      if (identical(_activeLoad, operation)) {
        _activeLoad = null;
      }
    });

    _activeLoad = operation;

    return operation;
  }

  Future<void> _performLoad({required bool replaceMobileSnapshot}) async {
    if (usesDesktopPagination && _pageCache.containsKey(currentPage)) {
      final cachedData = _pageCache[currentPage]!;

      list.assignAll(cachedData);

      final max = maxPage;

      canLoadMore.value = max != null ? currentPage < max : cachedData.length >= pageSize.value;

      pageEmpty.value = list.isEmpty;

      finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);

      scrollToTopImmediate();
      update();

      return;
    }

    final bool isNetworkSafe = await checkNetworkBeforeRequest();

    if (isClosed) return;

    if (!isNetworkSafe) {
      finishRefreshControllers(IndicatorResult.fail);
      return;
    }

    final int previousPageSnapshot = currentPage;

    try {
      loadding.value = true;
      pageError.value = false;
      pageEmpty.value = false;
      notLogin.value = false;

      if (list.isEmpty) {
        pageLoadding.value = true;
      }

      final combinedResult = <T>[];

      final seen = replaceMobileSnapshot ? <T>{} : <T>{...list};

      final int sizeToFetch = pageSize.value;

      var requestCount = 0;
      var noProgressCount = 0;

      while (combinedResult.length < sizeToFetch && requestCount < 20 && noProgressCount < 2) {
        final int neededCount = sizeToFetch - combinedResult.length;

        late final List<T> result;

        try {
          result = await fetchNetworkData(_virtualNetworkPage, neededCount);

          if (isClosed) return;
        } catch (_) {
          if (isClosed) return;

          // A later cursor/page is allowed to fail without erasing items that
          // the same transaction has already fetched successfully. This is
          // common with APIs that protect deeper pagination more aggressively
          // than their first page and with transient mobile network changes.
          // The partial page is committed below with canLoadMore=false; an
          // initial request failure still follows the normal error path.
          if (combinedResult.isEmpty) {
            rethrow;
          }

          break;
        }

        requestCount++;

        if (result.isEmpty) {
          break;
        }

        final previousLength = combinedResult.length;

        for (final item in result) {
          if (seen.add(item)) {
            combinedResult.add(item);
          }

          if (combinedResult.length >= sizeToFetch) {
            break;
          }
        }

        noProgressCount = combinedResult.length == previousLength ? noProgressCount + 1 : 0;

        _virtualNetworkPage++;
      }

      if (combinedResult.isEmpty && currentPage > 1) {
        canLoadMore.value = false;

        finishRefreshControllers(IndicatorResult.noMore);

        return;
      }

      if (usesDesktopPagination) {
        _pageCache[currentPage] = combinedResult;

        list.assignAll(combinedResult);

        final max = maxPage;

        canLoadMore.value = max != null ? currentPage < max : combinedResult.length >= pageSize.value;

        pageEmpty.value = list.isEmpty;

        finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);

        scrollToTopImmediate();
        update();
      } else {
        canLoadMore.value = combinedResult.length >= pageSize.value;

        if (replaceMobileSnapshot) {
          list.assignAll(combinedResult);
        } else {
          list.addAll(combinedResult);
        }

        pageEmpty.value = list.isEmpty;

        finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);
      }
    } catch (e) {
      if (isClosed) return;

      currentPage = previousPageSnapshot;

      handleError(e, showPageError: list.isEmpty);

      finishRefreshControllers(IndicatorResult.fail);
    } finally {
      if (!isClosed) {
        loadding.value = false;
        pageLoadding.value = false;
      }
    }
  }
}
