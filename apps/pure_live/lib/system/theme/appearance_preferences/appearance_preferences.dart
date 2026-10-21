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

/// What the app-wide wallpaper layer paints behind the pages.
enum WallpaperKind {
  /// No wallpaper: the themed surfaces show.
  none,

  /// One flat colour.
  solid,

  /// A linear gradient from the built-in catalog.
  gradient,

  /// A picture on the device.
  image,
}

/// The user's appearance choices, as persisted.
///
/// Every field is a primitive or a registry id — never a `pure_uikit` type.
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
    /// The design language registry id; empty means the build's default
    /// skin (fluent), which `ui_configuration_mapper.dart` resolves.
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

    /// What the wallpaper layer paints behind the pages.
    @Default(WallpaperKind.none) WallpaperKind wallpaperKind,

    /// The solid wallpaper colour as a 32-bit ARGB value; read when
    /// [WallpaperKind.solid].
    int? wallpaperColor,

    /// The gradient stops as 32-bit ARGB values, in order; two or more when
    /// [WallpaperKind.gradient]. Stored as colours rather than a catalog id,
    /// so a preset being renamed or removed never breaks a stored choice.
    @Default(<int>[]) List<int> wallpaperGradientColors,

    /// The gradient direction as a CSS angle (0 points up, clockwise
    /// positive); the wallpaper feature converts it to alignments.
    @Default(0) int wallpaperGradientAngle,

    /// The gradient stop positions, aligned with
    /// [wallpaperGradientColors]; empty spaces them evenly.
    @Default(<double>[]) List<double> wallpaperGradientStops,

    /// The wallpaper picture's absolute path; read when
    /// [WallpaperKind.image]. A path that no longer exists degrades the
    /// wallpaper to none at resolve time.
    @Default('') String wallpaperImagePath,

    /// How the wallpaper picture fills the surface, as a `BoxFit` name
    /// (`cover`, `contain` or `fill`); anything else resolves to cover.
    @Default('cover') String wallpaperFit,

    /// The Gaussian blur over the wallpaper picture, 0..20.
    @Default(0.0) double wallpaperBlur,

    /// How strongly the wallpaper picture is dimmed for legibility, 0..1.
    @Default(0.35) double wallpaperScrim,
  }) = _AppearancePreferences;

  /// Restores appearance preferences from JSON.
  factory AppearancePreferences.fromJson(Map<String, Object?> json) => _$AppearancePreferencesFromJson(json);
}
