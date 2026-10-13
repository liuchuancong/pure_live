import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a native Material UI slider from a [LanguageSliderSpec] (§9 Slider),
/// clamped to the spec range and disabled by dropping the callback.
abstract final class MaterialUiSliderBuilder {
  /// Builds the slider for [spec].
  static Widget build(BuildContext context, LanguageSliderSpec spec) => mu.Slider(
    value: spec.value.clamp(spec.min, spec.max),
    min: spec.min,
    max: spec.max,
    onChanged: spec.enabled ? spec.onChanged : null,
  );
}
