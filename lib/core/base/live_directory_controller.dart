import 'dart:async';

import 'package:dio/dio.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/interface/live_directory.dart';

/// One native cursor generation. Refresh builds a replacement separately from
/// the committed catalogue, so failures cannot relabel or consume old cards.
class _DirectoryBuffer {
  final rooms = <LiveRoom>[];
  final identities = <String>{};
  int nextPage = 1;
  String? nextCursor;
  bool hasMore = true;
  bool capacityReached = false;
}

/// A bounded, per-tab native-page pool. Keeps complete responses (including
/// overflow) and presents independent mobile/desktop page sizes. No other
/// paging implementation changes for platforms without the optional contract.
class LiveDirectoryController extends BasePageScrollAndStateBone<LiveRoom> {
  LiveDirectoryController({
    required this.directory,
    this.category,
    this.transform,
    this.maxBufferedItems = 20000,
    this.maxRequestsPerLoad = 20,
  });
  final LiveSiteDirectoryPager directory;
  final LiveArea? category;
  final List<LiveRoom> Function(List<LiveRoom>)? transform;
  final int maxBufferedItems;
  final int maxRequestsPerLoad;
  _DirectoryBuffer _buffer = _DirectoryBuffer();
  _DirectoryBuffer? _refreshBuffer;
  int _epoch = 0;
  int _visiblePage = 1;
  int _lastRequestedPage = 1;
  bool _disposed = false;
  Future<void>? _activeLoad;
  Future<void>? _pendingRepage;
  CancelToken? _cancel;

  bool _owns(int epoch) => !_disposed && !isClosed && epoch == _epoch;
  bool get _capacityReached => (_refreshBuffer ?? _buffer).capacityReached;

  @override
  Future<void>? get activePageOperation => _pendingRepage ?? _activeLoad;

  @override
  bool Function() captureNetworkRequestOwnership() {
    final epoch = _epoch;
    return () => _owns(epoch);
  }

  @override
  bool get showInlineError => true;

  @override
  String? get pageNotice =>
      directory is LiveDirectoryNotice ? i18n((directory as LiveDirectoryNotice).directoryNoticeKey) : null;

  @override
  String get retryActionLabel => i18n(_capacityReached ? 'refresh' : 'retry');

  @override
  Future<void> retryData() {
    if (_disposed || isClosed) return Future.value();
    return _pendingRepage ?? _activeLoad ?? (_capacityReached ? refreshData() : _startLoad(_lastRequestedPage));
  }

  @override
  Future<void> refreshData() async {
    final epoch = ++_epoch;
    _cancel?.cancel();
    await _activeLoad;
    if (!_owns(epoch)) return;
    // Keep both the visible rows AND their paging metadata until a replacement
    // is publishable. At most two independently bounded buffers are retained;
    // repeated refresh discards the previous staging buffer, not the catalogue.
    _refreshBuffer = _DirectoryBuffer();
    await _startLoad(1);
  }

  @override
  Future<void> loadData() => _pendingRepage ?? _activeLoad ?? _startLoad(_refreshBuffer != null ? 1 : currentPage);

  @override
  Future<void> loadMoreData() async {
    if (_activeLoad != null || _pendingRepage != null) return;
    if (_refreshBuffer != null) {
      await retryData();
      return;
    }
    if (!canLoadMore.value) return;
    final partialPage = _buffer.rooms.length < _visiblePage * pageSize.value && _buffer.hasMore;
    await _startLoad(partialPage ? _visiblePage : _visiblePage + 1);
  }

  @override
  Future<void> goToPage(int page) async {
    if (!usesDesktopPagination || _activeLoad != null || _pendingRepage != null || page < 1) return;
    if (page > _visiblePage && !canLoadMore.value && (page - 1) * pageSize.value >= _buffer.rooms.length) return;
    // Explicit navigation chooses the still-visible catalogue rather than
    // applying its page number to a failed refresh's unrelated cursor.
    _refreshBuffer = null;
    await _startLoad(page);
  }

  @override
  void setPageSize(int? newSize) {
    if (newSize == null || newSize < 1 || newSize == pageSize.value || _disposed) return;
    _refreshBuffer = null;
    final firstIndex = usesDesktopPagination ? (_visiblePage - 1) * pageSize.value : 0;
    pageSize.value = newSize;
    currentPage = firstIndex ~/ newSize + 1;
    // Coalesce size changes while an old request is in flight; preserve the
    // completed native page pool rather than restarting its network cursor.
    final epoch = ++_epoch;
    _cancel?.cancel();
    late final Future<void> repage;
    repage =
        (() async {
          await _activeLoad;
          if (_owns(epoch)) await _startLoad(currentPage);
        }()).whenComplete(() {
          if (identical(_pendingRepage, repage)) _pendingRepage = null;
        });
    _pendingRepage = repage;
    unawaited(repage);
  }

  Future<void> _startLoad(int targetPage) {
    if (_disposed || isClosed) return Future.value();
    final active = _activeLoad;
    if (active != null) return active;
    _lastRequestedPage = targetPage;
    late final Future<void> operation;
    operation = _performLoad(targetPage, _epoch, _refreshBuffer ?? _buffer).whenComplete(() {
      if (identical(_activeLoad, operation)) _activeLoad = null;
    });
    _activeLoad = operation;
    return operation;
  }

