import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';

/// Maps the core's resolved `DesignToken` into forui's `FThemeData` (§8.1).
///
/// What the token can decide here is the palette *variant*: `isDark` selects forui's
/// neutral dark theme, everything else stays on the library's own defaults. That is not
/// timidity — forui exposes no way for a host to recolor it. `FThemeData` has a private
/// constructor, and its `copyWith` carries `colors`, `typography` and `style` through
/// unchanged (only per-widget style deltas are parameters), so the accent, the neutral
/// roles, the corner radii and the font family have no field an adapter can write to.
/// forui's supported path for a custom palette is generating a theme file
/// (`dart run forui theme create`), which rebuilds every widget style from the palette
/// through its `inherit(...)` constructor — a per-widget translation this adapter
/// promotes into one control at a time, never by pretending (§8.1 "map only supported",
/// §15).
abstract final class ForuiThemeBuilder {
  /// Builds the forui theme data for [token].
  static forui.FThemeData build(DesignToken token) =>
      token.isDark ? forui.FTheme.neutral.dark.touch : forui.FTheme.neutral.light.touch;
}
