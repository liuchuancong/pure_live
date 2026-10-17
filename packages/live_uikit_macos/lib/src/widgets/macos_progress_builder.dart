import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a macOS progress indicator from a [LanguageProgressSpec] (§9 Progress).
///
/// Both forms are the library's own widgets, chosen by the spec:
/// [LanguageProgressSpec.value] non-null is `ProgressBar` — macOS's linear
/// determinate bar, whose value is a percentage, so the 0..1 fraction is scaled —
/// and a null value is `ProgressCircle`, which is what macOS itself uses for work
/// of unknown length. `ProgressBar.value` is required and non-null, so a spinner
/// has no bar form to be faked into.
///
/// [LanguageProgressSpec.height] is the track thickness and maps to the bar's own
/// height; a spinner has no track, so it keeps the library's radius there.
/// [LanguageProgressSpec.showLabel] has no slot on either widget, and this builder
/// does not overlay a hand-built percentage on the bar, so the label is not drawn
/// in this language at all (§15).
abstract final class MacosProgressBuilder {
  /// Builds the indicator for [spec].
  static Widget build(BuildContext context, LanguageProgressSpec spec) {
    final theme = LiveTheme.of(context);
    final value = spec.value;
    if (value == null) {
      // The spinner form the library has takes no colour of its own — only a
      // radius — so neither `height` nor `barColor` has a slot in this branch.
      return const macos.ProgressCircle();
    }
    return macos.ProgressBar(
      value: (value * 100).clamp(0.0, 100.0),
      height: spec.height,
      trackColor: spec.barColor ?? theme.colors.primary,
      backgroundColor: theme.colors.fillSecondary,
    );
  }
}
