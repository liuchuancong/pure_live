/// Page arithmetic shared by both controllers — the only place that
/// knows how pages, counts and sizes relate.
abstract final class PageMath {
  /// Total pages for [totalCount], or null when the total is unknown.
  static int? totalPages(int? totalCount, int pageSize) {
    if (totalCount == null) {
      return null;
    }
    return (totalCount + pageSize - 1) ~/ pageSize;
  }

  /// Whether [page] can be requested given an optional total.
  static bool isValidPage(int page, int? totalPages) => page >= 1 && (totalPages == null || page <= totalPages);

  /// The closest valid page to [desired]: never below 1, never past the
  /// last page when the total is known.
  ///
  /// A known total of zero means there are no pages at all, which is not the same
  /// thing as "page zero exists": an empty library must still be requested as
  /// page one, because `PageRequest` is 1-based and a loader asked for page 0
  /// computes a negative offset.
  static int clampPage(int desired, int? totalPages) {
    if (desired < 1) {
      return 1;
    }
    if (totalPages != null && totalPages > 0 && desired > totalPages) {
      return totalPages;
    }
    return desired;
  }

  /// Whether anything is known to follow the page described by its result.
  ///
  /// One rule for both controllers, consulted in the order the `PageResult`
  /// contract promises: the loader's explicit `hasMore` answer, then a known
  /// total, then — for a forward-only or cursor source that states neither —
  /// whether the page brought back anything at all. The last case deliberately
  /// keeps walking after a short page: with no total there is nothing to prove the
  /// walk finished until a page comes back empty, and cutting it off early would
  /// hide data rather than waste one request.
  static bool hasMoreAfter({
    required int page,
    required int pageSize,
    required int receivedCount,
    bool? hasMore,
    int? totalCount,
  }) {
    if (hasMore != null) {
      return hasMore;
    }
    final total = totalPages(totalCount, pageSize);
    if (total != null) {
      return page < total;
    }
    return receivedCount > 0;
  }

  /// The page that contains [index] (0-based) for [pageSize].
  ///
  /// A negative index is not in the list at all; answering page one keeps every
  /// caller inside the 1-based range. This matters more than it looks:
  /// `PageRequest`'s own guard is an `assert`, so a release build has nothing
  /// between a negative anchor and a loader computing `(0 - 1) * size` as a
  /// negative offset.
  static int pageForIndex(int index, int pageSize) => index <= 0 ? 1 : (index ~/ pageSize) + 1;

  /// The sublist of [items] shown on [page] (1-based).
  static List<T> slice<T>(List<T> items, int page, int pageSize) {
    final start = (page - 1) * pageSize;
    if (start >= items.length) {
      return const [];
    }
    final end = start + pageSize < items.length ? start + pageSize : items.length;
    return items.sublist(start, end);
  }
}
