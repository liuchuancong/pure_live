import 'package:live_uikit/src/styling/design_token.dart';
import 'package:live_uikit/src/styling/seed_token.dart';

/// A theme algorithm turns the seed (and, for post-algorithms, the token
/// produced so far) into the next stage — the exact shape of Ant's
/// `DerivativeFunc<SeedToken, MapToken>`, so several can be composed
/// (`[dark, compact]`).
typedef ThemeAlgorithm = DesignToken Function(SeedToken seed, DesignToken? previous);

/// The theme algorithms live_uikit ships, mirroring Ant Design's built-ins.
abstract final class ThemeAlgorithms {
  /// The default (light) algorithm: derive the whole token set from the seed.
  static DesignToken defaultAlgorithm(SeedToken seed, DesignToken? previous) => DesignToken.derive(seed, dark: false);

  /// The dark algorithm: the same derivation with the dark neutral and palette
  /// ordering (backgrounds lighten, text base flips to white).
  static DesignToken darkAlgorithm(SeedToken seed, DesignToken? previous) => DesignToken.derive(seed, dark: true);

  /// The compact algorithm: a *post* pass, as in Ant — take the previous token
  /// (or default) and re-derive it with a shorter control height and a tighter
  /// size step, keeping its light/dark variant.
  static DesignToken compactAlgorithm(SeedToken seed, DesignToken? previous) {
    final base = previous ?? defaultAlgorithm(seed, null);
    final tightened = base.seed.copyWith(controlHeight: base.seed.controlHeight - 4, sizeStep: base.seed.sizeStep - 2);
    return DesignToken.derive(tightened, dark: base.isDark);
  }

  /// Resolves [seed] through [algorithms] in order, threading the intermediate
  /// token so a post-algorithm like compact can see the variant it tightens.
  static DesignToken resolve(SeedToken seed, List<ThemeAlgorithm> algorithms) {
    if (algorithms.isEmpty) {
      return defaultAlgorithm(seed, null);
    }
    DesignToken? acc;
    for (final algorithm in algorithms) {
      acc = algorithm(seed, acc);
    }
    return acc!;
  }
}
