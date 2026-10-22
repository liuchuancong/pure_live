import 'dart:io' show Platform;

import 'package:flutter/widgets.dart' show Color;
import 'package:live_shell_desktop/live_shell_desktop.dart' show readWindowsAccentColor;
import 'package:pure_live/system/theme/appearance_preferences/appearance_preferences.dart';
import 'package:pure_live/system/theme/font_recommendations.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The one place that knows both the persisted [AppearancePreferences]
/// document and pure_uikit's [UiConfig].
///
/// The two stay decoupled on purpose: preferences stores plain primitives and
/// registry ids (never a `pure_uikit` type), so a stored document survives a
/// language or density being added, renamed or removed. These helpers are that
/// translation — the composition root loads preferences, turns them into a
/// [UiConfig] for `PureConfigProvider`, and writes the reverse mapping back
/// whenever the config changes.

/// Builds a [UiConfig] from [appearance]; an unknown language or density id
/// falls back to the default rather than blocking start-up.
///
/// The stored family goes through [resolveThemeFont]: `theme` becomes the
/// language's recommendation, [themeFontAvailable] says whether that family is
/// actually on disk and registered (the caller's font library), and anything
/// else — the system default, an explicit family — passes through. Without a
/// resolver every recommendation counts as available, which is what the
/// window-chrome path wants: it reads the config for colours, and an
/// unregistered family name still renders in the system font.
UiConfig uiConfigFromAppearance(
  AppearancePreferences appearance, {
  Color? dynamicAccent,
  bool Function(String id)? themeFontAvailable,
}) {
  final language = designLanguageOrDefault(appearance.designLanguageId);
  return UiConfig(
    language: language,
    brightness: switch (appearance.themeMode) {
      AppThemeMode.system => UiBrightnessMode.system,
      AppThemeMode.light => UiBrightnessMode.light,
      AppThemeMode.dark => UiBrightnessMode.dark,
    },
    // Fluent's shipped accent is the machine's own: an install left at its
    // defaults reads the accent Windows already chose, the way the system's
    // Fluent apps do. A stored choice — any other language — keeps its own
    // answer, and a machine without a readable accent keeps the language's
    // seed default.
    // 动态取色 outranks a stored accent when the system has one to give.
    accent: switch ((dynamicAccent, appearance.accentColor)) {
      (final Color fromSystem?, _) => fromSystem,
      (_, final int stored) => Color(stored),
      (_, null) when language == PureDesignLanguage.fluent && Platform.isWindows => readWindowsAccentColor(),
      _ => null,
    },
    pureBlack: appearance.pureBlack,
    density: _byName(UiDensity.values, appearance.densityId, UiDensity.comfortable),
    fontFamily: resolveThemeFont(appearance.fontFamily, language, isDownloaded: themeFontAvailable ?? (_) => true),
    fontScale: appearance.fontScale,
    bodySmallSize: appearance.bodySmallSize,
    bodySize: appearance.bodySize,
    subtitleSize: appearance.subtitleSize,
    titleSize: appearance.titleSize,
    headlineSize: appearance.headlineSize,
    transparency: appearance.transparency,
    reduceTransparency: appearance.reduceTransparency,
    animations: appearance.animations,
    focusOutline: appearance.focusOutline,
  );
}

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
  fontFamily: config.fontFamily ?? kThemeFontFamily,
  fontScale: config.fontScale,
  transparency: config.transparency,
  reduceTransparency: config.reduceTransparency,
  animations: config.animations,
  focusOutline: config.focusOutline,
);

/// The skin this build ships on when the user has not chosen: fluent, a
/// fully registered third-party language. The default only decides which
/// host answers first — every language renders its own whole contract, and a
/// stored id that names a language this build does not register is a fault the
/// startup resolver reports rather than a look to settle for.
///
/// One product value, not a per-platform guess: §6.3 of the v4 spec asks for
/// the default to be stated, so a Linux and an Android first run agree.
const PureDesignLanguage defaultDesignLanguage = PureDesignLanguage.fluent;

/// Ids that named something the enum no longer has.
///
/// The two Material- and iOS-shaped languages used to be spelled `materialUi`
/// and `cupertinoUi`; both ids are still what a document written before the
/// rename holds, and an unknown id would drop the viewer onto the build's
/// default skin — a language change they never asked for. The base, which that
/// older enum called `material`, is now `token`, and a stored `material` names
/// the Material library it visually matched all along.
const Map<String, PureDesignLanguage> _retiredIds = {
  'materialUi': PureDesignLanguage.material,
  'cupertinoUi': PureDesignLanguage.cupertino,
};

/// The language a stored id names, null when it names none.
///
/// Null covers both halves of §6.3's first two rows — nothing stored (an empty
/// id) and something stored that this build cannot read — and the startup
/// resolver is what turns each into its own origin, so the difference the user
/// needs reported survives the decode instead of collapsing into a default.
PureDesignLanguage? designLanguageByStoredId(String? id) {
  if (id == null || id.isEmpty) {
    return null;
  }
  final retired = _retiredIds[id];
  if (retired != null) {
    return retired;
  }
  for (final language in PureDesignLanguage.values) {
    if (language.name == id) {
      return language;
    }
  }
  return null;
}

/// The language an id names, or the product default when it names none.
///
/// Empty and unknown ids both land here; [designLanguageByStoredId] is the
/// version that keeps the two apart, which is what the startup resolver needs
/// to report why a language was not the one the user picked.
PureDesignLanguage designLanguageOrDefault(String? id) => designLanguageByStoredId(id) ?? defaultDesignLanguage;

T _byName<T>(List<T> values, String name, T fallback) {
  for (final value in values) {
    if ((value as Enum).name == name) {
      return value;
    }
  }
  return fallback;
}
