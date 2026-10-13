import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a Material UI segmented control from a [LanguageSegmentedSpec]
/// (§9): the labels become indexed [mu.ButtonSegment]s and the selection maps
/// back to an index callback.
abstract final class MaterialUiSegmentedBuilder {
  /// Builds the segmented control for [spec].
  static Widget build(BuildContext context, LanguageSegmentedSpec spec) => mu.SegmentedButton<int>(
    showSelectedIcon: false,
    segments: [for (var i = 0; i < spec.labels.length; i++) mu.ButtonSegment(value: i, label: Text(spec.labels[i]))],
    selected: {spec.index},
    onSelectionChanged: spec.enabled
        ? (s) {
            final v = s.first;
            spec.onChanged?.call(v);
          }
        : null,
  );
}
