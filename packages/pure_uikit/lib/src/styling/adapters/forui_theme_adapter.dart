import 'package:forui/forui.dart' as forui;

import 'package:pure_uikit/src/styling/adapters/pure_theme_adapter.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// Maps the resolved theme onto forui. What the token can decide is the palette
/// *variant* — `isDark` selects forui's neutral dark theme — and the chosen font
/// family, which forui carries on its typefaces rather than on the text styles.
///
/// Mapping notes: accent, radius, spacing and transparency are **not supported**
/// by this adapter — they are recorded here rather than faked, and forui's own
/// look is the language. `FThemeData.copyWith` deliberately refuses a
/// `typography` argument; the library's documented way to change it is to build
/// the theme data again from the preset's own pieces, which is also what lets
/// the change propagate into every widget style rather than sit beside them.
final class ForuiThemeAdapter implements PureThemeAdapter<forui.FThemeData> {
  /// The forui adapter.
  const new();

  @override
  forui.FThemeData resolve(PureTheme theme) {
    final token = theme.token;
    final base = token.isDark ? forui.FTheme.neutral.dark.touch : forui.FTheme.neutral.light.touch;
    final family = token.type.fontFamily;
    if (family == null) {
      return base;
    }
    // The preset is the touch variant on both branches, so rebuilding it with
    // `touch: true` reproduces it with one field changed.
    final typeface = forui.FTypeface.inherit(colors: base.colors, touch: true, fontFamily: family);
    return forui.FThemeData(
      colors: base.colors,
      touch: true,
      typography: forui.FTypography(display: typeface, body: typeface),
    );
  }
}
