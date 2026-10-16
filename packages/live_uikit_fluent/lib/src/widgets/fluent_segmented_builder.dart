import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a Fluent segmented control from a [LanguageSegmentedSpec] (§9 Segmented).
///
/// Fluent has no single segmented widget: the library's own answer to "one
/// choice out of a row" is a group of `ToggleButton`s, which is what WinUI calls
/// a segmented pick too — the selection is the accent-filled checked state rather
/// than a sliding thumb. So the group is composed here, out of the library's
/// widget, and each segment reports its own index.
///
/// [LanguageSegmentedSpec.expand] is mapped by giving every segment an equal
/// share of the row; a disabled group is a group of buttons with no callback,
/// which is the library's own inert state.
abstract final class FluentSegmentedBuilder {
  /// Builds the segmented track for [spec].
  static Widget build(BuildContext context, LanguageSegmentedSpec spec) {
    final select = spec.enabled ? spec.onChanged : null;
    return Row(
      mainAxisSize: spec.expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (var index = 0; index < spec.labels.length; index++)
          if (spec.expand) Expanded(child: _segment(spec, index, select)) else _segment(spec, index, select),
      ],
    );
  }

  static Widget _segment(LanguageSegmentedSpec spec, int index, void Function(int)? select) {
    return fluent.ToggleButton(
      checked: index == spec.index,
      semanticLabel: spec.labels[index],
      onChanged: select == null ? null : (_) => select(index),
      child: Text(spec.labels[index], maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
    );
  }
}
