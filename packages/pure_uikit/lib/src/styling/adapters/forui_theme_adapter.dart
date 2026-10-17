import 'package:forui/forui.dart' as forui;

import 'package:pure_uikit/src/styling/adapters/pure_theme_adapter.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// Maps the resolved theme onto forui. What the token can decide is the
/// palette *variant*: `isDark` selects forui's neutral dark theme, everything
/// else stays on the library's own defaults — forui exposes no way for a host
/// to recolor it (`FThemeData` has a private constructor, and its supported
/// path for a custom palette is generating a theme file).
///
/// Mapping notes: accent, font family, radius, spacing and transparency are
/// **not supported** by this adapter — they are recorded here rather than
/// faked, and forui's own look is the language.
final class ForuiThemeAdapter implements PureThemeAdapter<forui.FThemeData> {
  /// The forui adapter.
  const new();

  @override
  forui.FThemeData resolve(PureTheme theme) =>
      theme.token.isDark ? forui.FTheme.neutral.dark.touch : forui.FTheme.neutral.light.touch;
}
