/// pure_uikit's theme module: the bridges that turn a resolved `PureTheme`
/// into the theme data each host surface speaks. Today that is one bridge,
/// Fluent — the one full component library the v4 architecture keeps — which
/// answers both for fluent_ui (`FluentThemeData`, the `FluentApp` host) and
/// for the Material surfaces that survive outside it (`ThemeData`).
///
/// A bridge never asks the config which design language is active: a
/// non-fluent value falls back to Fluent, the decision the app's host
/// router already made.
library;

export 'fluent_theme.dart';
