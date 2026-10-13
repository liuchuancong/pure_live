import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_fluent/src/theme/fluent_theme_scope.dart';

/// The adapter's theme entry point (§8): wraps `child` in the Fluent scope built
/// from the resolved `DesignToken`. Kept as the seam the adapter calls so the
/// token→data→scope mapping lives entirely under `theme/`.
class FluentThemeMapper {
  /// A theme mapper.
  const new();

  /// Wraps [child] in the Fluent theme derived from [token].
  Widget wrap(BuildContext context, DesignToken token, Widget child) => FluentThemeScope(token: token, child: child);
}
