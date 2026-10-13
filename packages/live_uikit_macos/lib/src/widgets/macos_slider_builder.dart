import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a native macOS slider from a [LanguageSliderSpec] (§9 Slider). The
/// value is clamped to the spec range; `MacosSlider.onChanged` is non-nullable,
/// so disabling is handled by ignoring the callback when [LanguageSliderSpec.enabled]
/// is false.
abstract final class MacosSliderBuilder {
  /// Builds the slider for [spec].
  static Widget build(BuildContext context, LanguageSliderSpec spec) => macos.MacosSlider(
    value: spec.value.clamp(spec.min, spec.max),
    onChanged: (v) {
      if (spec.enabled) {
        spec.onChanged?.call(v);
      }
    },
  );
}
