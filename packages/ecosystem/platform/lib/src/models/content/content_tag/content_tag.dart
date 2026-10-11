// Module: lib/src/models/content/content_tag/content_tag.dart
// Purpose: A label the source puts on content, as the source names it.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md. Split out of the file that bundled it: one public
// type per file, and the file lives in a folder of its own (§2.1) so a model and anything generated
// for it are found in one place.

import '../../../support/json.dart';

/// A tag as one source labels content.
final class ContentTag {
  const ContentTag({required this.id, required this.name});

  factory ContentTag.fromJson(Map<String, Object?> json) =>
      ContentTag(id: requireString(json, 'id', 'content_ref'), name: requireString(json, 'name', 'content_ref'));

  final String id;
  final String name;

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'name': name};
}
