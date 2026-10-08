// Module: lib/src/models/content/paging.dart
// Purpose: The paging and query shapes every browse and search contract returns.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-models.md section 9. External protocols page differently - some by index,
// some by opaque token - and the runtime adapts them to this shape so no feature has to know which.

import '../../support/json.dart';
import 'content_ref.dart';

/// Which page to fetch. Page numbers are one-based, matching every protocol this app speaks.
final class PageRequest {
  const PageRequest({this.page = 1, this.pageSize = 20});

  static const PageRequest first = PageRequest();

  final int page;
  final int pageSize;

  Map<String, Object?> toJson() => <String, Object?>{
    'page': page,
    'pageSize': pageSize,
  };

  factory PageRequest.fromJson(Map<String, Object?> json) => PageRequest(
    page: (json['page'] as num?)?.toInt() ?? 1,
    pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
  );
}

/// One page of results.
final class PageResult<T> {
  const PageResult({
    required this.items,
    required this.page,
    required this.pageSize,
    this.hasMore = false,
    this.total,
  });

  /// An empty page, used when a source answered but had nothing for this query.
  const PageResult.empty()
    : items = const <Never>[],
      page = 1,
      pageSize = 0,
      hasMore = false,
      total = 0;

  final List<T> items;
  final int page;
  final int pageSize;

  /// Whether another page may exist. A source that cannot tell must say false rather than guess true,
  /// because a true here keeps a list spinning forever.
  final bool hasMore;

  /// Total count when the protocol reports one.
  final int? total;

  bool get isEmpty => items.isEmpty;

  Map<String, Object?> toJson(
    Map<String, Object?> Function(T item) encodeItem,
  ) {
    return <String, Object?>{
      'items': items.map(encodeItem).toList(growable: false),
      'page': page,
      'pageSize': pageSize,
      if (hasMore) 'hasMore': true,
      if (total != null) 'total': total,
    };
  }
}

/// How a browse request is ordered.
enum ContentSort { relevance, latest, popularity, rating, title }

/// A browse query inside one source.
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
final class SearchQuery {
  const SearchQuery({
    required this.keyword,
    this.page = const PageRequest(),
    this.kind,
    this.filters = const <String, Object?>{},
  });

  final String keyword;
  final PageRequest page;
  final ContentKind? kind;
  final Map<String, Object?> filters;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'keyword': keyword,
      'page': page.toJson(),
      if (kind != null) 'kind': kind!.name,
      if (filters.isNotEmpty) 'filters': filters,
    };
  }

  factory SearchQuery.fromJson(Map<String, Object?> json) => SearchQuery(
    keyword: json['keyword']! as String,
    page: PageRequest.fromJson(asObjectMap(json['page'])),
    kind: enumByName(ContentKind.values, json['kind'] as String?),
    filters: asObjectMap(json['filters']),
  );
}

/// Why a ticket is being refreshed.
///
/// Spec: docs/contracts/media-contract.md section 3 and docs/media/media-ticket.md section 2 list these
/// names; docs/architecture/evolution.md forbids renaming or reordering an enum once it exists, so the
/// documented set is used as written instead of a reduced local one. The four failure causes stay separate
/// because the recovery ladder differs per cause (docs/media/recovery.md).
enum RefreshReason {
  expiring,
  expired,
  networkError,
  http403,
  http404,
  decodeError,
  manual,
  qualityChanged,
  lineChanged,
}

/// A quality or line choice inside one source's own vocabulary.
final class SelectionRef {
  const SelectionRef(this.id, {this.label});

  final String id;
  final String? label;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    if (label != null) 'label': label,
  };

  factory SelectionRef.fromJson(Map<String, Object?> json) =>
      SelectionRef(json['id']! as String, label: json['label'] as String?);

  @override
  String toString() => 'SelectionRef($id)';

  @override
  bool operator ==(Object other) => other is SelectionRef && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
