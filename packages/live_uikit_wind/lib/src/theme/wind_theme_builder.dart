import 'package:flutter/material.dart' show Brightness, Color, MaterialColor;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/styling.dart';

/// Maps the core's resolved `DesignToken` into `WindThemeData` (§8.1): the
/// brightness follows the token, the accent overrides Wind's `primary` colour,
/// and a configured global font family overrides Wind's `sans` scale — so a
/// brightness, accent or font change re-skins the Wind subtree and the data is
/// rebuilt when the token changes (§8.3). Wind keeps the rest of its Tailwind
/// colour/space/typography maps at their defaults, so those keys are left
/// untouched rather than half-mapped (§8.1 "map only supported").
///
/// `syncWithSystem` is forced false: the core owns the brightness decision (from
/// `UiConfig.brightness`), so Wind must not second-guess it against the platform
/// setting (§8.3 runtime updates).
abstract final class WindThemeBuilder {
  /// Builds the Wind theme data for [token].
  static wind.WindThemeData build(DesignToken token) {
    final family = token.type.fontFamily;
    // Wind's `colors` scale is typed `MaterialColor`; the token exposes a single
    // accent, so it is expanded into a flat swatch (every shade = the accent)
    // rather than inventing tonal steps Wind would then render with (§8.1).
    final argb = token.color.primary.toARGB32();
    final accent = MaterialColor(
      argb,
      <int, Color>{for (final shade in const [50, 100, 200, 300, 400, 500, 600, 700, 800, 900]) shade: Color(argb)},
    );
    return wind.WindThemeData(
      brightness: token.isDark ? Brightness.dark : Brightness.light,
      syncWithSystem: false,
      colors: {'primary': accent},
      fontFamilies: family == null ? null : {'sans': family},
    );
  }
}
