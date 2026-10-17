import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Neumorphic progress bar from a [LanguageProgressSpec]
/// (§9 Progress).
///
/// **Mapped.** `neu.NeuProgressBar` is the library's own linear bar and already
/// draws exactly the Neumorphic reading of progress: a recessed trough
/// ([neu.NeuShape.pressed]) with an elevated dome for the fill
/// ([neu.NeuShape.convex]) at the theme's accent. Nothing is composed here —
/// [LanguageProgressSpec.value] goes to `value` (clamped, because the widget
/// asserts the range) and [LanguageProgressSpec.barColor] to `progressColor`,
/// while [LanguageProgressSpec.height] sizes the track.
///
/// [LanguageProgressSpec.showLabel] has no counterpart — the library's bar carries
/// no text — so the percentage is appended beside the bar in the token's caption
/// role, and a label asked for on an indeterminate bar is dropped rather than
/// invented. A null `value` is the library's own
/// pulse, which repeats until the widget leaves the tree; the core's contract
/// asks no timer of the language, so nothing here disposes it.
abstract final class NeumorphicProgressBuilder {
  /// Builds the progress bar for [spec].
  static Widget build(BuildContext context, LanguageProgressSpec spec) {
    final theme = LiveTheme.of(context);
    final surface = neu.NeuTheme.of(context);
    final value = spec.value;
    final bar = neu.NeuProgressBar(
      value: value?.clamp(0.0, 1.0),
      height: spec.height,
      progressColor: spec.barColor ?? surface.accentColor,
      trackColor: surface.baseColor,
    );

    if (!spec.showLabel || value == null) {
      return bar;
    }
    return Row(
      children: [
        Expanded(child: bar),
        SizedBox(width: theme.token.scale.sizes.sm),
        Text(
          '${(value.clamp(0.0, 1.0) * 100).round()}%',
          style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
        ),
      ],
    );
  }
}
