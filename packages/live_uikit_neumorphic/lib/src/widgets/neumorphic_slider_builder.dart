import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/styling.dart';

/// Builds a Neumorphic slider from a [LanguageSliderSpec] (§9 Slider), clamped
/// to the spec range and disabled by dropping the callback.
abstract final class NeumorphicSliderBuilder {
  /// Builds the slider for [spec].
  static Widget build(BuildContext context, LanguageSliderSpec spec) => neu.NeuSlider(
    value: spec.value.clamp(spec.min, spec.max),
    min: spec.min,
    max: spec.max,
    onChanged: spec.enabled ? spec.onChanged : null,
  );
}
