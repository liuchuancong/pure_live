/// The switchable design languages. Every value names the widget library the
/// app draws for it; the Pure widgets switch on it directly and construct that
/// library's real components — there is no adapter or spec in between.
library;


/// The switchable design languages.
enum PureDesignLanguage {
  /// Windows `fluent_ui`.
  fluent,

  /// macOS `macos_ui`.
  macos,

  /// `flutter_neumorphic_ui_kit`.
  neumorphic,

  /// `glass_morphism_plus`.
  glass,

  /// `fluttersdk_wind`.
  wind,

  /// `forui` (the shadcn-style `F*` widget library).
  forui,

  /// `material_ui` — Flutter's Material library, the same one
  /// `package:flutter/material.dart` was moved into: the Material design system,
  /// taken from the library's own widgets, theme and host.
  material,

  /// `cupertino_ui` — Flutter's Cupertino library, the same one
  /// `package:flutter/cupertino.dart` was moved into. This is the iOS language:
  /// its own widgets, its own host, its own navigation.
  cupertino,

  /// Ubuntu `yaru` — Material 3 carrying Ubuntu's token tables: the controls
  /// are the familiar Material ones, re-themed by `createYaruLightTheme` /
  /// `createYaruDarkTheme` from the app's accent, with Yaru's own widgets
  /// (`YaruIconButton`, its title bar family) where they exist.
  yaru,
}
