import 'package:live_pagination/src/math/page_math.dart';
import 'package:meta/meta.dart';

/// Marker for "keep the current value" in [PagedState.copyWith].
const Object unset = Object();

/// Immutable state of the desktop paged view: exactly one visible page.
///
/// `page == 0` means nothing loaded yet (before the first initialize).
/// On a failed page load the previous [items] stay visible and [error]
/// carries the failure — a broken jump never blanks the view.
@immutable
final class PagedState<T> {
  /// A state snapshot; [items] is wrapped unmodifiable.
  new({
    Iterable<T> items = const [],
    this.page = 0,
    this.pageSize = 20,
    this.totalCount,
    this.isLoading = false,
    this.loadingPage,
    this.error,
  }) : assert(page >= 0, 'page is 1-based once loaded; 0 means not loaded'),
       assert(pageSize > 0, 'pageSize must be > 0'),
       items = List<T>.unmodifiable(items);

  /// The items of the currently visible page.
  final List<T> items;

  /// The visible page; `0` until the first load completes.
  final int page;

  /// Items per page.
  final int pageSize;

  /// Total items when the source knows them.
  final int? totalCount;

  /// Total pages when the total is known.
  int? get totalPages => PageMath.totalPages(totalCount, pageSize);

  /// Whether a page request is in flight.
  final bool isLoading;

  /// The page currently being fetched, if any.
  final int? loadingPage;

  /// The last failure, if any; cleared on the next successful load.
  final Object? error;

  /// Whether nothing has loaded yet.
  bool get isUnloaded => page == 0 && !isLoading;

  /// A copy with the given fields replaced. Nullable members use the
  /// [unset] marker: pass a value to replace, pass `null` to clear, and
  /// omit to keep.
  PagedState<T> copyWith({
    Iterable<T>? items,
    int? page,
    int? pageSize,
    Object? totalCount = unset,
    bool? isLoading,
    Object? loadingPage = unset,
    Object? error = unset,
  }) => PagedState<T>(
    items: items ?? this.items,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
    totalCount: totalCount == unset ? this.totalCount : totalCount as int?,
    isLoading: isLoading ?? this.isLoading,
    loadingPage: loadingPage == unset ? this.loadingPage : loadingPage as int?,
    error: error == unset ? this.error : error,
  );

  @override
  bool operator ==(Object other) =>
      other is PagedState<T> &&
      other.page == page &&
      other.pageSize == pageSize &&
      other.totalCount == totalCount &&
      other.isLoading == isLoading &&
      other.loadingPage == loadingPage &&
      other.error == error &&
      _itemsEqual(other.items);

  @override
  int get hashCode => Object.hash(page, pageSize, totalCount, isLoading, loadingPage, error, Object.hashAll(items));

  @override
  String toString() =>
      'PagedState(page: $page, pageSize: $pageSize, '
      'totalCount: $totalCount, ${items.length} items, '
      'loading: $isLoading, error: $error)';

  bool _itemsEqual(List<T> other) {
    if (identical(other, items) || other.length != items.length) {
      return identical(other, items);
    }
    for (var i = 0; i < items.length; i++) {
      if (other[i] != items[i]) {
        return false;
      }
    }
    return true;
  }
}
