import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';

/// Builds a ForUI toast surface from a [LanguageToastSpec] (§9 Toast).
///
/// `FToast` is the library's own message body and — unlike the rest of forui's overlay
/// widgets — it is a plain `StatelessWidget`: it paints its decoration, its padding and
/// its icon row and asks for nothing from an ancestor. What needs an overlay is the
/// *toaster* around it (`FToaster`, `showFToast` and their controller), and that is the
/// core's: the placement, the entrance animation and the removal timer live in
/// `LiveToast.show`, which is why the spec carries a duration the surface never reads.
/// So the library's message body is returned directly rather than composed.
///
/// The severity is forui's own two-step choice — `destructive` for a warning or an error,
/// `primary` otherwise — while the glyph's colour stays the token's, because the token
/// decides that this app's `warning` looks like its `warning` in every language
/// (§9/ADR 0004). It is written through the style delta on the library's icon style, not
/// by hand-tinting a widget the library already themes.
abstract final class ForuiToastBuilder {
  /// Builds the toast surface for [spec].
  static Widget build(BuildContext context, LanguageToastSpec spec) {
    final theme = LiveTheme.of(context);
    final accent =
        spec.accent ??
        switch (spec.type) {
          LiveToastType.info => theme.colors.info,
          LiveToastType.success => theme.colors.success,
          LiveToastType.warning => theme.colors.warning,
          LiveToastType.error => theme.colors.error,
        };

    return forui.FToast(
      variant: switch (spec.type) {
        LiveToastType.warning || LiveToastType.error => forui.FToastVariant.destructive,
        LiveToastType.info || LiveToastType.success => forui.FToastVariant.primary,
      },
      icon: Icon(spec.icon ?? _glyph(spec.type)),
      title: Text(spec.message),
      style: forui.FToastStyleDelta.delta(iconStyle: forui.IconThemeDataDelta.delta(color: accent)),
    );
  }

  static IconData _glyph(LiveToastType type) => switch (type) {
    LiveToastType.info => Icons.info_outline,
    LiveToastType.success => Icons.check_circle_outline,
    LiveToastType.warning => Icons.warning_amber_rounded,
    LiveToastType.error => Icons.error_outline,
  };
}
