import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_forui/src/theme/forui_theme_scope.dart';

/// The adapter's theme entry point (§8): wraps `child` in the forui scope built from
/// the resolved `DesignToken`.
class ForuiThemeMapper {
  /// A theme mapper.
  const new();

  /// Wraps `child` in the forui theme derived from [token].
  Widget wrap(BuildContext context, DesignToken token, Widget child) => ForuiThemeScope(token: token, child: child);
}
