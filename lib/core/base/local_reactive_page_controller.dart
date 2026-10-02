import 'dart:async';

import 'package:pure_live/common/index.dart';

abstract class LocalReactivePageController<T> extends BasePageScrollAndStateBone<T> {
  final List<T> _localRawPool = [];
  bool _hasPublishedSnapshot = false;
  Future<void>? _activeExternalRefresh;
  bool _externalRefreshRunning = false;
  bool _publishedDuringRefresh = false;
  bool _refreshPending = false;
  int? _pendingPageSize;

  Future<void> Function()? onExternalRefresh;

  @override
  Future<void>? get activePageOperation => _activeExternalRefresh;

  void updateLocalReactivePool(List<T> freshData) {
    if (isClosed) return;
    // The first empty snapshot is still meaningful: it moves BasePageView
    // from its indeterminate loading state to the terminal empty state. The
    // old identity fast path returned before _processDataDistribution when
    // both lists started empty, leaving an infinite loading animation active
    // on fresh installs and consuming CPU/GPU frames while the app was idle.
    if (_hasPublishedSnapshot && _localRawPool.length == freshData.length) {
      var unchanged = true;
      for (var index = 0; index < freshData.length; index++) {
        if (!identical(_localRawPool[index], freshData[index])) {
          unchanged = false;
          break;
        }
      }
      if (unchanged) return;
    }
    _localRawPool.clear();
    _localRawPool.addAll(freshData);
    _hasPublishedSnapshot = true;
    if (_externalRefreshRunning) _publishedDuringRefresh = true;
    currentPage = 1;
    _processDataDistribution();
  }

  @override
  Future<void> refreshData() async {
    if (isClosed) return;
    _refreshPending = true;
    while (_activeExternalRefresh != null && !isClosed) {
      await _activeExternalRefresh;
    }
    if (!_refreshPending || isClosed) return;
    _refreshPending = false;
    await loadExternalSnapshot();
  }

  /// Initial loads share the current snapshot operation. Explicit refreshes
  /// instead retain one subsequent refresh intent, since settings may change
  /// while the previous snapshot is being read.
  Future<void> loadExternalSnapshot() {
    if (isClosed) return Future<void>.value();
    final active = _activeExternalRefresh;
    if (active != null) return active;
    final completion = Completer<void>();
    final operation = completion.future;
    // Publish ownership before invoking any callback or reactive loading
    // listener, including callbacks that publish their data synchronously.
    _activeExternalRefresh = operation;
    unawaited(
      _performExternalRefresh().then(
        (_) {
          if (identical(_activeExternalRefresh, operation)) _activeExternalRefresh = null;
          completion.complete();
        },
        onError: (Object error, StackTrace stack) {
          if (identical(_activeExternalRefresh, operation)) _activeExternalRefresh = null;
          completion.completeError(error, stack);
        },
      ),
    );
    return operation;
  }

  Future<void> _performExternalRefresh() async {
    _externalRefreshRunning = true;
    _publishedDuringRefresh = false;
    try {
      loadding.value = true;
      pageEmpty.value = false;
      pageError.value = false;
      notLogin.value = false;
      errorMsg.value = '';
      if (list.isEmpty) pageLoadding.value = true;
      await onExternalRefresh?.call();
      if (isClosed) return;
      if (!_publishedDuringRefresh) {
        currentPage = 1;
        _processDataDistribution();
      }
      finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);
    } catch (error) {
      if (isClosed) return;
      handleError(error, showPageError: list.isEmpty);
      pageEmpty.value = list.isEmpty;
      finishRefreshControllers(IndicatorResult.fail);
    } finally {
      _externalRefreshRunning = false;
      if (!isClosed) {
        loadding.value = false;
        pageLoadding.value = false;
      }
    }
  }

  @override
  Future<void> goToPage(int page) async {
    if (isClosed || _activeExternalRefresh != null || loadding.value || page < 1) return;
    if (!usesDesktopPagination) return;

    final maxPage = (_localRawPool.length / pageSize.value).ceil();
    if (page > maxPage) return;
    currentPage = page;
    _processDataDistribution();
  }

  @override
  void setPageSize(int? newSize) {
    if (isClosed || newSize == null || newSize < 1) return;
    _pendingPageSize = newSize;
    unawaited(_applyPendingPageSize());
  }

  Future<void> _applyPendingPageSize() async {
    // Derived local pages may own a separate transaction (favourite room
    // verification, for example), not the base external-snapshot callback.
    while (activePageOperation != null && !isClosed) {
      await activePageOperation;
    }
    if (isClosed) return;
    final newSize = _pendingPageSize;
    _pendingPageSize = null;
    if (newSize == null || pageSize.value == newSize) return;
    if (!usesDesktopPagination) {
      pageSize.value = newSize;
      return;
    }

    final int currentFirstItemIndex = (currentPage - 1) * pageSize.value;
    pageSize.value = newSize;
    currentPage = (currentFirstItemIndex ~/ newSize) + 1;
    _processDataDistribution();
  }

  @override
  Future<void> loadData() async {
    if (isClosed) return;
    _processDataDistribution();
  }

  @override
  Future<void> loadMoreData() async {
    if (isClosed) return;
    final active = _activeExternalRefresh;
    if (active != null) return active;
    await super.loadMoreData();
  }

  void _processDataDistribution() {
    if (isClosed) return;
    totalCount.value = _localRawPool.length;

    if (usesDesktopPagination) {
      _processDesktopSlicing();
    } else {
      _processMobileDisplayAll();
    }
  }

  void _processDesktopSlicing() {
    int startIndex = (currentPage - 1) * pageSize.value;
    if (startIndex >= _localRawPool.length) {
      if (_localRawPool.isEmpty) {
        list.clear();
        canLoadMore.value = false;
        pageEmpty.value = true;
        _finishLocalProjection(IndicatorResult.noMore);
        return;
      }
      currentPage = (_localRawPool.length / pageSize.value).ceil();
      startIndex = (currentPage - 1) * pageSize.value;
    }

    int endIndex = startIndex + pageSize.value;
    if (endIndex > _localRawPool.length) endIndex = _localRawPool.length;

    list.assignAll(_localRawPool.sublist(startIndex, endIndex));
    canLoadMore.value = endIndex < _localRawPool.length;
    pageEmpty.value = list.isEmpty;
    _finishLocalProjection(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);
    scrollToTopImmediate();
  }

  void _processMobileDisplayAll() {
    if (_localRawPool.isEmpty) {
      list.clear();
      canLoadMore.value = false;
      pageEmpty.value = true;
      _finishLocalProjection(IndicatorResult.noMore);
      return;
    }

    pageEmpty.value = false;
    list.assignAll(_localRawPool);
    canLoadMore.value = false;
    _finishLocalProjection(IndicatorResult.noMore);
  }

  void _finishLocalProjection(IndicatorResult result) {
    // A callback may publish before all of its asynchronous work is done.
    // Only the owner of that operation may finish the refresh indicator.
    if (!_externalRefreshRunning) finishRefreshControllers(result);
  }
}
