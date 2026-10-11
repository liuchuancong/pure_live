// Module: lib/src/models/content/content_category/content_category.dart
// Purpose: One entry of a source's own category table.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md. Split out of the file that bundled it: one public
// type per file, and the file lives in a folder of its own (§2.1) so a model and anything generated
// for it are found in one place.

import '../../../support/json.dart';

/// One entry of a source's category table. [parentId] builds the tree when a
/// source groups two levels (channel group -> sub-category); a flat source
/// leaves it null. The id is what a ContentQuery.category carries back.
final class ContentCategory {
  const ContentCategory({required this.id, required this.name, this.parentId, this.icon});

  factory ContentCategory.fromJson(Map<String, Object?> json) => ContentCategory(
    id: requireString(json, 'id', 'content_category'),
    name: requireString(json, 'name', 'content_category'),
    parentId: json['parentId'] as String?,
    icon: json['icon'] as String?,
  );

  final String id;
  final String name;
  final String? parentId;
  final String? icon;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    if (parentId != null) 'parentId': parentId,
    if (icon != null) 'icon': icon,
  };

  @override
  bool operator ==(Object other) => other is ContentCategory && other.id == id && other.parentId == parentId;

  @override
  int get hashCode => Object.hash(id, parentId);

  @override
  String toString() => 'ContentCategory($id $name)';
}
