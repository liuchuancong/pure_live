import 'package:pagination_core/src/contracts/page_loader.dart';
import 'package:pagination_core/src/contracts/page_request.dart';
import 'package:pagination_core/src/contracts/page_result.dart';
import 'package:pagination_core/src/contracts/pagination_session.dart';
import 'package:pagination_core/src/math/page_math.dart';
import 'package:pagination_core/src/state/paged_state.dart';
import 'package:pagination_core/src/state/refresh_position_policy.dart';

/// Desktop numbered pagination: holds exactly one visible page.
///
/// Jumping to a page is a single loader call — the controller never
/// issues follow-up requests to fill gaps. Failures keep the previously
/// shown page and surface through the state's `error`; a shrinking
/// dataset pulls the view back to the last valid page.
///
/// Notified listeners receive the full [PagedState] on every transition.
final class PagedController<T> {
  /// Builds a controller over [loader].
  ///
  /// [refreshPolicy] decides what a refresh shows afterwards (desktop
  /// default: the current page). [supportsJumpToPage] mirrors the
  /// loader's real ability — a forward-only cursor source must declare
  /// false so the UI can hide arbitrary-jump controls. [dataRefresher],
  /// when given, runs before every refresh so the repository can reload
  /// business data first.
  new({
    required this.loader,
    this.pageSize = 20,
    this.refreshPolicy = RefreshPositionPolicy.preserveCurrentPage,
    this.supportsJumpToPage = true,
    this.dataRefresher,
  });

  /// The page producer; see [PageLoader] for the contract.
  final PageLoader<T> loader;

  /// The refresh behaviour configured for this controller.
  final RefreshPositionPolicy refreshPolicy;

  /// Whether arbitrary page jumps are supported by the data source.
  final bool supportsJumpToPage;

  /// Items requested per page; change through [changePageSize].
  int pageSize;

  /// Runs before every refresh so the repository can reload business
  /// data first; null skips the step.
  final Future<void> Function()? dataRefresher;
  final PaginationSession _session = PaginationSession();
  final List<void Function(PagedState<T>)> _listeners = [];

  PagedState<T> _state = PagedState<T>();
  int? _lastFailedPage;
  bool _endReached = false;
  bool _disposed = false;

  /// The current state snapshot.
  PagedState<T> get state => _state;

  /// Starts listening for state transitions.
  void addListener(void Function(PagedState<T>) listener) => _listeners.add(listener);

  /// Stops listening.
  void removeListener(void Function(PagedState<T>) listener) => _listeners.remove(listener);

  /// Loads the first page when nothing is loaded yet; a no-op otherwise.
  Future<void> initialize() async {
    if (_state.page == 0) {
      await loadPage(1);
    }
  }

  /// Requests [desired] page. Duplicate requests during a flight are
  /// ignored; out-of-range pages are clamped when the total is known.
  ///
  /// When the dataset shrank and [desired] now points past the end, the
  /// controller re-requests the last valid page once instead of showing
  /// an empty out-of-range view.
  Future<void> loadPage(int desired) async {
    if (_disposed || _state.isLoading) {
      return;
    }
    final target = PageMath.clampPage(desired, PageMath.totalPages(_state.totalCount, pageSize));
    await _request(target);
  }

  /// Jumps to the first page.
  Future<void> first() => loadPage(1);

  /// Moves one page forward; returns false when already at the end (a
  /// known total, or a previously empty probe).
  Future<bool> next() async {
    final total = PageMath.totalPages(_state.totalCount, pageSize);
    if (_endReached || (total != null && _state.page >= total)) {
      return false;
    }
    await loadPage(_state.page + 1);
    return true;
  }

  /// Moves one page back; returns false when already on the first page.
  Future<bool> previous() async {
    if (_state.page <= 1) {
      return false;
    }
    await loadPage(_state.page - 1);
    return true;
  }

  /// Refreshes: optional data refresh first, then re-fetches per the
  /// configured [refreshPolicy]. In-flight requests are invalidated.
  Future<void> refresh() async {
    if (_disposed) {
      return;
    }
    _session.invalidate();
    _endReached = false;
    await dataRefresher?.call();
    final target = switch (refreshPolicy) {
      RefreshPositionPolicy.resetToFirstPage => 1,
      RefreshPositionPolicy.preserveCurrentPage => _state.page == 0 ? 1 : _state.page,
    };
    await _request(target, force: true);
  }

  /// Forces a rebuild from page 1, regardless of the refresh policy.
  Future<void> refreshFromStart() async {
    if (_disposed) {
      return;
    }
    _session.invalidate();
    _endReached = false;
    await dataRefresher?.call();
    await _request(1, force: true);
  }

  /// Re-runs the last failed page request.
  Future<void> retry() async {
    final failed = _lastFailedPage;
    if (failed != null && !_state.isLoading) {
      await _request(failed);
    }
  }

  /// Changes the page size and reloads, keeping the first visible item
  /// roughly in place.
  Future<void> changePageSize(int newSize) async {
    if (newSize <= 0 || newSize == pageSize || _disposed) {
      return;
    }
    final anchorIndex = (_state.page - 1) * pageSize;
    pageSize = newSize;
    _session.invalidate();
    _endReached = false;
    await _request(PageMath.pageForIndex(anchorIndex, newSize), force: true);
  }

  /// Stops the controller: listeners stay attached but every further
  /// operation and state update is dropped.
  void dispose() {
    _disposed = true;
    _session.invalidate();
    _listeners.clear();
  }

  Future<void> _request(int target, {bool force = false}) async {
    if (force) {
      _session.invalidate();
    }
    if (!_session.begin()) {
      return;
    }
    final token = _session.generation;
    _emit(_state.copyWith(isLoading: true, loadingPage: target, error: null));
    final PageResult<T> result;
    try {
      result = await loader(PageRequest(page: target, pageSize: pageSize));
    } on Object catch (error) {
      if (!_session.isCurrent(token) || _disposed) {
        return;
      }
      _session.end();
      _lastFailedPage = target;
      _emit(_state.copyWith(isLoading: false, loadingPage: null, error: error));
      return;
    }
    if (!_session.isCurrent(token) || _disposed) {
      return;
    }
    _session.end();
    _lastFailedPage = null;

    final totalCount = result.totalCount ?? _state.totalCount;
    final totalPages = PageMath.totalPages(totalCount, pageSize);
    final clamped = PageMath.clampPage(target, totalPages);

    // The dataset shrank under the requested page: re-request the last
    // valid page once so data and page number agree.
    if (result.items.isEmpty && target > 1 && clamped < target) {
      await _request(clamped);
      return;
    }

    _endReached = totalPages != null && clamped >= totalPages;
    _emit(PagedState<T>(items: result.items, page: clamped, pageSize: pageSize, totalCount: totalCount));
  }

  void _emit(PagedState<T> next) {
    _state = next;
    for (final listener in List.of(_listeners)) {
      listener(next);
    }
  }
}
