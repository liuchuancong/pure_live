import 'package:flutter/widgets.dart' show Brightness;
import 'package:live_uikit/styling.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Maps the core's resolved `DesignToken` into `MacosThemeData` (§8.1) — the
/// theme-data half, kept apart from installing it (`MacosThemeScope`).
abstract final class MacosThemeBuilder {
  /// Builds the macOS theme data for [token].
  static macos.MacosThemeData build(DesignToken token) => macos.MacosThemeData(
    brightness: token.isDark ? Brightness.dark : Brightness.light,
    primaryColor: token.color.primary,
  );
}
