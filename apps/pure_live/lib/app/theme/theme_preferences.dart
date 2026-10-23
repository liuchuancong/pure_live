import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/app_providers.dart' show appearanceStoreProvider;
import 'package:pure_live/app/configuration/app_preferences.dart' show AppearanceDocument, accentColorOf;
import 'package:pure_live/app/localization/locale_preferences.dart' show localePreferencesProvider;
import 'package:pure_live/app/theme/app_theme_mode.dart' show AppThemeMode;

/// The user's theme choices, backed by the persisted appearance document.
///
/// The controller is the document's write face: the boot loads the store,
/// this reads it into widgets, and every change writes the whole document
/// back (theme and language travel together in one file).
final class ThemePreferencesController extends Notifier<ThemePreferences> {
  @override
  ThemePreferences build() {
    final stored = ref.watch(appearanceStoreProvider).value;
    return ThemePreferences(mode: stored.themeMode, accentOverride: accentColorOf(stored));
  }

  /// Switches the light/dark mode.
  void setMode(AppThemeMode mode) {
    state = state.copyWith(mode: mode);
    _persist();
  }

  /// Picks the accent, or clears the override with null.
  void setAccent(Color? color) {
    state = state.copyWith(accentOverride: color, clearAccentOverride: color == null);
    _persist();
  }

  void _persist() {
    final document = AppearanceDocument(
      themeMode: state.mode,
      accentArgb: state.accentOverride?.toARGB32(),
      locale: ref.read(localePreferencesProvider.notifier).locale,
    );
    unawaited(ref.read(appearanceStoreProvider).save(document));
  }
}

/// The theme preferences the shell reads.
final themePreferencesProvider = NotifierProvider<ThemePreferencesController, ThemePreferences>(
  ThemePreferencesController.new,
);

/// The user's theme choices as the widgets see them.
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
