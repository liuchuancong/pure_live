// Module: lib/src/lib/src/models/content/search_query/search_query.dart
// Purpose: One search request.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md. Split out of the file that bundled it: one public
// type per file, and the file lives in a folder of its own (§2.1) so a model and anything generated
// for it are found in one place.

import '../../../support/json.dart';
import '../content_kind/content_kind.dart';
import '../page_request/page_request.dart';

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
