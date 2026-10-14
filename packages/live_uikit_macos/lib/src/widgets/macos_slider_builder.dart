import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a native macOS slider from a [LanguageSliderSpec] (§9 Slider). The
/// value is clamped to the spec range and the range itself is handed to the fork,
/// which asserts `min <= value <= max`.
///
/// Only an interactive spec belongs here: `MacosSlider.onChanged` is a required,
/// non-nullable callback, so a disabled slider has no representation in the
/// library — a closure that swallows the value would leave a live-looking control
/// (§9). The adapter routes that case to the shared token renderer, which is the
/// documented degradation path (§15), rather than approximating a disabled state.
abstract final class MacosSliderBuilder {
  /// Builds the slider for [spec].
  static Widget build(BuildContext context, LanguageSliderSpec spec) => macos.MacosSlider(
    value: spec.value.clamp(spec.min, spec.max),
    min: spec.min,
    max: spec.max,
    onChanged: spec.onChanged!,
  );
}
