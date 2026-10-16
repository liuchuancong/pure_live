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

/// The skin this build ships on when the user has not chosen: fluent, a
/// fully registered third-party language. The default only decides which
/// adapter answers first — the shared token base still renders anything a
/// language does not implement, and a user who explicitly picked the base keeps
/// it, since their stored id names it exactly.
const LiveDesignLanguage _defaultLanguage = LiveDesignLanguage.fluent;

/// Ids that named something the enum no longer has.
///
/// The two Material- and iOS-shaped languages used to be spelled `materialUi`
/// and `cupertinoUi`; both ids are still what a document written before the
/// rename holds, and an unknown id would drop the viewer onto the build's
/// default skin — a language change they never asked for. The base, which that
/// older enum called `material`, is now `token`, and a stored `material` names
/// the Material library it visually matched all along.
const Map<String, LiveDesignLanguage> _retiredIds = {
  'materialUi': LiveDesignLanguage.material,
  'cupertinoUi': LiveDesignLanguage.cupertino,
};

/// The language an id names; empty or unknown ids take the build's default
/// skin ([_defaultLanguage]).
LiveDesignLanguage _languageById(String id) {
  if (id.isEmpty) {
    return _defaultLanguage;
  }
  final retired = _retiredIds[id];
  if (retired != null) {
    return retired;
  }
  return _byName(LiveDesignLanguage.values, id, _defaultLanguage);
}

T _byName<T>(List<T> values, String name, T fallback) {
  for (final value in values) {
    if ((value as Enum).name == name) {
      return value;
    }
  }
  return fallback;
}
