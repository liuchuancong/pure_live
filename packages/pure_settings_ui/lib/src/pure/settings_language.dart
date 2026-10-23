import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/languages/fluent_settings_language.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart' show DevicePlatform;
import 'package:pure_uikit/pure_uikit.dart';

/// The design language's settings theme: declared in its own file under
/// `languages/`.
///
/// This is a lookup, not a decision. Re-pointing the app at another design
/// language means adding a file and a line here — never a case that some
/// other language is already sitting in, which is how a shared branch turns
/// two themes into one by accident.
const Map<PureDesignLanguage, SettingsLanguage> settingsLanguages = {PureDesignLanguage.fluent: fluentSettingsLanguage};

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
/// The shipped language names upstream's Windows 11 Settings rendering; a
/// language added here names [DevicePlatform.pure] instead, whose widgets are
/// built on pure_uikit's components. That is why this package names no
/// design-language library in its `pubspec.yaml`, and why the same lookup
/// that re-skins the rest of the app re-skins a settings screen as well.
DevicePlatform devicePlatformOf(PureDesignLanguage language) => settingsLanguageOf(language).platform;

/// The style [language] states for itself.
///
/// Consulted only by the pure rendering; a language whose [devicePlatformOf] is
/// one of upstream's never reaches it unless a caller forces
/// `platform: DevicePlatform.pure`.
PureSettingsStyle pureSettingsStyleOf(PureDesignLanguage language) => settingsLanguageOf(language).style;

/// The style of the design language resolved for the subtree around [context].
PureSettingsStyle pureSettingsStyle(BuildContext context) => pureSettingsStyleOf(PureTheme.of(context).config.language);
