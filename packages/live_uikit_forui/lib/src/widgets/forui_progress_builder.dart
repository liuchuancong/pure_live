import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';

/// Builds a ForUI progress bar from a [LanguageProgressSpec] (§9 Progress).
///
/// The library splits the two states the spec expresses with a null `value` into two
/// widgets, so both are mapped rather than approximated: a fraction is
/// `FDeterminateProgress` and null is `FProgress`, the library's own indeterminate
/// animation. [LanguageProgressSpec.height] goes to the style's track constraints and
/// [LanguageProgressSpec.barColor] to the fill's colour — both through forui's style
/// delta, which replaces only the field named and leaves the library's pill shape and
/// track colour alone, so the bar stays the theme's.
///
/// [LanguageProgressSpec.showLabel] has no slot: forui's indicator paints a bar and
/// nothing else, so the label is dropped rather than overlaid with a hand-built
/// percentage (§9/§15). It is the one field of this control the library cannot express.
abstract final class ForuiProgressBuilder {
  /// Builds the progress bar for [spec].
  static Widget build(BuildContext context, LanguageProgressSpec spec) {
    final constraints = BoxConstraints.tightFor(height: spec.height);
    final fill = spec.barColor == null ? null : forui.DecorationDelta.shapeDelta(color: spec.barColor);
    final value = spec.value;

    if (value == null) {
      return forui.FProgress(
        style: forui.FProgressStyleDelta.delta(constraints: constraints, fillDecoration: fill),
      );
    }
    return forui.FDeterminateProgress(
      // The widget asserts 0..1 on its own value, so an out-of-range fraction is
      // clamped rather than handed to the library as a crash (§15).
      value: value.clamp(0.0, 1.0),
      style: forui.FDeterminateProgressStyleDelta.delta(constraints: constraints, fillDecoration: fill),
    );
  }
}
