import 'package:live_pagination/src/state/paged_state.dart' show unset;
import 'package:meta/meta.dart';

/// Immutable state of the mobile infinite list: everything loaded so far.
///
/// [items] accumulates across pages — that is the essential difference
/// from the desktop paged view. [page] is the highest fully-loaded page;
/// [hasMore] gates further appends and is derived from the loader's
/// explicit answer, the known total, or the last page's fullness.
@immutable
final class InfiniteState<T> {
  /// A state snapshot; [items] is wrapped unmodifiable.
  new({
    Iterable<T> items = const [],
    this.page = 0,
    this.pageSize = 20,
    this.totalCount,
    this.hasMore = true,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.error,
  }) : assert(page >= 0, 'page is 1-based once loaded; 0 means not loaded'),
       assert(pageSize > 0, 'pageSize must be > 0'),
       items = List<T>.unmodifiable(items);

  /// Every item loaded so far, oldest first.
  final List<T> items;

  /// The highest fully-loaded page; `0` until the first load completes.
  final int page;

  /// Items requested per page.
  final int pageSize;

  /// Total items when the source knows them.
  final int? totalCount;

  /// Whether another page can be requested.
  final bool hasMore;

  /// Whether a refresh is in flight (first load included).
  final bool isRefreshing;

  /// Whether an append is in flight.
  final bool isLoadingMore;

  /// The last failure, if any. Refresh failures keep the old list;
  /// append failures keep the accumulated list.
  final Object? error;

  /// Whether the first refresh has not completed yet.
  bool get isUnloaded => page == 0 && !isRefreshing;

  /// A copy with the given fields replaced. Nullable members use the
  /// [unset] marker: pass a value to replace, pass `null` to clear, and
  /// omit to keep.
  InfiniteState<T> copyWith({
    Iterable<T>? items,
    int? page,
    int? pageSize,
    Object? totalCount = unset,
    bool? hasMore,
    bool? isRefreshing,
    bool? isLoadingMore,
    Object? error = unset,
  }) => InfiniteState<T>(
    items: items ?? this.items,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
    totalCount: totalCount == unset ? this.totalCount : totalCount as int?,
    hasMore: hasMore ?? this.hasMore,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error: error == unset ? this.error : error,
  );

  @override
  bool operator ==(Object other) =>
      other is InfiniteState<T> &&
      other.page == page &&
      other.pageSize == pageSize &&
      other.totalCount == totalCount &&
      other.hasMore == hasMore &&
      other.isRefreshing == isRefreshing &&
      other.isLoadingMore == isLoadingMore &&
      other.error == error &&
      _itemsEqual(other.items);

  @override
  int get hashCode =>
      Object.hash(page, pageSize, totalCount, hasMore, isRefreshing, isLoadingMore, error, Object.hashAll(items));

  @override
  String toString() =>
      'InfiniteState(page: $page, ${items.length} items, '
      'hasMore: $hasMore, refreshing: $isRefreshing, '
      'loadingMore: $isLoadingMore, error: $error)';

  bool _itemsEqual(List<T> other) {
    if (identical(other, items)) {
      return true;
    }
    if (other.length != items.length) {
      return false;
    }
    for (var i = 0; i < items.length; i++) {
      if (other[i] != items[i]) {
        return false;
      }
    }
    return true;
  }
}
