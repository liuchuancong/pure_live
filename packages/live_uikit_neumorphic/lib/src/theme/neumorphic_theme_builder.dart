import 'package:flutter/widgets.dart' show BorderRadius, Radius;
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/styling.dart';

/// Maps the core's resolved `DesignToken` into `NeuThemeData` (§8.1): the base
/// surface and accent colour come straight from the token, the panel corner
/// radius follows the token's `lg` radius, and the shadow tint follows the
/// token's shadow base — so a soft-embossed theme still tracks the app's
/// brightness, accent, radius and surface and is rebuilt when they change
/// (§8.3). Light source / depth / curvature are the style's fixed geometry, not
/// token-driven, so they stay at the library defaults (§8.1 "map only supported").
abstract final class NeumorphicThemeBuilder {
  /// Builds the Neumorphic theme data for [token].
  static neu.NeuThemeData build(DesignToken token) => neu.NeuThemeData(
    baseColor: token.color.bgLayout,
    accentColor: token.color.primary,
    borderRadius: BorderRadius.all(Radius.circular(token.scale.radii.lg)),
    customShadowColor: token.color.shadowBase,
  );
}
