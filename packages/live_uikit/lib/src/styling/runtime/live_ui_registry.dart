import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/diagnostics.dart';
import 'package:live_uikit/src/styling/shared/shared_language_adapter.dart';

/// The registered adapters by language, with a shared fallback so an
/// unregistered language still renders coherently.
final class LanguageRegistry {
  /// A registry of [adapters]; [fallback] answers any missing language.
  const new({required this.adapters, required this.fallback});

  /// The adapters by language.
  final Map<LiveDesignLanguage, LanguageAdapter> adapters;

  /// The adapter used when a language has no dedicated one yet.
  final LanguageAdapter fallback;

  /// The adapter for [language], falling back to [fallback] when absent.
  LanguageAdapter adapterFor(LiveDesignLanguage language) => adapters[language] ?? fallback;

  /// Whether [language] has a dedicated adapter (otherwise the shared fallback
  /// renders it) — the basis for a diagnosable downgrade (§7).
  bool isRegistered(LiveDesignLanguage language) => adapters.containsKey(language);

  /// How controls for [language] will be rendered (§15.2).
  LiveImplementationKind kindFor(LiveDesignLanguage language) =>
      isRegistered(language) ? LiveImplementationKind.adapterNative : LiveImplementationKind.shared;
}

/// The default registry, which now carries **no** design language: every style
/// (Material, Cupertino, and the third-party ones) lives in its own
/// `live_uikit_*` package and is registered by the application composition root,
/// so the core ships only contracts + the shared token fallback. Any control a
/// language does not override falls back to [SharedLanguageAdapter].
const LanguageRegistry defaultLanguageRegistry = LanguageRegistry(adapters: {}, fallback: SharedLanguageAdapter());
