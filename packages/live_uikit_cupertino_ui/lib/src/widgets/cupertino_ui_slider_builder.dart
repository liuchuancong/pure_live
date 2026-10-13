import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a native Cupertino UI slider from a [LanguageSliderSpec] (§9 Slider),
/// clamped to the spec range and disabled by dropping the callback.
abstract final class CupertinoUiSliderBuilder {
  /// Builds the slider for [spec].
  static Widget build(BuildContext context, LanguageSliderSpec spec) => cu.CupertinoSlider(
    value: spec.value.clamp(spec.min, spec.max),
    min: spec.min,
    max: spec.max,
    onChanged: spec.enabled ? (spec.onChanged ?? (_) {}) : null,
  );
}
