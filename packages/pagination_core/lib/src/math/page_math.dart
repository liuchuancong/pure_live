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
  static int clampPage(int desired, int? totalPages) {
    if (desired < 1) {
      return 1;
    }
    if (totalPages != null && desired > totalPages) {
      return totalPages;
    }
    return desired;
  }

  /// The page that contains [index] (0-based) for [pageSize].
  static int pageForIndex(int index, int pageSize) => (index ~/ pageSize) + 1;

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
