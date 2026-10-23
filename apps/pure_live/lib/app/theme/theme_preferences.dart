import 'package:flutter/widgets.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/theme/app_theme_mode.dart' show AppThemeMode;

/// The user's theme choices as plain primitives.
///
/// Preferences store values the theme factories understand — a mode and an
/// accent override — and nothing from the theme packages themselves, so a
/// stored document survives either package changing its types.
final class ThemePreferences {
  /// A set of preferences.
  const new({this.mode = AppThemeMode.system, this.accentOverride});

  /// Light/dark/system.
  final AppThemeMode mode;

  /// The accent the user picked, or null to use whatever the system offers.
  final Color? accentOverride;

  /// Returns a copy with the given fields replaced.
  ThemePreferences copyWith({AppThemeMode? mode, Color? accentOverride, bool clearAccentOverride = false}) =>
      ThemePreferences(
        mode: mode ?? this.mode,
        accentOverride: clearAccentOverride ? null : (accentOverride ?? this.accentOverride),
      );
}

/// The in-memory preference store.
///
/// Persistence arrives with the storage phase; when it does, this controller
/// gains a load and a write and the interface stays exactly this.
final class ThemePreferencesController extends Notifier<ThemePreferences> {
  @override
  ThemePreferences build() => const ThemePreferences();

  /// Switches the light/dark mode.
  void setMode(AppThemeMode mode) => state = state.copyWith(mode: mode);

  /// Picks the accent, or clears the override with null.
  void setAccent(Color? color) => state = state.copyWith(accentOverride: color, clearAccentOverride: color == null);
}

/// The theme preferences the shell reads.
final themePreferencesProvider = NotifierProvider<ThemePreferencesController, ThemePreferences>(
  ThemePreferencesController.new,
);
