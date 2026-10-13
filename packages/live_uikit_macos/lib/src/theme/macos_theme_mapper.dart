import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_macos/src/theme/macos_theme_scope.dart';

/// The adapter's theme entry point (§8): wraps `child` in the macOS scope built
/// from the resolved `DesignToken`; mapping lives under `theme/`.
class MacosThemeMapper {
  /// A theme mapper.
  const new();

  /// Wraps `child` in the macOS theme derived from [token].
  Widget wrap(BuildContext context, DesignToken token, Widget child) => MacosThemeScope(token: token, child: child);
}
