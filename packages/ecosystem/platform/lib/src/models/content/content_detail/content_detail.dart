// Module: lib/src/lib/src/models/content/content_detail/content_detail.dart
// Purpose: The full answer for one item, including its children.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md. Split out of the file that bundled it: one public
// type per file, and the file lives in a folder of its own (§2.1) so a model and anything generated
// for it are found in one place.

import '../../../support/json.dart';
import '../content_ref/content_ref.dart';
import '../content_summary/content_summary.dart';
import '../content_tag/content_tag.dart';

final class ContentDetail {
  const ContentDetail({
    required this.summary,
    this.description,
    this.children = const <ContentRef>[],
    this.tags = const <ContentTag>[],
    this.metadata = const <String, Object?>{},
  });

  factory ContentDetail.fromJson(Map<String, Object?> json) => ContentDetail(
    summary: ContentSummary.fromJson(asObjectMap(json['summary'])),
    description: json['description'] as String?,
    children: asObjectMapList(json['children']).map(ContentRef.fromJson).toList(growable: false),
    tags: asObjectMapList(json['tags']).map(ContentTag.fromJson).toList(growable: false),
    metadata: asObjectMap(json['metadata']),
  );

  final ContentSummary summary;
  final String? description;

  /// Episodes of a series, tracks of an album, channels of a playlist.
  final List<ContentRef> children;
  final List<ContentTag> tags;
  final Map<String, Object?> metadata;

  ContentRef get ref => summary.ref;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'summary': summary.toJson(),
      if (description != null) 'description': description,
      if (children.isNotEmpty) 'children': children.map((ref) => ref.toJson()).toList(growable: false),
      if (tags.isNotEmpty) 'tags': tags.map((tag) => tag.toJson()).toList(growable: false),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}
