import 'package:live_uikit/src/core/design_language.dart';
import 'package:live_uikit/src/core/ui_component_registry.dart';
import 'package:live_uikit/src/design_languages/material/material_components.dart';
import 'package:live_uikit/src/theme/live_theme_parts.dart';

/// The Material design language.
///
/// Material is the base every other language refines and the fallback every
/// unregistered request resolves to, so this adapter is the smallest
/// possible: it publishes the accent-derived parts unchanged and the
/// Material component set. There is deliberately no separate "base" theme
/// hidden behind it — the parts the other five languages start from are
/// these, and they are Material's colour science, which is why Material
/// needs no refinement of its own.
abstract final class MaterialLanguage {
  /// The language's component implementation.
  static const MaterialComponents components = MaterialComponents();

  /// The language's adapter, for the registry.
  static const LiveDesignLanguageAdapter adapter = LiveDesignLanguageAdapter(
    theme: _buildTheme,
    components: components,
  );

  /// The registry of Material alone, the starting point of the app.
  static const LiveComponentRegistry registry = LiveComponentRegistry(
    fallback: LiveDesignLanguage.material,
    languages: {LiveDesignLanguage.material: adapter},
  );

  static LiveThemeParts _buildTheme(LiveDesignLanguageContext context) => context.base;
}
