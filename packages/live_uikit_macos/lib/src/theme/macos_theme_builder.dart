import 'package:flutter/widgets.dart' show Brightness;
import 'package:live_uikit/live_uikit.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Maps the core's resolved `DesignToken` into `MacosThemeData` (§8.1):
/// brightness and the primary/accent colour follow the token, and the window
/// canvas colour follows the resolved surface — so a brightness, accent or
/// surface change re-skins the macOS subtree and the data is rebuilt when they
/// change (§8.3). `accentColor` is macOS's own fixed `AccentColor` swatch rather
/// than a free colour, and typography is a `MacosTypography` object, so both are
/// left at their defaults rather than half-mapped (§8.1 "map only supported").
abstract final class MacosThemeBuilder {
  /// Builds the macOS theme data for [token].
  static macos.MacosThemeData build(DesignToken token) => macos.MacosThemeData(
    brightness: token.isDark ? Brightness.dark : Brightness.light,
    primaryColor: token.color.primary,
    canvasColor: token.color.surface,
  );
}
