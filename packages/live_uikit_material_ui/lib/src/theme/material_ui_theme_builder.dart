import 'package:flutter/widgets.dart' show Brightness;
import 'package:live_uikit/styling.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Maps the core's resolved `DesignToken` into the fork's `ThemeData` (§8.1):
/// brightness and a seeded [mu.ColorScheme] both follow the token.
abstract final class MaterialUiThemeBuilder {
  /// Builds the Material UI theme data for [token].
  static mu.ThemeData build(DesignToken token) {
    final brightness = token.isDark ? Brightness.dark : Brightness.light;
    return mu.ThemeData(
      brightness: brightness,
      colorScheme: mu.ColorScheme.fromSeed(seedColor: token.color.primary, brightness: brightness),
    );
  }
}
