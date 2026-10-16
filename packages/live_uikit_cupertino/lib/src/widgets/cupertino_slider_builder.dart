import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a native Cupertino UI slider from a [LanguageSliderSpec] (§9 Slider),
/// clamped to the spec range and disabled by dropping the callback: a null
/// `onChanged` reaches the fork as null rather than as a closure that swallows
/// the drag, so a dead slider never looks live (§9/§15).
abstract final class CupertinoSliderBuilder {
  /// Builds the slider for [spec].
  static Widget build(BuildContext context, LanguageSliderSpec spec) => cu.CupertinoSlider(
    value: spec.value.clamp(spec.min, spec.max),
    min: spec.min,
    max: spec.max,
    onChanged: spec.enabled ? spec.onChanged : null,
  );
}
