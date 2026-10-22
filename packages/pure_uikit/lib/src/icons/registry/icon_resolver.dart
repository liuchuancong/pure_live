import 'package:flutter/widgets.dart' show TargetPlatform;
import 'package:pure_uikit/src/icons/api/pure_icon_key.dart';
import 'package:pure_uikit/src/icons/registry/icon_fallback.dart';
import 'package:pure_uikit/src/icons/registry/icon_mapping.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';

/// Which rule answered a key — the four tiers, highest priority first.
enum PureIconTier {
  /// A platform + design-language override for this single key.
  platformOverride,

  /// The current design language's default mapping.
  language,

  /// The app-wide mapping registered beside the language tables.
  global,

  /// Nothing answered: the built-in conspicuous glyph.
  fallback,
}

/// One resolved draw: the source plus how it was found.
class PureIconResolution {
  /// Builds a resolution.
  const new({required this.source, required this.tier, required this.key});

  /// The resource to draw.
  final PureIconSource source;

  /// The tier that answered.
  final PureIconTier tier;

  /// The key that was asked for (diagnostics).
  final PureIconKey key;

  /// A developer-facing note explaining a non-ideal answer; null when the
  /// draw followed the registration exactly.
  String? get diagnostic => tier == PureIconTier.fallback
      ? 'PureIcon: nothing registers "${key.id}" for its platform+language; drawing the fallback glyph. '
            'Check the app icon registry (language default, global mapping, overrides).'
      : null;
}

/// The four-tier lookup, kept out of the public registry's body.
class PureIconResolver {
  /// Builds the resolver over the registry's live tables.
  const new(this._overrides, this._languages, this._global);

  final Map<(TargetPlatform, PureDesignLanguage), PureIconMapping> _overrides;
  final Map<PureDesignLanguage, PureIconMapping> _languages;
  final PureIconMapping? _global;

  /// Ask the tiers in order: platform+language override, language default,
  /// global mapping, built-in fallback. Platform and language are separate
  /// dimensions — a Windows build may legitimately draw the Material set —
  /// so both are passed in rather than derived from the OS alone.
  PureIconResolution resolve(
    PureIconKey key, {
    required TargetPlatform platform,
    required PureDesignLanguage language,
  }) {
    final override = _overrides[(platform, language)]?.lookup(key);
    if (override != null) return PureIconResolution(source: override, tier: PureIconTier.platformOverride, key: key);
    final byLanguage = _languages[language]?.lookup(key);
    if (byLanguage != null) return PureIconResolution(source: byLanguage, tier: PureIconTier.language, key: key);
    final byGlobal = _global?.lookup(key);
    if (byGlobal != null) return PureIconResolution(source: byGlobal, tier: PureIconTier.global, key: key);
    return PureIconResolution(source: PureIconFallback.source, tier: PureIconTier.fallback, key: key);
  }
}
