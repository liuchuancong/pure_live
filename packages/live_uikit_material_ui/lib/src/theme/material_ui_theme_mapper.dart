import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_material_ui/src/theme/material_ui_theme_scope.dart';

/// The adapter's theme entry point (§8): wraps `child` in the Material UI scope
/// built from the resolved `DesignToken`.
class MaterialUiThemeMapper {
  /// A theme mapper.
  const new();

  /// Wraps `child` in the Material UI theme derived from [token].
  Widget wrap(BuildContext context, DesignToken token, Widget child) =>
      MaterialUiThemeScope(token: token, child: child);
}
