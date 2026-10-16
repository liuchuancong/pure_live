import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a Fluent progress bar from a [LanguageProgressSpec] (§9 Progress).
///
/// Fluent's bar is a percentage, so `value` is scaled to 0..100 while a null
/// value stays null and keeps the fork's own indeterminate animation (§9).
/// `height` maps to the fork's `strokeWidth` and `barColor` overrides the primary
/// tint; `showLabel` has no slot on `ProgressBar` and is dropped rather than
/// overlaid with a hand-built label (§15).
abstract final class FluentProgressBuilder {
  /// Builds the progress bar for [spec].
  static Widget build(BuildContext context, LanguageProgressSpec spec) {
    final theme = LiveTheme.of(context);
    return fluent.ProgressBar(
      value: spec.value == null ? null : spec.value! * 100,
      strokeWidth: spec.height,
      activeColor: spec.barColor ?? theme.colors.primary,
      backgroundColor: theme.colors.fillSecondary,
    );
  }
}
