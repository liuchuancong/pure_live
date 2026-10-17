import 'package:flutter/material.dart' show ThemeData;
import 'package:pure_uikit/src/styling/adapters/pure_theme_adapter.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:yaru/yaru.dart' as yaru;

/// Maps the resolved theme onto Yaru: the accent seeds Ubuntu's own theme
/// factories, so the palette, shapes and motion are the factories' choices.
///
/// Mapping notes: the factories return a fully-specified Material theme —
/// the font family a caller configures is applied by the Yaru host on top
/// (yaru's factories accept `fontFamily`, but their own type decisions are
/// part of the language, so the host decides), and per-token surfaces beyond
/// the accent are not Yaru's to customise.
final class YaruThemeAdapter implements PureThemeAdapter<ThemeData> {
  /// The Yaru adapter.
  const new();

  @override
  ThemeData resolve(PureTheme theme) {
    final primary = theme.token.color.primary;
    return theme.token.isDark
        ? yaru.createYaruDarkTheme(primaryColor: primary)
        : yaru.createYaruLightTheme(primaryColor: primary);
  }
}
