import 'package:flutter/widgets.dart' show Brightness;
import 'package:live_uikit/styling.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Maps the core's resolved `DesignToken` into the fork's `ThemeData` (§8.1):
/// brightness and a seeded `ColorScheme` follow the accent, while the page /
/// card surfaces and the global font family follow the resolved token — so a
/// brightness, accent, surface or font change re-skins the whole Material UI
/// subtree (§8.3). `visualDensity` is deliberately left out: Material's density
/// step is not derivable from the token here, and §8.1 warns against assuming a
/// widget responds to it (§8.1).
abstract final class MaterialUiThemeBuilder {
  /// Builds the Material UI theme data for [token].
  static mu.ThemeData build(DesignToken token) {
    final brightness = token.isDark ? Brightness.dark : Brightness.light;
    return mu.ThemeData(
      brightness: brightness,
      colorScheme: mu.ColorScheme.fromSeed(seedColor: token.color.primary, brightness: brightness),
      fontFamily: token.type.fontFamily,
      scaffoldBackgroundColor: token.color.surface,
      cardColor: token.color.surfaceElevated,
    );
  }
}
