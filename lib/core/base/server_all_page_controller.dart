import 'dart:async';

import 'package:pure_live/common/index.dart';

abstract class ServerAllPageController<T> extends BasePageScrollAndStateBone<T> {
  List<T>? _rawAllData;
  Future<void>? _activeLoad;
  bool _refreshPending = false;

  /// Includes the connectivity preflight before the visible loading flag is
  /// set. Local projections must not complete this operation's indicator.
  bool get hasActiveLoad => _activeLoad != null;

  @override
  Future<void>? get activePageOperation => _activeLoad;

  Future<List<T>> fetchAllServerData();

  /// Size of the active local catalogue. Tabbed controllers can project a
  /// different catalogue without fetching again or replacing the load cache.
  int get localItemCount => _rawAllData?.length ?? 0;

  @override
  Future<void> refreshData() async {
    if (isClosed) return;
    _refreshPending = true;
    final active = _activeLoad;
    if (active != null) await active;
    if (!_refreshPending || isClosed) return;
    _refreshPending = false;
    _rawAllData = null;
    currentPage = 1;
    await _startLoad();
  }

  @override
  Future<void> goToPage(int page) async {
    if (isClosed || _activeLoad != null || page < 1 || _rawAllData == null) return;
    if (!usesDesktopPagination) return;
    final maxPage = (localItemCount / pageSize.value).ceil();
    if (page > maxPage) return;
    currentPage = page;
    processLocalPaging();
  }

  @override
  void setPageSize(int? newSize) {
    if (isClosed || newSize == null || pageSize.value == newSize || _rawAllData == null) return;
    if (!usesDesktopPagination) {
      pageSize.value = newSize;
      return;
    }
    final int currentFirstItemIndex = (currentPage - 1) * pageSize.value;
    pageSize.value = newSize;
    currentPage = (currentFirstItemIndex ~/ newSize) + 1;
    processLocalPaging();
  }

  @override
  Future<void> loadData() async {
    final active = _activeLoad;
    if (active != null) return active;
    if (isClosed) return;
    return _startLoad();
  }

  @override
  Future<void> loadMoreData() async {
    if (isClosed) return;
    await super.loadMoreData();
  }

  Future<void> _startLoad() {
    final active = _activeLoad;
    if (active != null) return active;
    late final Future<void> operation;
    operation = _performLoad().whenComplete(() {
      if (identical(_activeLoad, operation)) _activeLoad = null;
    });
    _activeLoad = operation;
    return operation;
  }

  Future<void> _performLoad() async {
    if (_rawAllData != null) {
      processLocalPaging();
      return;
    }

    final bool isNetworkSafe = await checkNetworkBeforeRequest();
    if (isClosed) return;
    if (!isNetworkSafe) {
      finishRefreshControllers(IndicatorResult.fail);
      return;
    }

    try {
      loadding.value = true;
      pageError.value = false;
      pageEmpty.value = false;
      notLogin.value = false;
      pageLoadding.value = true;

      final result = await fetchAllServerData();
      // The Future has no cancellation contract. Observe its terminal result,
      // but never publish into a route whose controllers have been disposed.
      if (isClosed) return;
      _rawAllData = result;
      processLocalPaging();
    } catch (e) {
      if (isClosed) return;
      handleError(e, showPageError: list.isEmpty);
      finishRefreshControllers(IndicatorResult.fail);
    } finally {
      if (!isClosed) {
        loadding.value = false;
        pageLoadding.value = false;
      }
    }
  }

  void processLocalPaging() {
    if (isClosed || _rawAllData == null) return;
    final allItems = _rawAllData!;
    totalCount.value = allItems.length;

    if (allItems.isEmpty) {
      list.clear();
      canLoadMore.value = false;
      pageEmpty.value = true;
      finishRefreshControllers(IndicatorResult.noMore);
      return;
    }

    if (usesDesktopPagination) {
      int startIndex = (currentPage - 1) * pageSize.value;
      if (startIndex >= allItems.length) {
        currentPage = 1;
        startIndex = 0;
      }

      int endIndex = startIndex + pageSize.value;
      if (endIndex > allItems.length) endIndex = allItems.length;

      final newData = allItems.sublist(startIndex, endIndex);
      list.assignAll(newData);
      canLoadMore.value = endIndex < allItems.length;
      pageEmpty.value = list.isEmpty;
      finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);
      scrollToTopImmediate();
    } else {
      list.assignAll(allItems);
      canLoadMore.value = false;
      pageEmpty.value = list.isEmpty;
      finishRefreshControllers(IndicatorResult.noMore);
    }
  }
}
