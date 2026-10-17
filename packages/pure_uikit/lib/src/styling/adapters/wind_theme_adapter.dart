import 'package:flutter/material.dart' show Brightness, Color, HSLColor, MaterialColor;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;

import 'package:pure_uikit/src/styling/adapters/pure_theme_adapter.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// Maps the resolved theme onto Wind's [wind.WindThemeData]: the brightness
/// follows the token, the accent grows a real tonal ramp (Wind reads shades
/// off it for hovers, presses and disabled states — a flat swatch would
/// flatten every interaction state to one colour), and a configured global
/// font family overrides Wind's `sans` scale.
///
/// Mapping notes: Wind keeps the rest of its colour/space/typography maps at
/// their defaults rather than being half-mapped; `syncWithSystem` is forced
/// false because the core owns the brightness decision.
final class WindThemeAdapter implements PureThemeAdapter<wind.WindThemeData> {
  /// The Wind adapter.
  const new();

  @override
  wind.WindThemeData resolve(PureTheme theme) {
    final token = theme.token;
    final family = token.type.fontFamily;
    return wind.WindThemeData(
      brightness: token.isDark ? Brightness.dark : Brightness.light,
      syncWithSystem: false,
      colors: {'primary': _tonalSwatch(token.color.primary)},
      fontFamilies: family == null ? null : {'sans': family},
    );
  }

  MaterialColor _tonalSwatch(Color seed) {
    final hsl = HSLColor.fromColor(seed);
    Color step(double delta) =>
        hsl.withLightness((hsl.lightness + delta).clamp(0.05, 0.95)).toColor();
    return MaterialColor(
      seed.toARGB32(),
      <int, Color>{
        50: step(0.36),
        100: step(0.28),
        200: step(0.20),
        300: step(0.12),
        400: step(0.05),
        500: seed,
        600: step(-0.06),
        700: step(-0.13),
        800: step(-0.21),
        900: step(-0.30),
      },
    );
  }
}
