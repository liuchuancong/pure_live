// Module: lib/src/lib/src/models/content/page_request/page_request.dart
// Purpose: Which page to fetch.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md. Split out of the file that bundled it: one public
// type per file, and the file lives in a folder of its own (§2.1) so a model and anything generated
// for it are found in one place.

final class PageRequest {
  const PageRequest({this.page = 1, this.pageSize = 20, this.cursor});

  static const PageRequest first = PageRequest();

  final int page;
  final int pageSize;

  /// The server-defined continuation token from the previous answer. When set
  /// it wins over [page]: a cursor-mode source ignores page numbers entirely.
  final String? cursor;

  Map<String, Object?> toJson() => <String, Object?>{
    'page': page,
    'pageSize': pageSize,
    if (cursor != null) 'cursor': cursor,
  };

  factory PageRequest.fromJson(Map<String, Object?> json) => PageRequest(
    page: (json['page'] as num?)?.toInt() ?? 1,
    pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
    cursor: json['cursor'] as String?,
  );
}

/// One page of results.
