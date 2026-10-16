import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a Material UI segmented control from a [LanguageSegmentedSpec]
/// (§9): the labels become indexed [mu.ButtonSegment]s and the selection maps
/// back to an index callback. `expand` uses the fork's own `expandedInsets`
/// rather than a width hack, so the segments share the parent's width.
abstract final class MaterialSegmentedBuilder {
  /// Builds the segmented control for [spec].
  static Widget build(BuildContext context, LanguageSegmentedSpec spec) {
    final onChanged = spec.onChanged;
    return mu.SegmentedButton<int>(
      showSelectedIcon: false,
      expandedInsets: spec.expand ? EdgeInsets.zero : null,
      segments: [for (var i = 0; i < spec.labels.length; i++) mu.ButtonSegment(value: i, label: Text(spec.labels[i]))],
      selected: {spec.index},
      // A null callback or `enabled: false` disables the control (§9): the
      // closure exists only when the caller can be called back, so a dead
      // segmented control does not light up as though it responded.
      onSelectionChanged: spec.enabled && onChanged != null ? (s) => onChanged(s.first) : null,
    );
  }
}
