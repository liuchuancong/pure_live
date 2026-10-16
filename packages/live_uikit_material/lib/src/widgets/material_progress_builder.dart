import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a Material UI linear progress indicator from a [LanguageProgressSpec]
/// (§9), tinting the fill and track from the theme (or a `barColor` override).
///
/// `spec.showLabel` is a token-renderer affordance: the fork's indicator paints a
/// bar only, and §9 forbids overlaying a hand-built percentage widget. A Material
/// UI progress bar therefore never shows the trailing label — the degradation is
/// documented here rather than silently approximated (§15).
abstract final class MaterialProgressBuilder {
  /// Builds the progress bar for [spec].
  static Widget build(BuildContext context, LanguageProgressSpec spec) {
    final theme = LiveTheme.of(context);
    return mu.LinearProgressIndicator(
      // A null value stays null: the fork renders its own indeterminate
      // animation, which is the contract, not a determinate bar at 0.
      value: spec.value,
      minHeight: spec.height,
      color: spec.barColor ?? theme.colors.primary,
      backgroundColor: theme.colors.fillSecondary,
    );
  }
}
