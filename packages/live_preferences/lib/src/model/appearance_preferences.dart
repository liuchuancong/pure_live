import 'package:freezed_annotation/freezed_annotation.dart';

part 'appearance_preferences.freezed.dart';
part 'appearance_preferences.g.dart';

/// Which brightness the app follows.
enum AppThemeMode {
  /// Follow the system's light/dark setting.
  system,

  /// Always light.
  light,

  /// Always dark.
  dark,
}

/// Appearance preferences: the design language, the brightness and the
/// accent colour.
///
/// The design language is stored as its registry id (a plain string) on
/// purpose: the languages themselves are `live_uikit`'s, and a stored
/// document must not fail to load when a language is added, renamed or
/// removed — an unknown id falls back to the platform's default language
/// at resolve time, exactly like an unknown theme id did in 3.x.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class AppearancePreferences with _$AppearancePreferences {
  /// Appearance preferences with the shipping defaults.
  const factory AppearancePreferences({
    /// The design language registry id; empty means the platform's default
    /// language.
    @Default('') String designLanguageId,

    /// Which brightness the app follows.
    @Default(AppThemeMode.system) AppThemeMode themeMode,

    /// The accent colour as a 32-bit ARGB value; null means the design
    /// language's own accent.
    int? accentColor,

    /// Whether dark surfaces are drawn pure black, for OLED screens.
    @Default(false) bool pureBlack,
  }) = _AppearancePreferences;

  /// Restores appearance preferences from JSON.
  factory AppearancePreferences.fromJson(Map<String, Object?> json) => _$AppearancePreferencesFromJson(json);
}
