import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a Material UI toast surface from a [LanguageToastSpec] (§9 Toast).
///
/// Only the surface is built here: the overlay it floats in, the fade and the
/// removal timer stay in the core's `LiveToast.show`, which is why the spec
/// carries no duration. That is also why this is a `mu.Material` card rather than
/// a `mu.SnackBar` — the fork's bar reads `widget.animation!` in `initState` and
/// is only ever built by a `ScaffoldMessenger` that owns that animation, so a
/// SnackBar handed to a caller-owned overlay throws. The card takes its colour,
/// elevation, shape and text role from the fork's own `SnackBarThemeData`, which
/// is where Material keeps those decisions, so the surface is still the library's
/// rather than the shared renderer's.
///
/// The status colour is the token's, because the token decides that `warning`
/// looks like this app's `warning` in every language; the glyph is Material's own.
abstract final class MaterialToastBuilder {
  /// Builds the toast surface for [spec].
  static Widget build(BuildContext context, LanguageToastSpec spec) {
    final theme = LiveTheme.of(context);
    final material = mu.Theme.of(context);
    final bar = material.snackBarTheme;
    final accent =
        spec.accent ??
        switch (spec.type) {
          LiveToastType.info => theme.colors.info,
          LiveToastType.success => theme.colors.success,
          LiveToastType.warning => theme.colors.warning,
          LiveToastType.error => theme.colors.error,
        };
    final body = theme.text.body.merge(bar.contentTextStyle).copyWith(color: theme.colors.text);

    return mu.Material(
      type: mu.MaterialType.card,
      color: bar.backgroundColor ?? theme.colors.bgElevated,
      elevation: bar.elevation ?? 6,
      shape: bar.shape,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.md, vertical: theme.token.scale.sizes.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon ?? _glyph(spec.type), color: accent, size: body.fontSize),
            SizedBox(width: theme.token.scale.sizes.sm),
            Flexible(child: Text(spec.message, style: body)),
          ],
        ),
      ),
    );
  }

  static IconData _glyph(LiveToastType type) => switch (type) {
    LiveToastType.info => Icons.info_outline,
    LiveToastType.success => Icons.check_circle_outline,
    LiveToastType.warning => Icons.warning_amber_rounded,
    LiveToastType.error => Icons.error_outline,
  };
}
