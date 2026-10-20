import 'package:flutter/material.dart' show ThemeData;
import 'package:pure_uikit/src/styling/adapters/pure_theme_adapter.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:yaru/yaru.dart' as yaru;

/// Maps the resolved theme onto Yaru: the accent seeds Ubuntu's own theme
/// factories, so the palette, shapes and motion are the factories' choices.
///
/// Mapping notes: the factories return a fully-specified Material theme, which
/// is why the family cannot be passed to them as an argument and still reach a
/// widget — it is laid over the text theme they produced, in the same shape the Material
/// adapter uses. Ubuntu's own sizes, weights and heights stay as
/// the factory resolved them; per-token surfaces beyond the accent are not
/// Yaru's to customise.
final class YaruThemeAdapter implements PureThemeAdapter<ThemeData> {
  /// The Yaru adapter.
  const new();

  @override
  ThemeData resolve(PureTheme theme) {
    final primary = theme.token.color.primary;
    final data = theme.token.isDark
        ? yaru.createYaruDarkTheme(primaryColor: primary)
        : yaru.createYaruLightTheme(primaryColor: primary);
    final family = theme.token.type.fontFamily;
    if (family == null) {
      return data;
    }
    return data.copyWith(textTheme: data.textTheme.apply(fontFamily: family));
  }
}
