import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a native Material UI slider from a [LanguageSliderSpec] (§9 Slider),
/// clamped to the spec range, with the caller's focus node preserved so keyboard
/// and D-pad traversal reach the slider.
///
/// Only an interactive spec belongs here: `material_ui` 1.6.0 dereferences an
/// internal focus node it creates solely for an enabled slider
/// (`widget.focusNode ?? _focusNode!`), so a disabled `mu.Slider` throws while
/// building. The adapter routes that case to the shared token renderer instead
/// (§15), which keeps the control on-theme rather than rendering one that cannot
/// build; the fork fix retires that branch.
abstract final class MaterialSliderBuilder {
  /// Builds the slider for [spec].
  static Widget build(BuildContext context, LanguageSliderSpec spec) => mu.Slider(
    value: spec.value.clamp(spec.min, spec.max),
    min: spec.min,
    max: spec.max,
    onChanged: spec.onChanged,
    focusNode: spec.focusNode,
  );
}
