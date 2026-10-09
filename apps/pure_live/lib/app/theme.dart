// Module: lib/app/theme.dart
// Purpose: Material 3 light and dark themes shared by every screen.
// Author: liuchuancong
// Created: 2026-10-09

import 'package:flutter/material.dart';

/// Brand seed the color schemes are derived from. A user-facing theme picker
/// replaces this constant when the settings wave lands.
const Color pureLiveSeedColor = Color(0xFF6A5AE0);

/// The font family declared in pubspec.yaml; falls back to the platform default
/// on systems where the bundled MiSans fails to load.
const String pureLiveFontFamily = 'MI_Sans_Regular';

/// Application themes. Screens must read colors from [Theme.of] instead of
/// hard-coding values so a future theme plugin can swap the scheme.
abstract final class PureLiveTheme {
  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(seedColor: pureLiveSeedColor, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: pureLiveFontFamily,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(backgroundColor: colorScheme.surface, centerTitle: false),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: colorScheme.surfaceContainer),
      navigationRailTheme: NavigationRailThemeData(backgroundColor: colorScheme.surface),
    );
  }
}
