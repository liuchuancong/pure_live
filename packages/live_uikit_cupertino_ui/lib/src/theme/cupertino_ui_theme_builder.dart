import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart' show Brightness;
import 'package:live_uikit/styling.dart';

/// Maps the core's resolved `DesignToken` into the fork's `CupertinoThemeData`
/// (§8.1): brightness and primary colour follow the token.
abstract final class CupertinoUiThemeBuilder {
  /// Builds the Cupertino UI theme data for [token].
  static cu.CupertinoThemeData build(DesignToken token) => cu.CupertinoThemeData(
    brightness: token.isDark ? Brightness.dark : Brightness.light,
    primaryColor: token.color.primary,
  );
}
