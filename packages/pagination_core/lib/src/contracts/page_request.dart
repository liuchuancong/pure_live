/// A logical page request: which page, how many items per page.
///
/// Pages are 1-based. The request is what a controller asks for — the
/// loader decides how to produce it (one server call, five batch calls,
/// a local slice, anything).
final class PageRequest {
  /// A request for [page] (1-based, must be ≥ 1) with [pageSize] items
  /// (must be > 0).
  const new({required this.page, required this.pageSize})
    : assert(page >= 1, 'page is 1-based and must be >= 1'),
      assert(pageSize > 0, 'pageSize must be > 0');

  /// 1-based page number.
  final int page;

  /// Items requested for this page.
  final int pageSize;

  @override
  String toString() => 'PageRequest(page: $page, pageSize: $pageSize)';
}
