import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart' show BuildContext, IconData, Theme, Widget;
import 'package:pure_live/app/icons/app_icon_defaults.dart';
import 'package:pure_live/app/icons/app_icon_keys.dart';
import 'package:pure_live/app/icons/app_icon_mappings.dart';
import 'package:pure_live/app/icons/app_icon_overrides.dart';
import 'package:pure_uikit/pure_uikit.dart'
    show PureIcon, PureIconFallback, PureIconGlyph, PureIconKey, PureIconRegistry, PureIconState, PureTheme;

/// The app's icon installation and the facade business code calls.
///
/// Pages name an [AppIconKey]; nothing below this file imports an icon
/// font. `main()` calls [install] once before the first frame; every uikit
/// chrome then reads the registry through the theme.
abstract final class AppIcons {
  /// Registers the four tiers and publishes the registry (idempotent: the
  /// second call is a no-op, so tests and hot restarts never trip the
  /// kit's one-shot assert).
  static void install() {
    if (PureIconRegistry.hasInstalled) return;
    final registry = PureIconRegistry(
      onDiagnostic: (resolution) {
        if (kDebugMode) debugPrint(resolution.diagnostic);
      },
    )..setGlobal(appIconDefaults);
    for (final entry in appIconLanguageMappings.entries) {
      registry.registerLanguage(entry.key, entry.value);
    }
    for (final entry in appIconOverrides.entries) {
      registry.registerPlatformOverride(entry.key.$1, entry.key.$2, entry.value);
    }
    PureIconRegistry.install(registry);
  }

  /// The themed icon widget for [key]; size, colour and state follow the
  /// skin exactly as the kit's own draw rules dictate.
  static Widget of(BuildContext context, AppIconKey key, {PureIconState state = PureIconState.normal, double? size}) =>
      PureIcon(key, state: state, size: size);

  /// The resolved [IconData] for widget APIs that still take a plain glyph
  /// (the uikit destination tables). A custom SVG/brand source reports the
  /// kit's conspicuous fallback glyph here — draw [of] for those keys.
  static IconData glyph(BuildContext context, PureIconKey key) {
    final resolution = PureIconRegistry.current.resolve(
      key,
      platform: Theme.of(context).platform,
      language: PureTheme.of(context).config.language,
    );
    return switch (resolution.source) {
      PureIconGlyph(:final glyph) => glyph,
      _ => PureIconFallback.glyph,
    };
  }
}
