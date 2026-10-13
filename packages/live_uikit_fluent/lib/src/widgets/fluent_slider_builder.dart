import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a native Fluent slider from a [LanguageSliderSpec] (§9 Slider). The
/// value is clamped into `[min, max]` (the spec's range contract) and the
/// callback is dropped when the control is disabled.
abstract final class FluentSliderBuilder {
  /// Builds the slider for [spec].
  static Widget build(BuildContext context, LanguageSliderSpec spec) => fluent.Slider(
    value: spec.value.clamp(spec.min, spec.max),
    min: spec.min,
    max: spec.max,
    onChanged: spec.enabled ? spec.onChanged : null,
  );
}
