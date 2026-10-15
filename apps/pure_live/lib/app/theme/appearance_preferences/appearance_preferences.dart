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

/// The user's appearance choices, as persisted.
///
/// Every field is a primitive or a registry id — never a `live_uikit` type.
/// The design languages, densities and brightness modes belong to the UI
/// library, so a stored document must survive one being added, renamed or
/// removed; `ui_configuration_mapper.dart` resolves an unknown id to the
/// default instead of failing to load.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class AppearancePreferences with _$AppearancePreferences {
  /// Appearance preferences with the shipping defaults.
  const factory AppearancePreferences({
    /// The design language registry id; empty means the platform's default.
    @Default('') String designLanguageId,

    /// Which brightness the app follows.
    @Default(AppThemeMode.system) AppThemeMode themeMode,

    /// The accent colour as a 32-bit ARGB value; null means the design
    /// language's own accent.
    int? accentColor,

    /// Whether dark surfaces are drawn pure black, for OLED screens.
    @Default(false) bool pureBlack,

    /// The layout density registry id; empty means the default density.
    @Default('') String densityId,

    /// A global multiplier on every font size (the "enlarge text" control).
    @Default(1.0) double fontScale,

    /// A global font family override; null keeps the platform default.
    String? fontFamily,

    /// A multiplier (0..1) on glass/scrim opacity.
    @Default(1.0) double transparency,

    /// Accessibility: force surfaces opaque and disable backdrop blur.
    @Default(false) bool reduceTransparency,

    /// Whether motion runs.
    @Default(true) bool animations,

    /// Whether focused controls draw a visible outline.
    @Default(true) bool focusOutline,
  }) = _AppearancePreferences;

  /// Restores appearance preferences from JSON.
  factory AppearancePreferences.fromJson(Map<String, Object?> json) => _$AppearancePreferencesFromJson(json);
}
