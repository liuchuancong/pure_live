import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_cupertino/src/theme/cupertino_theme_scope.dart';

/// The adapter's theme entry point (§8): wraps `child` in the Cupertino UI scope
/// built from the resolved `DesignToken`.
class CupertinoThemeMapper {
  /// A theme mapper.
  const new();

  /// Wraps `child` in the Cupertino UI theme derived from [token].
  Widget wrap(BuildContext context, DesignToken token, Widget child) => CupertinoThemeScope(token: token, child: child);
}
