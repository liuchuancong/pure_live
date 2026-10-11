// Module: lib/src/lib/src/models/content/content_ref/content_ref.dart
// Purpose: A reference to content inside one source.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md. Split out of the file that bundled it: one public
// type per file, and the file lives in a folder of its own (§2.1) so a model and anything generated
// for it are found in one place.

import '../../../support/json.dart';
import '../../identifiers.dart';
import '../content_kind/content_kind.dart';

final class ContentRef {
  const ContentRef({
    required this.sourceId,
    required this.contentId,
    required this.kind,
    this.parentId,
    this.providerId,
    this.metadata = const <String, Object?>{},
  });

  factory ContentRef.fromJson(Map<String, Object?> json) {
    return ContentRef(
      sourceId: requireString(json, 'sourceId', 'content_ref'),
      contentId: requireString(json, 'contentId', 'content_ref'),
      kind: enumByName(ContentKind.values, json['kind'] as String?) ?? ContentKind.vod,
      parentId: json['parentId'] as String?,
      providerId: json['providerId'] as String?,
      metadata: asObjectMap(json['metadata']),
    );
  }

  final SourceId sourceId;

  /// The source's own identifier; only unique within that source.
  final ContentId contentId;
  final ContentKind kind;

  /// The containing item, for example the series an episode belongs to.
  final String? parentId;

  /// Which provider inside the repository served it, when the source distinguishes them.
  final ProviderId? providerId;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'sourceId': sourceId,
      'contentId': contentId,
      'kind': kind.name,
      if (parentId != null) 'parentId': parentId,
      if (providerId != null) 'providerId': providerId,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  /// Equality is the identity tuple from docs/contracts/platform-models.md section 16; metadata is
  /// deliberately excluded so a refreshed description never turns the same content into a new key.
  @override
  bool operator ==(Object other) {
    return other is ContentRef &&
        other.sourceId == sourceId &&
        other.contentId == contentId &&
        other.kind == kind &&
        other.parentId == parentId;
  }

  @override
  int get hashCode => Object.hash(sourceId, contentId, kind, parentId);

  @override
  String toString() => 'ContentRef($sourceId/$kind:$contentId)';
}

/// The converter pair a generated (freezed/json_serializable) model must hang on a nested [ContentRef] field.
///
/// Without it the generator writes the **object** into the map - `'ref': instance.ref` - which `jsonEncode`
/// happens to survive but our storage does not: the repositories persist the `toJson()` map itself, and reading
/// that back hit `json['ref'] as Map<String, dynamic>` on a live `ContentRef` and threw. The two directions are
/// paired here so no model can ship half of them.
ContentRef refFromJson(Object? value) =>
    ContentRef.fromJson(value is Map ? asObjectMap(value) : const <String, Object?>{});

ContentRef? refFromJsonOrNull(Object? value) => value == null ? null : refFromJson(value);

Map<String, Object?> refToJson(ContentRef value) => value.toJson();

Map<String, Object?>? refToJsonOrNull(ContentRef? value) => value?.toJson();

/// The card-sized view of content, used by lists and search results.
