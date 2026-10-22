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

  /// `material_ui`
  material,

  /// `cupertino_ui`
  ///
  cupertino,

  ///  `yaru`
  yaru,
}
