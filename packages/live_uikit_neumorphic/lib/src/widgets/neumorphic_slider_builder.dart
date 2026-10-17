import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Neumorphic slider from a [LanguageSliderSpec] (§9 Slider).
///
/// **Mapped.** `NeuSlider` is the library's own slider. The value is clamped to the
/// spec range first, and `enabled: false` reaches the widget as a null `onChanged`,
/// which is how this library draws an inert control.
abstract final class NeumorphicSliderBuilder {
  /// Builds the slider for [spec].
  static Widget build(BuildContext context, LanguageSliderSpec spec) => neu.NeuSlider(
    value: spec.value.clamp(spec.min, spec.max),
    min: spec.min,
    max: spec.max,
    onChanged: spec.enabled ? spec.onChanged : null,
  );
}
