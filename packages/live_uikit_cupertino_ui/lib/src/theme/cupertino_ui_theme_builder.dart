import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart' show Brightness;
import 'package:live_uikit/styling.dart';

/// Maps the core's resolved `DesignToken` into the fork's `CupertinoThemeData`
/// (§8.1): brightness and the primary/accent colour follow the token, and the
/// page background and the colour drawn *on* the brand fill follow the resolved
/// surfaces — so a brightness, accent or surface change re-skins the Cupertino UI
/// subtree (§8.3). Cupertino's font family lives on `CupertinoTextThemeData`
/// rather than the data root, so it is not mapped here (§8.1).
abstract final class CupertinoUiThemeBuilder {
  /// Builds the Cupertino UI theme data for [token].
  static cu.CupertinoThemeData build(DesignToken token) => cu.CupertinoThemeData(
    brightness: token.isDark ? Brightness.dark : Brightness.light,
    primaryColor: token.color.primary,
    primaryContrastingColor: token.color.onPrimary,
    scaffoldBackgroundColor: token.color.surface,
  );
}
