import 'dart:ui' show Brightness;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/theme/app_theme_factory.dart' show buildDsTheme;
import 'package:pure_live/app/theme/system_accent_color.dart' show readSystemAccentColor;
import 'package:pure_live/app/theme/theme_preferences.dart' show themePreferencesProvider;

/// The accent in force: the user's override, else the system's, else the
/// theme factory's own seed.
final resolvedAccentProvider = Provider<Color?>(
  (ref) => ref.watch(themePreferencesProvider).accentOverride ?? readSystemAccentColor(),
);

/// The light/dark switch the theme factory is seeded with.
final themeModeProvider = Provider<DsThemeMode>((ref) => ref.watch(themePreferencesProvider).mode.dsThemeMode);

/// The token set for one brightness; the app builds both at start-up and
/// `DsApp` picks per frame, so a system switch never mixes the two.
//
// ignore: specify_nonobvious_property_types
final dsThemeProvider = Provider.family<DsThemeData, Brightness>(
  (ref, brightness) => buildDsTheme(brightness: brightness, accent: ref.watch(resolvedAccentProvider)),
);
