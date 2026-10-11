// Module: lib/src/lib/src/models/content/content_metadata/content_metadata.dart
// Purpose: The descriptive columns a listing shows beside a title.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md. Split out of the file that bundled it: one public
// type per file, and the file lives in a folder of its own (§2.1) so a model and anything generated
// for it are found in one place.

import '../../../support/json.dart';

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

/// One entry of a source's category table. [parentId] builds the tree when a
/// source groups two levels (channel group -> sub-category); a flat source
/// leaves it null. The id is what a ContentQuery.category carries back.
