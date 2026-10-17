import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;

import 'package:pure_uikit/src/styling/adapters/pure_theme_adapter.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// Maps the resolved theme onto glass: the panel's tint, corner radius and
/// shadow follow the resolved token, so a brightness, accent or surface
/// change re-skins the glass surfaces.
///
/// Mapping notes: the frosted `blur` radius stays a constant — glassmorphism
/// blur is a transparency *effect*, driven by `UiConfig.transparency` rather
/// than the design token, so mapping it here would imply a token→blur link
/// that does not exist.
final class GlassThemeAdapter implements PureThemeAdapter<glass.GlassThemeData> {
  /// The glass adapter.
  const new();

  @override
  glass.GlassThemeData resolve(PureTheme theme) {
    final token = theme.token;
    return glass.GlassThemeData(
      blur: 16,
      color: token.color.bgContainer,
      borderRadius: token.scale.radii.lg,
      shadowColor: token.color.shadowBase,
    );
  }
}
