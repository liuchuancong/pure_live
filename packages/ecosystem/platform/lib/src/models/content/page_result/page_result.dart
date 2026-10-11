// Module: lib/src/models/content/page_result/page_result.dart
// Purpose: One page of results.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md. Split out of the file that bundled it: one public
// type per file, and the file lives in a folder of its own (§2.1) so a model and anything generated
// for it are found in one place.

import '../page_mode/page_mode.dart';

/// One page of results.
final class PageResult<T> {
  const PageResult({
    required this.items,
    required this.page,
    required this.pageSize,
    this.hasMore = false,
    this.total,
    this.mode = PageMode.fixedPage,
    this.nextCursor,
  });

  /// An empty page, used when a source answered but had nothing for this query.
  const PageResult.empty()
    : items = const <Never>[],
      page = 1,
      pageSize = 0,
      hasMore = false,
      total = 0,
      mode = PageMode.fixedPage,
      nextCursor = null;

  final List<T> items;
  final int page;
  final int pageSize;

  /// Whether another page may exist. A source that cannot tell must say false rather than guess true,
  /// because a true here keeps a list spinning forever. A singleShot answer
  /// carries false by definition.
  final bool hasMore;

  /// Total count when the protocol reports one.
  final int? total;

  /// How to read this answer and ask for the next one.
  final PageMode mode;

  /// The continuation token for cursor-mode sources; null otherwise. The next
  /// request sends it back as PageRequest.cursor.
  final String? nextCursor;

  bool get isEmpty => items.isEmpty;

  Map<String, Object?> toJson(Map<String, Object?> Function(T item) encodeItem) {
    return <String, Object?>{
      'items': items.map(encodeItem).toList(growable: false),
      'page': page,
      'pageSize': pageSize,
      if (hasMore) 'hasMore': true,
      if (total != null) 'total': total,
      'mode': mode.name,
      if (nextCursor != null) 'nextCursor': nextCursor,
    };
  }
}
