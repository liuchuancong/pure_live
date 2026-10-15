import 'package:flutter/widgets.dart' show Color;

import 'package:live_uikit/styling.dart' show LiveDesignLanguage, UiBrightnessMode, UiConfig, UiDensity;

import 'package:pure_live/app/theme/appearance_preferences/appearance_preferences.dart';

/// The one place that knows both the persisted [AppearancePreferences]
/// document and live_uikit's [UiConfig].
///
/// The two stay decoupled on purpose: preferences stores plain primitives and
/// registry ids (never a `live_uikit` type), so a stored document survives a
/// language or density being added, renamed or removed. These helpers are that
/// translation — the composition root loads preferences, turns them into a
/// [UiConfig] for `LiveConfigProvider`, and writes the reverse mapping back
/// whenever the config changes.

/// Builds a [UiConfig] from [appearance]; an unknown language or density id
/// falls back to the default rather than blocking start-up.
UiConfig uiConfigFromAppearance(AppearancePreferences appearance) => UiConfig(
  language: _languageById(appearance.designLanguageId),
  brightness: switch (appearance.themeMode) {
    AppThemeMode.system => UiBrightnessMode.system,
    AppThemeMode.light => UiBrightnessMode.light,
    AppThemeMode.dark => UiBrightnessMode.dark,
  },
  accent: appearance.accentColor == null ? null : Color(appearance.accentColor!),
  pureBlack: appearance.pureBlack,
  density: _byName(UiDensity.values, appearance.densityId, UiDensity.comfortable),
  fontFamily: appearance.fontFamily,
  fontScale: appearance.fontScale,
  transparency: appearance.transparency,
  reduceTransparency: appearance.reduceTransparency,
  animations: appearance.animations,
  focusOutline: appearance.focusOutline,
);

/// The persisted form of [config]; enums are stored as their `name`, so a later
/// rename or removal degrades to the default instead of failing to decode.
AppearancePreferences appearanceFromUiConfig(UiConfig config) => AppearancePreferences(
  designLanguageId: config.language.name,
  themeMode: switch (config.brightness) {
    UiBrightnessMode.system => AppThemeMode.system,
    UiBrightnessMode.light => AppThemeMode.light,
    UiBrightnessMode.dark => AppThemeMode.dark,
  },
  accentColor: config.accent?.toARGB32(),
  pureBlack: config.pureBlack,
  densityId: config.density.name,
  fontFamily: config.fontFamily,
  fontScale: config.fontScale,
  transparency: config.transparency,
  reduceTransparency: config.reduceTransparency,
  animations: config.animations,
  focusOutline: config.focusOutline,
);

/// The language an id names; empty or unknown ids take `material`, the shared
/// token base that renders every language without an adapter of its own.
LiveDesignLanguage _languageById(String id) {
  if (id.isEmpty) {
    return LiveDesignLanguage.material;
  }
  return _byName(LiveDesignLanguage.values, id, LiveDesignLanguage.material);
}

T _byName<T>(List<T> values, String name, T fallback) {
  for (final value in values) {
    if ((value as Enum).name == name) {
      return value;
    }
  }
  return fallback;
}
