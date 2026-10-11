// Module: lib/src/models/content/selection_ref/selection_ref.dart
// Purpose: A choice the viewer made from a menu the source published.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md. Split out of the file that bundled it: one public
// type per file, and the file lives in a folder of its own (§2.1) so a model and anything generated
// for it are found in one place.

/// A quality or line choice inside one source's own vocabulary.
final class SelectionRef {
  const SelectionRef(this.id, {this.label});

  final String id;
  final String? label;

  Map<String, Object?> toJson() => <String, Object?>{'id': id, if (label != null) 'label': label};

  factory SelectionRef.fromJson(Map<String, Object?> json) =>
      SelectionRef(json['id']! as String, label: json['label'] as String?);

  @override
  String toString() => 'SelectionRef($id)';

  @override
  bool operator ==(Object other) => other is SelectionRef && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
