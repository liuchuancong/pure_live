// Module: lib/src/models/content/content_ref.dart
// Purpose: The source-relative reference to a piece of content, which is the stable boundary between "what the user wants" and "how it plays".
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-models.md section 7. A ContentRef is relative to one source and must not
// be assumed globally unique; cross-source identity is a separate concern (ContentIdentity, later wave).
// It carries no player information (invariant 1) and no UI state.

import '../../support/json.dart';
import '../identifiers.dart';

/// What kind of content a reference points at.
enum ContentKind {
  liveChannel,
  liveRoom,
  vod,
  movie,
  series,
  episode,
  music,
  album,
  artist,
  playlist,
  stream,
  epgProgram,
  localMedia,
}

/// Extra descriptive fields. Only fields that are stable and widely consumed belong here.
final class ContentMetadata {
  const ContentMetadata({
    this.year,
    this.region,
    this.language,
    this.duration,
    this.rating,
    this.popularity,
    this.extra = const <String, Object?>{},
  });

  factory ContentMetadata.fromJson(Map<String, Object?> json) {
    return ContentMetadata(
      year: json['year'] as String?,
      region: json['region'] as String?,
      language: json['language'] as String?,
      duration: parseDurationMs(json['durationMs']),
      rating: (json['rating'] as num?)?.toDouble(),
      popularity: (json['popularity'] as num?)?.toInt(),
      extra: asObjectMap(json['extra']),
    );
  }

  final String? year;
  final String? region;
  final String? language;
  final Duration? duration;
  final double? rating;
  final int? popularity;
  final Map<String, Object?> extra;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (year != null) 'year': year,
      if (region != null) 'region': region,
      if (language != null) 'language': language,
      if (duration != null) 'durationMs': durationMs(duration),
      if (rating != null) 'rating': rating,
      if (popularity != null) 'popularity': popularity,
      if (extra.isNotEmpty) 'extra': extra,
    };
  }
}

/// A tag as one source labels content.
final class ContentTag {
  const ContentTag({required this.id, required this.name});

  factory ContentTag.fromJson(Map<String, Object?> json) =>
      ContentTag(id: requireString(json, 'id', 'content_ref'), name: requireString(json, 'name', 'content_ref'));

  final String id;
  final String name;

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'name': name};
}

/// A reference to content inside one source.
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

/// The full record for one item: its summary, its children and its tags.
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
