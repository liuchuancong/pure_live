import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';

/// Builds a ForUI segmented control from a [LanguageSegmentedSpec] (§9 Segmented).
///
/// **Composed, not mapped.** forui has no segmented-track widget: its only single
/// choice out of a row is `FTabs`, and that is a *tab view* — every entry carries a
/// content panel — which this package already spends on [LiveUiControl.tabBar]. A
/// segment is a value, not a view, so the track is assembled here out of the library's
/// own parts: `FButton`s in the ghost variant, where the chosen one takes
/// `FButton.selected`. That is forui's real toggled affordance (the same one the button
/// builder maps [LanguageButtonSpec.selected] onto), so the selection is drawn by the
/// library's style table rather than painted over it, and each segment reports its own
/// index.
///
/// [LanguageSegmentedSpec.expand] gives every segment an equal share of the row; a
/// disabled group is a group of buttons with no `onPress`, which is the library's own
/// inert state (§9).
abstract final class ForuiSegmentedBuilder {
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

  static Widget _segment(LanguageSegmentedSpec spec, int index, void Function(int)? select) => forui.FButton(
    variant: forui.FButtonVariant.ghost,
    selected: index == spec.index,
    onPress: select == null ? null : () => select(index),
    mainAxisSize: spec.expand ? MainAxisSize.max : MainAxisSize.min,
    child: Text(spec.labels[index], maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
  );
}
