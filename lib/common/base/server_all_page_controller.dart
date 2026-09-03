import 'dart:async';

import 'package:pure_live/common/index.dart';

abstract class ServerAllPageController<T> extends BasePageScrollAndStateBone<T> {
  List<T>? _rawAllData;
  Future<void>? _activeLoad;
  bool _refreshPending = false;

  Future<List<T>> fetchAllServerData();

  @override
  Future<void> refreshData() async {
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
    if (_activeLoad != null || page < 1 || _rawAllData == null) return;
    if (!usesDesktopPagination) return;
    final maxPage = (_rawAllData!.length / pageSize.value).ceil();
    if (page > maxPage) return;
    currentPage = page;
    processLocalPaging();
  }

  @override
  void setPageSize(int? newSize) {
    if (newSize == null || pageSize.value == newSize || _rawAllData == null) return;
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
    return _startLoad();
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

      _rawAllData = await fetchAllServerData();
      processLocalPaging();
    } catch (e) {
      handleError(e, showPageError: list.isEmpty);
      finishRefreshControllers(IndicatorResult.fail);
    } finally {
      loadding.value = false;
      pageLoadding.value = false;
    }
  }

  void processLocalPaging() {
    if (_rawAllData == null) return;
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
      finishRefreshControllers(
        canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore,
      );
      scrollToTopImmediate();
    } else {
      list.assignAll(allItems);
      canLoadMore.value = false;
      pageEmpty.value = list.isEmpty;
      finishRefreshControllers(IndicatorResult.noMore);
    }
  }
}
