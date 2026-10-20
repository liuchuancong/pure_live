import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:forui/forui.dart' as forui;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The public slider: one widget, every theme and density. It carries only
/// semantics (`value`, `min`, `max`, `onChanged`, `enabled`); its appearance
/// comes straight from the active design language's own widget library. [build]
/// switches on `UiConfig.language` and constructs the library's real component
/// directly — fluent_2's `FluentSlider` under fluent, `MacosSlider` under macOS,
/// `CupertinoSlider` under iOS, Material's `Slider` — so what the user sees is
/// exactly what that library's own documentation shows. Switching
/// `UiConfig.language` re-skins every slider.
class PureSlider extends StatelessWidget {
  /// A slider.
  const new({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.enabled = true,
    this.focusNode,
    super.key,
  });

  /// The current value.
  final double value;

  /// Called with each new value; null (or `enabled: false`) disables it.
  final ValueChanged<double>? onChanged;

  /// The lower bound.
  final double min;

  /// The upper bound.
  final double max;

  /// Whether the slider responds to input.
  final bool enabled;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final select = enabled ? onChanged : null;
    final clamped = value.clamp(min, max);
    final span = max - min;
    // The value normalised into the 0..1 track the fractional libraries measure
    // (forui lifts a track percentage, glass and wind compute the thumb's run
    // themselves), clamped so a value outside its own bounds still draws inside
    // the rail.
    final fraction = span <= 0 ? 0.0 : ((clamped - min) / span).clamp(0.0, 1.0);

    return switch (theme.config.language) {
      PureDesignLanguage.fluent => f2.FluentSlider(
        value: clamped,
        min: min,
        max: max,
        onChanged: select,
        focusNode: focusNode,
      ),
      // `MacosSlider.onChanged` is required and the widget has no disabled
      // state of its own, so the inert form is the library's rail with its
      // gestures taken away — borrowing Material's slider would have drawn a
      // different control wherever a caller disabled one.
      PureDesignLanguage.macos => IgnorePointer(
        ignoring: select == null,
        child: macos.MacosSlider(value: clamped, min: min, max: max, onChanged: select ?? _ignoreValue),
      ),
      // The Cupertino slider takes no focus node; a null callback is its inert
      // state.
      PureDesignLanguage.cupertino => cupertino.CupertinoSlider(value: clamped, min: min, max: max, onChanged: select),
      // forui's slider is lifted and measures a track percentage rather than
      // the spec's units, so the fraction goes in and what the thumb reports is
      // denormalised back; the library's value bubble is switched off because
      // it would announce "40%" for a value the caller reads as 40 of 0..100.
      // The field owns its focus internally, so [focusNode] is not mapped.
      PureDesignLanguage.forui => forui.FSlider(
        control: forui.FSliderControl.liftedContinuous(
          value: forui.FSliderValue(max: fraction),
          onChange: (next) => select?.call(min + next.max * span),
        ),
        enabled: select != null,
        tooltipControls: const forui.FSliderTooltipControls.disabled(),
      ),
      // glass_morphism_plus ships no slider: use Flutter's official Material
      // slider rather than a hand-painted glass track.
      PureDesignLanguage.glass => Slider(value: clamped, min: min, max: max, onChanged: select, focusNode: focusNode),
      PureDesignLanguage.neumorphic => neu.NeuSlider(value: clamped, min: min, max: max, onChanged: select),
      // fluttersdk_wind ships no slider: fall back to the official Material
      // slider.
      PureDesignLanguage.wind => Slider(value: clamped, min: min, max: max, onChanged: select, focusNode: focusNode),
      // Yaru ships no slider: the library has nothing between its chips and its
      // switches, so the official Material slider is the fallback.
      PureDesignLanguage.material ||
      PureDesignLanguage.yaru => Slider(value: clamped, min: min, max: max, onChanged: select, focusNode: focusNode),
    };
  }

  /// The callback that fills the one slot [macos.MacosSlider] insists on while
  /// the control is disabled; [IgnorePointer] keeps it from ever firing.
  static void _ignoreValue(double _) {}
}
