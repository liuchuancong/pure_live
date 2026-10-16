import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_neumorphic/src/theme/neumorphic_theme_scope.dart';

/// The adapter's theme entry point (§8): wraps `child` in the Neumorphic scope
/// built from the resolved `DesignToken`.
class NeumorphicThemeMapper {
  /// A theme mapper.
  const new();

  /// Wraps `child` in the Neumorphic theme derived from [token].
  Widget wrap(BuildContext context, DesignToken token, Widget child) =>
      NeumorphicThemeScope(token: token, child: child);
}
