// Module: lib/src/breadcrumbs.dart
// Purpose: The last few things the user did, kept in a bounded ring and scrubbed before it is kept.
// Author: liuchuancong
// Created: 2026-10-11
//
// "It broke when I switched to the second quality" is the sentence, and the trail is what turns it into a
// reproducible report. It is scrubbed on the way *in* rather than on the way out, because a breadcrumb that
// kept a room's signed url in plain text is already in the ring by the time somebody remembers to filter the
// export.

import 'package:pure_live_utils/pure_live_utils.dart';

import 'redaction.dart';

/// How many breadcrumbs one trail keeps.
const int kBreadcrumbLimit = 128;

/// The most any one breadcrumb's field text may cost, in characters.
const int kBreadcrumbFieldBudget = 240;

/// One step the user took.
final class Breadcrumb {
  const Breadcrumb({required this.at, required this.label, required this.category, required this.fields});

  final DateTime at;
  final String label;

  /// `ui`, `playback`, `network`, `auth` - a coarse bucket, so a report can be read by category.
  final String category;

  /// Already scrubbed and truncated. Values are strings by construction: a field that holds an object is a
  /// field that will hold something nobody meant to export.
  final Map<String, String> fields;

  String renderLine() {
    if (fields.isEmpty) {
      return '${at.toIso8601String()} [$category] $label';
    }
    final joined = fields.entries.map((entry) => '${entry.key}=${entry.value}').join(' ');
    return '${at.toIso8601String()} [$category] $label {$joined}';
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'at': at.toIso8601String(),
      'label': label,
      'category': category,
      if (fields.isNotEmpty) 'fields': <String, String>{...fields},
    };
  }

  @override
  String toString() => renderLine();
}

/// A bounded, redacted trail of user steps.
final class BreadcrumbTrail {
  BreadcrumbTrail({Clock? clock, this.limit = kBreadcrumbLimit, this.fieldBudget = kBreadcrumbFieldBudget})
    : _clock = clock ?? systemClock {
    if (limit < 1) {
      throw ArgumentError.value(limit, 'limit', 'must keep at least one crumb');
    }
  }

  final Clock _clock;
  final int limit;
  final int fieldBudget;

  final List<Breadcrumb> _crumbs = <Breadcrumb>[];
  int _dropped = 0;

  /// Oldest first.
  List<Breadcrumb> get trail => List<Breadcrumb>.unmodifiable(_crumbs);

  /// Crumbs evicted to stay inside [limit].
  int get droppedCount => _dropped;

  bool get isTruncated => _dropped > 0;

  bool get isEmpty => _crumbs.isEmpty;

  /// Records one step. [label] and every value are passed through [redactSecrets] and the field budget here.
  Breadcrumb leave(String label, {String category = 'ui', Map<String, Object?> fields = const <String, Object?>{}}) {
    final crumb = Breadcrumb(
      at: _clock().toUtc(),
      label: redactSecrets(requireNonBlank(label, name: 'label')),
      category: category,
      fields: _cleanFields(fields),
    );
    _crumb(crumb);
    return crumb;
  }

  /// The trail as report lines, newest last.
  List<String> renderLines() => _crumbs.map((crumb) => crumb.renderLine()).toList(growable: false);

  List<Map<String, Object?>> toJson() => _crumbs.map((crumb) => crumb.toJson()).toList(growable: false);

  void clear() {
    _crumbs.clear();
    _dropped = 0;
  }

  void _crumb(Breadcrumb crumb) {
    if (_crumbs.length >= limit) {
      _crumbs.removeAt(0);
      _dropped++;
    }
    _crumbs.add(crumb);
  }

  Map<String, String> _cleanFields(Map<String, Object?> fields) {
    final out = <String, String>{};
    fields.forEach((name, value) {
      if (value == null) {
        return;
      }
      out[name] = _clip(redactSecrets('$value'));
    });
    return out;
  }

  String _clip(String text) => text.length <= fieldBudget ? text : '${text.substring(0, fieldBudget)}…';
}
