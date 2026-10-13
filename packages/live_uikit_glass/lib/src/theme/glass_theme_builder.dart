import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/styling.dart';

/// Maps the core's resolved `DesignToken` into `GlassThemeData` (§8.1). The
/// glass panel's tint, corner radius and shadow now follow the resolved token,
/// so a brightness, accent or surface change re-skins the glass surfaces and the
/// data is rebuilt whenever the token changes (§8.3) — it is no longer a fixed
/// `const`. The frosted `blur` radius stays a constant: glassmorphism blur is a
/// transparency *effect*, driven by `UiConfig.transparency`/`reduceTransparency`
/// rather than the design token this builder receives, so mapping it here would
/// imply a token→blur link that does not exist (§8.1 "map only supported"). When
/// the environment cannot afford the blur, the `unsupportedEffect` diagnostic
/// governs the degraded solid surface (§13/§15).
abstract final class GlassThemeBuilder {
  /// Builds the Glass theme data for [token].
  static glass.GlassThemeData build(DesignToken token) => glass.GlassThemeData(
    blur: 16,
    color: token.color.bgContainer,
    borderRadius: token.scale.radii.lg,
    shadowColor: token.color.shadowBase,
  );
}
