import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart' show Brightness;
import 'package:live_uikit/styling.dart';

/// Maps the core's resolved `DesignToken` into `FluentThemeData` (§8.1) — the
/// theme-*data* half of the Fluent mapping, kept separate from installing it
/// into the widget tree (`FluentThemeScope`). Only what fluent_ui can take from
/// the token directly is mapped here: brightness and the token's font family
/// (`accentColor` is a fixed `AccentColor` palette, not a free colour).
abstract final class FluentThemeBuilder {
  /// Builds the Fluent theme data for [token].
  static fluent.FluentThemeData build(DesignToken token) => fluent.FluentThemeData(
    brightness: token.isDark ? Brightness.dark : Brightness.light,
    fontFamily: token.type.fontFamily,
  );
}
