import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_glass/src/theme/glass_theme_scope.dart';

/// The adapter's theme entry point (§8): wraps `child` in the Glass scope built
/// from the resolved `DesignToken`.
class GlassThemeMapper {
  /// A theme mapper.
  const new();

  /// Wraps `child` in the Glass theme derived from [token].
  Widget wrap(BuildContext context, DesignToken token, Widget child) => GlassThemeScope(token: token, child: child);
}
