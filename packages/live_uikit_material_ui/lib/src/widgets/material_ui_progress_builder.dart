import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a Material UI linear progress indicator from a [LanguageProgressSpec]
/// (§9), tinting the fill and track from the theme (or a `barColor` override).
abstract final class MaterialUiProgressBuilder {
  /// Builds the progress bar for [spec].
  static Widget build(BuildContext context, LanguageProgressSpec spec) {
    final theme = LiveTheme.of(context);
    return mu.LinearProgressIndicator(
      value: spec.value,
      minHeight: spec.height,
      color: spec.barColor ?? theme.colors.primary,
      backgroundColor: theme.colors.fillSecondary,
    );
  }
}
