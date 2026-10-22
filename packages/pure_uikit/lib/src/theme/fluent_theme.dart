import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart'
    show
        BorderRadius,
        Brightness,
        CardThemeData,
        Color,
        ColorScheme,
        Colors,
        DialogThemeData,
        RoundedRectangleBorder,
        ThemeData;
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The Fluent theme bridge: a resolved [PureTheme] translated into the theme
/// data the two host surfaces speak — fluent_ui's [fluent.FluentThemeData]
/// for the `FluentApp` host and Material's `ThemeData` for the few surfaces
/// that still paint through Material (the desktop window's clear colour, any
/// material-leaning view).
///
/// The bridge reads the four seed decisions a user actually sets — the
/// brightness, the accent (the token's `colors.primary`, grown into Fluent's
/// seven-step accent ramp), the font family and the corner radius — and
/// leaves everything else to each library's own defaults: a `FluentThemeData`
/// built from the brightness alone already carries the full WinUI resource
/// dictionary, so the bridge's job is re-branding, not re-specifying Fluent.
///
/// It never asks the config which design language is active: a non-fluent
/// value falls back to Fluent, the same decision the app's host router
/// already made, so one bridge serves every `PureDesignLanguage`. The
/// existing `FluentThemeAdapter` keeps its narrower three-slot contract for
/// the current host; this bridge is the v4 entry point the app assembles
/// themes from.
abstract final class FluentThemeBridge {
  /// Builds fluent_ui's [fluent.FluentThemeData] from the resolved [theme].
  ///
  /// The brightness picks Fluent's own resource dictionary; the accent is the
  /// token's primary ramp restated in Fluent's dialect; the font family rides
  /// the typography `apply`; the base control radius sets the focus border.
  static fluent.FluentThemeData fluentThemeData(PureTheme theme) {
    final colors = theme.colors;
    return fluent.FluentThemeData(
      brightness: theme.isDark ? Brightness.dark : Brightness.light,
      accentColor: _accent(colors.primary, hover: colors.primaryHover, active: colors.primaryActive),
      fontFamily: theme.token.type.fontFamily,
      focusTheme: fluent.FocusThemeData(borderRadius: BorderRadius.circular(theme.token.scale.radii.base)),
    );
  }

  /// Builds Material's `ThemeData` from the resolved [theme] — the Material 3
  /// scheme seeded from the same accent the Fluent side brands with, the same
  /// font family, and the large (card/dialog) radius on the two surfaces that
  /// carry one.
  static ThemeData materialThemeData(PureTheme theme) {
    final brightness = theme.isDark ? Brightness.dark : Brightness.light;
    final radius = theme.token.scale.radii.lg;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: theme.colors.primary, brightness: brightness),
      fontFamily: theme.token.type.fontFamily,
      cardTheme: CardThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius))),
      dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius))),
    );
  }

  /// Grows the Pure primary colour into Fluent's seven-step accent ramp; the
  /// hover and active steps seed the dark half, so an accent change re-brands
  /// the whole fluent subtree.
  static fluent.AccentColor _accent(Color primary, {required Color hover, required Color active}) =>
      fluent.AccentColor.swatch(<String, Color>{
        'darkest': Color.lerp(active, Colors.black, 0.25)!,
        'darker': Color.lerp(active, Colors.black, 0.10)!,
        'dark': active,
        'normal': primary,
        'light': hover,
        'lighter': Color.lerp(primary, Colors.white, 0.30)!,
        'lightest': Color.lerp(primary, Colors.white, 0.40)!,
      });
}
