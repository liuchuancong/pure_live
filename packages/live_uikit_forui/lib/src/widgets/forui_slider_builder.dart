import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';

/// Builds a ForUI slider from a [LanguageSliderSpec] (§9 Slider).
///
/// `FSlider` is the library's own slider and it is *lifted*: the spec's value goes in
/// and the next value comes out, so the caller keeps owning the number and this
/// builder mints no controller. forui measures a slider as a track percentage rather
/// than in the spec's units, so `min`/`max` are used twice — once to normalise
/// [LanguageSliderSpec.value] into 0..1 and once to denormalise what the thumb reports
/// back — and the library's value bubble is switched off because it would announce
/// "40%" for a value the caller reads as 40 of 0..100.
///
/// [LanguageSliderSpec.focusNode] has no slot: the widget is a form field and owns its
/// focus internally, so the node is not mapped rather than hung off an invented
/// wrapper. The library's inert state is `enabled: false`, which is what a disabled
/// spec *and* a null `onChanged` both reach — the spec documents a null callback as
/// disabling the control, so no swallowing closure is invented to keep it looking live
/// (§9).
abstract final class ForuiSliderBuilder {
  /// Builds the slider for [spec].
  static Widget build(BuildContext context, LanguageSliderSpec spec) {
    final report = spec.enabled ? spec.onChanged : null;
    final span = spec.max - spec.min;
    final fraction = span == 0 ? 0.0 : ((spec.value - spec.min) / span).clamp(0.0, 1.0);

    return forui.FSlider(
      control: forui.FSliderControl.liftedContinuous(
        value: forui.FSliderValue(max: fraction),
        onChange: (value) => report?.call(spec.min + value.max * span),
      ),
      enabled: report != null,
      tooltipControls: const forui.FSliderTooltipControls.disabled(),
    );
  }
}
