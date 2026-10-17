import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart' show Brightness;

import 'package:pure_uikit/src/styling/adapters/pure_theme_adapter.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// Maps the resolved theme onto Cupertino's [cupertino.CupertinoThemeData]:
/// brightness, the accent and its contrasting colour, and the page surface.
///
/// Mapping notes: Cupertino's theme capability is narrower than Material's —
/// there is no card colour, no radius scale and no density slot — so those
/// tokens answer through the Pure widgets themselves, not through this
/// adapter. Nothing is mapped that [cupertino.CupertinoThemeData] cannot
/// carry.
final class CupertinoThemeAdapter implements PureThemeAdapter<cupertino.CupertinoThemeData> {
  /// The Cupertino adapter.
  const new();

  @override
  cupertino.CupertinoThemeData resolve(PureTheme theme) {
    final token = theme.token;
    return cupertino.CupertinoThemeData(
      brightness: token.isDark ? Brightness.dark : Brightness.light,
      primaryColor: token.color.primary,
      primaryContrastingColor: token.color.onPrimary,
      scaffoldBackgroundColor: token.color.surface,
    );
  }
}
