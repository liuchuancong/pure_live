// Module: lib/src/models/content/content_summary/content_summary.dart
// Purpose: The card-sized view of content, used by lists and search results.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md. Split out of the file that bundled it: one public
// type per file, and the file lives in a folder of its own (§2.1) so a model and anything generated
// for it are found in one place.

import '../../../support/json.dart';
import '../content_metadata/content_metadata.dart';
import '../content_ref/content_ref.dart';

/// The card-sized view of content, used by lists and search results.
final class ContentSummary {
  const ContentSummary({
    required this.ref,
    required this.title,
    this.subtitle,
    this.cover,
    this.description,
    this.metadata = const ContentMetadata(),
  });

  factory ContentSummary.fromJson(Map<String, Object?> json) {
    return ContentSummary(
      ref: ContentRef.fromJson(asObjectMap(json['ref'])),
      title: requireString(json, 'title', 'content_ref'),
      subtitle: json['subtitle'] as String?,
      cover: json['cover'] as String?,
      description: json['description'] as String?,
      metadata: ContentMetadata.fromJson(asObjectMap(json['metadata'])),
    );
  }

  final ContentRef ref;
  final String title;
  final String? subtitle;
  final String? cover;
  final String? description;
  final ContentMetadata metadata;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'ref': ref.toJson(),
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (cover != null) 'cover': cover,
      if (description != null) 'description': description,
      'metadata': metadata.toJson(),
    };
  }
}
