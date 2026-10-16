import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart' show Brightness;
import 'package:live_uikit/live_uikit.dart';

/// Maps the core's resolved `DesignToken` into `FluentThemeData` (§8.1) — the
/// theme-*data* half of the Fluent mapping, kept separate from installing it
/// into the widget tree (`FluentThemeScope`). Brightness, the accent and a
/// configured global font family all follow the token.
///
/// `accentColor` is a `AccentColor.swatch` built from the one accent the token
/// names: Fluent's shade getters (`dark`, `darker`, `light`, …) fall back to
/// `normal` when a shade is absent, so supplying only `normal` is the honest
/// mapping — inventing tonal steps the token never declared would be the
/// half-mapped colour generation §8.1 rules out.
abstract final class FluentThemeBuilder {
  /// Builds the Fluent theme data for [token].
  static fluent.FluentThemeData build(DesignToken token) => fluent.FluentThemeData(
    brightness: token.isDark ? Brightness.dark : Brightness.light,
    accentColor: fluent.AccentColor.swatch({'normal': token.color.primary}),
    fontFamily: token.type.fontFamily,
  );
}
