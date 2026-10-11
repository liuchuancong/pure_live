import 'package:flutter/foundation.dart';
import 'package:live_platform/live_platform.dart';
import 'package:live_preferences/live_preferences.dart';
import 'package:live_uikit/live_uikit.dart';

/// Maps the platform layer's facts and the user's stored preferences onto the
/// UI layer's own types.
///
/// This is the composition root's job and nobody else's: `live_preferences`
/// stores plain values (a language id, an enum, an accent integer) and must
/// not know what a design language is; `live_uikit` renders them and must not
/// know what a preference document or a platform runtime is; and
/// `live_platform` answers where things live without knowing either. The
/// mapping lives here, in one direction, where a change on any side is
/// visible in one file.
abstract final class UiConfigurationMapper {
  /// Where the UI runs, from the platform runtime's facts.
  ///
  /// A TV is only ever the platform layer's [FormFactor.tv], which is itself
  /// only ever a declaration from the app shell — never `Platform.isAndroid`.
  static LiveUiPlatform platformOf(PlatformEnvironment environment) {
    if (kIsWeb) {
      return LiveUiPlatform.web;
    }
    return switch (environment.runtime.kind) {
      PlatformKind.android =>
        environment.runtime.formFactor == FormFactor.tv ? LiveUiPlatform.androidTv : LiveUiPlatform.android,
      PlatformKind.ios => LiveUiPlatform.ios,
      PlatformKind.windows => LiveUiPlatform.windows,
      PlatformKind.macos => LiveUiPlatform.macos,
      PlatformKind.linux => LiveUiPlatform.linux,
      // The platform layer could not identify the system; Flutter's own
      // target platform is a better answer than a guess of ours.
      PlatformKind.unknown => LiveUiPlatform.resolve(isTvBuild: environment.runtime.formFactor == FormFactor.tv),
    };
  }

  /// The environment the platform and a window width imply.
  static LiveUiEnvironment environmentOf(PlatformEnvironment environment, {double width = 0}) =>
      LiveUiEnvironment.forPlatform(
        platform: platformOf(environment),
        width: width,
        supportsBlur: environment.capabilities.windowing,
      );

  /// The configuration [preferences] asks for on [platform].
  ///
  /// An unknown or empty design language id resolves to the platform's own
  /// default rather than to Material everywhere: a Linux build should look
  /// like Ubuntu the first time it starts, not after the user finds the
  /// setting.
  static LiveUiConfiguration configurationOf(Preferences preferences, {required LiveUiPlatform platform}) =>
      LiveUiConfiguration(
        designLanguage: designLanguageOf(preferences, platform: platform),
        brightness: switch (preferences.appearance.themeMode) {
          AppThemeMode.system => LiveBrightness.system,
          AppThemeMode.light => LiveBrightness.light,
          AppThemeMode.dark => LiveBrightness.dark,
        },
        accentColor: preferences.appearance.accentColor,
        pureBlack: preferences.appearance.pureBlack,
      );

  /// The design language [preferences] asks for.
  static LiveDesignLanguage designLanguageOf(Preferences preferences, {required LiveUiPlatform platform}) =>
      LiveDesignLanguage.fromId(preferences.appearance.designLanguageId) ?? defaultDesignLanguageFor(platform);

  /// The language a platform starts with, before the user chooses.
  ///
  /// Each platform's own visual language where one exists, Material
  /// everywhere else — and a TV always Material, because the other languages'
  /// focus models are not what a remote control expects.
  static LiveDesignLanguage defaultDesignLanguageFor(LiveUiPlatform platform) => switch (platform) {
    LiveUiPlatform.ios => LiveDesignLanguage.cupertino,
    LiveUiPlatform.macos => LiveDesignLanguage.macos,
    LiveUiPlatform.windows => LiveDesignLanguage.fluent,
    LiveUiPlatform.linux => LiveDesignLanguage.yaru,
    LiveUiPlatform.android || LiveUiPlatform.androidTv || LiveUiPlatform.web => LiveDesignLanguage.material,
  };

  /// The registry of every design language this build ships, with Material as
  /// the fallback for anything unregistered.
  static LiveComponentRegistry registry() => MaterialLanguage.registry.withLanguages({
    LiveDesignLanguage.cupertino: CupertinoLanguage.adapter,
    LiveDesignLanguage.fluent: FluentLanguage.adapter,
    LiveDesignLanguage.macos: MacosLanguage.adapter,
    LiveDesignLanguage.yaru: YaruLanguage.adapter,
    LiveDesignLanguage.neumorphic: NeumorphicLanguage.adapter,
  });

  /// The store the design language setting is written to.
  static Future<void> selectDesignLanguage(PreferencesService preferences, LiveDesignLanguage language) =>
      preferences.updateAppearance((appearance) => appearance.copyWith(designLanguageId: language.id));

  /// The store the brightness setting is written to.
  static Future<void> selectBrightness(PreferencesService preferences, AppThemeMode mode) =>
      preferences.updateAppearance((appearance) => appearance.copyWith(themeMode: mode));

  /// The store the accent setting is written to; null restores the design
  /// language's own accent.
  static Future<void> selectAccent(PreferencesService preferences, int? color) =>
      preferences.updateAppearance((appearance) => appearance.copyWith(accentColor: color));
}
