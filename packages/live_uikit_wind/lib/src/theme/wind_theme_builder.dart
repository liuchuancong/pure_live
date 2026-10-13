import 'package:flutter/widgets.dart' show Brightness;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/styling.dart';

/// Maps the core's resolved `DesignToken` into `WindThemeData` (§8.1) — the
/// theme-data half, kept apart from installing it (`WindThemeScope`).
abstract final class WindThemeBuilder {
  /// Builds the Wind theme data for [token].
  static wind.WindThemeData build(DesignToken token) =>
      wind.WindThemeData(brightness: token.isDark ? Brightness.dark : Brightness.light);
}
