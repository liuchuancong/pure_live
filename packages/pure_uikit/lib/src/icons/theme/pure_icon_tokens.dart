import 'package:flutter/widgets.dart' show BuildContext, Color;
import 'package:pure_uikit/src/icons/api/pure_icon_style.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart' show PureTheme;

/// The design-language defaults for icon draws, and the state rules that
/// every language shares.
///
/// Size is the language's business (Fluent chrome is denser than
/// Material); colour is the theme's (tokens), and the state fades are
/// shared. Nothing here knows which icon library answered the glyph.
abstract final class PureIconTokens {
  /// The resting size one design language draws icons at.
  static double defaultSize(PureDesignLanguage language) => switch (language) {
    PureDesignLanguage.material => 24,
    PureDesignLanguage.cupertino => 20,
    PureDesignLanguage.yaru => 18,
    PureDesignLanguage.fluent => 16,
    PureDesignLanguage.macos => 15,
    PureDesignLanguage.neumorphic ||
    PureDesignLanguage.glass ||
    PureDesignLanguage.wind ||
    PureDesignLanguage.forui => 20,
  };

  /// The theme colour for [role]; null for [PureIconColorRole.preserve],
  /// which means "do not tint the artwork".
  static Color? colorFor(BuildContext context, PureIconColorRole role) {
    if (role == PureIconColorRole.preserve) return null;
    final colors = PureTheme.of(context).colors;
    return switch (role) {
      PureIconColorRole.foreground => colors.text,
      PureIconColorRole.accent => colors.primary,
      PureIconColorRole.tertiary => colors.textTertiary,
      PureIconColorRole.preserve => null,
    };
  }

  /// The opacity the interaction state imposes (disabled is the shared
  /// dim; hover and focus change colour, not alpha).
  static double opacityFor(PureIconState state) => state == PureIconState.disabled ? 0.38 : 1;
}
