import 'package:flutter/material.dart';

import 'package:pure_uikit/src/styling/adapters/pure_theme_adapter.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// Maps the resolved theme onto Material's [ThemeData]: a seeded colour
/// scheme follows the accent, while the page and card surfaces and the
/// global font family follow the resolved token.
///
/// The text-field shape is set here rather than at the call site on purpose:
/// Material's own default decoration is the *underline* variant, and the M3
/// answer is an outlined box whose border states the decorator resolves —
/// focused 2px, hovered and disabled at their own weights. A widget that passes
/// five flat `OutlineInputBorder`s replaces that resolution with a 1px line in
/// every state; a theme gives the shape once and leaves the states to the SDK.
///
/// Mapping notes: `spacing`, `radius` and `density` are Material-native
/// concepts the token pipeline expresses through `controlHeight`/`sizeStep`
/// (the compact algorithm), not through this adapter; Material's own
/// defaults answer where the tokens are silent.
final class MaterialThemeAdapter implements PureThemeAdapter<ThemeData> {
  /// The Material adapter.
  const new();

  @override
  ThemeData resolve(PureTheme theme) {
    final token = theme.token;
    final brightness = token.isDark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(seedColor: token.color.primary, brightness: brightness);
    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: token.type.fontFamily,
      scaffoldBackgroundColor: token.color.surface,
      cardColor: token.color.surfaceElevated,
      inputDecorationTheme: InputDecorationTheme(
        // The library's own 4-point outline radius, not the token's control
        // radius: this is the M3 field, and its corner is part of that identity.
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: scheme.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder: OutlineInputBorder(borderSide: BorderSide(color: scheme.error, width: 2)),
        disabledBorder: OutlineInputBorder(borderSide: BorderSide(color: scheme.onSurface)),
      ),
    );
  }
}
