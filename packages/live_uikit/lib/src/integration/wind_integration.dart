import 'package:flutter/material.dart' show MaterialColor;
import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart';

import 'package:live_uikit/src/theme/live_theme.dart';
import 'package:live_uikit/src/tokens/motion.dart';

/// The reviewed Wind UI integration.
///
/// ## What Wind is
///
/// `fluttersdk_wind` is a utility-first styling layer over Flutter's own
/// widgets: `WindTheme` plus `W`-prefixed widgets that take Tailwind-style
/// `className` strings, with responsive (`md:`), state (`hover:`) and dark
/// (`dark:`) prefixes. It is not a design language — its look is Tailwind's
/// palette and scale rendered with Flutter primitives, which is close
/// enough to Material that shipping it as a seventh language would put two
/// nearly identical options in the user's settings.
///
/// ## What this package adopts
///
/// Exactly one thing: the token bridge below. Application pages that want
/// utility-class layout can wrap a subtree in [scoped] and get Wind's
/// classes evaluated against Pure Live's palette, type scale, radii and
/// motion — so a page styled with `className: 'bg-surface rounded-lg p-4'`
/// still follows the user's design language, theme and accent, and a theme
/// switch does not leave a Tailwind-coloured island on screen.
///
/// ## What this package does not adopt, and why
///
/// * **Not as a component basis.** Wind's controls are Material primitives
///   with class-based styling; using them inside the Material language would
///   style the same control twice — once from Wind's defaults, once from the
///   design tokens — and the double styling is exactly the drift the
///   component contract exists to prevent.
/// * **Not for TV.** Wind's focus and remote-control behaviour is not
///   something this codebase has verified, and the TV acceptance criteria
///   (focus visibility, focus memory, d-pad navigation) are not met by
///   anything unverified. TV surfaces go through the focus infrastructure
///   instead.
/// * **Not as a theme owner.** `WindTheme` is installed *inside* the
///   `LiveThemeScope`, never instead of it: `LiveTheme` stays the single
///   source of truth, and this bridge derives Wind's theme from it in one
///   direction only.
abstract final class WindIntegration {
  /// Wind's theme data derived from [theme].
  ///
  /// The colour names Wind's classes use are mapped onto our semantic
  /// tokens, so `bg-surface`, `text-primary` and `ring-focus` mean the same
  /// thing inside a Wind subtree as they do in a `LiveTheme` component.
  static WindThemeData themeDataOf(LiveTheme theme) => WindThemeData(
    brightness: theme.brightness,
    colors: {
      'primary': _swatch(theme.colors.primary),
      'secondary': _swatch(theme.colors.secondary),
      'surface': _swatch(theme.colors.surface),
      'elevated': _swatch(theme.colors.surfaceElevated),
      'outline': _swatch(theme.colors.outline),
      'error': _swatch(theme.colors.error),
    },
    ringColor: theme.colors.focus,
    borderRadius: _radii(theme),
    fontSizes: _fontSizes(theme),
    fontFamilies: theme.typography.fontFamily == null ? const {} : {'sans': theme.typography.fontFamily!},
    shadows: {
      'card': _shadows(theme, theme.componentTheme.cardElevation),
      'dialog': _shadows(theme, 8),
      'focus': _shadows(theme, theme.focus.liftElevation),
    },
    transitionDurations: {
      'fast': theme.fast == Duration.zero ? LiveMotion.fast : theme.fast,
      'normal': theme.normal == Duration.zero ? LiveMotion.normal : theme.normal,
      'slow': theme.slow == Duration.zero ? LiveMotion.slow : theme.slow,
    },
  );

  /// [child] with Wind's classes resolved against [theme].
  static Widget scoped(LiveTheme theme, Widget child) => WindTheme(data: themeDataOf(theme), child: child);

  /// A Material swatch built from one colour, for Wind's palette map.
  ///
  /// Wind's classes address shades (`bg-primary-600`), so a single accent
  /// is expanded into a swatch by lightening and darkening it — the same
  /// relationship Material's own swatches have, derived from the token
  /// rather than from a second palette.
  static MaterialColor _swatch(Color color) => MaterialColor(color.toARGB32(), {
    50: _shift(color, 0.9),
    100: _shift(color, 0.8),
    200: _shift(color, 0.6),
    300: _shift(color, 0.4),
    400: _shift(color, 0.2),
    500: color,
    600: _shift(color, -0.15),
    700: _shift(color, -0.3),
    800: _shift(color, -0.45),
    900: _shift(color, -0.6),
  });

  static Color _shift(Color color, double amount) {
    if (amount == 0) {
      return color;
    }
    final target = amount < 0 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    return Color.lerp(color, target, amount.abs()) ?? color;
  }

  static Map<String, double> _radii(LiveTheme theme) {
    final geometry = theme.componentTheme;
    return {
      'sm': geometry.controlRadius,
      'DEFAULT': geometry.inputRadius,
      'md': geometry.cardRadius,
      'lg': geometry.dialogRadius,
      'xl': geometry.menuRadius,
      'full': 999,
    };
  }

  static Map<String, double> _fontSizes(LiveTheme theme) => {
    'xs': theme.typography.caption.fontSize ?? 12,
    'sm': theme.typography.bodySmall.fontSize ?? 13,
    'base': theme.typography.body.fontSize ?? 15,
    'lg': theme.typography.subtitle.fontSize ?? 15,
    'xl': theme.typography.title.fontSize ?? 18,
    '2xl': theme.typography.headline.fontSize ?? 22,
    '3xl': theme.typography.display.fontSize ?? 28,
  };

  static List<BoxShadow> _shadows(LiveTheme theme, double elevation) {
    if (elevation <= 0) {
      return const [];
    }
    final base = theme.colors.shadow;
    return [
      BoxShadow(color: base.withValues(alpha: 0.5), blurRadius: elevation * 1.5, offset: Offset(0, elevation * 0.5)),
      BoxShadow(color: base.withValues(alpha: 0.3), blurRadius: elevation * 4, offset: Offset(0, elevation * 1.5)),
    ];
  }
}
