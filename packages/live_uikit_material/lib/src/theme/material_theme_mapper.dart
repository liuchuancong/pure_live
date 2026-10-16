import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_material/src/theme/material_theme_scope.dart';

/// The adapter's theme entry point (§8): wraps `child` in the Material UI scope
/// built from the resolved `DesignToken`.
class MaterialThemeMapper {
  /// A theme mapper.
  const new();

  /// Wraps `child` in the Material UI theme derived from [token].
  Widget wrap(BuildContext context, DesignToken token, Widget child) => MaterialThemeScope(token: token, child: child);
}
