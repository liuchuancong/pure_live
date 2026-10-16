import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a Cupertino segmented track from a [LanguageSegmentedSpec] (§9
/// Segmented).
///
/// Mapped: `cu.CupertinoSegmentedControl` is the library's own one-choice-out-of-a
/// row, keyed by a value rather than by an index — so the keys here are the
/// indices, which is what the contract reports back. A disabled group is the
/// library's own inert state: every key goes into `disabledChildren`, which makes
/// each segment grey and stops its tap from reporting, so
/// [LanguageSegmentedSpec.enabled] needs no extra work and the required
/// `onValueChanged` never fires behind it.
///
/// [LanguageSegmentedSpec.expand] has no knob. The library's control divides the
/// width it is handed equally between its segments and cannot shrink-wrap to its
/// labels — its own `UnconstrainedBox` re-passes the incoming width constraint —
/// and that is also how iOS draws one: a segmented track spans its container and
/// the container decides how wide that is.
///
/// An index outside the labels is legal here and means "nothing selected", the
/// same reading the contract gives it. A track of fewer than two segments is not:
/// the library asserts `children.length >= 2`, so a spec it would throw on stays
/// with the shared renderer rather than crashing in the library (§15).
abstract final class CupertinoSegmentedBuilder {
  /// Builds the segmented track for [spec].
  static Widget build(BuildContext context, LanguageSegmentedSpec spec) {
    final select = spec.enabled ? spec.onChanged : null;
    final children = {
      for (var index = 0; index < spec.labels.length; index++)
        index: Text(spec.labels[index], maxLines: 1, overflow: TextOverflow.ellipsis),
    };
    return cu.CupertinoSegmentedControl<int>(
      children: children,
      groupValue: children.containsKey(spec.index) ? spec.index : null,
      onValueChanged: (index) => select?.call(index),
      disabledChildren: spec.enabled ? const <int>{} : children.keys.toSet(),
    );
  }
}
