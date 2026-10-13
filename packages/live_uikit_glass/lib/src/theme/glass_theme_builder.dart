import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/styling.dart';

/// Maps the core's resolved `DesignToken` into `GlassThemeData` (§8.1). Glass
/// exposes a fixed frosted surface today, so the data does not vary with the
/// token; the seam is kept so a token-driven blur can be added without touching
/// callers.
abstract final class GlassThemeBuilder {
  /// Builds the Glass theme data for [token].
  static glass.GlassThemeData build(DesignToken token) => const glass.GlassThemeData(blur: 16);
}
