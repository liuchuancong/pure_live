import 'package:flutter/material.dart';

import 'package:pure_uikit/src/styling/adapters/pure_theme_adapter.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// Maps the resolved theme onto Material's [ThemeData]: a seeded colour
/// scheme follows the accent, while the page and card surfaces and the
/// global font family follow the resolved token.
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
    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(seedColor: token.color.primary, brightness: brightness),
      fontFamily: token.type.fontFamily,
      scaffoldBackgroundColor: token.color.surface,
      cardColor: token.color.surfaceElevated,
    );
  }
}
