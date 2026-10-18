import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/languages/cupertino_settings_language.dart';
import 'package:pure_settings_ui/src/pure/languages/fluent_settings_language.dart';
import 'package:pure_settings_ui/src/pure/languages/forui_settings_language.dart';
import 'package:pure_settings_ui/src/pure/languages/glass_settings_language.dart';
import 'package:pure_settings_ui/src/pure/languages/macos_settings_language.dart';
import 'package:pure_settings_ui/src/pure/languages/material_settings_language.dart';
import 'package:pure_settings_ui/src/pure/languages/neumorphic_settings_language.dart';
import 'package:pure_settings_ui/src/pure/languages/wind_settings_language.dart';
import 'package:pure_settings_ui/src/pure/languages/yaru_settings_language.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart' show DevicePlatform;
import 'package:pure_uikit/pure_uikit.dart';

/// Every design language's settings theme: one entry per theme, each declared in
/// its own file under `languages/`.
///
/// This is a lookup, not a decision. Adding a design language means adding a
/// file and a line here — never a case that some other language is already
/// sitting in, which is how a shared branch turns two themes into one by
/// accident.
const Map<PureDesignLanguage, SettingsLanguage> settingsLanguages = {
  PureDesignLanguage.material: materialSettingsLanguage,
  PureDesignLanguage.cupertino: cupertinoSettingsLanguage,
  PureDesignLanguage.macos: macosSettingsLanguage,
  PureDesignLanguage.fluent: fluentSettingsLanguage,
  PureDesignLanguage.yaru: yaruSettingsLanguage,
  PureDesignLanguage.forui: foruiSettingsLanguage,
  PureDesignLanguage.glass: glassSettingsLanguage,
  PureDesignLanguage.neumorphic: neumorphicSettingsLanguage,
  PureDesignLanguage.wind: windSettingsLanguage,
};

/// The theme of [language].
SettingsLanguage settingsLanguageOf(PureDesignLanguage language) {
  final theme = settingsLanguages[language];
  if (theme == null) {
    throw StateError(
      'No settings theme declares ${language.name}. Add '
      'languages/${language.name}_settings_language.dart and list it in '
      'settingsLanguages.',
    );
  }
  return theme;
}

/// The settings style key [language] resolves to.
///
/// Five languages borrow a rendering upstream already drew — Android 16 cards,
/// iOS 26 grouped cards, macOS 26 System Settings, Windows 11 Settings and
/// GNOME's boxed lists — and each names which one in its own file. The rest
/// name [DevicePlatform.pure], whose widgets are built on pure_uikit's
/// components, so forui's, glass's, flutter_neumorphic_ui_kit's and
/// fluttersdk_wind's real widgets draw them according to whichever language is
/// active. That is why this package names no design-language library in its
/// `pubspec.yaml`, and why the same nine-value dispatch that re-skins the rest
/// of the app re-skins a settings screen as well.
DevicePlatform devicePlatformOf(PureDesignLanguage language) => settingsLanguageOf(language).platform;

/// The style [language] states for itself.
///
/// Consulted only by the pure rendering; a language whose [devicePlatformOf] is
/// one of upstream's never reaches it unless a caller forces
/// `platform: DevicePlatform.pure`.
PureSettingsStyle pureSettingsStyleOf(PureDesignLanguage language) => settingsLanguageOf(language).style;

/// The style of the design language resolved for the subtree around [context].
PureSettingsStyle pureSettingsStyle(BuildContext context) => pureSettingsStyleOf(PureTheme.of(context).config.language);
