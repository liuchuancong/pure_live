/// What a refresh does to the visible page.
enum RefreshPositionPolicy {
  /// Desktop default: re-fetch the current page and fix the page number
  /// if the dataset shrank.
  preserveCurrentPage,

  /// Mobile and query-change default: rebuild from page 1.
  resetToFirstPage,
}