  Future<void> _performLoad(int targetPage, int epoch, _DirectoryBuffer buffer) async {
    if (targetPage < 1 || pageSize.value < 1 || maxRequestsPerLoad < 1 || maxBufferedItems < 1) {
      return;
    }
    final targetSize = pageSize.value;
    final targetEnd = targetPage * targetSize;
    final targetStart = usesDesktopPagination ? (targetPage - 1) * targetSize : 0;
    final token = CancelToken();
    _cancel = token;
    Object? failure;
    try {
      loadding.value = true;
      pageLoadding.value = list.isEmpty;
      pageError.value = false;
      notLogin.value = false;
      errorMsg.value = '';
      var requests = 0;
      while (buffer.rooms.length < targetEnd &&
          buffer.hasMore &&
          !buffer.capacityReached &&
          requests < maxRequestsPerLoad) {
        final networkReady = await checkNetworkBeforeRequest();
        if (!_owns(epoch)) return;
        if (!networkReady) {
          finishRefreshControllers(IndicatorResult.fail);
          return;
        }
        final expectedPage = buffer.nextPage;
        late final LiveDirectoryPage response;
        try {
          response = directory is LiveSiteCursorDirectoryPager
              ? await (directory as LiveSiteCursorDirectoryPager).getDirectoryPageAtCursor(
                  page: expectedPage,
                  cursor: buffer.nextCursor,
                  category: category,
                  cancel: token,
                )
              : await directory.getDirectoryPage(page: expectedPage, category: category, cancel: token);
        } catch (error) {
          if (!_owns(epoch)) return;
          failure = error;
          break;
        }
        if (!_owns(epoch)) return;
        if (response.page != expectedPage || response.rooms.length > 1000) {
          failure = StateError('Directory pagination mismatch');
          break;
        }
        if (directory is LiveSiteCursorDirectoryPager &&
            response.hasMore &&
            (response.nextCursor == null ||
                response.nextCursor!.isEmpty ||
                response.nextCursor == buffer.nextCursor ||
                response.nextCursor!.length > 1024)) {
          failure = StateError('Directory cursor did not advance');
          break;
        }
        var rows = response.rooms.toList();
        if (category != null) rows = rows.map((room) => room.copyWith(area: category!.areaName)).toList();
        if (transform != null) rows = transform!(rows);
        final fresh = <LiveRoom>[];
        final pageIdentities = <String>{};
        for (final room in rows) {
          if (!buffer.identities.contains(room.identityKey) && pageIdentities.add(room.identityKey)) fresh.add(room);
        }
        // Never partially consume a native page and then advance past the
        // discarded remainder. A capacity failure keeps that page uncommitted.
        if (buffer.rooms.length + fresh.length > maxBufferedItems) {
          buffer.capacityReached = true;
          failure = i18n('directory_cache_limit');
          break;
        }
        buffer.rooms.addAll(fresh);
        buffer.identities.addAll(pageIdentities);
        buffer.nextPage++;
        buffer.nextCursor = response.nextCursor;
        buffer.hasMore = response.hasMore;
        requests++;
      }
      if (!_owns(epoch)) return;
      if (buffer.capacityReached) {
        // The buffer limit is still in effect when revisiting cached rows or
        // changing UI page size. It is not a successful end-of-directory read.
        failure = i18n('directory_cache_limit');
      } else if (buffer.rooms.length < targetEnd && buffer.hasMore && failure == null) {
        failure = i18n('directory_continue_loading');
      }
      // Errors and request budgets are retryable, not a fabricated end of the
      // list. Already committed cards remain available, including overflow.
      if (targetStart < buffer.rooms.length || (buffer.rooms.isEmpty && targetPage == 1 && !buffer.hasMore)) {
        final end = targetEnd.clamp(0, buffer.rooms.length);
        _buffer = buffer;
        if (identical(_refreshBuffer, buffer)) _refreshBuffer = null;
        _visiblePage = targetPage;
        currentPage = targetPage;
        list.assignAll(buffer.rooms.sublist(targetStart, end));
        if (usesDesktopPagination) scrollToTopImmediate();
      } else {
        currentPage = _visiblePage;
      }
      if (identical(buffer, _buffer)) {
        final visibleEnd = _visiblePage * targetSize;
        canLoadMore.value = visibleEnd < buffer.rooms.length || (buffer.hasMore && !buffer.capacityReached);
        totalCount.value = !buffer.hasMore ? buffer.rooms.length : null;
        pageEmpty.value = list.isEmpty && !buffer.hasMore && failure == null;
      }
      if (failure != null) {
        // Keep the visible list mounted; BasePageView renders a full-page error
        // only when there are no usable cards. Retry resumes the failed page.
        // BasePageView retains an inline recovery action alongside usable
        // cards, so cached navigation does not need repeated transient toasts.
        handleError(failure, showPageError: true);
        finishRefreshControllers(IndicatorResult.fail);
      } else {
        finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);
      }
    } catch (error) {
      if (_owns(epoch)) {
        currentPage = _visiblePage;
        handleError(error, showPageError: true);
        finishRefreshControllers(IndicatorResult.fail);
      }
    } finally {
      if (identical(_cancel, token)) _cancel = null;
      if (_owns(epoch)) {
        loadding.value = false;
        pageLoadding.value = false;
      }
    }
  }

  @override
  void onClose() {
    _disposed = true;
    _epoch++;
    _cancel?.cancel();
    _cancel = null;
    _buffer = _DirectoryBuffer();
    _refreshBuffer = null;
    super.onClose();
  }
}
