import 'package:flutter/material.dart' show Brightness;
import 'package:macos_ui/macos_ui.dart' as macos;

import 'package:pure_uikit/src/styling/adapters/pure_theme_adapter.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// Maps the resolved theme onto macOS's [macos.MacosThemeData]: accent,
/// brightness and the window canvas follow the token.
///
/// Mapping notes: window materials, the title bar, window buttons and the
/// window lifecycle are platform capabilities the adapter does not touch;
/// macOS's own defaults answer every token the library has no slot for.
final class MacosThemeAdapter implements PureThemeAdapter<macos.MacosThemeData> {
  /// The macOS adapter.
  const new();

  @override
  macos.MacosThemeData resolve(PureTheme theme) {
    final token = theme.token;
    return macos.MacosThemeData(
      brightness: token.isDark ? Brightness.dark : Brightness.light,
      primaryColor: token.color.primary,
      canvasColor: token.color.surface,
    );
  }
}
