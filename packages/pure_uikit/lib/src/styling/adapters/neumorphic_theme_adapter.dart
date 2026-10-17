import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;

import 'package:pure_uikit/src/styling/adapters/pure_theme_adapter.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// Maps the resolved theme onto neumorphic: the base surface and accent
/// colour come straight from the token, the panel corner radius follows the
/// token's `lg` radius and the shadow tint follows the token's shadow base.
///
/// Mapping notes: the light source, depth and curvature are the style's fixed
/// geometry — the essence of the language — not token-driven, so they stay at
/// the library defaults.
final class NeumorphicThemeAdapter implements PureThemeAdapter<neu.NeuThemeData> {
  /// The neumorphic adapter.
  const new();

  @override
  neu.NeuThemeData resolve(PureTheme theme) {
    final token = theme.token;
    return neu.NeuThemeData(
      baseColor: token.color.bgLayout,
      accentColor: token.color.primary,
      borderRadius: BorderRadius.all(Radius.circular(token.scale.radii.lg)),
      customShadowColor: token.color.shadowBase,
    );
  }
}
