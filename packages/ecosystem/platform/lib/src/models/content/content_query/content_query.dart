// Module: lib/src/lib/src/models/content/content_query/content_query.dart
// Purpose: One listing request.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md. Split out of the file that bundled it: one public
// type per file, and the file lives in a folder of its own (§2.1) so a model and anything generated
// for it are found in one place.

import '../../../support/json.dart';
import '../content_sort/content_sort.dart';
import '../page_request/page_request.dart';

final class ContentQuery {
  const ContentQuery({
    this.category,
    this.keyword,
    this.page = const PageRequest(),
    this.sort,
    this.filters = const <String, Object?>{},
  });

  final String? category;
  final String? keyword;
  final PageRequest page;
  final ContentSort? sort;
  final Map<String, Object?> filters;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (category != null) 'category': category,
      if (keyword != null) 'keyword': keyword,
      'page': page.toJson(),
      if (sort != null) 'sort': sort!.name,
      if (filters.isNotEmpty) 'filters': filters,
    };
  }

  factory ContentQuery.fromJson(Map<String, Object?> json) => ContentQuery(
    category: json['category'] as String?,
    keyword: json['keyword'] as String?,
    page: PageRequest.fromJson(asObjectMap(json['page'])),
    sort: enumByName(ContentSort.values, json['sort'] as String?),
    filters: asObjectMap(json['filters']),
  );
}

/// A search request. Kept separate from ContentQuery because search has no category to scope by.
