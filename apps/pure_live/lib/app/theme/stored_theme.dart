import 'package:desen_ui/desen_ui.dart';

import 'package:pure_live/app/theme/system_accent_color.dart' show readSystemAccentColor;
import 'package:pure_live/app/theme/theme_persistence.dart';
import 'package:pure_live/app/theme/theme_settings.dart';

/// The theme settings as stored: the root's boot seed, and the room
/// windows' — whose prefs are the main engine's snapshot, so the same
/// reads answer both.
AppThemeSettings readStoredAppThemeSettings() {
  final settings = AppThemeSettings((b) {
    final accent = readSystemAccentColor();
    if (accent != null) b.seed = DsSeed.color(accent);
    final storedSeed = ThemePersistence.readSeed();
    if (storedSeed != null) {
      var named = false;
      for (final (name, seed) in kNamedSeeds) {
        if (name == storedSeed) {
          b.seed = seed;
          named = true;
        }
      }
      if (!named) {
        final custom = ThemePersistence.parseSeedColor(storedSeed);
        if (custom != null) b.seed = DsSeed.color(custom);
      }
    }
    final mode = ThemePersistence.readMode();
    if (mode != null) b.mode = mode;
    final corners = ThemePersistence.readCorners();
    if (corners != null) b.cornerStyle = corners;
    final contrast = ThemePersistence.readContrast();
    if (contrast != null) b.contrast = contrast;
    final selection = ThemePersistence.readSelectionStyle();
    if (selection != null) b.selectionStyle = selection;
    final autoClash = ThemePersistence.readAutoClashRule();
    if (autoClash != null) b.autoClashRule = autoClash;
    b.density = ThemePersistence.readDensity();
  });
  final font = ThemePersistence.readFont();
  if (font != null) return settings.rebuild((b) => b..fontFamily = font);
  return settings;
}

/// The pinned locale's stored code ('zh-CN', 'en'), or null to follow the
/// system. The caller applies it to `LocaleSettings` itself.
String? readStoredLocaleCode() => ThemePersistence.readLocale();
