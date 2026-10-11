// Module: lib/src/models/content/content_chapter.dart
// Purpose: One marked position inside a playable item - a chapter, a segment, a 分P boundary.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/capability-contract.md section 1 (chapter capability).
//
// `at` is an offset inside the item, not a wall-clock time. It is stored as milliseconds under `atMs` so a
// chapter list can never be mistaken for a schedule by the same code path that parses timestamps elsewhere.

import '../../support/json.dart';

/// One chapter mark.
final class ContentChapter {
  const ContentChapter({required this.title, required this.at, this.image, this.id});

  factory ContentChapter.fromJson(Map<String, Object?> json) => ContentChapter(
    title: requireString(json, 'title', 'content_chapter'),
    at: parseDurationMs(json['atMs']) ?? Duration.zero,
    image: json['image'] is String ? json['image']! as String : null,
    id: json['id'] is String ? json['id']! as String : null,
  );

  final String title;

  /// Where the chapter begins inside the item.
  final Duration at;

  /// The thumbnail the platform draws on the seek bar, when it has one.
  final String? image;

  /// The platform's own id, kept because bilibili's chapter jumps address chapters by it rather than by time.
  final String? id;

  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    'atMs': durationMs(at),
    if (image != null) 'image': image,
    if (id != null) 'id': id,
  };

  /// Orders a chapter list. A source that answers them out of order is corrected by the caller rather than
  /// trusted: a seek bar built from unsorted marks is unusable, not merely untidy.
  static int byOffset(ContentChapter a, ContentChapter b) => a.at.compareTo(b.at);

  @override
  bool operator ==(Object other) =>
      other is ContentChapter && other.title == title && other.at == at && other.image == image && other.id == id;

  @override
  int get hashCode => Object.hash(title, at, image, id);

  @override
  String toString() => 'ContentChapter($title @${at.inSeconds}s)';
}
