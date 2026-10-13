import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_wind/src/theme/wind_theme_scope.dart';

/// The adapter's theme entry point (§8): wraps `child` in the Wind scope built
/// from the resolved `DesignToken`.
class WindThemeMapper {
  /// A theme mapper.
  const new();

  /// Wraps `child` in the Wind theme derived from [token].
  Widget wrap(BuildContext context, DesignToken token, Widget child) => WindThemeScope(token: token, child: child);
}
