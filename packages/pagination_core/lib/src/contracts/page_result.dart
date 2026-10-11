/// The ready-made content of one logical page, as the loader promises it.
///
/// Contract: [items] are exactly the data of the requested page — not a
/// raw batch, not a prefix of something larger. Aggregation, slicing and
/// cursor handling are the loader's job.
final class PageResult<T> {
  /// A page result; [items] is copied into an unmodifiable list.
  new({required Iterable<T> items, this.totalCount, this.hasMore}) : items = List<T>.unmodifiable(items);

  /// The items of this logical page, in display order.
  final List<T> items;

  /// Total items across all pages, when the source knows it. Null means
  /// unknown — never fabricated.
  final int? totalCount;

  /// Whether more pages exist after this one. Null means the source does
  /// not say; controllers then derive it from [totalCount] or from the
  /// page fullness.
  final bool? hasMore;

  @override
  String toString() => 'PageResult(${items.length} items, totalCount: $totalCount, hasMore: $hasMore)';
}
