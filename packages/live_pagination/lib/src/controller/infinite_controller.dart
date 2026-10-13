import 'package:pagination_core/src/contracts/page_loader.dart';
import 'package:pagination_core/src/contracts/page_request.dart';
import 'package:pagination_core/src/contracts/page_result.dart';
import 'package:pagination_core/src/contracts/pagination_session.dart';
import 'package:pagination_core/src/math/page_math.dart';
import 'package:pagination_core/src/state/infinite_state.dart';

/// Mobile infinite scrolling: accumulates every loaded page.
///
/// Refreshes rebuild the list from page 1 (the scroll-position UX stays
/// with the UI layer); appends keep the accumulated items untouched on
/// failure so a retry can resume at the same page. Stale results — an
/// append answering after a refresh started, a refresh answering after a
/// query change — are dropped by generation, never merged into the new
/// list.
///
/// Notified listeners receive the full [InfiniteState] on every
/// transition.
final class InfiniteController<T> {
  /// Builds a controller over [loader]. [dataRefresher], when given,
  /// runs before every refresh so the repository can reload business
  /// data first.
  new({required this.loader, this.pageSize = 20, this.dataRefresher});

  /// The page producer; see [PageLoader] for the contract.
  final PageLoader<T> loader;

  /// Items requested per page.
  final int pageSize;

  /// Runs before every refresh so the repository can reload business
  /// data first; null skips the step.
  final Future<void> Function()? dataRefresher;

  final PaginationSession _session = PaginationSession();
  final List<void Function(InfiniteState<T>)> _listeners = [];

  InfiniteState<T> _state = InfiniteState<T>();
  int? _failedAppendPage;
  bool _refreshFailed = false;
  bool _disposed = false;

  /// The current state snapshot.
  InfiniteState<T> get state => _state;

  /// Starts listening for state transitions.
  void addListener(void Function(InfiniteState<T>) listener) => _listeners.add(listener);

  /// Stops listening.
  void removeListener(void Function(InfiniteState<T>) listener) => _listeners.remove(listener);

  /// Loads the first page when nothing is loaded yet; a no-op otherwise.
  Future<void> initialize() async {
    if (_state.page == 0) {
      await refresh();
    }
  }

  /// Rebuilds the list from page 1: optional data refresh first, then a
  /// fresh first page. In-flight appends and refreshes are invalidated.
  ///
  /// On failure the previously loaded list stays visible and [InfiniteState.error]
  /// carries the failure; [retry] then re-runs the refresh.
  Future<void> refresh() async {
    if (_disposed) {
      return;
    }
    _session.invalidate();
    _failedAppendPage = null;
    _refreshFailed = false;
    _emit(_state.copyWith(isRefreshing: true, isLoadingMore: false, error: null));
    final token = _session.generation;
    await dataRefresher?.call();
    if (!_session.isCurrent(token) || _disposed) {
      return;
    }
    final PageResult<T> result;
    try {
      result = await loader(PageRequest(page: 1, pageSize: pageSize));
    } on Object catch (error) {
      if (!_session.isCurrent(token) || _disposed) {
        return;
      }
      _session.end();
      _refreshFailed = true;
      _emit(_state.copyWith(isRefreshing: false, error: error));
      return;
    }
    if (!_session.isCurrent(token) || _disposed) {
      return;
    }
    _session.end();
    _emit(
      InfiniteState<T>(
        items: result.items,
        page: 1,
        pageSize: pageSize,
        totalCount: result.totalCount,
        hasMore: _hasMoreAfter(result, page: 1, appendedCount: 0),
      ),
    );
  }

  /// Appends the next page; a no-op when a refresh or another append is
  /// in flight, or when [InfiniteState.hasMore] is false.
  ///
  /// On failure the accumulated list stays and [retry] re-requests the
  /// same page — batches are never skipped because a failed page keeps
  /// its position.
  Future<bool> loadNext() async {
    if (_disposed || _state.isRefreshing || _state.isLoadingMore || !_state.hasMore) {
      return false;
    }
    final target = _state.page + 1;
    _emit(_state.copyWith(isLoadingMore: true, error: null));
    final token = _session.generation;
    final PageResult<T> result;
    try {
      result = await loader(PageRequest(page: target, pageSize: pageSize));
    } on Object catch (error) {
      if (!_session.isCurrent(token) || _disposed) {
        return false;
      }
      _session.end();
      _failedAppendPage = target;
      _emit(_state.copyWith(isLoadingMore: false, error: error));
      return false;
    }
    if (!_session.isCurrent(token) || _disposed) {
      return false;
    }
    _session.end();
    _failedAppendPage = null;
    final combined = [..._state.items, ...result.items];
    _emit(
      InfiniteState<T>(
        items: combined,
        page: target,
        pageSize: pageSize,
        totalCount: result.totalCount ?? _state.totalCount,
        hasMore: _hasMoreAfter(result, page: target, appendedCount: result.items.length),
      ),
    );
    return true;
  }

  /// Re-runs the last failed operation: the interrupted append when one
  /// exists, otherwise the failed refresh.
  Future<void> retry() async {
    if (_disposed || _state.isRefreshing || _state.isLoadingMore) {
      return;
    }
    final failedPage = _failedAppendPage;
    if (failedPage != null && failedPage == _state.page + 1) {
      await loadNext();
      return;
    }
    if (_refreshFailed || _state.page == 0) {
      await refresh();
    }
  }

  /// Stops the controller: listeners stay attached but every further
  /// operation and state update is dropped.
  void dispose() {
    _disposed = true;
    _session.invalidate();
    _listeners.clear();
  }

  /// Derives continuation from the loader's explicit answer, the known
  /// total, or whether the page came back with any items.
  bool _hasMoreAfter(PageResult<T> result, {required int page, required int appendedCount}) {
    if (result.hasMore != null) {
      return result.hasMore!;
    }
    final totalPages = PageMath.totalPages(result.totalCount, pageSize);
    if (totalPages != null) {
      return page < totalPages;
    }
    return appendedCount > 0;
  }

  void _emit(InfiniteState<T> next) {
    _state = next;
    for (final listener in List.of(_listeners)) {
      listener(next);
    }
  }
}
