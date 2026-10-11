import 'package:flutter/foundation.dart';

import 'package:live_uikit/src/components/contracts/live_design_language_components.dart';
import 'package:live_uikit/src/core/design_language.dart';
import 'package:live_uikit/src/theme/live_theme_parts.dart';

/// Builds one design language's theme parts.
///
/// A language implements this once — `(context) => context.base.withParts(…)`
/// for a language that refines the base, a full palette for one that does
/// not — and the resolver calls it. Keeping the builder separate from the
/// component implementation lets a language ship them in either order while
/// the other side falls back.
typedef LiveThemeBuilder = LiveThemeParts Function(LiveDesignLanguageContext context);

/// One design language: how it themes and how it renders components.
@immutable
final class LiveDesignLanguageAdapter {
  /// An adapter of a theme builder and a component implementation.
  const new({required this.theme, required this.components});

  /// Builds the language's theme parts.
  final LiveThemeBuilder theme;

  /// Renders the component contract.
  final LiveDesignLanguageComponents components;
}

/// The design languages the app can render, and the fallback for the ones
/// it cannot.
///
/// Registration is explicit and total: the registry starts with the
/// fallback language (Material) and every additional language is added by
/// the composition root. A language that was stored in the user's settings
/// but is not registered — a document from a newer build, a platform build
/// compiled without it — resolves to the fallback *and says so* in
/// `LiveTheme.fallbacks`, because silently rendering a different design
/// language than the one the user chose is the kind of bug nobody can
/// report.
@immutable
final class LiveComponentRegistry {
  /// A registry of [fallback] plus any additional [languages].
  const new({required this.fallback, this.languages = const {}});

  /// The language every unregistered request resolves to.
  final LiveDesignLanguage fallback;

  /// The registered languages, by id.
  final Map<LiveDesignLanguage, LiveDesignLanguageAdapter> languages;

  /// Whether [language] is registered.
  bool isRegistered(LiveDesignLanguage language) => languages.containsKey(language);

  /// The registered languages, including the fallback.
  Set<LiveDesignLanguage> get registered => {fallback, ...languages.keys};

  /// The adapter of [language], falling back when it is not registered.
  LiveDesignLanguageAdapter adapterFor(LiveDesignLanguage language) =>
      languages[language] ??
      languages[fallback] ??
      (throw StateError('the fallback language ${fallback.id} is not registered'));

  /// The same registry with [language] registered (replacing an earlier
  /// registration of it), for the composition root.
  LiveComponentRegistry withLanguage(LiveDesignLanguage language, LiveDesignLanguageAdapter adapter) =>
      LiveComponentRegistry(fallback: fallback, languages: {...languages, language: adapter});

  /// The same registry with [adapters] registered.
  LiveComponentRegistry withLanguages(Map<LiveDesignLanguage, LiveDesignLanguageAdapter> adapters) =>
      LiveComponentRegistry(fallback: fallback, languages: {...languages, ...adapters});
}
